# FocusEcho Browser Acceptance Tests

This Selenium suite contains ten distinct cases for the legacy static web experience published at the selected GitHub Pages URL. It replaces the former generated catalogue, whose duplicate cases and action-only predicates could report success without checking an outcome.

The Flutter application, FastAPI backend, and browser extension retain their own test suites under `mobile_app/test`, `backend/app/tests`, and `browser_extension/tests`. The unified case catalogue and the mapping to those existing suites are in [`docs/QA_TEST_CASE_CATALOGUE.md`](../docs/QA_TEST_CASE_CATALOGUE.md).

## Requirements

- Python 3.10 or newer
- Selenium 4.48 or newer
- Chrome with a compatible driver, or Microsoft Edge with a compatible driver
- The selected target must be reachable

Install the browser and report dependencies from the repository root:

```powershell
python -m pip install -r automation/requirements.txt
```

## Run against the local web build

Start the static app from the repository root:

```powershell
python -m http.server 8081 --directory web
```

In a second PowerShell window:

```powershell
$env:TEST_ENV = "local"
$env:BASE_URL = "http://127.0.0.1:8081/"
$env:BROWSER = "edge"
python -m automation.runner
```

Set `BROWSER` to `chrome` if Chrome is available. Local mode rejects non-loopback URLs to prevent accidental production requests.

## Run the safe browser cases against GitHub Pages

The browser acceptance suite uses synthetic input and browser-local state only:

```powershell
$env:TEST_ENV = "production"
$env:BASE_URL = "https://vignesh-DA.github.io/FocusEcho/"
$env:BROWSER = "edge"
python -m automation.runner
```

Production authentication probes that test OTP verification are documented separately and must use a reserved synthetic identity. Load tests, data mutation, and active vulnerability payloads are not part of this production Selenium run.

## Run local backend load and vulnerability smoke checks

These runners use FastAPI `TestClient` and mocked persistence. They validate request handling and authorization boundaries in-process; they do not measure Supabase or production capacity.

```powershell
python automation/load/runner.py
python automation/vulnerability/runner.py
```

The load runner reports throughput and latency with local smoke budgets (P95 1,000 ms for ordinary requests and 2,000 ms for a 500-event batch). Treat these numbers as local regression signals, not production SLAs. The vulnerability runner is a small local probe suite, not an external penetration test.

Run the QA catalogue and CI-gate controls with:

```powershell
python -m pytest automation/test_quality_controls.py automation/tests/test_full_suite_report.py -q
```

## Combined Full-Suite Excel Report

To generate the combined master Excel workbook covering all suites (Selenium, Backend, Flutter, Browser Extension, QA Controls, Load Smoke, Vulnerability):

```powershell
python -m automation.reports.full_suite_excel_report
```

Output files:
- Combined Full-Suite: `Test Results/Excel/Full_Test_Suite_Report.xlsx` (also at `test-results/Full_Test_Suite_Report.xlsx`)
- Selenium Acceptance Only: `Test Results/Excel/Automation_Test_Report.xlsx` / `Selenium_Acceptance_Report.xlsx`

Both are automatically uploaded to GitHub Actions under artifact `focusecho-test-results`.

## Quality gate and evidence

- Every Selenium case must return the boolean `True` to pass. `None`, a click with no postcondition, and exceptions fail the case.
- The default pass threshold is 100%, with zero critical failures allowed.
- Test rows begin as `Not Run`; the runner assigns `Passed` or `Failed` only after evaluating the assertion.
- Machine-readable JSON, HTML diagnostics, screenshots for failures, and Excel summaries are written under `Test Results/`.
- A blocked browser/driver/deployment prerequisite is an infrastructure blocker, not a pass.

For the mobile and backend test strategy, load cases, vulnerability cases, evidence fields, and execution status, see the unified catalogue.
