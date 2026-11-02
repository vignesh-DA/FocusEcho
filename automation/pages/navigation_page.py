"""
Navigation Page Object for FocusEcho
Manages sidebar navigation links, mobile drawer toggling, breadcrumbs, and deep-linking.
"""

from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class NavigationPage(BasePage):
    """Page object for application routing and navigation."""

    LOC_SIDEBAR = (By.ID, "app-sidebar")
    LOC_SIDEBAR_TOGGLE_BTN = (By.ID, "sidebar-toggle-btn")
    LOC_BRAND_LOGO = (By.ID, "brand-logo")

    LOC_NAV_DASHBOARD = (By.ID, "nav-dashboard")
    LOC_NAV_TIMER = (By.ID, "nav-timer")
    LOC_NAV_PARKING_LOT = (By.ID, "nav-parking-lot")
    LOC_NAV_ANALYTICS = (By.ID, "nav-analytics")
    LOC_NAV_COACH = (By.ID, "nav-coach")
    LOC_NAV_REFLECTION = (By.ID, "nav-reflection")
    LOC_NAV_SETTINGS = (By.ID, "nav-settings")

    def navigate_to_section(self, section_name: str) -> None:
        """Click on the corresponding nav item."""
        nav_map = {
            "dashboard": self.LOC_NAV_DASHBOARD,
            "timer": self.LOC_NAV_TIMER,
            "parking-lot": self.LOC_NAV_PARKING_LOT,
            "analytics": self.LOC_NAV_ANALYTICS,
            "coach": self.LOC_NAV_COACH,
            "reflection": self.LOC_NAV_REFLECTION,
            "settings": self.LOC_NAV_SETTINGS
        }
        if section_name.lower() in nav_map:
            self.click(nav_map[section_name.lower()])

    def is_section_active(self, section_name: str) -> bool:
        """Check if a content section has the 'active' class."""
        sec_id = f"section-{section_name.lower()}"
        elem = self.driver.find_element(By.ID, sec_id)
        return "active" in elem.get_attribute("class")

    def get_heading_text(self) -> str:
        """Get topbar page heading."""
        return self.find_element(self.LOC_PAGE_HEADING).text

    def get_breadcrumb_text(self) -> str:
        """Get breadcrumb string."""
        return self.find_element(self.LOC_BREADCRUMBS).text

    def toggle_mobile_sidebar(self) -> None:
        """Click mobile drawer hamburger toggle."""
        self.driver.execute_script("document.getElementById('sidebar-toggle-btn').click();")
