"""
Base Page Object for FocusEcho Automation Framework
All Page Objects inherit from BasePage. Enforces BASE_URL resolution and
provides shared element interaction primitives.
"""

from selenium.webdriver.remote.webdriver import WebDriver
from selenium.webdriver.common.by import By
from selenium.webdriver.remote.webelement import WebElement
from automation.config.config import Config
from automation.utils.wait_utils import WaitUtils
from automation.utils.logger import logger

class BasePage:
    """Foundational page object containing shared locators and interactions."""

    # Common Global Locators
    LOC_APP_TITLE = (By.ID, "app-title")
    LOC_GLOBAL_ALERT = (By.ID, "global-alert")
    LOC_ALERT_MESSAGE = (By.ID, "alert-message")
    LOC_ALERT_CLOSE_BTN = (By.ID, "alert-close-btn")
    LOC_THEME_TOGGLE_BTN = (By.ID, "theme-toggle-btn")
    LOC_SYNC_STATUS = (By.ID, "sync-status")
    LOC_SYNC_STATUS_TEXT = (By.ID, "sync-status-text")
    LOC_BREADCRUMBS = (By.ID, "breadcrumbs")
    LOC_PAGE_HEADING = (By.ID, "page-heading")
    LOC_SKIP_LINK = (By.ID, "skip-link")

    def __init__(self, driver: WebDriver):
        self.driver = driver
        self.wait = WaitUtils(driver)

    def open(self, path: str = "") -> None:
        """Navigate to an application URL resolved strictly via Config.BASE_URL."""
        target_url = Config.get_url(path)
        logger.info(f"Navigating to: {target_url}")
        self.driver.get(target_url)
        self.wait.wait_for_page_ready()

    def get_title(self) -> str:
        """Return the current document title."""
        return self.driver.title

    def get_current_url(self) -> str:
        """Return the current browser URL."""
        return self.driver.current_url

    def find_element(self, locator: tuple) -> WebElement:
        """Wait for element visibility and return."""
        return self.wait.wait_for_visible(locator)

    def click(self, locator: tuple) -> None:
        """Safely click an element with retry handling."""
        self.wait.safe_click(locator)

    def type_text(self, locator: tuple, text: str, clear: bool = True) -> None:
        """Enter text into an input field."""
        elem = self.wait.wait_for_visible(locator)
        if clear:
            elem.clear()
        elem.send_keys(text)

    def is_visible(self, locator: tuple, timeout: int = 3) -> bool:
        """Check if an element is currently visible."""
        try:
            WaitUtils(self.driver, timeout).wait_for_visible(locator)
            return True
        except Exception:
            return False

    def toggle_theme(self) -> None:
        """Toggle between Dark and Light themes."""
        self.click(self.LOC_THEME_TOGGLE_BTN)

    def get_body_classes(self) -> list:
        """Return list of CSS classes on body tag."""
        body = self.driver.find_element(By.TAG_NAME, "body")
        return body.get_attribute("class").split()

    def get_alert_message(self) -> str:
        """Get text from global alert banner if visible."""
        if self.is_visible(self.LOC_GLOBAL_ALERT):
            return self.find_element(self.LOC_ALERT_MESSAGE).text
        return ""
