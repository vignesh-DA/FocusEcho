"""Build a single named-case workbook from the outputs produced by CI suites."""

from __future__ import annotations

import json
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

ROOT = Path(__file__).resolve().parents[2]
RESULTS = ROOT / "test-results"
EXCEL_DIR = ROOT / "Test Results" / "Excel"


@dataclass
class Case:
    suite: str
    test_id: str
    name: str
    status: str
    details: str = ""


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def junit_cases(path: Path, suite_name: str) -> list[Case]:
    if not path.exists():
        raise FileNotFoundError(f"Required test report not found: {path}")
    root = ET.parse(path).getroot()
    cases = []
    for index, node in enumerate(root.iter("testcase"), start=1):
        name = node.attrib.get("name", "Unnamed test")
        status = "Failed" if node.find("failure") is not None or node.find("error") is not None else (
            "Skipped" if node.find("skipped") is not None else "Passed"
        )
        prefix = "BACKEND" if suite_name == "Backend" else "QA"
        cases.append(Case(suite_name, f"{prefix}-{index:03d}", name, status))
    return cases


def selenium_cases() -> list[Case]:
    path = ROOT / "Test Results" / "JSON" / "execution-results.json"
    if not path.exists():
        raise FileNotFoundError(f"Required Selenium results not found: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    return [
        Case("Selenium Acceptance", item.get("test_id", ""), item.get("test_name", ""), item.get("status", "Not Run"), item.get("actual_result", ""))
        for item in payload.get("test_cases", [])
    ]


def flutter_cases() -> list[Case]:
    cases_by_progress: dict[tuple[int, int, int], Case] = {}
    pattern = re.compile(r"^\s*\d{2}:\d{2}\s+\+(\d+)(?:\s+-(\d+))?(?:\s+~(\d+))?:\s+(.+?\.dart):\s+(.+?)\s*$")
    flutter_log = re.sub(r"\x1b\[[0-9;]*m", "", read_text(RESULTS / "flutter-test.log"))
    for line in flutter_log.splitlines():
        match = pattern.match(line)
        if not match:
            continue
        passed_now, failed_now, skipped_now = (int(match.group(1)), int(match.group(2) or 0), int(match.group(3) or 0))
        test_file, name = match.group(4), match.group(5)
        key = (passed_now, failed_now, skipped_now)
        status = "Failed" if failed_now else "Skipped" if skipped_now else "Passed"
        cases_by_progress[key] = Case("Flutter", test_file, name, status)
    summary = re.findall(r"\+(\d+)(?:\s+-(\d+))?(?:\s+~(\d+))?:\s+(?:All tests passed|Some tests failed)", flutter_log)
    if not summary:
        raise ValueError("Flutter test log has no completed summary line")
    passed, failed, skipped = (int(summary[-1][0]), int(summary[-1][1] or 0), int(summary[-1][2] or 0))
    extracted = []
    for index in range(1, passed + 1):
        case = cases_by_progress.get((index, 0, 0))
        if case is None:
            case = Case("Flutter", "", f"Flutter test {index} (runner did not emit a test name)", "Passed")
        case.test_id = f"FLUTTER-{index:03d}"
        extracted.append(case)
    extracted.extend(Case("Flutter", f"FLUTTER-FAIL-{i+1:03d}", "Flutter test failure (see raw Flutter log)", "Failed") for i in range(failed))
    extracted.extend(Case("Flutter", f"FLUTTER-SKIP-{i+1:03d}", "Flutter test skipped", "Skipped") for i in range(skipped))
    return extracted


def extension_cases() -> list[Case]:
    text = re.sub(r"\x1b\[[0-9;]*m", "", read_text(RESULTS / "extension.log"))
    # Windows PowerShell may transcode Node's UTF-8 checkmarks through the active code page.
    text = text.replace("âœ…", "✅").replace("â�Œ", "❌")
    cases: list[Case] = []
    replay_id = None
    for line in text.splitlines():
        if "Total:" in line:
            continue
        heading = re.match(r"\s*==\s*(S\d+_[^\s]+)\s*$", line)
        if heading:
            replay_id = heading.group(1)
            continue
        replay = re.match(r"\s*(PASS|FAIL)\s+(.+?)\s+\(", line)
        if replay and replay_id:
            cases.append(Case("Browser Extension Replay", replay_id, replay.group(2).strip(), "Passed" if replay.group(1) == "PASS" else "Failed"))
            replay_id = None
            continue
        match = re.search(r"✅\s+(.+)$", line)
        if match:
            cases.append(Case("Browser Extension", f"EXT-{len(cases)+1:03d}", match.group(1).strip(), "Passed"))
        elif re.search(r"❌\s+(.+)$", line):
            match = re.search(r"❌\s+(.+)$", line)
            cases.append(Case("Browser Extension", f"EXT-{len(cases)+1:03d}", match.group(1).strip(), "Failed"))
    # These runners summarize a single structural check instead of individual assertions.
    if "PASS: all manifest-referenced files exist" in text:
        cases.append(Case("Browser Extension Manifest", "EXT-MANIFEST-001", "All manifest referenced files exist", "Passed"))
    elif "FAIL: manifest" in text:
        cases.append(Case("Browser Extension Manifest", "EXT-MANIFEST-001", "All manifest referenced files exist", "Failed"))
    if "PASS: parking lot popup" in text:
        cases.append(Case("Browser Extension Parking Lot", "EXT-PARK-001", "Popup limits, safe rendering, and bridge wiring", "Passed"))
    elif "FAIL: parking lot popup" in text:
        cases.append(Case("Browser Extension Parking Lot", "EXT-PARK-001", "Popup limits, safe rendering, and bridge wiring", "Failed"))
    notification_match = re.search(r"Desktop notification checks:\s*(\d+) passed,\s*(\d+) failed", text)
    if notification_match:
        names = [
            "Distraction notification shows the host without exposing the intention",
            "Distraction notification schedules a repeating 30-second nudge",
            "Paused sessions clear the repeat alarm and active notification",
            "Notification click focuses the FocusEcho dashboard tab",
        ]
        passed, failed = map(int, notification_match.groups())
        for index in range(passed):
            cases.append(Case("Browser Extension Notifications", f"EXT-NOTIF-{index+1:03d}", names[index] if index < len(names) else f"Desktop notification check {index+1}", "Passed"))
        for index in range(failed):
            cases.append(Case("Browser Extension Notifications", f"EXT-NOTIF-FAIL-{index+1:03d}", f"Desktop notification check {index+1}", "Failed"))
    expected = 228
    if len(cases) != expected:
        raise ValueError(f"Extension log produced {len(cases)} named cases; expected {expected}")
    return cases


def line_suite_cases(filename: str, suite: str, expression: str, summary: str, expected: int) -> list[Case]:
    text = read_text(RESULTS / filename)
    found = []
    for line in text.splitlines():
        match = re.search(expression, line)
        if match:
            status = "Failed" if match.group(1).lower() == "fail" else "Passed"
            found.append(Case(suite, match.group(2), match.group(3).strip(), status, line.strip()))
    if not re.search(summary, text):
        raise ValueError(f"{suite} summary not found in {filename}")
    if len(found) != expected:
        raise ValueError(f"{suite} log names {len(found)} checks; expected {expected}")
    return found


def build() -> Path:
    cases: list[Case] = []
    # The Selenium run creates its JSON and four detailed Selenium workbooks.
    cases.extend(selenium_cases())
    cases.extend(junit_cases(RESULTS / "backend-junit.xml", "Backend"))
    cases.extend(junit_cases(RESULTS / "qa-quality-junit.xml", "QA Controls"))
    cases.extend(flutter_cases())
    cases.extend(extension_cases())
    cases.extend(line_suite_cases(
        "load.log", "Load Smoke",
        r"\[(Pass|Fail)\]\s+(LOAD-[A-Z0-9-]+):\s*(.+?)\s+—",
        r"LOAD SUITE SUMMARY:\s*\d+/\d+ passed;\s*\d+ failed", 8,
    ))
    cases.extend(line_suite_cases(
        "vulnerability.log", "Vulnerability",
        r"\[(Pass|Fail)\]\s+(VULN-[A-Z0-9-]+)\s+\([^)]*\):\s*(.+?)\s+—",
        r"VULNERABILITY SUITE SUMMARY:\s*\d+/\d+ controls passed;\s*\d+ failed", 10,
    ))

    if not cases:
        raise ValueError("Combined report has no test cases")

    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "All Test Cases"
    sheet.append(["Test ID", "Suite", "Test Name", "Status", "Details"])
    for cell in sheet[1]:
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = PatternFill("solid", fgColor="1F2937")
    fill_by_status = {
        "Passed": PatternFill("solid", fgColor="D1FAE5"),
        "Failed": PatternFill("solid", fgColor="FEE2E2"),
        "Skipped": PatternFill("solid", fgColor="FEF3C7"),
    }
    for case in cases:
        sheet.append([case.test_id, case.suite, case.name, case.status, case.details])
        for cell in sheet[sheet.max_row]:
            cell.alignment = Alignment(vertical="top", wrap_text=True)
        sheet.cell(sheet.max_row, 4).fill = fill_by_status.get(case.status, PatternFill())
    widths = {1: 26, 2: 28, 3: 72, 4: 14, 5: 72}
    for index, width in widths.items():
        sheet.column_dimensions[get_column_letter(index)].width = width
    sheet.freeze_panes = "A2"
    sheet.auto_filter.ref = sheet.dimensions

    summary = workbook.create_sheet("Suite Summary")
    summary.append(["Suite", "Total", "Passed", "Failed", "Skipped"])
    for cell in summary[1]:
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = PatternFill("solid", fgColor="1F2937")
    for suite in dict.fromkeys(case.suite for case in cases):
        group = [case for case in cases if case.suite == suite]
        summary.append([suite, len(group), sum(x.status == "Passed" for x in group), sum(x.status == "Failed" for x in group), sum(x.status == "Skipped" for x in group)])
    summary.append(["TOTAL", len(cases), sum(x.status == "Passed" for x in cases), sum(x.status == "Failed" for x in cases), sum(x.status == "Skipped" for x in cases)])
    for index, width in enumerate([32, 14, 14, 14, 14], start=1):
        summary.column_dimensions[get_column_letter(index)].width = width
    summary.freeze_panes = "A2"

    EXCEL_DIR.mkdir(parents=True, exist_ok=True)
    target = EXCEL_DIR / "Full_Test_Suite_Report.xlsx"
    workbook.save(target)
    passed = sum(case.status == "Passed" for case in cases)
    failed = sum(case.status == "Failed" for case in cases)
    skipped = sum(case.status == "Skipped" for case in cases)
    print(f"Created {target} with {len(cases)} named test cases: {passed} passed, {failed} failed, {skipped} skipped.")
    return target


if __name__ == "__main__":
    build()
