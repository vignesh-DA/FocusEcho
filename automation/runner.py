"""
Enterprise Test Execution Orchestrator for FocusEcho Selenium Framework
Executes 400+ E2E test cases, tracks metrics, captures evidence,
generates Excel, HTML, JSON, and Step Summary artifacts, and enforces quality gates.
"""

import sys
import os
import json
import time

try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
from datetime import datetime
from automation.config.config import Config, JSON_DIR, RESULTS_ROOT
from automation.drivers.driver_factory import DriverFactory
from automation.utils.logger import logger
from automation.utils.screenshot import ScreenshotUtil
from automation.tests import SUITES
from automation.reports.excel_reporter import ExcelReporter
from automation.reports.html_reporter import HTMLReporter
from automation.reports.summary_generator import SummaryGenerator

def run_all_e2e_tests() -> int:
    """Execute the entire E2E test suite and generate all artifacts."""
    logger.info("=" * 70)
    logger.info("⚡ FOCUSECHO ENTERPRISE E2E SELENIUM AUTOMATION RUNNER")
    logger.info(f"Target BASE_URL: {Config.BASE_URL}")
    logger.info("=" * 70)

    # MANDATORY: Verify URL requirement
    try:
        Config.validate_url()
    except ValueError as val_err:
        logger.error(str(val_err))
        return 1

    driver = None
    all_results = []
    start_time = time.time()

    try:
        driver = DriverFactory.create_driver(headless=Config.HEADLESS)
        logger.info(f"Connected to browser session: {driver.session_id}")

        # Run each test suite sequentially
        for suite_name, suite_runner in SUITES:
            logger.info(f"\n--- Running Suite: {suite_name} ---")
            suite_start = time.time()
            suite_results = suite_runner(driver)
            suite_duration = time.time() - suite_start
            
            passed_count = sum(1 for r in suite_results if r.status == "Passed")
            logger.info(f"Completed {suite_name}: {passed_count}/{len(suite_results)} passed ({suite_duration:.2f}s)")
            
            # Post-process failures for screenshots and console logs
            for r in suite_results:
                if r.status == "Failed":
                    screenshot_path = ScreenshotUtil.capture_screenshot(driver, r.test_id)
                    if screenshot_path:
                        r.screenshot_path = str(screenshot_path)
                    r.console_logs = DriverFactory.get_browser_logs(driver)

            all_results.extend(suite_results)

    except Exception as exc:
        logger.critical(f"FATAL: Unhandled exception during E2E execution: {exc}", exc_info=True)
        return 1
    finally:
        if driver:
            try:
                driver.quit()
                logger.info("WebDriver session terminated gracefully.")
            except Exception:
                pass

    total_duration = time.time() - start_time
    total_tests = len(all_results)
    passed_tests = sum(1 for r in all_results if r.status == "Passed")
    failed_tests = sum(1 for r in all_results if r.status == "Failed")
    skipped_tests = sum(1 for r in all_results if r.status in ("Skipped", "Blocked"))
    pass_pct = (passed_tests / total_tests * 100) if total_tests else 0

    critical_tests = [r for r in all_results if r.priority == "Critical"]
    critical_failed = sum(1 for r in critical_tests if r.status == "Failed")
    critical_fail_pct = (critical_failed / len(critical_tests) * 100) if critical_tests else 0

    logger.info("\n" + "=" * 70)
    logger.info("EXECUTION SUMMARY")
    logger.info(f"Total Tests Executed: {total_tests}")
    logger.info(f"Passed: {passed_tests} | Failed: {failed_tests} | Skipped: {skipped_tests}")
    logger.info(f"Pass Percentage: {pass_pct:.2f}% (Threshold: {Config.PASS_PERCENTAGE_THRESHOLD}%)")
    logger.info(f"Critical Failures: {critical_failed}/{len(critical_tests)} ({critical_fail_pct:.2f}%, Max Allowed: {Config.MAX_CRITICAL_FAIL_PERCENTAGE}%)")
    logger.info(f"Total Execution Duration: {total_duration:.2f} seconds")
    logger.info("=" * 70)

    # 1. Generate JSON Results
    json_path = JSON_DIR / "execution-results.json"
    results_dict = {
        "metadata": {
            "base_url": Config.BASE_URL,
            "timestamp": datetime.utcnow().isoformat(),
            "duration_seconds": round(total_duration, 2),
            "total": total_tests,
            "passed": passed_tests,
            "failed": failed_tests,
            "skipped": skipped_tests,
            "pass_percentage": round(pass_pct, 2)
        },
        "test_cases": [r.to_dict() for r in all_results]
    }
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(results_dict, f, indent=2)
    logger.info(f"Generated JSON results at {json_path}")

    # 2. Generate Excel Reports (4 workbooks)
    ExcelReporter.generate_all(all_results, Config.BASE_URL)

    # 3. Generate HTML Reports (execution-report.html & dashboard.html)
    HTMLReporter.generate_all(all_results, Config.BASE_URL)

    # 4. Generate GitHub Summary
    summary_md = SummaryGenerator.generate_summary(
        results=all_results,
        base_url=Config.BASE_URL,
        build_status="PASS",
        deploy_status="PASS",
        execution_duration=total_duration
    )

    # Append to GITHUB_STEP_SUMMARY if available
    step_summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary_file:
        try:
            with open(step_summary_file, "a", encoding="utf-8") as f:
                f.write(summary_md + "\n")
            logger.info("Wrote summary to $GITHUB_STEP_SUMMARY")
        except Exception as exc:
            logger.warning(f"Could not write to GITHUB_STEP_SUMMARY: {exc}")

    # QUALITY GATE PASS/FAIL LOGIC:
    # Fail only if:
    # - Deployment fails (handled in Stage 7)
    # - More than 5% critical test cases fail
    # - Pass percentage < 95%
    if critical_fail_pct > Config.MAX_CRITICAL_FAIL_PERCENTAGE:
        logger.error(f"QUALITY GATE FAILED: Critical test failures ({critical_fail_pct:.1f}%) exceeded {Config.MAX_CRITICAL_FAIL_PERCENTAGE}% limit.")
        return 1

    if pass_pct < Config.PASS_PERCENTAGE_THRESHOLD:
        logger.error(f"QUALITY GATE FAILED: Pass percentage ({pass_pct:.1f}%) is below {Config.PASS_PERCENTAGE_THRESHOLD}% threshold.")
        return 1

    logger.info("QUALITY GATE PASSED: All deployment and E2E criteria met successfully.")
    return 0

if __name__ == "__main__":
    sys.exit(run_all_e2e_tests())
