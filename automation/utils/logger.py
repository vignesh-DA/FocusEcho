"""
Logging Utility for FocusEcho Selenium Test Framework
Provides structured timestamped logging to console and persistent log files.
"""

import logging
import sys
from pathlib import Path

try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

from automation.config.config import LOG_DIR

LOG_FILE = LOG_DIR / "automation.log"

def get_logger(name: str = "FocusEchoAutomation") -> logging.Logger:
    """Configures and returns a logger instance."""
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger

    logger.setLevel(logging.DEBUG)
    formatter = logging.Formatter(
        fmt="[%(asctime)s] [%(levelname)-8s] [%(name)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    # Console Handler
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.INFO)
    ch.setFormatter(formatter)
    logger.addHandler(ch)

    # File Handler
    try:
        fh = logging.FileHandler(LOG_FILE, encoding="utf-8")
        fh.setLevel(logging.DEBUG)
        fh.setFormatter(formatter)
        logger.addHandler(fh)
    except Exception as exc:
        print(f"Warning: Could not create file handler for {LOG_FILE}: {exc}")

    return logger

logger = get_logger()
