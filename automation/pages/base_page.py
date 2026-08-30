"""
BasePage: Foundation class for all Page Object Models.
Provides element interaction, waits, scrolling, and screenshot helpers.
"""

import time
import logging
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import (
    TimeoutException, NoSuchElementException, StaleElementReferenceException
)

from config.test_config import EXPLICIT_WAIT, ANIMATION_TIMEOUT

logger = logging.getLogger(__name__)


class BasePage:
    """Base class for all page objects in FocusEcho automation."""

    def __init__(self, driver):
        self.driver = driver
        self.wait = WebDriverWait(driver, EXPLICIT_WAIT)

    # ─────────────────────────────────────────────────────────────────────────
    # Element Finders
    # ─────────────────────────────────────────────────────────────────────────

    def find_by_id(self, resource_id: str, timeout: int = EXPLICIT_WAIT):
        """Find element by resource-id."""
        full_id = resource_id if ":" in resource_id else f"com.focusecho.ai:id/{resource_id}"
        return self._wait_for(AppiumBy.ID, full_id, timeout)

    def find_by_text(self, text: str, timeout: int = EXPLICIT_WAIT):
        """Find element by exact text."""
        return self._wait_for(AppiumBy.ANDROID_UIAUTOMATOR,
                              f'new UiSelector().text("{text}")', timeout)

    def find_by_text_contains(self, text: str, timeout: int = EXPLICIT_WAIT):
        """Find element that contains the given text."""
        return self._wait_for(AppiumBy.ANDROID_UIAUTOMATOR,
                              f'new UiSelector().textContains("{text}")', timeout)

    def find_by_desc(self, desc: str, timeout: int = EXPLICIT_WAIT):
        """Find element by content-description (accessibility label)."""
        return self._wait_for(AppiumBy.ACCESSIBILITY_ID, desc, timeout)

    def find_by_xpath(self, xpath: str, timeout: int = EXPLICIT_WAIT):
        """Find element by XPath."""
        return self._wait_for(AppiumBy.XPATH, xpath, timeout)

    def find_by_class(self, class_name: str, timeout: int = EXPLICIT_WAIT):
        """Find element by class name."""
        return self._wait_for(AppiumBy.CLASS_NAME, class_name, timeout)

    def find_all_by_class(self, class_name: str):
        """Find all elements matching class name."""
        return self.driver.find_elements(AppiumBy.CLASS_NAME, class_name)

    def find_all_by_text_contains(self, text: str):
        """Find all elements containing text."""
        return self.driver.find_elements(
            AppiumBy.ANDROID_UIAUTOMATOR,
            f'new UiSelector().textContains("{text}")'
        )

    def _wait_for(self, by, value, timeout):
        try:
            return WebDriverWait(self.driver, timeout).until(
                EC.presence_of_element_located((by, value))
            )
        except TimeoutException:
            raise TimeoutException(
                f"Element not found: [{by}] '{value}' within {timeout}s\n"
                f"Current activity: {self._current_activity()}"
            )

    # ─────────────────────────────────────────────────────────────────────────
    # Interaction Helpers
    # ─────────────────────────────────────────────────────────────────────────

    def click(self, element_or_text, by_text: bool = False):
        """Click an element or find-by-text and click."""
        elem = self.find_by_text(element_or_text) if by_text else element_or_text
        elem.click()
        time.sleep(ANIMATION_TIMEOUT)

    def type_text(self, element, text: str, clear_first: bool = True):
        """Type text into an input field."""
        if clear_first:
            element.clear()
        element.send_keys(text)

    def tap(self, x: int, y: int):
        """Tap at absolute coordinates."""
        self.driver.tap([(x, y)])

    def long_press(self, element, duration_ms: int = 1500):
        """Long press on an element."""
        from appium.webdriver.common.touch_action import TouchAction
        action = TouchAction(self.driver)
        action.long_press(element, duration=duration_ms).release().perform()

    def swipe_up(self, swipes: int = 1):
        """Swipe up to scroll down."""
        size = self.driver.get_window_size()
        w, h = size["width"], size["height"]
        for _ in range(swipes):
            self.driver.swipe(w // 2, int(h * 0.7), w // 2, int(h * 0.3), 600)
            time.sleep(0.5)

    def swipe_down(self, swipes: int = 1):
        """Swipe down to scroll up / trigger pull-to-refresh."""
        size = self.driver.get_window_size()
        w, h = size["width"], size["height"]
        for _ in range(swipes):
            self.driver.swipe(w // 2, int(h * 0.3), w // 2, int(h * 0.7), 600)
            time.sleep(0.5)

    def scroll_to_text(self, text: str):
        """Scroll until element with text is visible."""
        try:
            self.driver.find_element(
                AppiumBy.ANDROID_UIAUTOMATOR,
                f'new UiScrollable(new UiSelector().scrollable(true)).scrollIntoView('
                f'new UiSelector().text("{text}"))'
            )
        except NoSuchElementException:
            pass

    def pull_to_refresh(self):
        """Trigger pull-to-refresh gesture."""
        self.swipe_down(swipes=2)
        time.sleep(2)

    # ─────────────────────────────────────────────────────────────────────────
    # Visibility / State Checks
    # ─────────────────────────────────────────────────────────────────────────

    def is_visible(self, locator_func, *args, timeout: int = 5) -> bool:
        """Return True if element is visible within timeout, else False."""
        try:
            elem = locator_func(*args, timeout=timeout)
            return elem.is_displayed()
        except (TimeoutException, NoSuchElementException):
            return False

    def is_text_visible(self, text: str, timeout: int = 5) -> bool:
        return self.is_visible(self.find_by_text, text, timeout=timeout)

    def is_text_contains_visible(self, text: str, timeout: int = 5) -> bool:
        return self.is_visible(self.find_by_text_contains, text, timeout=timeout)

    def wait_for_text_visible(self, text: str, timeout: int = EXPLICIT_WAIT):
        """Wait until text is visible on screen."""
        return self.find_by_text(text, timeout=timeout)

    def wait_for_text_gone(self, text: str, timeout: int = EXPLICIT_WAIT):
        """Wait until text disappears from screen."""
        try:
            WebDriverWait(self.driver, timeout).until_not(
                lambda d: d.find_element(
                    AppiumBy.ANDROID_UIAUTOMATOR,
                    f'new UiSelector().text("{text}")'
                ).is_displayed()
            )
        except Exception:
            pass

    def get_element_text(self, element) -> str:
        return element.text.strip()

    def get_text_by_locator(self, text: str) -> str:
        return self.find_by_text(text).text.strip()

    def is_element_enabled(self, element) -> bool:
        return element.is_enabled()

    def is_element_checked(self, element) -> bool:
        return element.get_attribute("checked") == "true"

    def get_attribute(self, element, attr: str) -> str:
        return element.get_attribute(attr) or ""

    # ─────────────────────────────────────────────────────────────────────────
    # Screenshots
    # ─────────────────────────────────────────────────────────────────────────

    def take_screenshot(self, name: str) -> str:
        """Capture screenshot and return file path."""
        from utils.screenshot_utils import ScreenshotUtils
        return ScreenshotUtils.capture(self.driver, name)

    # ─────────────────────────────────────────────────────────────────────────
    # Navigation Helpers
    # ─────────────────────────────────────────────────────────────────────────

    def press_back(self):
        """Press Android back button."""
        self.driver.back()
        time.sleep(ANIMATION_TIMEOUT)

    def press_home(self):
        """Press Android home button."""
        self.driver.press_keycode(3)  # KEYCODE_HOME
        time.sleep(1)

    def bring_app_to_foreground(self):
        """Bring FocusEcho to the foreground."""
        self.driver.activate_app("com.focusecho.ai")
        time.sleep(2)

    def _current_activity(self) -> str:
        try:
            return self.driver.current_activity
        except Exception:
            return "unknown"

    # ─────────────────────────────────────────────────────────────────────────
    # Performance
    # ─────────────────────────────────────────────────────────────────────────

    def measure_load_time(self, action_fn, identifier_fn) -> float:
        """
        Measure time between calling action_fn and identifier_fn becoming True.
        Returns elapsed seconds.
        """
        start = time.time()
        action_fn()
        identifier_fn()
        return time.time() - start
