"""
pytest conftest.py — Session fixtures, test lifecycle hooks, and result tracking
for FocusEcho E2E Appium Framework.
"""

import sys
import time
import pytest
import logging
from datetime import datetime
from pathlib import Path

# Add automation root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from drivers.appium_driver import DriverFactory
from utils.screenshot_utils import ScreenshotUtils
from utils.log_utils import setup_logger, save_logcat_for_test
from utils.excel_reporter import ExcelReporter, generate_all_reports
from utils.html_reporter import HtmlReporter
from utils.json_reporter import JsonReporter, SummaryReporter
from config.test_config import BUILD_NUMBER, DEVICE_NAME, ANDROID_VERSION

logger = setup_logger("conftest")

# ─────────────────────────────────────────────────────────────────────────────
# Session-level result store
# ─────────────────────────────────────────────────────────────────────────────
_test_results: list[dict] = []
_session_start: float = 0.0


# ─────────────────────────────────────────────────────────────────────────────
# Fixtures
# ─────────────────────────────────────────────────────────────────────────────

@pytest.fixture(scope="session")
def appium_driver():
    """
    Session-scoped Appium driver.
    Shared across all tests in a session to avoid repeated app launches.
    Use `function_driver` fixture for tests that need a fresh session.
    """
    global _session_start
    _session_start = time.time()
    logger.info(f"🚀 Starting Appium session | Build: {BUILD_NUMBER} | Device: {DEVICE_NAME}")

    driver = DriverFactory.create_driver()
    yield driver

    logger.info("🛑 Terminating session Appium driver.")
    DriverFactory.quit_driver(driver)


@pytest.fixture(scope="function")
def driver(appium_driver):
    """
    Function-scoped driver wrapper.
    Restarts the app before each test for isolation.
    """
    DriverFactory.restart_app(appium_driver)
    time.sleep(2)
    yield appium_driver


@pytest.fixture(scope="function")
def fresh_driver():
    """
    Function-scoped driver with a completely fresh session (fullReset).
    Use for onboarding/auth tests that need clean app state.
    """
    driver = DriverFactory.create_driver(no_reset=False)
    time.sleep(3)
    yield driver
    DriverFactory.quit_driver(driver)


@pytest.fixture(scope="function")
def stateful_driver():
    """
    Function-scoped driver keeping existing app data (noReset=True).
    Use for tests that need to build on previous state.
    """
    driver = DriverFactory.create_driver(no_reset=True)
    time.sleep(2)
    yield driver
    DriverFactory.quit_driver(driver)


@pytest.fixture(autouse=True)
def test_metadata(request):
    """Auto-use fixture that tracks test start/end and records results."""
    test_id = request.node.get_closest_marker("test_id")
    tc_id = test_id.args[0] if test_id else request.node.name

    module_marker = request.node.get_closest_marker("module")
    module = module_marker.args[0] if module_marker else "General"

    priority_marker = request.node.get_closest_marker("priority")
    priority = priority_marker.args[0] if priority_marker else "P3"

    start_time = time.time()
    yield

    duration = round(time.time() - start_time, 2)
    rep = getattr(request.node, "_test_report", None)
    if rep is None:
        return

    status = "PASS" if rep.passed else ("FAIL" if rep.failed else "SKIP")
    error_msg = ""
    screenshot_path = ""

    if rep.failed:
        error_msg = str(rep.longrepr)[:500] if rep.longrepr else ""
        # Capture screenshot on failure
        driver_fixture = request.node.funcargs.get("driver") or request.node.funcargs.get("fresh_driver")
        if driver_fixture:
            screenshot_path = ScreenshotUtils.capture_on_failure(driver_fixture, tc_id, request.node.name)
            save_logcat_for_test(tc_id)

    _test_results.append({
        "test_id": tc_id,
        "module": module,
        "name": request.node.name,
        "priority": priority,
        "status": status,
        "duration": duration,
        "error_message": error_msg,
        "screenshot_path": screenshot_path,
        "timestamp": datetime.now().isoformat(),
    })


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """Capture test report in the node for use in test_metadata fixture."""
    outcome = yield
    rep = outcome.get_result()
    if call.when == "call":
        item._test_report = rep


# ─────────────────────────────────────────────────────────────────────────────
# Session-end: Generate All Reports
# ─────────────────────────────────────────────────────────────────────────────

def pytest_sessionfinish(session, exitstatus):
    """Generate all reports after the full test session completes."""
    if not _test_results:
        logger.warning("No test results to report.")
        return

    total_duration = round(time.time() - _session_start, 2)
    logger.info(f"\n{'='*60}")
    logger.info(f"📊 Generating Reports | {len(_test_results)} tests | {total_duration}s")
    logger.info(f"{'='*60}")

    try:
        # Excel Reports
        generate_all_reports(_test_results)

        # HTML Reports
        html = HtmlReporter(_test_results)
        html.generate()

        # JSON Report
        json_rep = JsonReporter(_test_results)
        json_rep.generate()

        # Markdown Summary (also writes to GITHUB_STEP_SUMMARY)
        summary = SummaryReporter(_test_results)
        summary.generate()
        summary.write_github_step_summary()

        passed = sum(1 for r in _test_results if r["status"].upper() in ("PASS", "PASSED"))
        failed = sum(1 for r in _test_results if r["status"].upper() in ("FAIL", "FAILED"))
        pass_rate = round(passed / len(_test_results) * 100, 1) if _test_results else 0

        logger.info(f"✅ Reports generated.")
        logger.info(f"   Total: {len(_test_results)} | Passed: {passed} | Failed: {failed} | Pass Rate: {pass_rate}%")

    except Exception as exc:
        logger.error(f"Report generation failed: {exc}")
        import traceback
        traceback.print_exc()


# ─────────────────────────────────────────────────────────────────────────────
# Custom Markers Registration
# ─────────────────────────────────────────────────────────────────────────────

def pytest_configure(config):
    config.addinivalue_line("markers", "test_id(id): Test case identifier (e.g. TC_AUTH_001)")
    config.addinivalue_line("markers", "module(name): Feature module name")
    config.addinivalue_line("markers", "priority(level): Test priority P1/P2/P3")
    config.addinivalue_line("markers", "smoke: Quick smoke test")
    config.addinivalue_line("markers", "regression: Full regression test")
    config.addinivalue_line("markers", "auth: Authentication tests")
    config.addinivalue_line("markers", "onboarding: Onboarding flow tests")
    config.addinivalue_line("markers", "dashboard: Dashboard tests")
    config.addinivalue_line("markers", "focus_session: Focus session tests")
    config.addinivalue_line("markers", "analytics: Analytics screen tests")
    config.addinivalue_line("markers", "streaks: Streaks and XP tests")
    config.addinivalue_line("markers", "settings: Settings screen tests")
    config.addinivalue_line("markers", "navigation: Navigation tests")
    config.addinivalue_line("markers", "validation: Input validation tests")
    config.addinivalue_line("markers", "error_handling: Error handling tests")
    config.addinivalue_line("markers", "performance: Performance smoke tests")
    config.addinivalue_line("markers", "accessibility: Accessibility tests")
