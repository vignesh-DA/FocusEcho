"""
Page Objects for FocusEcho Onboarding Screens:
  - SplashPage
  - ConsentPage
  - PermissionWizardPage
"""

import time
from pages.base_page import BasePage
from config.test_config import SPLASH_TIMEOUT, EXPLICIT_WAIT


class SplashPage(BasePage):
    """
    FocusEcho Splash Screen (/splash).
    Shows app logo + name briefly, then auto-redirects.
    """

    APP_NAME_TEXT = "Focus Echo AI"

    def wait_for_splash_to_disappear(self, timeout: int = SPLASH_TIMEOUT) -> None:
        """Wait until splash auto-navigates away."""
        time.sleep(3)  # Give splash minimum display time

    def is_splash_visible(self) -> bool:
        return self.is_text_contains_visible("Focus Echo", timeout=3)

    def wait_for_redirect(self) -> None:
        """Wait for any redirect after splash (to consent or dashboard)."""
        time.sleep(SPLASH_TIMEOUT)


class ConsentPage(BasePage):
    """
    FocusEcho Consent Screen (/consent).
    User must accept data consent before proceeding.
    """

    ACCEPT_BUTTON_TEXT = "Accept"
    CONSENT_TITLE_KEYWORDS = ["consent", "privacy", "agree", "terms", "data"]

    def is_on_consent_screen(self) -> bool:
        for kw in self.CONSENT_TITLE_KEYWORDS:
            if self.is_text_contains_visible(kw, timeout=3):
                return True
        return False

    def accept_consent(self) -> None:
        """Tap the Accept / I Agree button."""
        for text in ["Accept", "I Agree", "Agree", "Continue", "OK"]:
            if self.is_text_visible(text, timeout=2):
                self.find_by_text(text).click()
                time.sleep(2)
                return
        # Fallback: scroll and tap any enabled button at bottom
        self.swipe_up()
        for text in ["Accept", "I Agree", "Agree", "Continue"]:
            if self.is_text_visible(text, timeout=2):
                self.find_by_text(text).click()
                time.sleep(2)
                return

    def scroll_consent_content(self) -> None:
        """Scroll through the consent document."""
        self.swipe_up(swipes=3)

    def is_accept_button_visible(self) -> bool:
        for text in ["Accept", "I Agree", "Agree", "Continue"]:
            if self.is_text_visible(text, timeout=2):
                return True
        return False

    def decline_consent(self) -> None:
        """Tap Decline if available."""
        for text in ["Decline", "No", "Cancel"]:
            if self.is_text_visible(text, timeout=2):
                self.find_by_text(text).click()
                return


class PermissionWizardPage(BasePage):
    """
    FocusEcho Permission Wizard Screen (/permission-wizard).
    Guides user through granting Usage Access, Accessibility, and Battery Optimization.
    """

    GRANT_BUTTON_TEXTS = ["Grant", "Allow", "Enable", "Open Settings", "Next", "Continue"]
    SKIP_BUTTON_TEXTS = ["Skip", "Later", "Not Now"]

    def is_on_permission_wizard(self) -> bool:
        return (
            self.is_text_contains_visible("Permission", timeout=5)
            or self.is_text_contains_visible("Usage Access", timeout=3)
            or self.is_text_contains_visible("Accessibility", timeout=3)
        )

    def get_current_permission_title(self) -> str:
        """Return the title of the current permission step."""
        for text in ["Usage Access", "Accessibility Service", "Battery Optimization", "Notifications"]:
            if self.is_text_contains_visible(text, timeout=2):
                return text
        return "Unknown"

    def tap_grant(self) -> None:
        """Tap the primary grant/allow button."""
        for text in self.GRANT_BUTTON_TEXTS:
            if self.is_text_visible(text, timeout=2):
                self.find_by_text(text).click()
                time.sleep(2)
                return

    def skip_permission(self) -> None:
        """Skip the current permission step if possible."""
        for text in self.SKIP_BUTTON_TEXTS:
            if self.is_text_visible(text, timeout=2):
                self.find_by_text(text).click()
                time.sleep(1)
                return

    def count_permission_steps(self) -> int:
        """Return number of indicator dots/steps visible."""
        dots = self.find_all_by_class("android.widget.LinearLayout")
        return len(dots)

    def is_next_button_enabled(self) -> bool:
        for text in ["Next", "Continue", "Grant"]:
            if self.is_text_visible(text, timeout=2):
                elem = self.find_by_text(text, timeout=2)
                return self.is_element_enabled(elem)
        return False

    def proceed_through_all_permissions_without_granting(self) -> None:
        """Navigate through all permission steps by skipping/using next."""
        for _ in range(5):  # Max 5 steps
            skipped = False
            for text in self.SKIP_BUTTON_TEXTS + ["Next"]:
                if self.is_text_visible(text, timeout=2):
                    self.find_by_text(text).click()
                    time.sleep(1)
                    skipped = True
                    break
            if not skipped:
                break
