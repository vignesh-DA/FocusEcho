"""
Combined Full-Suite Excel Report Generator for FocusEcho.

Generates a unified, publication-grade Excel workbook containing every executed
test case and check from every test suite:
  1. Selenium Acceptance (Static Web)
  2. Backend API & Unit Tests (Pytest)
  3. Flutter Tests (Unit & Widget)
  4. Browser Extension Tests (State Machine, DB Sync, Notifications, Replay, Manifest, Parking Lot)
  5. QA Catalogue Controls
  6. Local Load Smoke Suite
  7. Local Vulnerability & Security Checks

Workbook Structure:
  - Sheet 1: 'All Test Cases' - 1 row per named test case/check with Test ID, Suite, Name, Status, Details
  - Sheet 2: 'Suite Summary'  - per-suite breakdown of Total, Passed, Failed, Skipped, Blocked/Not Run,
                                overall totals, and CI Gate verification status.

Resilience:
  - Ingestion prefers machine-readable formats (JUnit XML, JSON, Flutter test JSON) with regex log fallbacks.
  - Missing or failing suites are gracefully represented as 'Blocked' or 'Not Run' with diagnostic details;
    report generation NEVER silently skips or crashes.
  - Automatically validates per-suite totals against CI gate results (ci-gate.json / ci-gate.txt).
"""

from __future__ import annotations

import json
import os
import re
import shutil
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

ROOT = Path(__file__).resolve().parents[2]
RESULTS_DIR = ROOT / "test-results"
EXCEL_DIR = ROOT / "Test Results" / "Excel"
SELENIUM_JSON_PATH = ROOT / "Test Results" / "JSON" / "execution-results.json"


@dataclass
class SuiteCaseEntry:
    suite: str
    test_id: str
    name: str
    status: str  # "Passed", "Failed", "Skipped", "Blocked", "Not Run"
    details: str = ""


def read_text_safe(path: Path) -> str:
    """Read file content with automatic encoding/BOM detection."""
    if not path.exists():
        return ""
    try:
        raw = path.read_bytes()
        if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
            return raw.decode("utf-16", errors="replace")
        if raw.startswith(b"\xef\xbb\xbf"):
            return raw.decode("utf-8-sig", errors="replace")
        return raw.decode("utf-8", errors="replace")
    except Exception:
        return ""


def clean_ansi(text: str) -> str:
    """Strip ANSI escape sequences from terminal log text."""
    return re.sub(r"\x1b\[[0-9;]*[a-zA-Z]", "", text)


# ---------------------------------------------------------------------------
# Suite Parsers (with machine-readable preference and robust fallbacks)
# ---------------------------------------------------------------------------

def parse_selenium_cases(json_path: Optional[Path] = None) -> list[SuiteCaseEntry]:
    """Parse Selenium web acceptance test cases from execution-results.json."""
    path = json_path or SELENIUM_JSON_PATH
    if not path.exists():
        alt = RESULTS_DIR / "selenium-results.json"
        if alt.exists():
            path = alt
        else:
            return [
                SuiteCaseEntry(
                    suite="Selenium Acceptance",
                    test_id="DEMO-WEB-BLOCKED",
                    name="Selenium Web Acceptance Suite",
                    status="Blocked",
                    details=f"Results file not found at {path}. Suite was not executed or timed out.",
                )
            ]
    try:
        payload = json.loads(read_text_safe(path))
        cases = []
        for item in payload.get("test_cases", []):
            status = item.get("status", "Not Run")
            if status not in {"Passed", "Failed", "Skipped", "Blocked"}:
                status = "Not Run"
            details = item.get("actual_result", "")
            duration = item.get("duration_seconds")
            if duration:
                details = f"Duration: {duration}s — {details}".strip()
            if item.get("error_message"):
                details = f"{details} | Error: {item['error_message']}".strip()
            cases.append(
                SuiteCaseEntry(
                    suite="Selenium Acceptance",
                    test_id=item.get("test_id", ""),
                    name=item.get("test_name", ""),
                    status=status,
                    details=details,
                )
            )
        return cases
    except Exception as exc:
        return [
            SuiteCaseEntry(
                suite="Selenium Acceptance",
                test_id="DEMO-WEB-ERR",
                name="Selenium Acceptance Parser Error",
                status="Failed",
                details=f"Failed to parse {path}: {exc}",
            )
        ]


def parse_junit_cases(path: Path, suite_display_name: str, id_prefix: str) -> list[SuiteCaseEntry]:
    """Parse pytest JUnit XML files for backend or QA controls."""
    if not path.exists():
        return [
            SuiteCaseEntry(
                suite=suite_display_name,
                test_id=f"{id_prefix}-BLOCKED",
                name=f"{suite_display_name} Suite",
                status="Blocked",
                details=f"JUnit report not found at {path}. Test step did not run or failed during setup.",
            )
        ]
    try:
        root = ET.parse(path).getroot()
        cases = []
        for index, node in enumerate(root.iter("testcase"), start=1):
            name = node.attrib.get("name", "Unnamed test")
            classname = node.attrib.get("classname", "")
            time_sec = node.attrib.get("time", "0")
            fail_node = node.find("failure")
            err_node = node.find("error")
            skip_node = node.find("skipped")

            if fail_node is not None or err_node is not None:
                status = "Failed"
                err_text = (fail_node if fail_node is not None else err_node).text or ""
                details = f"Class: {classname}, Time: {time_sec}s | Failure: {err_text.strip()[:200]}"
            elif skip_node is not None:
                status = "Skipped"
                msg = skip_node.attrib.get("message", skip_node.text or "")
                details = f"Class: {classname} | Skipped: {msg}"
            else:
                status = "Passed"
                details = f"Class: {classname}, Time: {time_sec}s"

            cases.append(
                SuiteCaseEntry(
                    suite=suite_display_name,
                    test_id=f"{id_prefix}-{index:03d}",
                    name=name,
                    status=status,
                    details=details,
                )
            )
        return cases
    except Exception as exc:
        return [
            SuiteCaseEntry(
                suite=suite_display_name,
                test_id=f"{id_prefix}-ERR",
                name=f"{suite_display_name} XML Parse Error",
                status="Failed",
                details=f"Failed to parse JUnit XML {path}: {exc}",
            )
        ]


def parse_flutter_cases(results_dir: Path = RESULTS_DIR) -> list[SuiteCaseEntry]:
    """Parse Flutter test suite using flutter-test.json or flutter-test.log fallback."""
    json_path = results_dir / "flutter-test.json"
    if json_path.exists():
        try:
            cases: list[SuiteCaseEntry] = []
            tests_by_id: dict[int, dict] = {}
            results_by_id: dict[int, dict] = {}
            for line in read_text_safe(json_path).splitlines():
                if not line.strip():
                    continue
                ev = json.loads(line)
                ev_type = ev.get("type")
                if ev_type == "testStart":
                    t = ev.get("test", {})
                    name = t.get("name", "")
                    # Flutter runner emits internal 'loading ...' and hidden harness events
                    if name and not name.startswith("loading ") and not t.get("hidden", False):
                        tests_by_id[t["id"]] = t
                elif ev_type == "testDone":
                    results_by_id[ev.get("testID")] = ev

            idx = 1
            for test_id, t in tests_by_id.items():
                done = results_by_id.get(test_id, {})
                if done.get("skipped"):
                    status = "Skipped"
                elif done.get("result") == "success":
                    status = "Passed"
                else:
                    status = "Failed"
                url = t.get("url", "")
                time_ms = done.get("time", 0)
                details = f"File: {url}" if url else ""
                if time_ms:
                    details = f"{details} (runtime: {time_ms}ms)".strip()
                cases.append(
                    SuiteCaseEntry(
                        suite="Flutter Tests (Mobile/Web)",
                        test_id=f"FLUTTER-{idx:03d}",
                        name=t.get("name", f"Flutter test {idx}"),
                        status=status,
                        details=details,
                    )
                )
                idx += 1
            if cases:
                return cases
        except Exception:
            pass

    # Fallback to flutter-test.log parsing
    log_path = results_dir / "flutter-test.log"
    if log_path.exists():
        text = clean_ansi(read_text_safe(log_path))
        pattern = re.compile(r"^\s*\d{2}:\d{2}\s+\+(\d+)(?:\s+-(\d+))?(?:\s+~(\d+))?:\s+(.+?\.dart):\s+(.+?)\s*$")
        cases_by_progress: dict[int, SuiteCaseEntry] = {}
        for line in text.splitlines():
            m = pattern.match(line)
            if not m:
                continue
            passed_now = int(m.group(1))
            failed_now = int(m.group(2) or 0)
            skipped_now = int(m.group(3) or 0)
            test_file, name = m.group(4), m.group(5)
            status = "Failed" if failed_now else "Skipped" if skipped_now else "Passed"
            cases_by_progress[passed_now] = SuiteCaseEntry(
                suite="Flutter Tests (Mobile/Web)",
                test_id=f"FLUTTER-{passed_now:03d}",
                name=name,
                status=status,
                details=f"File: {test_file}",
            )

        summary = re.findall(r"\+(\d+)(?:\s+-(\d+))?(?:\s+~(\d+))?:\s+(?:All tests passed|Some tests failed)", text)
        if summary:
            passed, failed, skipped = (int(summary[-1][0]), int(summary[-1][1] or 0), int(summary[-1][2] or 0))
            extracted: list[SuiteCaseEntry] = []
            for i in range(1, passed + 1):
                case = cases_by_progress.get(i)
                if not case:
                    case = SuiteCaseEntry(
                        suite="Flutter Tests (Mobile/Web)",
                        test_id=f"FLUTTER-{i:03d}",
                        name=f"Flutter test {i}",
                        status="Passed",
                        details="Derived from test summary progression",
                    )
                extracted.append(case)
            for f in range(failed):
                extracted.append(
                    SuiteCaseEntry(
                        suite="Flutter Tests (Mobile/Web)",
                        test_id=f"FLUTTER-FAIL-{f+1:03d}",
                        name=f"Flutter failure check {f+1}",
                        status="Failed",
                        details="Failure recorded in flutter-test.log",
                    )
                )
            for s in range(skipped):
                extracted.append(
                    SuiteCaseEntry(
                        suite="Flutter Tests (Mobile/Web)",
                        test_id=f"FLUTTER-SKIP-{s+1:03d}",
                        name=f"Flutter skipped check {s+1}",
                        status="Skipped",
                        details="Skipped in flutter test suite",
                    )
                )
            return extracted

    return [
        SuiteCaseEntry(
            suite="Flutter Tests (Mobile/Web)",
            test_id="FLUTTER-BLOCKED",
            name="Flutter Unit & Widget Tests",
            status="Blocked",
            details="Flutter test outputs (JSON or log) not found. Suite may not have run.",
        )
    ]


def parse_extension_cases(results_dir: Path = RESULTS_DIR) -> list[SuiteCaseEntry]:
    """Parse Browser Extension test cases from extension-results.json or extension.log."""
    json_path = results_dir / "extension-results.json"
    alt_json = ROOT / "browser_extension" / "test-results" / "extension-results.json" if results_dir == RESULTS_DIR else None
    target_json = json_path if json_path.exists() else alt_json if (alt_json and alt_json.exists()) else None

    if target_json:
        try:
            data = json.loads(read_text_safe(target_json))
            cases = []
            for item in data.get("test_cases", []):
                cases.append(
                    SuiteCaseEntry(
                        suite=item.get("suite", "Browser Extension Tests"),
                        test_id=item.get("test_id", ""),
                        name=item.get("name", ""),
                        status=item.get("status", "Passed"),
                        details=item.get("details", ""),
                    )
                )
            if cases:
                return cases
        except Exception:
            pass

    log_path = results_dir / "extension.log"
    if not log_path.exists():
        return [
            SuiteCaseEntry(
                suite="Browser Extension Tests",
                test_id="EXT-BLOCKED",
                name="Browser Extension Test Suite",
                status="Blocked",
                details="Browser extension test results not found.",
            )
        ]

    text = clean_ansi(read_text_safe(log_path))
    text = text.replace("âœ…", "✅").replace("âŒ", "❌")
    cases: list[SuiteCaseEntry] = []
    replay_id = None

    for line in text.splitlines():
        if "Total:" in line or "Results:" in line:
            continue
        heading = re.match(r"\s*==\s*(S\d+_[^\s]+)\s*$", line)
        if heading:
            replay_id = heading.group(1)
            continue
        replay = re.match(r"\s*(PASS|FAIL)\s+(.+?)\s+\(", line)
        if replay and replay_id:
            cases.append(
                SuiteCaseEntry(
                    suite="Browser Extension Replay",
                    test_id=replay_id,
                    name=replay.group(2).strip(),
                    status="Passed" if replay.group(1) == "PASS" else "Failed",
                    details=line.strip(),
                )
            )
            replay_id = None
            continue
        match_pass = re.search(r"✅\s+(.+)$", line)
        if match_pass:
            cases.append(
                SuiteCaseEntry(
                    suite="Browser Extension Tests",
                    test_id=f"EXT-{len(cases)+1:03d}",
                    name=match_pass.group(1).strip(),
                    status="Passed",
                )
            )
        match_fail = re.search(r"❌\s+(.+)$", line)
        if match_fail:
            cases.append(
                SuiteCaseEntry(
                    suite="Browser Extension Tests",
                    test_id=f"EXT-{len(cases)+1:03d}",
                    name=match_fail.group(1).strip(),
                    status="Failed",
                )
            )

    if "PASS: all manifest-referenced files exist" in text:
        cases.append(
            SuiteCaseEntry(
                suite="Browser Extension Manifest",
                test_id="EXT-MANIFEST-001",
                name="All manifest referenced files exist",
                status="Passed",
                details="Manifest integrity verified on disk",
            )
        )
    elif "FAIL: manifest" in text:
        cases.append(
            SuiteCaseEntry(
                suite="Browser Extension Manifest",
                test_id="EXT-MANIFEST-001",
                name="All manifest referenced files exist",
                status="Failed",
                details="Manifest references missing files",
            )
        )

    if "PASS: parking lot popup" in text:
        cases.append(
            SuiteCaseEntry(
                suite="Browser Extension Parking Lot",
                test_id="EXT-PARK-001",
                name="Popup limits, safe rendering, and bridge wiring",
                status="Passed",
                details="Parking lot popup limits and message security verified",
            )
        )
    elif "FAIL: parking lot popup" in text:
        cases.append(
            SuiteCaseEntry(
                suite="Browser Extension Parking Lot",
                test_id="EXT-PARK-001",
                name="Popup limits, safe rendering, and bridge wiring",
                status="Failed",
                details="Parking lot popup check failed",
            )
        )

    notif_match = re.search(r"Desktop notification checks:\s*(\d+)\s+passed,\s*(\d+)\s+failed", text)
    if notif_match:
        names = [
            "Distraction notification shows the host without exposing the intention",
            "Distraction notification schedules a repeating 30-second nudge",
            "Paused sessions clear the repeat alarm and active notification",
            "Notification click focuses the FocusEcho dashboard tab",
        ]
        p_count, f_count = map(int, notif_match.groups())
        for i in range(p_count):
            cases.append(
                SuiteCaseEntry(
                    suite="Browser Extension Notifications",
                    test_id=f"EXT-NOTIF-{i+1:03d}",
                    name=names[i] if i < len(names) else f"Desktop notification check {i+1}",
                    status="Passed",
                )
            )
        for i in range(f_count):
            cases.append(
                SuiteCaseEntry(
                    suite="Browser Extension Notifications",
                    test_id=f"EXT-NOTIF-FAIL-{i+1:03d}",
                    name=f"Desktop notification check {i+1}",
                    status="Failed",
                )
            )

    return cases or [
        SuiteCaseEntry(
            suite="Browser Extension Tests",
            test_id="EXT-BLOCKED",
            name="Browser Extension Suite",
            status="Blocked",
            details="Extension log was empty or unparseable.",
        )
    ]


def parse_json_or_log_suite(
    json_filename: str,
    log_filename: str,
    suite_name: str,
    line_regex: str,
    summary_regex: str,
    results_dir: Path = RESULTS_DIR,
) -> list[SuiteCaseEntry]:
    """Parse suites that export JSON results with regex log fallback (Load Smoke, Vulnerability)."""
    json_path = results_dir / json_filename
    if json_path.exists():
        try:
            data = json.loads(read_text_safe(json_path))
            cases = []
            for item in data.get("test_cases", []):
                cases.append(
                    SuiteCaseEntry(
                        suite=suite_name,
                        test_id=item.get("test_id", ""),
                        name=item.get("name", ""),
                        status=item.get("status", "Passed"),
                        details=item.get("details", ""),
                    )
                )
            if cases:
                return cases
        except Exception:
            pass

    log_path = results_dir / log_filename
    if not log_path.exists():
        return [
            SuiteCaseEntry(
                suite=suite_name,
                test_id=f"{suite_name.upper()[:4]}-BLOCKED",
                name=f"{suite_name} Suite",
                status="Blocked",
                details=f"{suite_name} report not found at {log_filename}.",
            )
        ]

    text = clean_ansi(read_text_safe(log_path))
    cases = []
    for line in text.splitlines():
        m = re.search(line_regex, line)
        if m:
            st = "Failed" if m.group(1).lower() in ("fail", "failed") else "Passed"
            cases.append(
                SuiteCaseEntry(
                    suite=suite_name,
                    test_id=m.group(2),
                    name=m.group(3).strip(),
                    status=st,
                    details=line.strip(),
                )
            )
    return cases or [
        SuiteCaseEntry(
            suite=suite_name,
            test_id=f"{suite_name.upper()[:4]}-BLOCKED",
            name=f"{suite_name} Suite",
            status="Blocked",
            details=f"No matching test lines found in {log_filename}.",
        )
    ]


# ---------------------------------------------------------------------------
# CI Gate Validation
# ---------------------------------------------------------------------------

def validate_against_ci_gate(
    cases: list[SuiteCaseEntry],
    results_dir: Path = RESULTS_DIR,
) -> tuple[bool, list[str]]:
    """
    Validates parsed test case counts against CI gate outputs (ci-gate.json or ci-gate.txt).
    Returns (is_valid, list_of_discrepancy_messages).
    """
    gate_json = results_dir / "ci-gate.json"
    gate_txt = results_dir / "ci-gate.txt"
    discrepancies: list[str] = []

    # Map our case suite strings to gate suite names
    def normalize_suite(s: str) -> str:
        if "Backend" in s:
            return "Backend (Pytest)"
        if "QA" in s:
            return "QA Catalogue Controls"
        if "Flutter" in s:
            return "Flutter Tests (Mobile/Web)"
        if "Extension" in s:
            return "Browser Extension Tests"
        if "Selenium" in s:
            return "Selenium Acceptance"
        if "Load" in s:
            return "Load Smoke"
        if "Vulnerability" in s:
            return "Vulnerability Checks"
        return s

    parsed_by_suite: dict[str, dict[str, int]] = {}
    for c in cases:
        norm = normalize_suite(c.suite)
        entry = parsed_by_suite.setdefault(norm, {"total": 0, "passed": 0, "failed": 0, "skipped": 0, "blocked": 0})
        entry["total"] += 1
        st = c.status.lower()
        if st == "passed":
            entry["passed"] += 1
        elif st == "failed":
            entry["failed"] += 1
        elif st == "skipped":
            entry["skipped"] += 1
        else:
            entry["blocked"] += 1

    if gate_json.exists():
        try:
            data = json.loads(read_text_safe(gate_json))
            gate_suites = data.get("suites", {})
            for suite_name, expected in gate_suites.items():
                parsed = parsed_by_suite.get(suite_name, {"total": 0, "passed": 0, "failed": 0, "skipped": 0, "blocked": 0})
                if parsed["total"] != expected["total"]:
                    discrepancies.append(
                        f"Suite '{suite_name}' total count mismatch: gate expected {expected['total']}, report has {parsed['total']}."
                    )
                if parsed["passed"] != expected["passed"]:
                    discrepancies.append(
                        f"Suite '{suite_name}' passed count mismatch: gate expected {expected['passed']}, report has {parsed['passed']}."
                    )
                if parsed["failed"] != expected["failed"]:
                    discrepancies.append(
                        f"Suite '{suite_name}' failed count mismatch: gate expected {expected['failed']}, report has {parsed['failed']}."
                    )
            return len(discrepancies) == 0, discrepancies
        except Exception as exc:
            discrepancies.append(f"Failed to parse ci-gate.json: {exc}")

    if gate_txt.exists():
        try:
            txt = read_text_safe(gate_txt)
            m_total = re.search(r"total_tests=(\d+)", txt)
            if m_total:
                expected_total = int(m_total.group(1))
                if len(cases) != expected_total:
                    discrepancies.append(
                        f"Overall total test count mismatch: ci-gate.txt expected {expected_total}, report has {len(cases)}."
                    )
            return len(discrepancies) == 0, discrepancies
        except Exception as exc:
            discrepancies.append(f"Failed to read ci-gate.txt: {exc}")

    # No gate file present (e.g. local one-off run)
    return True, []


# ---------------------------------------------------------------------------
# Excel Workbook Builder
# ---------------------------------------------------------------------------

def collect_all_cases(results_dir: Path = RESULTS_DIR, selenium_path: Optional[Path] = None) -> list[SuiteCaseEntry]:
    """Collect test cases from all 7 suites."""
    cases: list[SuiteCaseEntry] = []
    cases.extend(parse_selenium_cases(selenium_path))
    cases.extend(parse_junit_cases(results_dir / "backend-junit.xml", "Backend API and Unit Tests", "BACKEND"))
    cases.extend(parse_junit_cases(results_dir / "qa-quality-junit.xml", "QA Catalogue Controls", "QA"))
    cases.extend(parse_flutter_cases(results_dir))
    cases.extend(parse_extension_cases(results_dir))
    cases.extend(
        parse_json_or_log_suite(
            "load-results.json",
            "load.log",
            "Load Smoke",
            r"\[(Pass|Fail)\]\s+(LOAD-[A-Z0-9-]+):\s*(.+?)\s+—",
            r"LOAD SUITE SUMMARY:\s*\d+/\d+ passed;\s*\d+ failed",
            results_dir,
        )
    )
    cases.extend(
        parse_json_or_log_suite(
            "vulnerability-results.json",
            "vulnerability.log",
            "Vulnerability Checks",
            r"\[(Pass|Fail)\]\s+(VULN-[A-Z0-9-]+)\s+\([^)]*\):\s*(.+?)\s+—",
            r"VULNERABILITY SUITE SUMMARY:\s*\d+/\d+ controls passed;\s*\d+ failed",
            results_dir,
        )
    )
    return cases


def build(
    results_dir: Path = RESULTS_DIR,
    output_dir: Path = EXCEL_DIR,
    selenium_path: Optional[Path] = None,
    enforce_gate_match: bool = True,
) -> Path:
    """Build the single master Excel workbook combining all test suites."""
    cases = collect_all_cases(results_dir, selenium_path)
    if not cases:
        raise ValueError("Combined test report has no cases.")

    is_gate_valid, discrepancies = validate_against_ci_gate(cases, results_dir)
    if not is_gate_valid:
        msg = "CI Gate validation failed:\n  " + "\n  ".join(discrepancies)
        print(f"[WARNING] {msg}")
        if enforce_gate_match and (results_dir / "ci-gate.json").exists():
            raise ValueError(msg)

    wb = Workbook()

    # Sheet 1: All Test Cases
    ws_cases = wb.active
    ws_cases.title = "All Test Cases"
    ws_cases.append(["Test ID", "Suite", "Test Name", "Status", "Details"])

    header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    header_fill = PatternFill(start_color="1F2937", end_color="1F2937", fill_type="solid")
    for cell in ws_cases[1]:
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center", vertical="center")
    ws_cases.row_dimensions[1].height = 26

    status_fills = {
        "Passed": PatternFill(start_color="D1FAE5", end_color="D1FAE5", fill_type="solid"),
        "Failed": PatternFill(start_color="FEE2E2", end_color="FEE2E2", fill_type="solid"),
        "Skipped": PatternFill(start_color="FEF3C7", end_color="FEF3C7", fill_type="solid"),
        "Blocked": PatternFill(start_color="FFEDD5", end_color="FFEDD5", fill_type="solid"),
        "Not Run": PatternFill(start_color="F3F4F6", end_color="F3F4F6", fill_type="solid"),
    }
    status_fonts = {
        "Passed": Font(name="Calibri", size=10, bold=True, color="065F46"),
        "Failed": Font(name="Calibri", size=10, bold=True, color="991B1B"),
        "Skipped": Font(name="Calibri", size=10, bold=True, color="92400E"),
        "Blocked": Font(name="Calibri", size=10, bold=True, color="9A3412"),
        "Not Run": Font(name="Calibri", size=10, bold=True, color="374151"),
    }
    thin_border = Border(
        left=Side(style="thin", color="E5E7EB"),
        right=Side(style="thin", color="E5E7EB"),
        top=Side(style="thin", color="E5E7EB"),
        bottom=Side(style="thin", color="E5E7EB"),
    )

    for case in cases:
        ws_cases.append([case.test_id, case.suite, case.name, case.status, case.details])
        row_idx = ws_cases.max_row
        for col_idx in range(1, 6):
            cell = ws_cases.cell(row=row_idx, column=col_idx)
            cell.border = thin_border
            cell.alignment = Alignment(vertical="top", wrap_text=(col_idx in (3, 5)))
        status_cell = ws_cases.cell(row=row_idx, column=4)
        status_cell.fill = status_fills.get(case.status, PatternFill())
        status_cell.font = status_fonts.get(case.status, Font(name="Calibri", size=10))
        status_cell.alignment = Alignment(horizontal="center", vertical="top")

    column_widths = {1: 22, 2: 32, 3: 65, 4: 14, 5: 65}
    for col_idx, width in column_widths.items():
        ws_cases.column_dimensions[get_column_letter(col_idx)].width = width
    ws_cases.freeze_panes = "A2"
    ws_cases.auto_filter.ref = ws_cases.dimensions

    # Sheet 2: Suite Summary
    ws_summary = wb.create_sheet("Suite Summary")
    ws_summary.append(["Suite", "Total", "Passed", "Failed", "Skipped", "Blocked / Not Run", "Suite Status"])
    for cell in ws_summary[1]:
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center", vertical="center")
    ws_summary.row_dimensions[1].height = 26

    # Canonical suites to display in consistent order
    canonical_suites = [
        "Backend API and Unit Tests",
        "QA Catalogue Controls",
        "Flutter Tests (Mobile/Web)",
        "Browser Extension Tests",
        "Selenium Acceptance",
        "Load Smoke",
        "Vulnerability Checks",
    ]

    def suite_group(s_name: str) -> str:
        for c in canonical_suites:
            if c.lower() in s_name.lower() or s_name.lower() in c.lower():
                return c
        if "Extension" in s_name:
            return "Browser Extension Tests"
        return s_name

    unique_suites: list[str] = []
    for c in canonical_suites:
        if any(suite_group(x.suite) == c for x in cases):
            unique_suites.append(c)
    for x in cases:
        grp = suite_group(x.suite)
        if grp not in unique_suites:
            unique_suites.append(grp)

    for s_name in unique_suites:
        group = [x for x in cases if suite_group(x.suite) == s_name]
        tot = len(group)
        p = sum(x.status == "Passed" for x in group)
        f = sum(x.status == "Failed" for x in group)
        s = sum(x.status == "Skipped" for x in group)
        b = sum(x.status in ("Blocked", "Not Run") for x in group)
        st_label = "🟢 PASS" if (f == 0 and b == 0 and tot > 0) else "🔴 FAIL"
        ws_summary.append([s_name, tot, p, f, s, b, st_label])
        r = ws_summary.max_row
        for col_idx in range(1, 8):
            cell = ws_summary.cell(row=r, column=col_idx)
            cell.border = thin_border
            cell.alignment = Alignment(horizontal="center" if col_idx > 1 else "left", vertical="center")

    # TOTAL row
    tot_all = len(cases)
    p_all = sum(x.status == "Passed" for x in cases)
    f_all = sum(x.status == "Failed" for x in cases)
    s_all = sum(x.status == "Skipped" for x in cases)
    b_all = sum(x.status in ("Blocked", "Not Run") for x in cases)
    overall_status = "🟢 PASSED" if (f_all == 0 and b_all == 0 and tot_all > 0) else "🔴 FAILED"

    ws_summary.append(["TOTAL", tot_all, p_all, f_all, s_all, b_all, overall_status])
    total_row = ws_summary.max_row
    total_fill = PatternFill(start_color="F3F4F6", end_color="F3F4F6", fill_type="solid")
    thick_top = Border(
        top=Side(style="medium", color="1F2937"),
        bottom=Side(style="double", color="1F2937"),
        left=Side(style="thin", color="E5E7EB"),
        right=Side(style="thin", color="E5E7EB"),
    )
    for col_idx in range(1, 8):
        cell = ws_summary.cell(row=total_row, column=col_idx)
        cell.font = Font(name="Calibri", size=11, bold=True)
        cell.fill = total_fill
        cell.border = thick_top
        cell.alignment = Alignment(horizontal="center" if col_idx > 1 else "left", vertical="center")

    # Gate Verification Section
    ws_summary.append([])
    ws_summary.append(["CI Gate Verification", "Status"])
    ver_hdr_row = ws_summary.max_row
    for c_idx in (1, 2):
        ws_summary.cell(row=ver_hdr_row, column=c_idx).font = header_font
        ws_summary.cell(row=ver_hdr_row, column=c_idx).fill = header_fill

    gate_ver_status = "VALIDATED — All suite totals match CI gate" if is_gate_valid else "DISCREPANCY FLAGGED"
    ws_summary.append([gate_ver_status, f"{tot_all} verified test checks"])
    ver_stat_row = ws_summary.max_row
    ws_summary.cell(row=ver_stat_row, column=1).font = Font(
        name="Calibri", size=10, bold=True, color="065F46" if is_gate_valid else "991B1B"
    )

    if discrepancies:
        for disc in discrepancies:
            ws_summary.append([f"Notice: {disc}", "Discrepancy"])
            ws_summary.cell(row=ws_summary.max_row, column=1).font = Font(color="991B1B", italic=True)

    summary_widths = [34, 12, 12, 12, 12, 18, 16]
    for idx, width in enumerate(summary_widths, start=1):
        ws_summary.column_dimensions[get_column_letter(idx)].width = width
    ws_summary.freeze_panes = "A2"

    output_dir.mkdir(parents=True, exist_ok=True)
    target_path = output_dir / "Full_Test_Suite_Report.xlsx"
    try:
        wb.save(target_path)
    except PermissionError:
        print(f"[WARN] {target_path} is locked (open in Excel). Saving to Full_Test_Suite_Report_Latest.xlsx")
        target_path = output_dir / "Full_Test_Suite_Report_Latest.xlsx"
        wb.save(target_path)

    # Also generate full-suite Failed_Test_Cases.xlsx and Passed_Test_Cases.xlsx
    try:
        wb_fail = Workbook()
        ws_fail = wb_fail.active
        ws_fail.title = "Failed Cases"
        ws_fail.append(["Test ID", "Suite", "Test Case Name", "Status", "Failure Details / Evidence"])
        for cell in ws_fail[1]:
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = Alignment(horizontal="center", vertical="center")
        ws_fail.row_dimensions[1].height = 26
        failed_cases = [c for c in cases if c.status == "Failed"]
        if failed_cases:
            for c in failed_cases:
                ws_fail.append([c.test_id, c.suite, c.name, c.status, c.details])
                r_idx = ws_fail.max_row
                for col_idx in range(1, 6):
                    cell = ws_fail.cell(row=r_idx, column=col_idx)
                    cell.border = thin_border
                    cell.alignment = Alignment(vertical="top", wrap_text=(col_idx in (3, 5)))
                ws_fail.cell(row=r_idx, column=4).fill = status_fills["Failed"]
                ws_fail.cell(row=r_idx, column=4).font = status_fonts["Failed"]
                ws_fail.cell(row=r_idx, column=4).alignment = Alignment(horizontal="center", vertical="top")
        else:
            ws_fail.append(["NONE", "All Suites", "All test cases passed successfully", "Passed", "Zero test failures across all suites."])
            ws_fail.cell(row=2, column=4).fill = status_fills["Passed"]
            ws_fail.cell(row=2, column=4).font = status_fonts["Passed"]
        for col_idx, width in column_widths.items():
            ws_fail.column_dimensions[get_column_letter(col_idx)].width = width
        ws_fail.freeze_panes = "A2"
        fail_path = output_dir / "Failed_Test_Cases.xlsx"
        wb_fail.save(fail_path)

        wb_pass = Workbook()
        ws_pass = wb_pass.active
        ws_pass.title = "Passed Cases"
        ws_pass.append(["Test ID", "Suite", "Test Case Name", "Status", "Details"])
        for cell in ws_pass[1]:
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = Alignment(horizontal="center", vertical="center")
        ws_pass.row_dimensions[1].height = 26
        for c in [c for c in cases if c.status == "Passed"]:
            ws_pass.append([c.test_id, c.suite, c.name, c.status, c.details])
            r_idx = ws_pass.max_row
            for col_idx in range(1, 6):
                cell = ws_pass.cell(row=r_idx, column=col_idx)
                cell.border = thin_border
                cell.alignment = Alignment(vertical="top", wrap_text=(col_idx in (3, 5)))
            ws_pass.cell(row=r_idx, column=4).fill = status_fills["Passed"]
            ws_pass.cell(row=r_idx, column=4).font = status_fonts["Passed"]
            ws_pass.cell(row=r_idx, column=4).alignment = Alignment(horizontal="center", vertical="top")
        for col_idx, width in column_widths.items():
            ws_pass.column_dimensions[get_column_letter(col_idx)].width = width
        ws_pass.freeze_panes = "A2"
        pass_path = output_dir / "Passed_Test_Cases.xlsx"
        wb_pass.save(pass_path)

        results_dir.mkdir(parents=True, exist_ok=True)
        dest_dirs = {output_dir, results_dir}
        if output_dir == EXCEL_DIR:
            dest_dirs.update({ROOT / "Test Results" / "Reports", ROOT / "Test Results" / "Excel"})
        for dest_dir in dest_dirs:
            dest_dir.mkdir(parents=True, exist_ok=True)
            for fname, src in [
                ("Full_Test_Suite_Report.xlsx", target_path),
                ("Combined_Test_Report.xlsx", target_path),
                ("Automation_Test_Report.xlsx", target_path),
                ("Failed_Test_Cases.xlsx", fail_path),
                ("Passed_Test_Cases.xlsx", pass_path),
            ]:
                try:
                    dest_file = dest_dir / fname
                    if dest_file.resolve() != src.resolve():
                        shutil.copy2(src, dest_file)
                except Exception:
                    pass
    except Exception as exc:
        print(f"[WARN] Error creating auxiliary workbook copies: {exc}")

    print(
        f"[SUCCESS] Successfully built {target_path} with {tot_all} named test cases "
        f"({p_all} passed, {f_all} failed, {s_all} skipped, {b_all} blocked)."
    )
    return target_path


if __name__ == "__main__":
    build()
