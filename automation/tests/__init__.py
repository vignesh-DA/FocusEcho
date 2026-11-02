"""
FocusEcho Test Suite Registry
Aggregates all 14 test suites covering 420 executable test cases.
"""

from typing import List
from selenium.webdriver.remote.webdriver import WebDriver
from automation.models.test_result import TestCaseResult

from . import (
    test_01_authentication,
    test_02_authorization,
    test_03_navigation,
    test_04_ui_validation,
    test_05_forms,
    test_06_crud_operations,
    test_07_input_validation,
    test_08_error_handling,
    test_09_session_management,
    test_10_file_upload,
    test_11_accessibility,
    test_12_responsive_design,
    test_13_performance_smoke,
    test_14_regression,
)

SUITES = [
    ("Authentication", test_01_authentication.run_tests),
    ("Authorization", test_02_authorization.run_tests),
    ("Navigation", test_03_navigation.run_tests),
    ("UI Validation", test_04_ui_validation.run_tests),
    ("Forms", test_05_forms.run_tests),
    ("CRUD Operations", test_06_crud_operations.run_tests),
    ("Input Validation", test_07_input_validation.run_tests),
    ("Error Handling", test_08_error_handling.run_tests),
    ("Session Management", test_09_session_management.run_tests),
    ("File Upload", test_10_file_upload.run_tests),
    ("Accessibility", test_11_accessibility.run_tests),
    ("Responsive Design", test_12_responsive_design.run_tests),
    ("Performance Smoke Tests", test_13_performance_smoke.run_tests),
    ("Regression", test_14_regression.run_tests),
]

def run_all_suites(driver: WebDriver) -> List[TestCaseResult]:
    """Execute all test suites in order and return all test case results."""
    all_results = []
    for suite_name, suite_runner in SUITES:
        results = suite_runner(driver)
        all_results.extend(results)
    return all_results
