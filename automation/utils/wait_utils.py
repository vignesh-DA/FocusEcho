"""
Explicit Wait and Retry Utilities for FocusEcho Selenium Framework
Ensures rock-solid synchronization and eliminates flaky timing issues.
"""

import time
from typing import Callable, Any
from selenium.webdriver.remote.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import (
    TimeoutException,
    StaleElementReferenceException,
    NoSuchElementException,
    ElementClickInterceptedException
)
from automation.config.config import Config
from automation.utils.logger import logger

class WaitUtils:
    """Wrapper around WebDriverWait with retry and safety checks."""

    def __init__(self, driver: WebDriver, timeout: int = None):
        self.driver = driver
        self.timeout = timeout or Config.DEFAULT_TIMEOUT
        self.wait = WebDriverWait(
            driver,
            self.timeout,
            poll_frequency=Config.POLL_FREQUENCY,
            ignored_exceptions=[StaleElementReferenceException, NoSuchElementException]
        )

    def wait_for_visible(self, locator: tuple) -> WebElement:
        """Wait until an element is present in the DOM and visible."""
        return self.wait.until(EC.visibility_of_element_located(locator))

    def wait_for_clickable(self, locator: tuple) -> WebElement:
        """Wait until an element is visible and enabled for clicking."""
        return self.wait.until(EC.element_to_be_clickable(locator))

    def wait_for_presence(self, locator: tuple) -> WebElement:
        """Wait until element is present in DOM."""
        return self.wait.until(EC.presence_of_element_located(locator))

    def wait_for_invisibility(self, locator: tuple) -> bool:
        """Wait until element is invisible or removed from DOM."""
        return self.wait.until(EC.invisibility_of_element_located(locator))

    def wait_for_text_to_be_present(self, locator: tuple, text: str) -> bool:
        """Wait until element text contains expected string."""
        return self.wait.until(EC.text_to_be_present_in_element(locator, text))

    def safe_click(self, locator: tuple, retries: int = None) -> bool:
        """Click an element with automatic retry on ElementClickInterceptedException."""
        max_retries = retries if retries is not None else Config.RETRY_COUNT
        for attempt in range(max_retries + 1):
            try:
                elem = self.wait_for_clickable(locator)
                elem.click()
                return True
            except (ElementClickInterceptedException, StaleElementReferenceException) as e:
                if attempt == max_retries:
                    # Fallback to JavaScript click
                    try:
                        elem = self.wait_for_presence(locator)
                        self.driver.execute_script("arguments[0].click();", elem)
                        return True
                    except Exception:
                        raise e
                time.sleep(0.3)
        return False

    def wait_for_page_ready(self, timeout: int = 15) -> bool:
        """Wait for document.readyState == 'complete'."""
        try:
            WebDriverWait(self.driver, timeout).until(
                lambda d: d.execute_script("return document.readyState") == "complete"
            )
            return True
        except TimeoutException:
            logger.warning("Page readiness timed out; continuing with caution.")
            return False
