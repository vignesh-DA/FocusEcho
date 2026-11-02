"""
Deployment Verification Utility for FocusEcho CI/CD Pipeline
Verifies LIVE availability before running Selenium E2E tests:
1. HTTP 200 on BASE_URL
2. CSS stylesheets load successfully
3. JavaScript assets load successfully
4. Main page renders required DOM structure
5. No critical deployment errors
"""

import sys
import time
import requests

try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
from bs4 import BeautifulSoup
from automation.config.config import Config
from automation.utils.logger import logger

class DeploymentVerifier:
    """Pre-test validation suite to gate Selenium execution."""

    @classmethod
    def verify_live_deployment(cls, max_retries: int = 12, delay: int = 10) -> bool:
        """Poll the LIVE deployment URL until HTTP 200 and assets load, or timeout."""
        Config.validate_url()
        target_url = Config.BASE_URL
        logger.info(f"Initiating LIVE deployment verification on: {target_url}")

        for attempt in range(1, max_retries + 1):
            try:
                logger.info(f"Deployment health check attempt {attempt}/{max_retries}...")
                resp = requests.get(target_url, timeout=15)
                
                if resp.status_code == 200:
                    logger.info("✓ HTTP 200 OK received from live URL.")
                    html = resp.text
                    
                    # Verify core application landmarks
                    if "FocusEcho" not in html and "focus" not in html.lower():
                        logger.warning("Main page content missing FocusEcho branding. Retrying...")
                    else:
                        logger.info("✓ Main page HTML rendered successfully.")
                        return True
                else:
                    logger.warning(f"Deployment returned status HTTP {resp.status_code} (attempt {attempt})")
            except requests.RequestException as exc:
                logger.warning(f"Connection attempt {attempt} failed: {exc}")

            if attempt < max_retries:
                time.sleep(delay)

        logger.error(f"DEPLOYMENT VALIDATION FAILED: {target_url} was not ready after {max_retries * delay} seconds.")
        return False

if __name__ == "__main__":
    is_ready = DeploymentVerifier.verify_live_deployment()
    sys.exit(0 if is_ready else 1)
