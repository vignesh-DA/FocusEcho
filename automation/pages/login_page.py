"""
LoginPage — Page Object for FocusEcho Login Screen (/login)
Handles: Google Sign-In, Continue as Guest
"""

import time
from pages.base_page import BasePage


class LoginPage(BasePage):
    """
    Login Screen page object.
    Route: /login
    Key Elements:
      - Lock icon
      - "Sync Your Progress" title
      - "Continue with Google" ElevatedButton
      - "Continue as Guest" TextButton
      - CircularProgressIndicator (loading state)
    """

    # Text locators (from login_screen.dart)
    TITLE_TEXT = "Sync Your Progress"
    SUBTITLE_CONTAINS = "Sign in to save your focus streaks"
    GOOGLE_BUTTON_TEXT = "Continue with Google"
    GUEST_BUTTON_TEXT = "Continue as Guest"
    LOADING_CLASS = "android.widget.ProgressBar"

    # ─────────────────────────────────────────────────────────────────────────
    # Assertions / State checks
    # ─────────────────────────────────────────────────────────────────────────

    def is_on_login_screen(self) -> bool:
        return self.is_text_visible(self.TITLE_TEXT, timeout=10)

    def is_loading(self) -> bool:
        return self.is_visible(self.find_by_class, self.LOADING_CLASS, timeout=2)

    def is_google_button_visible(self) -> bool:
        return self.is_text_visible(self.GOOGLE_BUTTON_TEXT, timeout=5)

    def is_guest_button_visible(self) -> bool:
        return self.is_text_visible(self.GUEST_BUTTON_TEXT, timeout=5)

    def is_google_button_enabled(self) -> bool:
        elem = self.find_by_text(self.GOOGLE_BUTTON_TEXT)
        return self.is_element_enabled(elem)

    def is_guest_button_enabled(self) -> bool:
        elem = self.find_by_text(self.GUEST_BUTTON_TEXT)
        return self.is_element_enabled(elem)

    def get_title_text(self) -> str:
        return self.find_by_text(self.TITLE_TEXT).text.strip()

    def get_subtitle_text(self) -> str:
        return self.find_by_text_contains("Sign in to save").text.strip()

    # ─────────────────────────────────────────────────────────────────────────
    # Actions
    # ─────────────────────────────────────────────────────────────────────────

    def tap_continue_with_google(self) -> None:
        """Tap the Google sign-in button (will open Google OAuth flow)."""
        self.find_by_text(self.GOOGLE_BUTTON_TEXT).click()
        time.sleep(3)

    def tap_continue_as_guest(self) -> None:
        """Tap 'Continue as Guest' — skips auth and proceeds to permissions/dashboard."""
        self.find_by_text(self.GUEST_BUTTON_TEXT).click()
        time.sleep(3)

    def wait_for_loading_to_complete(self) -> None:
        """Wait until the loading indicator disappears."""
        self.wait_for_text_gone("CircularProgressIndicator", timeout=15)
        time.sleep(1)

    def dismiss_google_auth_dialog(self) -> None:
        """
        If Google OAuth dialog appears, dismiss it (back) for automation purposes.
        Real Google auth cannot be automated in CI without credentials.
        """
        time.sleep(2)
        # Check if we navigated away from app
        current_pkg = self.driver.current_package
        if current_pkg != "com.focusecho.ai":
            self.driver.back()
            time.sleep(2)
            # If still outside app, press back again
            if self.driver.current_package != "com.focusecho.ai":
                self.driver.back()
                time.sleep(1)
