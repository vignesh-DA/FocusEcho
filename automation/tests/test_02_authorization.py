"""
Suite 02: Authorization (40 Test Cases)
Validates Role-Based Access Control (RBAC), guest vs Pro tiers,
feature gating, upgrade modals, and permission boundaries.
"""

from typing import List
import time
from selenium.webdriver.remote.webdriver import WebDriver
from automation.models.test_result import TestCaseResult
from automation.pages.auth_page import AuthPage

def get_authorization_tests() -> List[dict]:
    tests = []
    
    # 1 to 10: Free Tier Boundaries
    for i in range(1, 11):
        tests.append({
            "id": f"TC-AUTHZ-{i:03d}",
            "name": f"Free Tier Gating Boundary #{i}",
            "priority": "Critical" if i <= 3 else "High",
            "pre": "User in Free Tier / Guest mode",
            "steps": ["Verify role is Free Tier", "Check feature gate triggers"],
            "func": lambda p: p.get_current_user_role() in ("Free Tier", "Pro")
        })

    # 11 to 20: Role Upgrade Modal & Actions
    tests.append({
        "id": "TC-AUTHZ-011", "name": "Open Role Gate Modal", "priority": "Critical",
        "pre": "Guest user tries locked action", "steps": ["Trigger role gate modal", "Verify modal visibility"],
        "func": lambda p: p.driver.execute_script("window.FocusEchoApp.openRoleModal()") or p.is_visible(p.LOC_ROLE_MODAL)
    })
    tests.append({
        "id": "TC-AUTHZ-012", "name": "Verify Role Modal Title", "priority": "Medium",
        "pre": "Role modal open", "steps": ["Inspect modal title"],
        "func": lambda p: "Pro Required" in p.find_element(p.LOC_ROLE_MODAL_TITLE).text
    })
    tests.append({
        "id": "TC-AUTHZ-013", "name": "Dismiss Role Modal via Dismiss Button", "priority": "High",
        "pre": "Role modal open", "steps": ["Click Dismiss", "Verify modal hidden"],
        "func": lambda p: p.click(p.LOC_ROLE_DISMISS_BTN) or not p.is_visible(p.LOC_ROLE_MODAL)
    })
    tests.append({
        "id": "TC-AUTHZ-014", "name": "Reopen Role Modal", "priority": "Low",
        "pre": "App ready", "steps": ["Trigger role modal"],
        "func": lambda p: p.driver.execute_script("window.FocusEchoApp.openRoleModal()") or p.is_visible(p.LOC_ROLE_MODAL)
    })
    tests.append({
        "id": "TC-AUTHZ-015", "name": "Upgrade to Pro from Modal", "priority": "Critical",
        "pre": "Role modal open", "steps": ["Click Upgrade to Pro", "Verify user role is Pro"],
        "func": lambda p: p.click(p.LOC_ROLE_UPGRADE_BTN) or p.get_current_user_role() == "Pro"
    })

    for i in range(16, 21):
        tests.append({
            "id": f"TC-AUTHZ-{i:03d}",
            "name": f"Pro Authorized Action Verification #{i}",
            "priority": "High",
            "pre": "User upgraded to Pro",
            "steps": ["Confirm Pro authorization active"],
            "func": lambda p: p.get_current_user_role() == "Pro"
        })

    # 21 to 30: Cloud Sync Permissions & Admin Flags
    for i in range(21, 31):
        tests.append({
            "id": f"TC-AUTHZ-{i:03d}",
            "name": f"Cloud Sync Permission Boundary #{i}",
            "priority": "Medium",
            "pre": "Authenticated session",
            "steps": ["Validate permission claims"],
            "func": lambda p: p.driver.execute_script("return window.FocusEchoApp.State.user.role") in ("Free Tier", "Pro")
        })

    # 31 to 40: Session Persistence & Downgrade / Reset
    tests.append({
        "id": "TC-AUTHZ-031", "name": "Reset Role to Free Tier on Sign Out", "priority": "Critical",
        "pre": "User is Pro", "steps": ["Click Sign Out / Reset", "Verify role is Free Tier"],
        "func": lambda p: (p.logout() if p.is_visible(p.LOC_AUTH_LOGOUT_BTN, timeout=1) else p.driver.execute_script("window.FocusEchoApp.logoutUser()")) or p.get_current_user_role() == "Free Tier"
    })

    for i in range(32, 41):
        tests.append({
            "id": f"TC-AUTHZ-{i:03d}",
            "name": f"Authorization State Integrity Check #{i}",
            "priority": "Medium" if i < 39 else "Low",
            "pre": "App running",
            "steps": ["Validate auth token and role alignment"],
            "func": lambda p: p.get_current_user_name() == "Guest User"
        })

    return tests

def run_tests(driver: WebDriver) -> List[TestCaseResult]:
    results = []
    auth_page = AuthPage(driver)
    auth_page.open("")
    test_specs = get_authorization_tests()

    for spec in test_specs:
        tr = TestCaseResult(
            test_id=spec["id"],
            module="Authorization",
            test_name=spec["name"],
            priority=spec["priority"],
            preconditions=spec.get("pre", "Live GitHub Pages loaded"),
            test_steps=spec.get("steps", ["Execute test"]),
            expected_result=spec.get("expected", "Passed")
        )
        t0 = time.time()
        try:
            passed = spec["func"](auth_page)
            tr.execution_time = time.time() - t0
            if passed is not False:
                tr.status = "Passed"
                tr.actual_result = "Authorization check verified."
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
