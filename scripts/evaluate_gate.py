import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# Force UTF-8 on stdout for cross-platform compatibility
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

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
        text = clean_ansi(log_path.read_text(encoding="utf-8", errors="replace"))
        m = re.search(r"(\d+)\s+passed", text)
        passed = int(m.group(1)) if m else 0
        mf = re.search(r"(\d+)\s+failed", text)
        failed = int(mf.group(1)) if mf else 0
        ms = re.search(r"(\d+)\s+skipped", text)
        skipped = int(ms.group(1)) if ms else 0
        return {"name": "Backend (Pytest)", "total": passed + failed + skipped, "passed": passed, "failed": failed, "skipped": skipped}
    return None

def parse_flutter_test():
    log_path = Path("test-results/flutter-test.log")
    if not log_path.exists():
        return None
    text = clean_ansi(log_path.read_text(encoding="utf-8", errors="replace"))
    # Matches patterns like: "+41: All tests passed!" or "+38 -3: Some tests failed."
    m = re.findall(r"\+(\d+)(?:\s+-(\d+))?:\s+(?:All tests passed|Some tests failed)", text)
    if m:
        passed_str, failed_str = m[-1]
        passed = int(passed_str)
        failed = int(failed_str) if failed_str else 0
        return {"name": "Flutter Tests (Mobile/Web)", "total": passed + failed, "passed": passed, "failed": failed, "skipped": 0}
    # Fallback: find highest +count if summary line was formatted differently
    all_plus = re.findall(r"\+(\d+)", text)
    if all_plus:
        highest = max(int(x) for x in all_plus)
        return {"name": "Flutter Tests (Mobile/Web)", "total": highest, "passed": highest, "failed": 0, "skipped": 0}
    return None

def parse_extension():
    log_path = Path("test-results/extension.log")
    if not log_path.exists():
        return None
    text = clean_ansi(log_path.read_text(encoding="utf-8", errors="replace"))
    total_passed = 0
    total_failed = 0

    # 1. State machine: Total: 177 | ✅ Passed: 177 | ❌ Failed: 0
    m_sm = re.search(r"Total:\s+(\d+)\s+\|\s*✅?\s*Passed:\s+(\d+)\s+\|\s*❌?\s*Failed:\s+(\d+)", text)
    if m_sm:
        total_passed += int(m_sm.group(2))
        total_failed += int(m_sm.group(3))

    # 2. Database Sync: Results: 36 passed, 0 failed
    m_db = re.search(r"Results:\s+(\d+)\s+passed,\s+(\d+)\s+failed", text)
    if m_db:
        total_passed += int(m_db.group(1))
        total_failed += int(m_db.group(2))

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
    text = clean_ansi(log_path.read_text(encoding="utf-8", errors="replace"))
    if "No issues found!" in text:
        return {"issues": 0, "status": "clean"}
    m = re.search(r"(\d+)\s+issues?\s+found", text)
    issues = int(m.group(1)) if m else 0
    return {"issues": issues, "status": "clean" if issues == 0 else "warnings/errors"}

def main():
    checks = {
        "Backend": os.environ.get("BACKEND_RESULT", "failure"),
        "Flutter analyze": os.environ.get("FLUTTER_ANALYZE_RESULT", "failure"),
        "Flutter tests": os.environ.get("FLUTTER_TEST_RESULT", "failure"),
        "Extension": os.environ.get("EXTENSION_RESULT", "failure"),
    }
    suites = [s for s in [parse_backend(), parse_flutter_test(), parse_extension()] if s]

    total_test_cases = sum(s["total"] for s in suites)
    total_passed = sum(s["passed"] for s in suites)
    total_failed = sum(s["failed"] for s in suites)
    total_skipped = sum(s.get("skipped", 0) for s in suites)

    passed_checks = sum(result == "success" for result in checks.values())
    total_checks = len(checks)
    threshold = float(os.environ.get("PASS_THRESHOLD_PERCENT", "100"))
    pass_rate = passed_checks * 100 / total_checks
    gate = (pass_rate >= threshold) and (total_failed == 0)

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
        st = "🟢 PASS" if s["failed"] == 0 and s["total"] > 0 else "🔴 FAIL"
        lines.append(f"| **{s['name']}** | {s['total']} | {s['passed']} | {s['failed']} | {s['skipped']} | {st} |")

    lines.append(f"| **TOTAL TEST CASES** | **{total_test_cases}** | **{total_passed}** | **{total_failed}** | **{total_skipped}** | **{status_icon} {status_str}** |")
    lines.append("")

    # Add Analyze info if available
    analyze_info = parse_flutter_analyze()
    if analyze_info:
        lines.append(f"**Static Analysis:** {analyze_info['issues']} issues found ({analyze_info['status']})")
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
    raise SystemExit(0 if gate else 1)

if __name__ == "__main__":
    main()
