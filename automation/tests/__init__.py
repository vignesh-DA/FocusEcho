"""Curated browser acceptance suite; backend, Flutter, and extension suites
remain in their respective project test directories.
"""

from selenium.webdriver.remote.webdriver import WebDriver

from automation.models.test_result import TestCaseResult
from automation.tests.test_web_acceptance import run_tests as run_web_acceptance_tests

SUITES = [
    ("Web acceptance", run_web_acceptance_tests),
]


def run_all_suites(driver: WebDriver) -> list[TestCaseResult]:
    """Execute each curated Selenium suite and retain every result."""
    return [result for _, run_suite in SUITES for result in run_suite(driver)]
