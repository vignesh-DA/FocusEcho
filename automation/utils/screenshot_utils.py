"""
Screenshot Utilities for FocusEcho Appium Framework
"""

import os
import time
import logging
from pathlib import Path
from datetime import datetime

from config.test_config import SCREENSHOTS_DIR

logger = logging.getLogger(__name__)


class ScreenshotUtils:
    """Handles screenshot capture, naming, and organisation."""

    _counter = 0

    @classmethod
    def capture(cls, driver, name: str) -> str:
        """
        Capture a screenshot and save it to the Screenshots directory.

        Args:
            driver: Appium WebDriver instance.
            name: Descriptive name for the screenshot.

        Returns:
            Absolute path to the saved screenshot file.
        """
        cls._counter += 1
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        safe_name = cls._sanitize(name)
        filename = f"{cls._counter:04d}_{timestamp}_{safe_name}.png"
        filepath = SCREENSHOTS_DIR / filename

        try:
            driver.save_screenshot(str(filepath))
            logger.info(f"📸 Screenshot saved: {filepath.name}")
            return str(filepath)
        except Exception as exc:
            logger.warning(f"Screenshot capture failed for '{name}': {exc}")
            return ""

    @classmethod
    def capture_on_failure(cls, driver, test_id: str, test_name: str) -> str:
        """Capture screenshot specifically on test failure."""
        name = f"FAIL_{test_id}_{test_name}"
        return cls.capture(driver, name)

    @classmethod
    def capture_step(cls, driver, test_id: str, step: str) -> str:
        """Capture screenshot at a specific test step."""
        name = f"{test_id}_step_{step}"
        return cls.capture(driver, name)

    @staticmethod
    def _sanitize(name: str) -> str:
        """Remove/replace characters invalid in filenames."""
        invalid = r'<>:"/\|?*'
        for ch in invalid:
            name = name.replace(ch, "_")
        name = name.replace(" ", "_")
        return name[:80]  # Cap at 80 chars

    @classmethod
    def get_device_screenshot(cls, driver, name: str) -> str:
        """
        Capture screenshot via ADB (device-level) for deeper debugging.
        Falls back to driver.save_screenshot if ADB not available.
        """
        adb_path = cls._find_adb()
        if adb_path:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            remote_path = f"/sdcard/focusecho_screen_{timestamp}.png"
            local_path = SCREENSHOTS_DIR / f"device_{timestamp}_{cls._sanitize(name)}.png"
            try:
                os.system(f"{adb_path} shell screencap -p {remote_path}")
                os.system(f"{adb_path} pull {remote_path} {local_path}")
                os.system(f"{adb_path} shell rm {remote_path}")
                return str(local_path)
            except Exception as exc:
                logger.warning(f"ADB screenshot failed: {exc}")

        return cls.capture(driver, f"device_{name}")

    @staticmethod
    def _find_adb() -> str:
        """Find ADB executable path."""
        android_home = os.getenv("ANDROID_HOME") or os.getenv("ANDROID_SDK_ROOT")
        if android_home:
            adb = Path(android_home) / "platform-tools" / "adb"
            if adb.exists():
                return str(adb)
            adb_win = adb.with_suffix(".exe")
            if adb_win.exists():
                return str(adb_win)
        return ""

    @classmethod
    def reset_counter(cls) -> None:
        cls._counter = 0

    @classmethod
    def list_all_screenshots(cls) -> list[str]:
        """Return sorted list of all captured screenshot paths."""
        return sorted([str(p) for p in SCREENSHOTS_DIR.glob("*.png")])
