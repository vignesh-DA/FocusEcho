"""
Reflection Page Object for FocusEcho
Manages post-session rating, drift reasons checkboxes, notes, and submission.
"""

from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class ReflectionPage(BasePage):
    """Page object for Session Reflection form."""

    LOC_STAR_RATING_GROUP = (By.ID, "star-rating-group")
    LOC_RATING_VALUE = (By.ID, "reflection-rating-value")
    LOC_NOTES_INPUT = (By.ID, "reflection-notes")
    LOC_SUBMIT_BTN = (By.ID, "reflection-submit-btn")
    LOC_SUCCESS_MSG = (By.ID, "reflection-success-msg")

    LOC_CHK_STUCK = (By.ID, "chk-stuck")
    LOC_CHK_FATIGUE = (By.ID, "chk-fatigue")
    LOC_CHK_NOTIF = (By.ID, "chk-notif")
    LOC_CHK_IMPULSE = (By.ID, "chk-impulse")

    def set_rating(self, stars: int) -> None:
        """Select 1-5 stars."""
        star_btn = self.driver.find_element(By.CSS_SELECTOR, f".star-btn[data-rating='{stars}']")
        star_btn.click()

    def select_drift_reasons(self, stuck: bool = False, fatigue: bool = False, notif: bool = False, impulse: bool = False) -> None:
        """Toggle drift checkboxes."""
        if stuck:
            self.click(self.LOC_CHK_STUCK)
        if fatigue:
            self.click(self.LOC_CHK_FATIGUE)
        if notif:
            self.click(self.LOC_CHK_NOTIF)
        if impulse:
            self.click(self.LOC_CHK_IMPULSE)

    def submit_reflection(self, notes: str = "") -> None:
        """Add notes and submit reflection form."""
        if notes:
            self.type_text(self.LOC_NOTES_INPUT, notes)
        self.click(self.LOC_SUBMIT_BTN)

    def is_success_displayed(self) -> bool:
        """Check if success banner appeared."""
        return self.is_visible(self.LOC_SUCCESS_MSG)
