"""Fast checks that keep the browser test catalogue meaningful."""

from automation.config.config import Config
from automation.models.test_result import TestCaseResult as CaseResult
from automation.tests import SUITES
from automation.tests import test_web_acceptance
from automation.load.runner import _calculate_percentiles
from automation.vulnerability.runner import _SecMockClient
from scripts.evaluate_gate import (
    parse_flutter_analyze,
    parse_flutter_test,
    required_suite_gaps,
)


REQUIRED_SPEC_FIELDS = {
    "id",
    "module",
    "name",
    "priority",
    "preconditions",
    "steps",
    "expected",
    "check",
}


def test_browser_case_ids_are_unique_and_specs_are_complete():
    specs = test_web_acceptance._case_specs()
    ids = [spec["id"] for spec in specs]

    assert len(ids) == len(set(ids))
    assert all(spec.keys() >= REQUIRED_SPEC_FIELDS for spec in specs)
    assert all(spec["name"].strip() for spec in specs)
    assert all(callable(spec["check"]) for spec in specs)


def test_runner_registry_contains_only_curated_selenium_cases():
    assert [name for name, _ in SUITES] == ["Web acceptance"]


def test_test_result_does_not_claim_success_before_execution():
    result = CaseResult(
        test_id="QA-CONTROL-001",
        module="QA controls",
        test_name="Unexecuted cases remain unexecuted",
        priority="Low",
        preconditions="None",
        test_steps=[],
        expected_result="The initial status is Not Run.",
    )

    assert result.status == "Not Run"


def test_local_mode_rejects_a_production_target(monkeypatch):
    monkeypatch.setattr(Config, "TEST_ENV", "local")
    monkeypatch.setattr(Config, "BASE_URL", "https://example.com/")

    try:
        Config.validate_url()
    except ValueError as error:
        assert "loopback" in str(error)
    else:
        raise AssertionError("Local mode accepted a public URL.")


def test_production_mode_rejects_a_local_target(monkeypatch):
    monkeypatch.setattr(Config, "TEST_ENV", "production")
    monkeypatch.setattr(Config, "BASE_URL", "http://127.0.0.1:8081/")

    try:
        Config.validate_url()
    except ValueError as error:
        assert "public HTTPS" in str(error)
    else:
        raise AssertionError("Production mode accepted a loopback URL.")


def test_case_runner_does_not_count_none_as_a_pass(monkeypatch):
    monkeypatch.setattr(test_web_acceptance, "_open_app", lambda _driver: None)
    monkeypatch.setattr(
        test_web_acceptance,
        "_case_specs",
        lambda: [
            {
                "id": "QA-CONTROL-002",
                "module": "QA controls",
                "name": "A missing assertion result fails",
                "priority": "Low",
                "preconditions": "None",
                "steps": [],
                "expected": "The result must be the boolean True.",
                "check": lambda _driver: None,
            }
        ],
    )

    result = test_web_acceptance.run_tests(object())[0]

    assert result.status == "Failed"
    assert result.actual_result == "Expected behavior was not observed."


def test_case_runner_accepts_only_an_explicit_true_result(monkeypatch):
    monkeypatch.setattr(test_web_acceptance, "_open_app", lambda _driver: None)
    monkeypatch.setattr(
        test_web_acceptance,
        "_case_specs",
        lambda: [
            {
                "id": "QA-CONTROL-003",
                "module": "QA controls",
                "name": "An asserted result can pass",
                "priority": "Low",
                "preconditions": "None",
                "steps": [],
                "expected": "The check returns True.",
                "check": lambda _driver: True,
            }
        ],
    )

    result = test_web_acceptance.run_tests(object())[0]

    assert result.status == "Passed"


def test_load_percentiles_use_nearest_rank_for_100_values():
    assert _calculate_percentiles(list(range(1, 101))) == (50, 90, 95, 99, 100)


def test_load_percentiles_are_zero_when_no_requests_ran():
    assert _calculate_percentiles([]) == (0.0, 0.0, 0.0, 0.0, 0.0)


def test_security_mock_applies_owner_filter_before_returning_sessions():
    client = _SecMockClient(session_owner="user-a")
    victim_sessions = (
        client.table("focus_sessions")
        .select("id")
        .eq("user_id", "user-b")
        .in_("id", ["victim-session"])
        .execute()
        .data
    )
    owned_sessions = (
        client.table("focus_sessions")
        .select("id")
        .eq("user_id", "user-a")
        .in_("id", ["owned-session"])
        .execute()
        .data
    )

    assert victim_sessions == []
    assert owned_sessions == [{"id": "owned-session"}]


def test_ci_gate_rejects_missing_or_empty_required_suite_results():
    required_names = [
        "Backend (Pytest)",
        "QA Catalogue Controls",
        "Flutter Tests (Mobile/Web)",
        "Browser Extension Tests",
        "Selenium Acceptance",
        "Load Smoke",
        "Vulnerability Checks",
    ]
    suites = [
        {"name": name, "total": 0 if name == "Load Smoke" else 1}
        for name in required_names[:-1]
    ]

    missing, empty = required_suite_gaps(suites)

    assert missing == ["Vulnerability Checks"]
    assert empty == ["Load Smoke"]


def test_flutter_parser_does_not_infer_success_from_partial_progress(monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)
    results = tmp_path / "test-results"
    results.mkdir()
    (results / "flutter-test.log").write_text("00:01 +91: Last test name\n", encoding="utf-8")

    assert parse_flutter_test() is None


def test_flutter_parser_counts_skipped_cases(monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)
    results = tmp_path / "test-results"
    results.mkdir()
    (results / "flutter-test.log").write_text(
        "00:01 +90 ~1: All tests passed!\n", encoding="utf-8"
    )

    assert parse_flutter_test() == {
        "name": "Flutter Tests (Mobile/Web)",
        "total": 91,
        "passed": 90,
        "failed": 0,
        "skipped": 1,
    }


def test_ci_summary_distinguishes_flutter_info_from_warnings(monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)
    results = tmp_path / "test-results"
    results.mkdir()
    (results / "flutter-analyze.log").write_text(
        "info - Suggested style cleanup\n1 issue found.\n", encoding="utf-8"
    )

    analysis = parse_flutter_analyze()

    assert analysis == {
        "issues": 1,
        "infos": 1,
        "warnings_errors": 0,
        "status": "clean",
    }
