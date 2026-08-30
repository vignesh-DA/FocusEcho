"""
Test Configuration for FocusEcho Appium E2E Framework
"""

import os
from pathlib import Path

# ─────────────────────────────────────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────────────────────────────────────
AUTOMATION_ROOT = Path(__file__).parent.parent
REPORTS_DIR = AUTOMATION_ROOT / "reports"
SCREENSHOTS_DIR = REPORTS_DIR / "Screenshots"
LOGS_DIR = REPORTS_DIR / "Logs"
EXCEL_DIR = REPORTS_DIR / "Excel"
HTML_DIR = REPORTS_DIR / "HTML"
JSON_DIR = REPORTS_DIR / "JSON"
SUMMARY_DIR = REPORTS_DIR / "Summary"

# Ensure directories exist
for _dir in [REPORTS_DIR, SCREENSHOTS_DIR, LOGS_DIR, EXCEL_DIR, HTML_DIR, JSON_DIR, SUMMARY_DIR]:
    _dir.mkdir(parents=True, exist_ok=True)

# ─────────────────────────────────────────────────────────────────────────────
# Timeouts (seconds)
# ─────────────────────────────────────────────────────────────────────────────
IMPLICIT_WAIT = 10
EXPLICIT_WAIT = 20
PAGE_LOAD_TIMEOUT = 30
ANIMATION_TIMEOUT = 3
SPLASH_TIMEOUT = 10       # Splash redirects in ~2–3 seconds
PERFORMANCE_THRESHOLD_S = 3.0  # Screen must load in under 3 seconds

# ─────────────────────────────────────────────────────────────────────────────
# Retry
# ─────────────────────────────────────────────────────────────────────────────
MAX_RETRIES = 2
RETRY_DELAY_S = 2

# ─────────────────────────────────────────────────────────────────────────────
# App Info
# ─────────────────────────────────────────────────────────────────────────────
APP_NAME = "Focus Echo AI"
APP_VERSION = "1.0.0"
APP_PACKAGE = "com.focusecho.ai"

# ─────────────────────────────────────────────────────────────────────────────
# Build Metadata (injected by CI)
# ─────────────────────────────────────────────────────────────────────────────
BUILD_NUMBER = os.getenv("BUILD_NUMBER", "local")
GIT_COMMIT = os.getenv("GITHUB_SHA", "local")[:8]
BRANCH = os.getenv("GITHUB_REF_NAME", "local")
DEVICE_NAME = os.getenv("DEVICE_NAME", "emulator-5554")
ANDROID_VERSION = os.getenv("PLATFORM_VERSION", "13.0")

# ─────────────────────────────────────────────────────────────────────────────
# Parallel Execution
# ─────────────────────────────────────────────────────────────────────────────
PARALLEL_WORKERS = int(os.getenv("PARALLEL_WORKERS", "1"))

# ─────────────────────────────────────────────────────────────────────────────
# Reporting
# ─────────────────────────────────────────────────────────────────────────────
EXCEL_REPORT_NAME = "Automation_Test_Report.xlsx"
HTML_REPORT_NAME = "execution-report.html"
JSON_REPORT_NAME = "execution-results.json"
DASHBOARD_REPORT_NAME = "dashboard.html"
TRENDS_REPORT_NAME = "trends.html"
SUMMARY_REPORT_NAME = "summary.md"

# History — used by GitHub Pages deployment
HISTORY_DIR = REPORTS_DIR / "history"
HISTORY_DIR.mkdir(parents=True, exist_ok=True)

# ─────────────────────────────────────────────────────────────────────────────
# Failure Criteria
# ─────────────────────────────────────────────────────────────────────────────
MAX_CRITICAL_FAILURE_PERCENT = 5  # Workflow FAILS if > 5% critical tests fail
PASS_RATE_THRESHOLD = 95           # Workflow PASSES if pass% >= 95
