import os
import re
import sys
import json
import xml.etree.ElementTree as ET
from pathlib import Path

# Force UTF-8 on stdout for cross-platform compatibility
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

def read_file_text(path: Path) -> str:
    """Read file with automatic BOM/encoding handling."""
    if not path.exists():
        return ""
    raw = path.read_bytes()
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        return raw.decode("utf-16", errors="replace")
    elif raw.startswith(b"\xef\xbb\xbf"):
        return raw.decode("utf-8-sig", errors="replace")
    return raw.decode("utf-8", errors="replace")


def clean_ansi(text: str) -> str:
    """Strip ANSI escape sequences from logs."""
    return re.sub(r"\x1b\[[0-9;]*[a-zA-Z]", "", text)


def parse_backend():
    xml_path = Path("test-results/backend-junit.xml")
    log_path = Path("test-results/backend.log")
    if xml_path.exists():
        try:
            tree = ET.parse(xml_path)
            root = tree.getroot()
            suite = root.find("testsuite")
            if suite is None:
                suite = root
            total = int(suite.attrib.get("tests", 0))
            failures = int(suite.attrib.get("failures", 0))
            errors = int(suite.attrib.get("errors", 0))
            skipped = int(suite.attrib.get("skipped", 0))
            failed = failures + errors
            passed = max(0, total - failed - skipped)
            return {"name": "Backend (Pytest)", "total": total, "passed": passed, "failed": failed, "skipped": skipped}
        except Exception:
            pass
    if log_path.exists():
        text = clean_ansi(read_file_text(log_path))
        m = re.search(r"(\d+)\s+passed", text)
        passed = int(m.group(1)) if m else 0
        mf = re.search(r"(\d+)\s+failed", text)
        failed = int(mf.group(1)) if mf else 0
        ms = re.search(r"(\d+)\s+skipped", text)
        skipped = int(ms.group(1)) if ms else 0
        return {"name": "Backend (Pytest)", "total": passed + failed + skipped, "passed": passed, "failed": failed, "skipped": skipped}
    return None

def parse_junit(path: str, name: str):
    xml_path = Path(path)
    if not xml_path.exists():
        return None
    try:
        root = ET.parse(xml_path).getroot()
        suites = [root] if root.tag == "testsuite" else root.findall("testsuite")
        total = sum(int(s.attrib.get("tests", 0)) for s in suites)
        failed = sum(int(s.attrib.get("failures", 0)) + int(s.attrib.get("errors", 0)) for s in suites)
        skipped = sum(int(s.attrib.get("skipped", 0)) for s in suites)
        return {"name": name, "total": total, "passed": max(0, total - failed - skipped), "failed": failed, "skipped": skipped}
    except (ET.ParseError, OSError, ValueError):
        return None

def parse_selenium():
    result_path = Path("Test Results/JSON/execution-results.json")
    if not result_path.exists():
        return None
    try:
        cases = json.loads(result_path.read_text(encoding="utf-8")).get("test_cases", [])
        passed = sum(case.get("status") == "Passed" for case in cases)
        failed = sum(case.get("status") == "Failed" for case in cases)
        skipped = sum(case.get("status") in {"Skipped", "Blocked", "Not Run"} for case in cases)
        return {"name": "Selenium Acceptance", "total": len(cases), "passed": passed, "failed": failed, "skipped": skipped}
    except (json.JSONDecodeError, OSError, TypeError):
        return None

def parse_summary(path: str, name: str, pattern: str):
    json_map = {
        "Load Smoke": Path("test-results/load-results.json"),
        "Vulnerability Checks": Path("test-results/vulnerability-results.json"),
    }
    cand = json_map.get(name)
    if cand and cand.exists():
        try:
            data = json.loads(read_file_text(cand))
            return {
                "name": name,
                "total": data.get("total", len(data.get("test_cases", []))),
                "passed": data.get("passed", 0),
                "failed": data.get("failed", 0),
                "skipped": data.get("skipped", 0),
            }
        except Exception:
            pass

    log_path = Path(path)
    if not log_path.exists():
        return None
    text = clean_ansi(read_file_text(log_path))
    matches = re.findall(pattern, text, flags=re.IGNORECASE)
    if not matches:
        return None
    passed, failed = (int(matches[-1][0]), int(matches[-1][1]))
    return {"name": name, "total": passed + failed, "passed": passed, "failed": failed, "skipped": 0}

def parse_flutter_test():
    json_path = Path("test-results/flutter-test.json")
    if json_path.exists():
        try:
            passed = 0
            failed = 0
            skipped = 0
            real_tests = set()
            events = []
            for line in read_file_text(json_path).splitlines():
                if not line.strip():
                    continue
                ev = json.loads(line)
                events.append(ev)
                if ev.get("type") == "testStart":
                    t = ev.get("test", {})
                    name = t.get("name", "")
                    if name and not name.startswith("loading ") and not t.get("hidden", False):
                        real_tests.add(t["id"])
            for ev in events:
                if ev.get("type") == "testDone" and ev.get("testID") in real_tests:
                    if ev.get("skipped"):
                        skipped += 1
                    elif ev.get("result") == "success":
                        passed += 1
                    else:
                        failed += 1
            if real_tests:
                return {
                    "name": "Flutter Tests (Mobile/Web)",
                    "total": len(real_tests),
                    "passed": passed,
                    "failed": failed,
                    "skipped": skipped,
                }
        except Exception:
            pass

    log_path = Path("test-results/flutter-test.log")
    if not log_path.exists():
        return None
    text = clean_ansi(read_file_text(log_path))
    # Matches summaries such as "+41: All tests passed!", "+38 -3: Some tests failed",
    # and Flutter's skipped-test marker ("~N").
    m = re.findall(
        r"\+(\d+)(?:\s+-(\d+))?(?:\s+~(\d+))?:\s+(?:All tests passed|Some tests failed)",
        text,
    )
    if m:
        passed_str, failed_str, skipped_str = m[-1]
        passed = int(passed_str)
        failed = int(failed_str) if failed_str else 0
        skipped = int(skipped_str) if skipped_str else 0
        return {
            "name": "Flutter Tests (Mobile/Web)",
            "total": passed + failed + skipped,
            "passed": passed,
            "failed": failed,
            "skipped": skipped,
        }
    return None

def parse_extension():
    json_path = Path("test-results/extension-results.json")
    if json_path.exists():
        try:
            data = json.loads(read_file_text(json_path))
            return {
                "name": "Browser Extension Tests",
                "total": data.get("total", len(data.get("test_cases", []))),
                "passed": data.get("passed", 0),
                "failed": data.get("failed", 0),
                "skipped": data.get("skipped", 0),
            }
        except Exception:
            pass

    log_path = Path("test-results/extension.log")
    if not log_path.exists():
        return None
    text = clean_ansi(read_file_text(log_path))
    total_passed = 0
    total_failed = 0

    # 1. State machine: Total: 177 | ✅ Passed: 177 | ❌ Failed: 0
    m_sm = re.search(r"Total:\s+(\d+)\s+\|\s*✅?\s*Passed:\s+(\d+)\s+\|\s*❌?\s*Failed:\s+(\d+)", text)
    if m_sm:
        total_passed += int(m_sm.group(2))
        total_failed += int(m_sm.group(3))

    # 2. Database Sync & Extended tests: Results: X passed, Y failed
    m_results = re.findall(r"Results:\s+(\d+)\s+passed,\s+(\d+)\s+failed", text)
    for m in m_results:
        total_passed += int(m[0])
        total_failed += int(m[1])

    # 3. Desktop notifications: Desktop notification checks: 4 passed, 0 failed
    m_notif = re.search(r"Desktop notification checks:\s+(\d+)\s+passed,\s+(\d+)\s+failed", text)
    if m_notif:
        total_passed += int(m_notif.group(1))
        total_failed += int(m_notif.group(2))

    # 4. Replay scenarios: 9/9 scenarios passed
    m_scen = re.search(r"(\d+)/(\d+)\s+scenarios passed", text)
    if m_scen:
        total_passed += int(m_scen.group(1))

    # 5. Manifest check: PASS: all manifest-referenced files exist
    if "PASS: all manifest-referenced files exist" in text:
        total_passed += 1

    # 6. Parking lot check
    if "PASS: parking lot popup" in text:
        total_passed += 1

    total = total_passed + total_failed
    return {"name": "Browser Extension Tests", "total": total, "passed": total_passed, "failed": total_failed, "skipped": 0}

def parse_flutter_analyze():
    log_path = Path("test-results/flutter-analyze.log")
    if not log_path.exists():
        return None
    text = clean_ansi(read_file_text(log_path))
    if "No issues found!" in text:
        return {"issues": 0, "infos": 0, "warnings_errors": 0, "status": "clean"}
    m = re.search(r"(\d+)\s+issues?\s+found", text)
    issues = int(m.group(1)) if m else 0
    severities = re.findall(r"^\s*(info|warning|error)\s+[-•]", text, flags=re.IGNORECASE | re.MULTILINE)
    infos = sum(severity.lower() == "info" for severity in severities)
    warnings_errors = sum(severity.lower() in {"warning", "error"} for severity in severities)
    return {
        "issues": issues,
        "infos": infos,
        "warnings_errors": warnings_errors,
        "status": "clean" if warnings_errors == 0 else "warnings/errors",
    }


def required_suite_gaps(suites: list[dict]) -> tuple[list[str], list[str]]:
    """Return required suites that are missing or reported zero cases."""
    required = {
        "Backend (Pytest)",
        "QA Catalogue Controls",
        "Flutter Tests (Mobile/Web)",
        "Browser Extension Tests",
        "Selenium Acceptance",
        "Load Smoke",
        "Vulnerability Checks",
    }
    by_name = {suite["name"]: suite for suite in suites}
    missing = sorted(required - by_name.keys())
    empty = sorted(name for name in required & by_name.keys() if by_name[name]["total"] == 0)
    return missing, empty

def main():
    checks = {
        "Backend": os.environ.get("BACKEND_RESULT", "failure"),
        "Flutter analyze": os.environ.get("FLUTTER_ANALYZE_RESULT", "failure"),
        "Flutter tests": os.environ.get("FLUTTER_TEST_RESULT", "failure"),
        "Extension": os.environ.get("EXTENSION_RESULT", "failure"),
        "QA catalogue": os.environ.get("QA_QUALITY_RESULT", "failure"),
        "Selenium": os.environ.get("SELENIUM_RESULT", "failure"),
        "Load smoke": os.environ.get("LOAD_RESULT", "failure"),
        "Vulnerability": os.environ.get("VULNERABILITY_RESULT", "failure"),
    }
    suites = [s for s in [
        parse_backend(),
        parse_junit("test-results/qa-quality-junit.xml", "QA Catalogue Controls"),
        parse_flutter_test(),
        parse_extension(),
        parse_selenium(),
        parse_summary("test-results/load.log", "Load Smoke", r"LOAD SUITE SUMMARY:\s*(\d+)/\d+ passed;\s*(\d+) failed"),
        parse_summary("test-results/vulnerability.log", "Vulnerability Checks", r"VULNERABILITY SUITE SUMMARY:\s*(\d+)/\d+ controls passed;\s*(\d+) failed"),
    ] if s]

    total_test_cases = sum(s["total"] for s in suites)
    total_passed = sum(s["passed"] for s in suites)
    total_failed = sum(s["failed"] for s in suites)
    total_skipped = sum(s.get("skipped", 0) for s in suites)

    passed_checks = sum(result == "success" for result in checks.values())
    total_checks = len(checks)
    threshold = float(os.environ.get("PASS_THRESHOLD_PERCENT", "100"))
    pass_rate = passed_checks * 100 / total_checks
    missing_suites, empty_suites = required_suite_gaps(suites)
    gate = (
        pass_rate >= threshold
        and total_failed == 0
        and total_skipped == 0
        and not missing_suites
        and not empty_suites
    )

    status_icon = "🟢" if gate else "🔴"
    status_str = "PASSED" if gate else "FAILED"

    lines = [
        f"# {status_icon} FocusEcho CI Test Report",
        "",
        "### 📊 Test Cases Breakdown",
        "",
        "| Test Suite | Total Tests | Passed ✅ | Failed ❌ | Skipped ⚠️ | Suite Status |",
        "| :--- | :---: | :---: | :---: | :---: | :---: |",
    ]

    for s in suites:
        st = "🟢 PASS" if s["failed"] == 0 and s["skipped"] == 0 and s["total"] > 0 else "🔴 FAIL"
        lines.append(f"| **{s['name']}** | {s['total']} | {s['passed']} | {s['failed']} | {s['skipped']} | {st} |")

    lines.append(f"| **TOTAL TEST CASES** | **{total_test_cases}** | **{total_passed}** | **{total_failed}** | **{total_skipped}** | **{status_icon} {status_str}** |")
    lines.append("")

    # Add Analyze info if available
    analyze_info = parse_flutter_analyze()
    if analyze_info:
        lines.append(
            f"**Static Analysis:** {analyze_info['warnings_errors']} warnings/errors; "
            f"{analyze_info['infos']} informational suggestions ({analyze_info['status']})"
        )
        lines.append("")

    lines.append("### 🛠️ Workflow Step Checks")
    lines.append("")
    lines.append("| Check Step | Outcome |")
    lines.append("| :--- | :---: |")
    for name, result in checks.items():
        res_icon = "✅ success" if result == "success" else f"❌ {result}"
        lines.append(f"| {name} | {res_icon} |")

    lines.append("")
    lines.append(f"**Gate Decision:** **{status_str}** — Steps Passed: **{passed_checks}/{total_checks} ({pass_rate:.0f}%)** | Threshold: **{threshold:g}%**")
    lines.append(f"**Test Cases Summary:** **{total_passed} passed**, **{total_failed} failed**, **{total_skipped} skipped** out of **{total_test_cases} total**.")
    if missing_suites:
        lines.append(f"**Missing required suite results:** {', '.join(missing_suites)}")
    if empty_suites:
        lines.append(f"**Empty required suite results:** {', '.join(empty_suites)}")

    summary = "\n".join(lines) + "\n"
    print(summary)

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        Path(summary_path).write_text(summary, encoding="utf-8")

    Path("test-results").mkdir(parents=True, exist_ok=True)
    Path("test-results/ci-summary.md").write_text(summary, encoding="utf-8")
    Path("test-results/ci-gate.txt").write_text(
        f"total_tests={total_test_cases}\npassed_tests={total_passed}\nfailed_tests={total_failed}\npass_rate={pass_rate:.0f}%\nresult={status_str}\n",
        encoding="utf-8",
    )
    gate_json_data = {
        "gate_passed": gate,
        "status": status_str,
        "total_test_cases": total_test_cases,
        "total_passed": total_passed,
        "total_failed": total_failed,
        "total_skipped": total_skipped,
        "suites": {
            s["name"]: {
                "total": s["total"],
                "passed": s["passed"],
                "failed": s["failed"],
                "skipped": s.get("skipped", 0),
            }
            for s in suites
        },
    }
    Path("test-results/ci-gate.json").write_text(
        json.dumps(gate_json_data, indent=2), encoding="utf-8"
    )
    raise SystemExit(0 if gate else 1)

if __name__ == "__main__":
    main()
