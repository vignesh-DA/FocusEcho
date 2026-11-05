"""Focused Selenium acceptance cases for the deployed static web experience.

Each case returns an explicit boolean. A successful click or a ``None`` return
value is never treated as evidence that the expected behavior occurred.
"""

import time
import traceback
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.remote.webdriver import WebDriver

from automation.config.config import Config, SCREENSHOT_DIR
from automation.models.test_result import TestCaseResult


def _open_app(driver: WebDriver) -> None:
    driver.get(Config.BASE_URL)
    driver.execute_script("window.localStorage.clear(); window.sessionStorage.clear();")
    driver.refresh()
    WebDriverWait(driver, Config.DEFAULT_TIMEOUT).until(
        EC.visibility_of_element_located((By.ID, "app-title"))
    )
    WebDriverWait(driver, Config.DEFAULT_TIMEOUT).until(
        EC.visibility_of_element_located((By.ID, "section-dashboard"))
    )


def _case_specs() -> list[dict]:
    return [
        {
            "id": "DEMO-WEB-SHELL-001",
            "module": "Application shell",
            "name": "Core application shell loads with dashboard navigation",
            "priority": "Critical",
            "preconditions": "The selected local or production target is reachable.",
            "steps": ["Open the configured base URL", "Inspect the page title and primary landmarks"],
            "expected": "The FocusEcho title, main navigation, and dashboard are rendered.",
            "check": lambda driver: (
                "FocusEcho" in driver.title
                and driver.find_element(By.ID, "main-nav-menu").is_displayed()
                and driver.find_element(By.ID, "section-dashboard").is_displayed()
            ),
        },
        {
            "id": "DEMO-WEB-NAV-001",
            "module": "Navigation",
            "name": "Primary navigation selects the focus timer",
            "priority": "High",
            "preconditions": "The application shell has loaded.",
            "steps": ["Select Focus Timer in the primary navigation", "Inspect the URL and active section"],
            "expected": "The timer route is selected and its content section becomes active.",
            "check": lambda driver: _navigate_to_timer(driver),
        },
        {
            "id": "DEMO-WEB-AUTH-001",
            "module": "Authentication",
            "name": "Guest access returns the interface to an identified guest state",
            "priority": "High",
            "preconditions": "A fresh page load with no browser-persisted account state.",
            "steps": ["Open account access", "Choose Guest Mode", "Continue as an anonymous guest"],
            "expected": "Guest identity is shown, the role is Free Tier, and sign-out becomes available.",
            "check": lambda driver: _continue_as_guest(driver),
        },
        {
            "id": "DEMO-WEB-AUTH-002",
            "module": "Authentication",
            "name": "Malformed email is rejected before authenticated state is created",
            "priority": "High",
            "preconditions": "A fresh page load.",
            "steps": ["Submit an invalid email through the auth validator", "Inspect the error and auth state"],
            "expected": "Validation fails, a field-level message appears, and no authenticated state is created.",
            "check": lambda driver: _reject_invalid_email(driver),
        },
        {
            "id": "DEMO-WEB-AUTH-003",
            "module": "Authentication",
            "name": "A one-time code shorter than six digits is rejected",
            "priority": "High",
            "preconditions": "A fresh page load.",
            "steps": ["Submit a valid-format synthetic email with a three-digit code", "Inspect the error and auth state"],
            "expected": "Validation fails and the browser remains unauthenticated.",
            "check": lambda driver: _reject_short_code(driver),
        },
        {
            "id": "DEMO-WEB-AUTH-004",
            "module": "Authentication security",
            "name": "An unissued six-digit code cannot create an authenticated session",
            "priority": "Critical",
            "preconditions": "Use a clean browser session and the reserved .invalid test address.",
            "steps": ["Submit an arbitrary six-digit code", "Inspect the result and authentication state"],
            "expected": "Without a configured verification service, no OTP creates an authenticated session or token.",
            "check": lambda driver: _reject_unissued_code(driver),
        },
        {
            "id": "DEMO-WEB-SESSION-001",
            "module": "Focus session",
            "name": "Timer start, pause, resume, and stop preserve valid state transitions",
            "priority": "Critical",
            "preconditions": "A fresh page load.",
            "steps": ["Enter a non-empty focus goal", "Start, pause, resume, and stop the timer"],
            "expected": "Timer state transitions RUNNING → PAUSED → RUNNING → IDLE in order.",
            "check": lambda driver: _exercise_timer_transitions(driver),
        },
        {
            "id": "DEMO-WEB-PARK-001",
            "module": "Parking lot",
            "name": "Parking-lot entries remain removable and render markup as inert text",
            "priority": "High",
            "preconditions": "A fresh page load.",
            "steps": ["Add a unique entry containing an HTML event-handler payload", "Verify it renders as text", "Remove it"],
            "expected": "Markup creates no DOM elements or script execution; the item is removed and existing entries remain unchanged.",
            "check": lambda driver: _add_and_remove_escaped_parking_item(driver),
        },
        {
            "id": "DEMO-WEB-REFLECT-001",
            "module": "Session reflection",
            "name": "Saving a reflection displays confirmation feedback",
            "priority": "Medium",
            "preconditions": "A fresh page load.",
            "steps": ["Open the reflection section", "Submit the reflection form", "Inspect confirmation status"],
            "expected": "The success confirmation becomes visible after a valid submission.",
            "check": lambda driver: _submit_reflection(driver),
        },
        {
            "id": "DEMO-WEB-PROFILE-001",
            "module": "Profile settings",
            "name": "Malformed profile email is rejected without updating the profile",
            "priority": "Medium",
            "preconditions": "A fresh page load with the default guest profile.",
            "steps": ["Open Settings", "Enter an invalid profile email", "Save profile changes"],
            "expected": "A validation error appears and the current profile identity is unchanged.",
            "check": lambda driver: _reject_invalid_profile_email(driver),
        },
    ]


def _navigate_to_timer(driver: WebDriver) -> bool:
    driver.find_element(By.ID, "nav-timer").click()
    return WebDriverWait(driver, Config.DEFAULT_TIMEOUT).until(
        lambda browser: "active" in browser.find_element(By.ID, "section-timer").get_attribute("class")
        and browser.current_url.endswith("#timer")
    )


def _continue_as_guest(driver: WebDriver) -> bool:
    driver.find_element(By.ID, "auth-modal-open-btn").click()
    driver.find_element(By.ID, "tab-guest").click()
    driver.find_element(By.ID, "auth-continue-guest-btn").click()
    return (
        driver.find_element(By.ID, "nav-user-name").text == "Guest User"
        and driver.find_element(By.ID, "nav-user-role").text == "Free Tier"
        and driver.execute_script("return window.FocusEchoApp.State.user.isGuest") is True
        and driver.execute_script("return window.FocusEchoApp.State.user.isAuthenticated") is False
        and driver.execute_script("return window.FocusEchoApp.State.user.token") is None
        and driver.find_element(By.ID, "auth-modal-open-btn").is_displayed()
        and not driver.find_element(By.ID, "auth-logout-btn").is_displayed()
    )


def _reject_invalid_email(driver: WebDriver) -> bool:
    driver.find_element(By.ID, "auth-modal-open-btn").click()
    WebDriverWait(driver, Config.DEFAULT_TIMEOUT).until(
        EC.visibility_of_element_located((By.CSS_SELECTOR, "#auth-modal .modal-dialog"))
    )
    result = driver.execute_script(
        "return window.FocusEchoApp.authenticateUser('not-an-email', '123456');"
    )
    return (
        result is False
        and driver.find_element(By.ID, "auth-email-error").text.strip() != ""
        and driver.execute_script("return window.FocusEchoApp.State.user.isAuthenticated") is False
    )


def _reject_short_code(driver: WebDriver) -> bool:
    driver.find_element(By.ID, "auth-modal-open-btn").click()
    WebDriverWait(driver, Config.DEFAULT_TIMEOUT).until(
        EC.visibility_of_element_located((By.CSS_SELECTOR, "#auth-modal .modal-dialog"))
    )
    result = driver.execute_script(
        "return window.FocusEchoApp.authenticateUser(arguments[0], '123');",
        "qa-auth-probe@example.invalid",
    )
    return (
        result is False
        and driver.find_element(By.ID, "auth-otp-error").text.strip() != ""
        and driver.execute_script("return window.FocusEchoApp.State.user.isAuthenticated") is False
    )


def _reject_unissued_code(driver: WebDriver) -> bool:
    driver.find_element(By.ID, "auth-modal-open-btn").click()
    WebDriverWait(driver, Config.DEFAULT_TIMEOUT).until(
        EC.visibility_of_element_located((By.CSS_SELECTOR, "#auth-modal .modal-dialog"))
    )
    driver.find_element(By.ID, "auth-email-input").send_keys("qa-auth-probe@example.invalid")
    driver.find_element(By.ID, "auth-otp-input").send_keys("908172")
    driver.find_element(By.ID, "auth-submit-btn").click()
    return (
        "verification service" in driver.find_element(By.ID, "auth-otp-error").text.lower()
        and driver.execute_script("return window.FocusEchoApp.State.user.isAuthenticated") is False
        and driver.execute_script("return window.FocusEchoApp.State.user.token") is None
    )


def _exercise_timer_transitions(driver: WebDriver) -> bool:
    observed = driver.execute_script(
        """
        const app = window.FocusEchoApp;
        document.getElementById('session-goal-input').value = 'Complete a QA review';
        app.startTimer();
        const states = [app.State.timer.state];
        app.pauseTimer(); states.push(app.State.timer.state);
        document.getElementById('timer-resume-btn').click(); states.push(app.State.timer.state);
        app.stopTimer(); states.push(app.State.timer.state);
        return states;
        """
    )
    return observed == ["RUNNING", "PAUSED", "RUNNING", "IDLE"]


def _add_and_remove_escaped_parking_item(driver: WebDriver) -> bool:
    return driver.execute_script(
        """
        const app = window.FocusEchoApp;
        const text = 'QA <img src=x onerror=window.__qa_xss=true> item ' + Date.now();
        window.__qa_xss = false;
        const before = app.State.parkingLot.map(entry => entry.id);
        const added = app.addParkingItem(text, 'High');
        const item = app.State.parkingLot.find(entry => entry.text === text);
        const row = item && document.getElementById('parking-item-' + item.id);
        const appeared = row && row.querySelector('.item-text').textContent === text;
        const inert = row && row.querySelector('img') === null && window.__qa_xss === false;
        if (row) row.querySelector('.delete-parking-btn').click();
        const removed = !app.State.parkingLot.some(entry => entry.text === text);
        const existingUnchanged = JSON.stringify(before) === JSON.stringify(app.State.parkingLot.map(entry => entry.id));
        return added === true && appeared === true && inert === true && removed === true && existingUnchanged === true;
        """
    ) is True


def _submit_reflection(driver: WebDriver) -> bool:
    driver.find_element(By.ID, "nav-reflection").click()
    driver.find_element(By.ID, "reflection-submit-btn").click()
    return WebDriverWait(driver, Config.DEFAULT_TIMEOUT).until(
        EC.visibility_of_element_located((By.ID, "reflection-success-msg"))
    ).is_displayed()


def _reject_invalid_profile_email(driver: WebDriver) -> bool:
    driver.find_element(By.ID, "nav-settings").click()
    driver.find_element(By.ID, "profile-email-input").clear()
    driver.find_element(By.ID, "profile-email-input").send_keys("bad-address")
    before = driver.execute_script("return window.FocusEchoApp.State.user.email")
    driver.find_element(By.ID, "profile-save-btn").click()
    is_invalid = driver.execute_script(
        "return !document.getElementById('profile-email-input').checkValidity()"
    )
    after = driver.execute_script("return window.FocusEchoApp.State.user.email")
    return is_invalid is True and before == after


def run_tests(driver: WebDriver) -> list[TestCaseResult]:
    """Run focused cases and require an explicit ``True`` for every pass."""
    results: list[TestCaseResult] = []
    for spec in _case_specs():
        result = TestCaseResult(
            test_id=spec["id"],
            module=spec["module"],
            test_name=spec["name"],
            priority=spec["priority"],
            preconditions=spec["preconditions"],
            test_steps=spec["steps"],
            expected_result=spec["expected"],
        )
        started = time.perf_counter()
        try:
            _open_app(driver)
            passed = spec["check"](driver)
            result.status = "Passed" if passed is True else "Failed"
            result.actual_result = "Expected behavior observed." if passed is True else "Expected behavior was not observed."
            if passed is not True:
                result.error_message = "The case did not return an explicit True assertion result."
                if hasattr(driver, "save_screenshot"):
                    screenshot = SCREENSHOT_DIR / f"{result.test_id}_failed.png"
                    if driver.save_screenshot(str(screenshot)):
                        result.screenshot_path = str(screenshot)
                result.console_logs = driver.get_log("browser") if hasattr(driver, "get_log") else []
        except Exception as error:  # noqa: BLE001 - capture per-case browser failures
            result.status = "Failed"
            result.actual_result = f"Execution raised {type(error).__name__}."
            result.error_message = type(error).__name__
            result.stack_trace = traceback.format_exc()
        finally:
            result.execution_time = time.perf_counter() - started
        results.append(result)
    return results
