"""
FocusEcho Automation Configuration Module
Enterprise configuration loader supporting environment variables, defaults,
and CI/CD execution flags. Hardcoded URLs are forbidden.
"""

import os
from pathlib import Path

# Base Paths
AUTOMATION_ROOT = Path(__file__).resolve().parent.parent
PROJECT_ROOT = AUTOMATION_ROOT.parent
RESULTS_ROOT = PROJECT_ROOT / "Test Results"

# Output Directories
EXCEL_DIR = RESULTS_ROOT / "Excel"
HTML_DIR = RESULTS_ROOT / "HTML"
SCREENSHOT_DIR = RESULTS_ROOT / "Screenshots"
LOG_DIR = RESULTS_ROOT / "Logs"
JSON_DIR = RESULTS_ROOT / "JSON"
SUMMARY_DIR = RESULTS_ROOT / "Summary"

for directory in [EXCEL_DIR, HTML_DIR, SCREENSHOT_DIR, LOG_DIR, JSON_DIR, SUMMARY_DIR]:
    directory.mkdir(parents=True, exist_ok=True)

class Config:
    """Test target and browser configuration."""

    TEST_ENV = os.environ.get("TEST_ENV", "local").strip().lower()
    if TEST_ENV not in {"local", "production"}:
        raise ValueError("TEST_ENV must be either 'local' or 'production'.")
    DEFAULT_BASE_URL = (
        "http://127.0.0.1:8081/"
        if TEST_ENV == "local"
        else "https://vignesh-DA.github.io/FocusEcho/"
    )
    BASE_URL = os.environ.get("BASE_URL", DEFAULT_BASE_URL).strip()
    if not BASE_URL.endswith("/") and not BASE_URL.endswith(".html"):
        BASE_URL += "/"

    # Browser Configuration
    BROWSER = os.environ.get("BROWSER", "chrome").strip().lower()
    HEADLESS = os.environ.get("HEADLESS", "true").lower() in ("true", "1", "yes")
    WINDOW_WIDTH = int(os.environ.get("WINDOW_WIDTH", "1920"))
    WINDOW_HEIGHT = int(os.environ.get("WINDOW_HEIGHT", "1080"))

    # Timing and Waits
    DEFAULT_TIMEOUT = int(os.environ.get("DEFAULT_TIMEOUT", "10"))
    POLL_FREQUENCY = float(os.environ.get("POLL_FREQUENCY", "0.25"))
    PAGE_LOAD_TIMEOUT = int(os.environ.get("PAGE_LOAD_TIMEOUT", "30"))
    SCRIPT_TIMEOUT = int(os.environ.get("SCRIPT_TIMEOUT", "20"))
    RETRY_COUNT = int(os.environ.get("RETRY_COUNT", "2"))

    # Pass / Fail Quality Gate Thresholds
    PASS_PERCENTAGE_THRESHOLD = float(os.environ.get("PASS_PERCENTAGE_THRESHOLD", "100.0"))
    MAX_CRITICAL_FAIL_PERCENTAGE = float(os.environ.get("MAX_CRITICAL_FAIL_PERCENTAGE", "0.0"))

    # Artifact Retention (Days)
    ARTIFACT_RETENTION_DAYS = 30

    @classmethod
    def get_url(cls, path: str = "") -> str:
        """Resolve an endpoint against the configured BASE_URL."""
        clean_path = path.lstrip("/")
        if not clean_path:
            return cls.BASE_URL
        if clean_path.startswith("#"):
            if cls.BASE_URL.endswith(".html"):
                return cls.BASE_URL + clean_path
            return cls.BASE_URL.rstrip("/") + "/" + clean_path
        if cls.BASE_URL.endswith("/"):
            return cls.BASE_URL + clean_path
        return cls.BASE_URL + "/" + clean_path

    @classmethod
    def validate_url(cls) -> None:
        """Prevent accidental production traffic from local runs and vice versa."""
        from urllib.parse import urlparse

        parsed = urlparse(cls.BASE_URL)
        local_hosts = {"localhost", "127.0.0.1", "0.0.0.0", "::1"}
        is_local_host = (parsed.hostname or "").lower() in local_hosts
        if cls.TEST_ENV == "local":
            if parsed.scheme not in {"http", "https"} or not is_local_host:
                raise ValueError("Local test mode must target localhost or a loopback address.")
        elif parsed.scheme != "https" or is_local_host:
            raise ValueError("Production test mode requires a public HTTPS URL.")
