"""
Screenshot Utility for FocusEcho Selenium Test Framework
Captures full-page and viewport screenshots upon test step failure.
"""

import base64
import time
from pathlib import Path
from selenium.webdriver.remote.webdriver import WebDriver
from automation.config.config import SCREENSHOT_DIR
from automation.utils.logger import logger

class ScreenshotUtil:
    """Manages screenshot capture and thumbnail encoding."""

    @staticmethod
    def capture_screenshot(driver: WebDriver, test_id: str, suffix: str = "failed") -> Path:
        """Capture screenshot and save to Test Results/Screenshots/."""
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        clean_id = test_id.replace("/", "_").replace(" ", "_")
        filename = f"{clean_id}_{suffix}_{timestamp}.png"
        filepath = SCREENSHOT_DIR / filename

        try:
            driver.save_screenshot(str(filepath))
            logger.info(f"Screenshot saved: {filepath.name}")
            return filepath
        except Exception as exc:
            logger.error(f"Failed to capture screenshot for {test_id}: {exc}")
            return None

    @staticmethod
    def get_base64_thumbnail(filepath: Path) -> str:
        """Convert an image file to a base64 data URI for inline HTML rendering."""
        if not filepath or not filepath.exists():
            return ""
        try:
            with open(filepath, "rb") as f:
                encoded = base64.b64encode(f.read()).decode("utf-8")
                return f"data:image/png;base64,{encoded}"
        except Exception as exc:
            logger.warning(f"Error encoding thumbnail for {filepath}: {exc}")
            return ""
