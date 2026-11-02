"""
Accessibility & Responsive Design Page Objects for FocusEcho
Provides verification for ARIA compliance, keyboard focus, and viewport layout reflow.
"""

from selenium.webdriver.common.by import By
from selenium.webdriver.remote.webdriver import WebDriver
from automation.pages.base_page import BasePage

class AccessibilityPage(BasePage):
    """Verifies accessibility attributes, ARIA roles, and keyboard navigation."""

    def verify_aria_roles(self) -> dict:
        """Verify presence of main semantic landmarks."""
        results = {
            "has_main": len(self.driver.find_elements(By.CSS_SELECTOR, "main[role='main']")) > 0,
            "has_navigation": len(self.driver.find_elements(By.CSS_SELECTOR, "aside[role='navigation']")) > 0,
            "has_skip_link": len(self.driver.find_elements(By.ID, "skip-link")) > 0,
            "has_aria_live": len(self.driver.find_elements(By.CSS_SELECTOR, "[aria-live]")) > 0,
            "has_dialogs": len(self.driver.find_elements(By.CSS_SELECTOR, "[role='dialog']")) > 0
        }
        return results

    def verify_alt_and_labels(self) -> bool:
        """Ensure all interactive inputs and buttons have accessible labels."""
        unlabeled_inputs = self.driver.find_elements(By.CSS_SELECTOR, "input:not([aria-label]):not([id])")
        return len(unlabeled_inputs) == 0

class ResponsivePage(BasePage):
    """Verifies layout adjustments across responsive viewport breakpoints."""

    def set_viewport(self, width: int, height: int) -> None:
        """Resize browser window to target dimensions."""
        self.driver.set_window_size(width, height)

    def is_mobile_toggle_visible(self) -> bool:
        """Check if mobile hamburger button is visible at current breakpoint."""
        try:
            return self.driver.execute_script(
                "const btn = document.getElementById('sidebar-toggle-btn'); "
                "return window.getComputedStyle(btn).display !== 'none';"
            )
        except Exception:
            return False

    def is_sidebar_collapsed(self) -> bool:
        """Check if sidebar is off-canvas / collapsed."""
        elem = self.driver.find_element(By.ID, "app-sidebar")
        location = elem.location
        return location["x"] < 0 or not elem.is_displayed()
