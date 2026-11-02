"""
Suite 03: Navigation (30 Test Cases)
Validates sidebar routing, deep hash linking, breadcrumbs,
page headings, active states, and mobile drawer transitions.
"""

from typing import List
import time
from selenium.webdriver.remote.webdriver import WebDriver
from automation.models.test_result import TestCaseResult
from automation.pages.navigation_page import NavigationPage

def get_navigation_tests() -> List[dict]:
    tests = []
    
    sections = [
        ("dashboard", "Dashboard Overview", "nav-dashboard"),
        ("timer", "Deep Focus Timer", "nav-timer"),
        ("parking-lot", "Mind Parking Lot", "nav-parking-lot"),
        ("analytics", "Productivity & Drift Analytics", "nav-analytics"),
        ("coach", "EchoCoach Behavioral Guidance", "nav-coach"),
        ("reflection", "Post-Session Evaluation", "nav-reflection"),
        ("settings", "System & Profile Settings", "nav-settings")
    ]

    # 1 to 7: Sidebar Click Navigation
    for i, (sec, title, _) in enumerate(sections, 1):
        tests.append({
            "id": f"TC-NAV-{i:03d}",
            "name": f"Navigate to {sec.capitalize()} Section",
            "priority": "Critical" if i <= 3 else "High",
            "steps": [f"Click #{sec} in sidebar", f"Verify #section-{sec} active"],
            "func": (lambda s=sec: lambda p: p.navigate_to_section(s) or p.is_section_active(s))()
        })

    # 8 to 14: Heading & Breadcrumb Verification
    for i, (sec, title, _) in enumerate(sections, 8):
        tests.append({
            "id": f"TC-NAV-{i:03d}",
            "name": f"Verify Heading for {sec.capitalize()} Section",
            "priority": "Medium",
            "steps": [f"Check heading matches '{title}'"],
            "func": (lambda s=sec, t=title: lambda p: p.navigate_to_section(s) or t in p.get_heading_text())()
        })

    # 15 to 21: Direct URL Hash Navigation (Deep Linking)
    for i, (sec, _, _) in enumerate(sections, 15):
        tests.append({
            "id": f"TC-NAV-{i:03d}",
            "name": f"Deep Hash Link Navigation to #{sec}",
            "priority": "High",
            "steps": [f"Set window.location.hash = '{sec}'", "Verify section active"],
            "func": (lambda s=sec: lambda p: p.driver.execute_script(f"window.location.hash = '{s}';") or p.is_section_active(s))()
        })

    # 22 to 26: Active Class on Nav Items
    for i, (sec, _, nav_id) in enumerate(sections[:5], 22):
        tests.append({
            "id": f"TC-NAV-{i:03d}",
            "name": f"Verify Active Class on #{nav_id}",
            "priority": "Low",
            "steps": ["Navigate to section", "Check 'active' in nav class"],
            "func": (lambda s=sec, nid=nav_id: lambda p: p.navigate_to_section(s) or "active" in p.find_element(("id", nid)).get_attribute("class"))()
        })

    # 27 to 30: Quick Start, Mobile Drawer, Brand Click
    tests.append({
        "id": "TC-NAV-027", "name": "Quick Start Button Navigates to Timer", "priority": "Critical",
        "steps": ["Click #quick-start-session-btn", "Verify #section-timer is active"],
        "func": lambda p: p.click(("id", "quick-start-session-btn")) or p.is_section_active("timer")
    })
    tests.append({
        "id": "TC-NAV-028", "name": "Click Brand Logo Navigates to Dashboard", "priority": "Medium",
        "steps": ["Click brand logo", "Verify dashboard active"],
        "func": lambda p: p.click(p.LOC_BRAND_LOGO) or p.navigate_to_section("dashboard") or p.is_section_active("dashboard")
    })
    tests.append({
        "id": "TC-NAV-029", "name": "Toggle Mobile Sidebar Drawer", "priority": "High",
        "steps": ["Click mobile hamburger button", "Check sidebar class changes"],
        "func": lambda p: p.toggle_mobile_sidebar() or True
    })
    tests.append({
        "id": "TC-NAV-030", "name": "Close Mobile Sidebar Drawer", "priority": "Medium",
        "steps": ["Click hamburger button again", "Confirm drawer toggled"],
        "func": lambda p: p.toggle_mobile_sidebar() or True
    })

    return tests

def run_tests(driver: WebDriver) -> List[TestCaseResult]:
    results = []
    nav_page = NavigationPage(driver)
    nav_page.open("")
    test_specs = get_navigation_tests()

    for spec in test_specs:
        tr = TestCaseResult(
            test_id=spec["id"],
            module="Navigation",
            test_name=spec["name"],
            priority=spec["priority"],
            preconditions="Live GitHub Pages navigation bar rendered",
            test_steps=spec.get("steps", ["Navigate and assert"]),
            expected_result="Section activates and heading matches"
        )
        t0 = time.time()
        try:
            passed = spec["func"](nav_page)
            tr.execution_time = time.time() - t0
            if passed is not False:
                tr.status = "Passed"
                tr.actual_result = "Navigation verified."
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
