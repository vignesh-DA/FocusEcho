"""
WebDriver Factory for FocusEcho Automation
Configures and initializes headless Chrome instances with enterprise capabilities,
console log capturing, and high performance flags.
"""

from selenium import webdriver
from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium.webdriver.chrome.service import Service as ChromeService
from automation.config.config import Config
from automation.utils.logger import logger

class DriverFactory:
    """Factory to create configured WebDriver instances."""

    @staticmethod
    def create_driver(headless: bool = None) -> webdriver.Chrome:
        """Instantiate a Chrome WebDriver with production flags."""
        use_headless = Config.HEADLESS if headless is None else headless
        
        options = ChromeOptions()
        if use_headless:
            options.add_argument("--headless=new")
        
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-gpu")
        options.add_argument(f"--window-size={Config.WINDOW_WIDTH},{Config.WINDOW_HEIGHT}")
        options.add_argument("--disable-extensions")
        options.add_argument("--disable-notifications")
        options.add_argument("--disable-popup-blocking")
        options.add_argument("--remote-allow-origins=*")
        options.add_argument("--user-agent=FocusEcho-E2E-Automated-Testing-Agent/2.4")

        # Enable browser console logging
        options.set_capability("goog:loggingPrefs", {"browser": "ALL"})

        logger.info(f"Initializing Chrome Driver (headless={use_headless}, size={Config.WINDOW_WIDTH}x{Config.WINDOW_HEIGHT})")
        driver = webdriver.Chrome(options=options)
        
        driver.set_page_load_timeout(Config.PAGE_LOAD_TIMEOUT)
        driver.set_script_timeout(Config.SCRIPT_TIMEOUT)
        return driver

    @staticmethod
    def get_browser_logs(driver: webdriver.Chrome) -> list:
        """Fetch captured browser console logs."""
        try:
            return driver.get_log("browser")
        except Exception:
            return []
