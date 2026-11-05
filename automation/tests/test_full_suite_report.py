"""
Tests for the FocusEcho Combined Full-Suite Excel Report Generator.
Validates:
  - Ingestion of JUnit XML, Flutter JSON/log, extension JSON/log, and load/vulnerability results.
  - Correct handling of mixed statuses (Passed, Failed, Skipped, Blocked, Not Run).
  - Resilient fallback when suite outputs are missing (graceful 'Blocked' reporting, no crashes).
  - Validation against CI gate totals (detection and flagging of discrepancies).
  - Workbook structure, sheet names, headers, styles, and summary totals using openpyxl.
"""

from __future__ import annotations

import json
from pathlib import Path
import xml.etree.ElementTree as ET

import openpyxl
import pytest

from automation.reports.full_suite_excel_report import (
    SuiteCaseEntry,
    build,
    collect_all_cases,
    parse_extension_cases,
    parse_flutter_cases,
    parse_json_or_log_suite,
    parse_junit_cases,
    parse_selenium_cases,
    validate_against_ci_gate,
)


@pytest.fixture
def temp_results_env(tmp_path):
    """Fixture providing a temporary results directory structure."""
    results_dir = tmp_path / "test-results"
    results_dir.mkdir(parents=True)
    excel_dir = tmp_path / "Test Results" / "Excel"
    excel_dir.mkdir(parents=True)
    json_dir = tmp_path / "Test Results" / "JSON"
    json_dir.mkdir(parents=True)
    return {
        "root": tmp_path,
        "results_dir": results_dir,
        "excel_dir": excel_dir,
        "json_dir": json_dir,
    }


def test_parse_junit_cases_mixed_statuses(tmp_path):
    xml_file = tmp_path / "test-junit.xml"
    content = """<?xml version="1.0" encoding="utf-8"?>
    <testsuites>
      <testsuite name="pytest" tests="3" errors="0" failures="1" skipped="1">
        <testcase classname="pkg.test_a" name="test_pass" time="0.010" />
        <testcase classname="pkg.test_b" name="test_fail" time="0.025">
          <failure message="AssertionError">Expected 1 == 2</failure>
        </testcase>
        <testcase classname="pkg.test_c" name="test_skip" time="0.001">
          <skipped message="Platform not supported" />
        </testcase>
      </testsuite>
    </testsuites>
    """
    xml_file.write_text(content, encoding="utf-8")

    cases = parse_junit_cases(xml_file, "Backend API Tests", "BACKEND")
    assert len(cases) == 3
    assert cases[0].status == "Passed"
    assert cases[0].test_id == "BACKEND-001"
    assert "0.010s" in cases[0].details

    assert cases[1].status == "Failed"
    assert cases[1].test_id == "BACKEND-002"
    assert "AssertionError" in cases[1].details or "Expected 1 == 2" in cases[1].details

    assert cases[2].status == "Skipped"
    assert cases[2].test_id == "BACKEND-003"
    assert "Platform not supported" in cases[2].details


def test_parse_junit_cases_missing_file_reports_blocked(tmp_path):
    missing_file = tmp_path / "non_existent.xml"
    cases = parse_junit_cases(missing_file, "Backend API Tests", "BACKEND")
    assert len(cases) == 1
    assert cases[0].status == "Blocked"
    assert "not found" in cases[0].details.lower()


def test_parse_selenium_cases_mixed_and_missing(tmp_path):
    json_file = tmp_path / "execution-results.json"
    payload = {
        "test_cases": [
            {
                "test_id": "DEMO-WEB-001",
                "test_name": "Login shell check",
                "status": "Passed",
                "actual_result": "Rendered login form",
                "duration_seconds": 0.5,
            },
            {
                "test_id": "DEMO-WEB-002",
                "test_name": "Failed submission",
                "status": "Failed",
                "actual_result": "Button unclickable",
                "error_message": "ElementClickInterceptedException",
            },
            {
                "test_id": "DEMO-WEB-003",
                "test_name": "Skipped test",
                "status": "Skipped",
                "actual_result": "Skip marker",
            },
        ]
    }
    json_file.write_text(json.dumps(payload), encoding="utf-8")
    cases = parse_selenium_cases(json_file)
    assert len(cases) == 3
    assert [c.status for c in cases] == ["Passed", "Failed", "Skipped"]
    assert "ElementClickInterceptedException" in cases[1].details

    # Missing file test
    missing = tmp_path / "missing.json"
    blocked_cases = parse_selenium_cases(missing)
    assert len(blocked_cases) == 1
    assert blocked_cases[0].status == "Blocked"


def test_parse_flutter_cases_json_events(tmp_path):
    json_path = tmp_path / "flutter-test.json"
    events = [
        {"type": "start", "time": 0},
        {"type": "suite", "suite": {"id": 0, "path": "test/sample_test.dart"}, "time": 0},
        {"type": "testStart", "test": {"id": 1, "name": "loading test/sample_test.dart", "hidden": True}, "time": 1},
        {"type": "testDone", "testID": 1, "result": "success", "skipped": False, "time": 10},
        {"type": "testStart", "test": {"id": 2, "name": "Feature A should work", "hidden": False, "url": "test/a.dart"}, "time": 12},
        {"type": "testDone", "testID": 2, "result": "success", "skipped": False, "time": 15},
        {"type": "testStart", "test": {"id": 3, "name": "Feature B fails", "hidden": False, "url": "test/b.dart"}, "time": 16},
        {"type": "testDone", "testID": 3, "result": "failure", "skipped": False, "time": 20},
        {"type": "testStart", "test": {"id": 4, "name": "Feature C is skipped", "hidden": False, "url": "test/c.dart"}, "time": 21},
        {"type": "testDone", "testID": 4, "result": "success", "skipped": True, "time": 22},
    ]
    with open(json_path, "w", encoding="utf-8") as f:
        for ev in events:
            f.write(json.dumps(ev) + "\n")

    cases = parse_flutter_cases(tmp_path)
    assert len(cases) == 3  # "loading" was excluded
    assert cases[0].name == "Feature A should work" and cases[0].status == "Passed"
    assert cases[1].name == "Feature B fails" and cases[1].status == "Failed"
    assert cases[2].name == "Feature C is skipped" and cases[2].status == "Skipped"


def test_parse_extension_cases_json_and_fallback(tmp_path):
    json_path = tmp_path / "extension-results.json"
    payload = {
        "suite": "Browser Extension Tests",
        "total": 2,
        "passed": 1,
        "failed": 1,
        "test_cases": [
            {"suite": "Browser Extension Tests", "test_id": "EXT-001", "name": "State check", "status": "Passed", "details": "ok"},
            {"suite": "Browser Extension Tests", "test_id": "EXT-002", "name": "Sync check", "status": "Failed", "details": "bad"},
        ],
    }
    json_path.write_text(json.dumps(payload), encoding="utf-8")
    cases = parse_extension_cases(tmp_path)
    assert len(cases) == 2
    assert cases[0].status == "Passed"
    assert cases[1].status == "Failed"

    # Test fallback to log
    json_path.unlink()
    log_path = tmp_path / "extension.log"
    log_path.write_text(
        "PASS: all manifest-referenced files exist.\n"
        "  ✅  transition A to B\n"
        "  ❌  transition C to D\n"
        "PASS: parking lot popup\n"
        "Desktop notification checks: 4 passed, 0 failed.\n"
        "== S1_replay_test\n"
        "  PASS  first scenario  (want 1, got 1)\n",
        encoding="utf-8",
    )
    cases_from_log = parse_extension_cases(tmp_path)
    assert any(c.test_id == "EXT-MANIFEST-001" and c.status == "Passed" for c in cases_from_log)
    assert any(c.status == "Failed" and "transition C to D" in c.name for c in cases_from_log)
    assert any(c.test_id == "EXT-PARK-001" and c.status == "Passed" for c in cases_from_log)


def test_ci_gate_validation_detects_mismatches(tmp_path):
    cases = [
        SuiteCaseEntry(suite="Backend API and Unit Tests", test_id="B-001", name="t1", status="Passed"),
        SuiteCaseEntry(suite="Backend API and Unit Tests", test_id="B-002", name="t2", status="Failed"),
    ]
    gate_file = tmp_path / "ci-gate.json"

    # Matching gate
    gate_file.write_text(
        json.dumps(
            {
                "suites": {
                    "Backend (Pytest)": {"total": 2, "passed": 1, "failed": 1, "skipped": 0}
                }
            }
        ),
        encoding="utf-8",
    )
    valid, discrepancies = validate_against_ci_gate(cases, tmp_path)
    assert valid is True
    assert discrepancies == []

    # Mismatched gate
    gate_file.write_text(
        json.dumps(
            {
                "suites": {
                    "Backend (Pytest)": {"total": 3, "passed": 3, "failed": 0, "skipped": 0}
                }
            }
        ),
        encoding="utf-8",
    )
    valid, discrepancies = validate_against_ci_gate(cases, tmp_path)
    assert valid is False
    assert len(discrepancies) > 0


def test_build_full_workbook_and_inspect_openpyxl(temp_results_env):
    results_dir = temp_results_env["results_dir"]
    excel_dir = temp_results_env["excel_dir"]
    json_dir = temp_results_env["json_dir"]

    # 1. Selenium
    sel_path = json_dir / "execution-results.json"
    sel_path.write_text(
        json.dumps(
            {
                "test_cases": [
                    {"test_id": "SEL-001", "test_name": "Shell check", "status": "Passed", "actual_result": "ok"}
                ]
            }
        ),
        encoding="utf-8",
    )

    # 2. Backend
    (results_dir / "backend-junit.xml").write_text(
        """<testsuite tests="2" failures="0"><testcase name="test_1"/><testcase name="test_2"/></testsuite>""",
        encoding="utf-8",
    )

    # 3. QA Controls
    (results_dir / "qa-quality-junit.xml").write_text(
        """<testsuite tests="1" failures="0"><testcase name="test_qa_1"/></testsuite>""",
        encoding="utf-8",
    )

    # 4. Flutter
    (results_dir / "flutter-test.json").write_text(
        json.dumps({"type": "testStart", "test": {"id": 1, "name": "flutter_1", "hidden": False}}) + "\n"
        + json.dumps({"type": "testDone", "testID": 1, "result": "success", "skipped": False}) + "\n",
        encoding="utf-8",
    )

    # 5. Extension
    (results_dir / "extension-results.json").write_text(
        json.dumps(
            {
                "test_cases": [
                    {"suite": "Browser Extension Tests", "test_id": "EXT-001", "name": "ext_1", "status": "Passed"}
                ]
            }
        ),
        encoding="utf-8",
    )

    # 6. Load
    (results_dir / "load-results.json").write_text(
        json.dumps(
            {
                "test_cases": [
                    {"test_id": "LOAD-001", "name": "Health load", "status": "Passed", "details": "RPS: 100"}
                ]
            }
        ),
        encoding="utf-8",
    )

    # 7. Vulnerability
    (results_dir / "vulnerability-results.json").write_text(
        json.dumps(
            {
                "test_cases": [
                    {"test_id": "VULN-001", "name": "Auth header check", "status": "Passed", "details": "401"}
                ]
            }
        ),
        encoding="utf-8",
    )

    # Gate JSON matching exactly: 1 + 2 + 1 + 1 + 1 + 1 + 1 = 8
    (results_dir / "ci-gate.json").write_text(
        json.dumps(
            {
                "suites": {
                    "Selenium Acceptance": {"total": 1, "passed": 1, "failed": 0, "skipped": 0},
                    "Backend (Pytest)": {"total": 2, "passed": 2, "failed": 0, "skipped": 0},
                    "QA Catalogue Controls": {"total": 1, "passed": 1, "failed": 0, "skipped": 0},
                    "Flutter Tests (Mobile/Web)": {"total": 1, "passed": 1, "failed": 0, "skipped": 0},
                    "Browser Extension Tests": {"total": 1, "passed": 1, "failed": 0, "skipped": 0},
                    "Load Smoke": {"total": 1, "passed": 1, "failed": 0, "skipped": 0},
                    "Vulnerability Checks": {"total": 1, "passed": 1, "failed": 0, "skipped": 0},
                }
            }
        ),
        encoding="utf-8",
    )

    target_xlsx = build(
        results_dir=results_dir,
        output_dir=excel_dir,
        selenium_path=sel_path,
        enforce_gate_match=True,
    )

    assert target_xlsx.exists()
    wb = openpyxl.load_workbook(target_xlsx)
    assert "All Test Cases" in wb.sheetnames
    assert "Suite Summary" in wb.sheetnames

    ws_cases = wb["All Test Cases"]
    assert ws_cases.max_row == 9  # 1 header + 8 cases
    headers = [cell.value for cell in ws_cases[1]]
    assert headers == ["Test ID", "Suite", "Test Name", "Status", "Details"]

    ws_summary = wb["Suite Summary"]
    summary_headers = [cell.value for cell in ws_summary[1]]
    assert summary_headers == ["Suite", "Total", "Passed", "Failed", "Skipped", "Blocked / Not Run", "Suite Status"]

    # Check that TOTAL row matches sum of cases
    found_total = False
    for row in ws_summary.iter_rows(values_only=True):
        if row and row[0] == "TOTAL":
            found_total = True
            assert row[1] == 8
            assert row[2] == 8
            assert row[3] == 0
            assert "PASSED" in str(row[6])
    assert found_total
