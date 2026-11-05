"""
WebDriver Factory for FocusEcho Automation
Configures and initializes headless Chrome instances with enterprise capabilities,
console log capturing, and high performance flags.
"""

from selenium import webdriver
from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium.webdriver.edge.options import Options as EdgeOptions
from automation.config.config import Config
from automation.utils.logger import logger

class DriverFactory:
    """Factory to create configured WebDriver instances."""

    @staticmethod
    def create_driver(headless: bool = None) -> webdriver.Remote:
        """Create a configured Chrome or Edge WebDriver."""
        use_headless = Config.HEADLESS if headless is None else headless

        if Config.BROWSER == "chrome":
            options = ChromeOptions()
            browser_factory = webdriver.Chrome
        elif Config.BROWSER == "edge":
            options = EdgeOptions()
            browser_factory = webdriver.Edge
        else:
            raise ValueError("BROWSER must be either 'chrome' or 'edge'.")
        if use_headless:
            options.add_argument("--headless=new" if Config.BROWSER == "chrome" else "--headless")
        options.add_argument(f"--window-size={Config.WINDOW_WIDTH},{Config.WINDOW_HEIGHT}")
        options.add_argument("--disable-notifications")
        options.add_argument("--disable-popup-blocking")
        options.add_argument("--user-agent=FocusEcho-QA-Automation/1.0")

        logger.info(
            "Initializing %s WebDriver (headless=%s, size=%sx%s)",
            Config.BROWSER,
            use_headless,
            Config.WINDOW_WIDTH,
            Config.WINDOW_HEIGHT,
        )
        driver = browser_factory(options=options)
        driver.set_page_load_timeout(Config.PAGE_LOAD_TIMEOUT)
        driver.set_script_timeout(Config.SCRIPT_TIMEOUT)
        return driver

    @staticmethod
    def get_browser_logs(driver: webdriver.Remote) -> list:
        """Fetch captured browser console logs."""
        try:
            return driver.get_log("browser")
        except Exception:
            return []
