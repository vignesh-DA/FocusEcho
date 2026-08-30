"""
Logging Utilities for FocusEcho Appium Framework
"""

import logging
import sys
from datetime import datetime
from pathlib import Path

from config.test_config import LOGS_DIR


def setup_logger(name: str = "focusecho_automation", level: int = logging.DEBUG) -> logging.Logger:
    """
    Configure and return a logger with both file and console handlers.

    Args:
        name: Logger name.
        level: Logging level.

    Returns:
        Configured logger instance.
    """
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger  # Already configured

    logger.setLevel(level)

    # Formatter
    fmt = logging.Formatter(
        "%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # File handler — writes to Logs/automation_<timestamp>.log
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = LOGS_DIR / f"automation_{timestamp}.log"
    fh = logging.FileHandler(str(log_file), encoding="utf-8")
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    # Console handler
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.INFO)
    ch.setFormatter(fmt)
    logger.addHandler(ch)

    return logger


class TestLogger:
    """Per-test structured logger with step tracking."""

    def __init__(self, test_id: str, test_name: str):
        self.test_id = test_id
        self.test_name = test_name
        self.logger = setup_logger(f"test.{test_id}")
        self.steps: list[dict] = []
        self.start_time = datetime.now()

    def step(self, description: str) -> None:
        """Log a test step."""
        step_num = len(self.steps) + 1
        msg = f"[{self.test_id}] Step {step_num}: {description}"
        self.logger.info(msg)
        self.steps.append({"step": step_num, "description": description, "time": datetime.now().isoformat()})

    def pass_test(self, message: str = "") -> None:
        elapsed = (datetime.now() - self.start_time).total_seconds()
        self.logger.info(f"✅ PASS | {self.test_id} | {self.test_name} | {elapsed:.2f}s | {message}")

    def fail_test(self, reason: str, screenshot_path: str = "") -> None:
        elapsed = (datetime.now() - self.start_time).total_seconds()
        self.logger.error(
            f"❌ FAIL | {self.test_id} | {self.test_name} | {elapsed:.2f}s\n"
            f"   Reason: {reason}\n"
            f"   Screenshot: {screenshot_path}"
        )

    def skip_test(self, reason: str = "") -> None:
        self.logger.warning(f"⏭  SKIP | {self.test_id} | {self.test_name} | {reason}")

    def info(self, message: str) -> None:
        self.logger.info(f"[{self.test_id}] {message}")

    def warning(self, message: str) -> None:
        self.logger.warning(f"[{self.test_id}] ⚠ {message}")

    def error(self, message: str) -> None:
        self.logger.error(f"[{self.test_id}] ✗ {message}")


def capture_logcat(lines: int = 200) -> str:
    """Capture recent Android logcat entries."""
    import os
    adb = _find_adb()
    if not adb:
        return "ADB not found — logcat unavailable"
    try:
        result = os.popen(f"{adb} logcat -d -t {lines}").read()
        return result
    except Exception as exc:
        return f"Logcat capture failed: {exc}"


def save_logcat_for_test(test_id: str) -> str:
    """Save logcat output for a specific failed test."""
    log_content = capture_logcat(lines=300)
    log_file = LOGS_DIR / f"logcat_{test_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    log_file.write_text(log_content, encoding="utf-8")
    return str(log_file)


def _find_adb() -> str:
    from pathlib import Path
    import os
    android_home = os.getenv("ANDROID_HOME") or os.getenv("ANDROID_SDK_ROOT")
    if android_home:
        adb = Path(android_home) / "platform-tools" / "adb"
        if adb.exists():
            return str(adb)
        adb_win = adb.with_suffix(".exe")
        if adb_win.exists():
            return str(adb_win)
    return ""
