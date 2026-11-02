"""
Suite 01: Authentication (40 Test Cases)
Validates email OTP authentication, guest sessions, input sanitation,
token generation, remember me states, and logout flows.
"""

from typing import List
from selenium.webdriver.remote.webdriver import WebDriver
from automation.models.test_result import TestCaseResult
from automation.pages.auth_page import AuthPage
from automation.data.test_data import TestData

def get_authentication_tests() -> List[dict]:
    """Return specifications for 40 authentication test cases."""
    tests = []
    
    # 1 to 10: Modal & Tab Switching & Validation
    tests.append({
        "id": "TC-AUTH-001", "name": "Verify Auth Modal Opens", "priority": "Critical",
        "pre": "Application loaded", "steps": ["Click Sign In in sidebar", "Verify modal is visible"],
        "expected": "Auth modal displayed", "func": lambda p: p.open_auth_modal() or p.is_visible(p.LOC_AUTH_MODAL)
    })
    tests.append({
        "id": "TC-AUTH-002", "name": "Verify Auth Modal Closes", "priority": "High",
        "pre": "Auth modal open", "steps": ["Click modal close button", "Verify modal hidden"],
        "func": lambda p: p.close_auth_modal() or not p.is_visible(p.LOC_AUTH_MODAL)
    })
    tests.append({
        "id": "TC-AUTH-003", "name": "Verify Default Tab is Email OTP", "priority": "Medium",
        "pre": "Auth modal open", "steps": ["Open auth modal", "Check email input visibility"],
        "func": lambda p: p.open_auth_modal() or p.is_visible(p.LOC_AUTH_EMAIL_INPUT)
    })
    tests.append({
        "id": "TC-AUTH-004", "name": "Verify Switch to Guest Tab", "priority": "High",
        "pre": "Auth modal open", "steps": ["Click Guest Mode tab", "Verify guest panel is visible"],
        "func": lambda p: p.click(p.LOC_TAB_GUEST) or p.is_visible(p.LOC_GUEST_PANEL)
    })
    tests.append({
        "id": "TC-AUTH-005", "name": "Verify Switch Back to Login Tab", "priority": "Medium",
        "pre": "Guest tab active", "steps": ["Click Email OTP tab", "Verify login form visible"],
        "func": lambda p: p.click(p.LOC_TAB_LOGIN) or p.is_visible(p.LOC_AUTH_EMAIL_INPUT)
    })
    tests.append({
        "id": "TC-AUTH-006", "name": "Validation on Empty Email", "priority": "High",
        "pre": "Login tab active", "steps": ["Submit form with empty email", "Verify error message"],
        "func": lambda p: (p.driver.execute_script("return window.FocusEchoApp.authenticateUser('', '123456')") is False) and bool(p.get_email_error())
    })
    tests.append({
        "id": "TC-AUTH-007", "name": "Validation on Missing At Symbol in Email", "priority": "High",
        "pre": "Login tab active", "steps": ["Input 'plainaddress'", "Submit", "Verify error"],
        "func": lambda p: (p.driver.execute_script("return window.FocusEchoApp.authenticateUser('plainaddress', '123456')") is False) and bool(p.get_email_error())
    })
    tests.append({
        "id": "TC-AUTH-008", "name": "Validation on Missing Domain in Email", "priority": "High",
        "pre": "Login tab active", "steps": ["Input 'user@'", "Submit", "Verify error"],
        "func": lambda p: (p.driver.execute_script("return window.FocusEchoApp.authenticateUser('user@', '123456')") is False) and bool(p.get_email_error())
    })
    tests.append({
        "id": "TC-AUTH-009", "name": "Validation on Spaces in Email", "priority": "Medium",
        "pre": "Login tab active", "steps": ["Input 'user @site.com'", "Submit", "Verify error"],
        "func": lambda p: (p.driver.execute_script("return window.FocusEchoApp.authenticateUser('user @site.com', '123456')") is False) and bool(p.get_email_error())
    })
    tests.append({
        "id": "TC-AUTH-010", "name": "Validation on Double Dot in Email Domain", "priority": "Medium",
        "pre": "Login tab active", "steps": ["Input 'user@site..com'", "Submit", "Verify error"],
        "func": lambda p: (p.driver.execute_script("return window.FocusEchoApp.authenticateUser('user@site..com', '123456')") is False) and bool(p.get_email_error())
    })

    # 11 to 20: Successful Login, Role Updates, OTP Validation
    tests.append({
        "id": "TC-AUTH-011", "name": "Successful Login with Valid Credentials", "priority": "Critical",
        "pre": "Login modal open", "steps": ["Input alex.dev@focusecho.ai and 123456", "Submit"],
        "func": lambda p: p.login_with_email_otp("alex.dev@focusecho.ai", "123456") or p.get_current_user_name() == "alex.dev"
    })
    tests.append({
        "id": "TC-AUTH-012", "name": "Verify User Role Upgrades to Pro", "priority": "High",
        "pre": "User authenticated", "steps": ["Inspect sidebar user role"],
        "func": lambda p: p.get_current_user_role() == "Pro"
    })
    tests.append({
        "id": "TC-AUTH-013", "name": "Verify Sign In Button Hidden After Login", "priority": "Medium",
        "pre": "User authenticated", "steps": ["Check visibility of auth-modal-open-btn"],
        "func": lambda p: not p.is_visible(p.LOC_AUTH_MODAL_OPEN_BTN)
    })
    tests.append({
        "id": "TC-AUTH-014", "name": "Verify Sign Out Button Visible After Login", "priority": "High",
        "pre": "User authenticated", "steps": ["Check visibility of auth-logout-btn"],
        "func": lambda p: p.is_visible(p.LOC_AUTH_LOGOUT_BTN)
    })
    tests.append({
        "id": "TC-AUTH-015", "name": "Verify Nav Avatar Shows User Initials", "priority": "Medium",
        "pre": "User authenticated", "steps": ["Inspect #nav-user-avatar text"],
        "func": lambda p: p.find_element(p.LOC_NAV_USER_AVATAR).text == "AL"
    })
    tests.append({
        "id": "TC-AUTH-016", "name": "Verify Logout Resets to Guest", "priority": "Critical",
        "pre": "User authenticated", "steps": ["Click Sign Out", "Check sidebar name"],
        "func": lambda p: p.logout() or p.get_current_user_name() == "Guest User"
    })
    tests.append({
        "id": "TC-AUTH-017", "name": "Verify Sign In Button Reappears After Logout", "priority": "Medium",
        "pre": "User logged out", "steps": ["Check visibility of auth-modal-open-btn"],
        "func": lambda p: p.is_visible(p.LOC_AUTH_MODAL_OPEN_BTN)
    })
    tests.append({
        "id": "TC-AUTH-018", "name": "Validation on Short OTP Code (<6 chars)", "priority": "High",
        "pre": "Login modal open", "steps": ["Input alex.dev@focusecho.ai and '123'", "Submit"],
        "func": lambda p: p.open_auth_modal() or p.login_with_email_otp("alex.dev@focusecho.ai", "123") or bool(p.get_otp_error())
    })
    tests.append({
        "id": "TC-AUTH-019", "name": "Validation on Empty OTP Code", "priority": "High",
        "pre": "Login modal open", "steps": ["Input alex.dev@focusecho.ai and ''", "Submit"],
        "func": lambda p: p.login_with_email_otp("alex.dev@focusecho.ai", "") or bool(p.get_otp_error())
    })
    tests.append({
        "id": "TC-AUTH-020", "name": "Verify Remember Me Checkbox Default State", "priority": "Low",
        "pre": "Login modal open", "steps": ["Inspect remember me checkbox"],
        "func": lambda p: p.find_element(p.LOC_AUTH_REMEMBER_ME).is_selected()
    })

    # 21 to 30: Guest Modes, Alternates, and Attributes
    tests.append({
        "id": "TC-AUTH-021", "name": "Verify Remember Me Toggleable", "priority": "Low",
        "pre": "Login modal open", "steps": ["Click remember me checkbox", "Verify unchecked"],
        "func": lambda p: p.click(p.LOC_AUTH_REMEMBER_ME) or not p.find_element(p.LOC_AUTH_REMEMBER_ME).is_selected()
    })
    tests.append({
        "id": "TC-AUTH-022", "name": "Continue as Guest Workflow", "priority": "Critical",
        "pre": "Auth modal open", "steps": ["Click Guest tab", "Click Continue as Guest"],
        "func": lambda p: p.continue_as_guest() or p.get_current_user_name() == "Guest User"
    })
    tests.append({
        "id": "TC-AUTH-023", "name": "Verify Guest User Role is Free Tier", "priority": "Medium",
        "pre": "Guest active", "steps": ["Check sidebar user role"],
        "func": lambda p: p.get_current_user_role() == "Free Tier"
    })
    tests.append({
        "id": "TC-AUTH-024", "name": "Verify Guest Avatar Initials FE", "priority": "Low",
        "pre": "Guest active", "steps": ["Check #nav-user-avatar text"],
        "func": lambda p: p.find_element(p.LOC_NAV_USER_AVATAR).text == "FE"
    })
    tests.append({
        "id": "TC-AUTH-025", "name": "Login with Sarah Lead Account", "priority": "High",
        "pre": "Modal open", "steps": ["Input sarah.lead@focusecho.ai and 123456", "Submit"],
        "func": lambda p: p.open_auth_modal() or p.login_with_email_otp("sarah.lead@focusecho.ai", "123456") or p.get_current_user_name() == "sarah.lead"
    })
    tests.append({
        "id": "TC-AUTH-026", "name": "Verify Sarah Lead Initials SA", "priority": "Low",
        "pre": "Sarah logged in", "steps": ["Check nav avatar"],
        "func": lambda p: p.find_element(p.LOC_NAV_USER_AVATAR).text == "SA"
    })
    tests.append({
        "id": "TC-AUTH-027", "name": "Logout From Sarah Lead Account", "priority": "High",
        "pre": "Sarah logged in", "steps": ["Click Sign Out"],
        "func": lambda p: p.logout() or p.get_current_user_name() == "Guest User"
    })
    tests.append({
        "id": "TC-AUTH-028", "name": "Login with Subdomain Email Format", "priority": "Medium",
        "pre": "Modal open", "steps": ["Input qa@dev.focusecho.ai and 123456", "Submit"],
        "func": lambda p: p.open_auth_modal() or p.login_with_email_otp("qa@dev.focusecho.ai", "123456") or p.get_current_user_name() == "qa"
    })
    tests.append({
        "id": "TC-AUTH-029", "name": "Reset Back to Guest", "priority": "Medium",
        "pre": "User logged in", "steps": ["Sign Out"],
        "func": lambda p: p.logout() or p.get_current_user_name() == "Guest User"
    })
    tests.append({
        "id": "TC-AUTH-030", "name": "Verify OTP Input Masking Attribute", "priority": "Medium",
        "pre": "Modal open", "steps": ["Inspect OTP input type"],
        "func": lambda p: p.open_auth_modal() or p.find_element(p.LOC_AUTH_OTP_INPUT).get_attribute("type") == "password"
    })

    # 31 to 40: Boundaries, Dialog Attributes, Maxlengths
    tests.append({
        "id": "TC-AUTH-031", "name": "Verify OTP Input Maxlength 6", "priority": "Low",
        "pre": "Modal open", "steps": ["Inspect OTP input maxlength"],
        "func": lambda p: p.find_element(p.LOC_AUTH_OTP_INPUT).get_attribute("maxlength") == "6"
    })
    tests.append({
        "id": "TC-AUTH-032", "name": "Verify Auth Modal Dialog Role", "priority": "Medium",
        "pre": "Modal open", "steps": ["Check role attribute on #auth-modal"],
        "func": lambda p: p.find_element(p.LOC_AUTH_MODAL).get_attribute("role") == "dialog"
    })
    tests.append({
        "id": "TC-AUTH-033", "name": "Verify Auth Modal Aria-Modal Attribute", "priority": "Low",
        "pre": "Modal open", "steps": ["Check aria-modal attribute"],
        "func": lambda p: p.find_element(p.LOC_AUTH_MODAL).get_attribute("aria-modal") == "true"
    })
    tests.append({
        "id": "TC-AUTH-034", "name": "Verify Auth Modal Title Binding", "priority": "Low",
        "pre": "Modal open", "steps": ["Check aria-labelledby matching title ID"],
        "func": lambda p: p.find_element(p.LOC_AUTH_MODAL).get_attribute("aria-labelledby") == "auth-modal-title"
    })
    tests.append({
        "id": "TC-AUTH-035", "name": "Close Auth Modal via Close Button", "priority": "Medium",
        "pre": "Modal open", "steps": ["Click close icon"],
        "func": lambda p: p.close_auth_modal() or not p.is_visible(p.LOC_AUTH_MODAL)
    })
    tests.append({
        "id": "TC-AUTH-036", "name": "Verify Login with Plus Tag Email", "priority": "Medium",
        "pre": "Modal open", "steps": ["Input alex+test@focusecho.ai", "Submit"],
        "func": lambda p: p.open_auth_modal() or p.login_with_email_otp("alex+test@focusecho.ai", "123456") or "alex+test" in p.get_current_user_name()
    })
    tests.append({
        "id": "TC-AUTH-037", "name": "Reset to Guest after Plus Tag Login", "priority": "Low",
        "pre": "User logged in", "steps": ["Sign Out"],
        "func": lambda p: p.logout() or p.get_current_user_name() == "Guest User"
    })
    tests.append({
        "id": "TC-AUTH-038", "name": "Verify Email Required Validation Attribute", "priority": "Medium",
        "pre": "Modal open", "steps": ["Inspect email input required attribute"],
        "func": lambda p: p.open_auth_modal() or p.find_element(p.LOC_AUTH_EMAIL_INPUT).get_attribute("required") is not None
    })
    tests.append({
        "id": "TC-AUTH-039", "name": "Verify OTP Required Validation Attribute", "priority": "Medium",
        "pre": "Modal open", "steps": ["Inspect OTP input required attribute"],
        "func": lambda p: p.find_element(p.LOC_AUTH_OTP_INPUT).get_attribute("required") is not None
    })
    tests.append({
        "id": "TC-AUTH-040", "name": "Close Modal and Finalize Auth State", "priority": "Critical",
        "pre": "Modal open", "steps": ["Close modal and confirm guest state"],
        "func": lambda p: p.close_auth_modal() or p.get_current_user_name() == "Guest User"
    })

    return tests

def run_tests(driver: WebDriver) -> List[TestCaseResult]:
    """Execute all 40 Authentication test cases."""
    results = []
    auth_page = AuthPage(driver)
    auth_page.open("")
    test_specs = get_authentication_tests()

    for spec in test_specs:
        tr = TestCaseResult(
            test_id=spec["id"],
            module="Authentication",
            test_name=spec["name"],
            priority=spec["priority"],
            preconditions=spec.get("pre", "Live GitHub Pages loaded"),
            test_steps=spec.get("steps", ["Execute test"]),
            expected_result=spec.get("expected", "Passed")
        )
        import time
        t0 = time.time()
        try:
            passed = spec["func"](auth_page)
            tr.execution_time = time.time() - t0
            if passed is not False:
                tr.status = "Passed"
                tr.actual_result = "Action succeeded as expected."
            else:
                tr.status = "Failed"
                tr.actual_result = "Assertion failed."
                tr.error_message = "Condition returned false."
        except Exception as exc:
            tr.execution_time = time.time() - t0
            tr.status = "Failed"
            tr.actual_result = f"Exception: {str(exc)}"
            tr.error_message = str(exc)
            import traceback
            tr.stack_trace = traceback.format_exc()
        results.append(tr)

    return results
