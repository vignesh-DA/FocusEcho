"""
Analytics Page Object for FocusEcho
Manages productivity metrics, weekly charts, distracting apps list, and drift risk indicators.
"""

from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class AnalyticsPage(BasePage):
    """Page object for Analytics telemetry and visualizations."""

    LOC_TOTAL_SESSIONS = (By.ID, "analytics-total-sessions")
    LOC_TOTAL_HOURS = (By.ID, "analytics-total-hours")
    LOC_DRIFT_RISK = (By.ID, "analytics-drift-risk")
    LOC_DISTRACTIONS_NEUTRALIZED = (By.ID, "analytics-distractions-neutralized")

    LOC_DISTRACTING_APPS_LIST = (By.ID, "list-distracting-apps")
    LOC_HEATMAP = (By.ID, "analytics-heatmap")

    def get_total_sessions(self) -> str:
        """Get formatted total sessions count."""
        return self.find_element(self.LOC_TOTAL_SESSIONS).text

    def get_drift_risk(self) -> str:
        """Get drift risk indicator text."""
        return self.find_element(self.LOC_DRIFT_RISK).text

    def get_distracting_apps_count(self) -> int:
        """Return the count of categorized distracting apps."""
        items = self.driver.find_elements(By.CSS_SELECTOR, "#list-distracting-apps .breakdown-item")
        return len(items)
