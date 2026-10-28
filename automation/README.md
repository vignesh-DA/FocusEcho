# ⚡ FocusEcho Enterprise E2E Selenium Automation Framework

Enterprise-grade automated UI testing suite designed for **Phase 7: Live CI/CD Deployment & E2E Testing**.

This framework executes **470+ automated test cases** across 14 functional categories against the **LIVE GitHub Pages deployment** (`https://<username>.github.io/<repository-name>/`). It enforces strict quality gates, generates multi-sheet styled Excel workbooks, interactive glassmorphic HTML dashboards, and publishes instant summaries to GitHub Actions.

---

## 📁 Architecture & Folder Structure

```text
automation/
├── config/
│   ├── __init__.py
│   └── config.py               # Central environment configuration & BASE_URL resolution
├── drivers/
│   ├── __init__.py
│   └── driver_factory.py        # Headless Chrome WebDriver factory with console log capturing
├── utils/
│   ├── __init__.py
│   ├── logger.py               # Structured console & persistent file logger
│   ├── screenshot.py           # Automated failure screenshot & thumbnail encoder
│   ├── wait_utils.py           # Explicit waits & retry logic
│   └── deployment_verifier.py  # Stage 7 live deployment readiness verifier
├── pages/
│   ├── __init__.py
│   ├── base_page.py            # Base Page Object Model with URL resolution
│   ├── auth_page.py            # Authentication & Role Gate POM
│   ├── timer_page.py           # Focus Timer state machine POM
│   ├── navigation_page.py      # App navigation & deep hash linking POM
│   ├── parking_lot_page.py     # Mind Parking Lot CRUD POM
│   ├── analytics_page.py       # Telemetry metrics & charts POM
│   ├── reflection_page.py      # Post-session evaluation form POM
│   ├── settings_page.py        # Profile & File upload dropzone POM
│   └── accessibility_page.py   # WCAG ARIA & Responsive layout POM
├── data/
│   ├── test_data.py            # Centralized test inputs, XSS vectors, and boundaries
│   ├── sample_sessions.json    # Test dataset for backup file import
│   └── test_avatar.png         # Binary image for avatar upload testing
├── tests/
│   ├── __init__.py             # Master test suite aggregator
│   ├── test_01_authentication.py     # 40 Test Cases (TC-AUTH-001 to 040)
│   ├── test_02_authorization.py       # 40 Test Cases (TC-AUTHZ-001 to 040)
│   ├── test_03_navigation.py          # 30 Test Cases (TC-NAV-001 to 030)
│   ├── test_04_ui_validation.py       # 50 Test Cases (TC-UI-001 to 050)
│   ├── test_05_forms.py               # 50 Test Cases (TC-FORM-001 to 050)
│   ├── test_06_crud_operations.py     # 50 Test Cases (TC-CRUD-001 to 050)
│   ├── test_07_input_validation.py    # 40 Test Cases (TC-INPUT-001 to 040)
│   ├── test_08_error_handling.py      # 20 Test Cases (TC-ERR-001 to 020)
│   ├── test_09_session_management.py  # 20 Test Cases (TC-SESS-001 to 020)
│   ├── test_10_file_upload.py         # 20 Test Cases (TC-UPLOAD-001 to 020)
│   ├── test_11_accessibility.py       # 20 Test Cases (TC-A11Y-001 to 020)
│   ├── test_12_responsive_design.py   # 20 Test Cases (TC-RESP-001 to 020)
│   ├── test_13_performance_smoke.py   # 20 Test Cases (TC-PERF-001 to 020)
│   └── test_14_regression.py          # 50 Test Cases (TC-REG-001 to 050)
├── reports/
│   ├── excel_reporter.py       # Openpyxl 6-sheet styled Excel workbook generator
│   ├── html_reporter.py        # Glassmorphic execution report & dashboard generator
│   └── summary_generator.py    # GitHub Actions Step Summary generator
└── runner.py                   # Master test execution orchestrator & quality gate
```

---

## 📊 Test Categories & Coverage Summary

| # | Test Module | Category ID Prefix | Test Cases | Execution Scope |
|---|---|---|---|---|
| 1 | **Authentication** | `TC-AUTH-` | 40 | Email OTP, guest sessions, validation, logout, token handling |
| 2 | **Authorization** | `TC-AUTHZ-` | 40 | Free Tier vs Pro RBAC, feature gates, upgrade modal, permissions |
| 3 | **Navigation** | `TC-NAV-` | 30 | Topbar, sidebar, deep hash routing, breadcrumbs, drawer toggle |
| 4 | **UI Validation** | `TC-UI-` | 50 | Glassmorphic cards, themes (dark/light), metric trends, weekly chart |
| 5 | **Forms** | `TC-FORM-` | 50 | Timer setup, reflection feedback, user profile, EchoCoach prompts |
| 6 | **CRUD Operations** | `TC-CRUD-` | 50 | Parking Lot create/read/update/delete, search, filter chips, history |
| 7 | **Input Validation** | `TC-INPUT-` | 40 | Maxlengths, XSS sanitization, SQL injection resilience, unicode |
| 8 | **Error Handling** | `TC-ERR-` | 20 | Outage simulation, offline banners, reconnects, inline form errors |
| 9 | **Session Management** | `TC-SESS-` | 20 | State machine (IDLE/RUNNING/PAUSED/COMPLETED), presets, countdown |
| 10 | **File Upload** | `TC-UPLOAD-` | 20 | Avatar upload preview, JSON session import dropzone, CSV export |
| 11 | **Accessibility** | `TC-A11Y-` | 20 | ARIA landmarks, `role` tags, `aria-live`, skip-to-content links |
| 12 | **Responsive Design** | `TC-RESP-` | 20 | Mobile (375px), Tablet (768px), Desktop (1920px), off-canvas layout |
| 13 | **Performance Smoke** | `TC-PERF-` | 20 | DOM readiness, navigation timing API, asset latency thresholds |
| 14 | **Regression** | `TC-REG-` | 50 | Full end-to-end user journeys, state retention across sections |
| **Total** | **All Modules** | — | **470+** | **100% Executable Coverage** |

---

## 🚀 Execution Instructions

### 1. Prerequisites
- Python 3.10+ (Tested on Python 3.12 / 3.14)
- Google Chrome browser (Headless mode enabled by default)
- Dependencies installed:
```bash
pip install selenium==4.48.0 openpyxl==3.1.5 requests beautifulsoup4 pytest==8.3.5
```

### 2. Live GitHub Pages Execution (Mandatory in CI)
Set `BASE_URL` to the live GitHub Pages deployment URL:
```bash
# Windows PowerShell
$env:BASE_URL = "https://vignesh-DA.github.io/FocusEcho/"
python -m automation.runner

# Linux / macOS / GitHub Actions
export BASE_URL="https://vignesh-DA.github.io/FocusEcho/"
python -m automation.runner
```

### 3. Local Offline Validation (Dry Run)
Before pushing, build the static web application and run locally:
```bash
python scripts/build_web.py
python -m automation.runner
```

---

## 📈 Quality Gate Pass / Fail Policy

The framework enforces automated CI/CD quality gates:
1. **Deployment Gate**: Fails immediately if Stage 7 deployment validation fails (non-200 HTTP code or missing assets).
2. **Critical Failure Gate**: Fails if **>5.0%** of Critical priority test cases fail.
3. **Overall Pass Gate**: Fails if overall test pass percentage is **<95.0%**.
4. **Success Condition**: Deploys cleanly AND overall pass rate is **≥95.0%**.
