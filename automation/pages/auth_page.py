"""
Authentication and Authorization Page Object for FocusEcho
Manages Sign In modal, OTP verification, guest transitions, and role enforcement.
"""

from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class AuthPage(BasePage):
    """Page object for FocusEcho authentication modal and user states."""

    # Locators
    LOC_AUTH_MODAL_OPEN_BTN = (By.ID, "auth-modal-open-btn")
    LOC_AUTH_LOGOUT_BTN = (By.ID, "auth-logout-btn")
    LOC_AUTH_MODAL = (By.ID, "auth-modal")
    LOC_AUTH_MODAL_CLOSE_BTN = (By.ID, "auth-modal-close-btn")
    LOC_AUTH_MODAL_TITLE = (By.ID, "auth-modal-title")

    LOC_TAB_LOGIN = (By.ID, "tab-login")
    LOC_TAB_GUEST = (By.ID, "tab-guest")
    LOC_AUTH_EMAIL_INPUT = (By.ID, "auth-email-input")
    LOC_AUTH_OTP_INPUT = (By.ID, "auth-otp-input")
    LOC_AUTH_REMEMBER_ME = (By.ID, "auth-remember-me")
    LOC_AUTH_SUBMIT_BTN = (By.ID, "auth-submit-btn")
    LOC_AUTH_EMAIL_ERROR = (By.ID, "auth-email-error")
    LOC_AUTH_OTP_ERROR = (By.ID, "auth-otp-error")

    LOC_GUEST_PANEL = (By.ID, "auth-guest-panel")
    LOC_CONTINUE_GUEST_BTN = (By.ID, "auth-continue-guest-btn")

    # User Profile Header
    LOC_NAV_USER_NAME = (By.ID, "nav-user-name")
    LOC_NAV_USER_ROLE = (By.ID, "nav-user-role")
    LOC_NAV_USER_AVATAR = (By.ID, "nav-user-avatar")

    # Role Gate Modal
    LOC_ROLE_MODAL = (By.ID, "role-modal")
    LOC_ROLE_MODAL_TITLE = (By.ID, "role-modal-title")
    LOC_ROLE_UPGRADE_BTN = (By.ID, "role-upgrade-btn")
    LOC_ROLE_DISMISS_BTN = (By.ID, "role-dismiss-btn")

    def open_auth_modal(self) -> None:
        """Open the authentication modal."""
        self.click(self.LOC_AUTH_MODAL_OPEN_BTN)
        self.wait.wait_for_visible(self.LOC_AUTH_MODAL)

    def close_auth_modal(self) -> None:
        """Close the authentication modal."""
        self.click(self.LOC_AUTH_MODAL_CLOSE_BTN)
        self.wait.wait_for_invisibility(self.LOC_AUTH_MODAL)

    def login_with_email_otp(self, email: str, otp: str) -> None:
        """Perform email + OTP login."""
        if not self.is_visible(self.LOC_AUTH_MODAL):
            self.open_auth_modal()
        self.click(self.LOC_TAB_LOGIN)
        self.type_text(self.LOC_AUTH_EMAIL_INPUT, email)
        self.type_text(self.LOC_AUTH_OTP_INPUT, otp)
        self.click(self.LOC_AUTH_SUBMIT_BTN)

    def continue_as_guest(self) -> None:
        """Switch to guest mode."""
        self.click(self.LOC_TAB_GUEST)
        self.click(self.LOC_CONTINUE_GUEST_BTN)

    def logout(self) -> None:
        """Sign out the current user."""
        self.click(self.LOC_AUTH_LOGOUT_BTN)

    def get_current_user_name(self) -> str:
        """Return the user display name in sidebar."""
        return self.find_element(self.LOC_NAV_USER_NAME).text

    def get_current_user_role(self) -> str:
        """Return the user tier/role in sidebar."""
        return self.find_element(self.LOC_NAV_USER_ROLE).text

    def get_email_error(self) -> str:
        """Return email validation error message."""
        return self.find_element(self.LOC_AUTH_EMAIL_ERROR).text

    def get_otp_error(self) -> str:
        """Return OTP validation error message."""
        return self.find_element(self.LOC_AUTH_OTP_ERROR).text
