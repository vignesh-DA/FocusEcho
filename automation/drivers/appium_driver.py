"""
Appium Driver Factory for FocusEcho E2E Framework
Creates and manages WebDriver sessions with retry logic.
"""

import time
import logging
from appium import webdriver

# Appium-Python-Client 3.x moved UiAutomator2Options to a sub-module.
# Try the new location first, fall back to the legacy path.
try:
    from appium.options.android.uiautomator2.base import UiAutomator2Options
except ImportError:
    try:
        from appium.options import UiAutomator2Options  # type: ignore[no-redef]
    except ImportError:
        from appium.webdriver.common.appiumby import AppiumBy  # type: ignore[no-redef]
        UiAutomator2Options = None  # type: ignore[assignment,misc]
from selenium.common.exceptions import WebDriverException

from config.appium_config import APPIUM_SERVER_URL, DESIRED_CAPABILITIES, DESIRED_CAPABILITIES_NO_RESET
from config.test_config import IMPLICIT_WAIT, MAX_RETRIES, RETRY_DELAY_S

logger = logging.getLogger(__name__)


class DriverFactory:
    """Creates Appium WebDriver sessions with retry support."""

    @staticmethod
    def create_driver(no_reset: bool = False, retry_count: int = MAX_RETRIES) -> webdriver.Remote:
        """
        Create an Appium Remote driver session.

        Args:
            no_reset: If True, keeps app data between sessions (faster, stateful tests).
            retry_count: Number of retry attempts if session creation fails.

        Returns:
            Configured Appium WebDriver instance.
        """
        caps = DESIRED_CAPABILITIES_NO_RESET if no_reset else DESIRED_CAPABILITIES
        options = UiAutomator2Options().load_capabilities(caps)

        last_exception = None
        for attempt in range(1, retry_count + 2):
            try:
                logger.info(f"Creating Appium session (attempt {attempt}/{retry_count + 1})...")
                driver = webdriver.Remote(APPIUM_SERVER_URL, options=options)
                driver.implicitly_wait(IMPLICIT_WAIT)
                logger.info(f"✓ Appium session created: {driver.session_id}")
                return driver
            except WebDriverException as exc:
                last_exception = exc
                logger.warning(f"Session creation failed (attempt {attempt}): {exc}")
                if attempt <= retry_count:
                    time.sleep(RETRY_DELAY_S * attempt)

        raise RuntimeError(
            f"Failed to create Appium session after {retry_count + 1} attempts. "
            f"Last error: {last_exception}"
        )

    @staticmethod
    def quit_driver(driver: webdriver.Remote) -> None:
        """Safely quit the driver session."""
        if driver:
            try:
                driver.quit()
                logger.info("✓ Appium session terminated.")
            except Exception as exc:
                logger.warning(f"Error quitting driver: {exc}")

    @staticmethod
    def restart_app(driver: webdriver.Remote) -> None:
        """Terminate and re-launch the app (keeps session alive)."""
        try:
            driver.terminate_app("com.focusecho.ai")
            time.sleep(1)
            driver.activate_app("com.focusecho.ai")
            time.sleep(2)
            logger.info("✓ App restarted.")
        except Exception as exc:
            logger.warning(f"Error restarting app: {exc}")

    @staticmethod
    def reset_app(driver: webdriver.Remote) -> None:
        """Clear app data and restart (equivalent to full reset without session teardown)."""
        try:
            driver.terminate_app("com.focusecho.ai")
            driver.clear_app("com.focusecho.ai")
            time.sleep(1)
            driver.activate_app("com.focusecho.ai")
            time.sleep(3)
            logger.info("✓ App data cleared and restarted.")
        except Exception as exc:
            logger.warning(f"Error resetting app: {exc}")
