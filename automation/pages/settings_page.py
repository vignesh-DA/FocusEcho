"""
Settings & File Upload Page Object for FocusEcho
Manages user profile, file upload dropzone (avatar & JSON backup), and simulation controls.
"""

from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class SettingsPage(BasePage):
    """Page object for System Settings and File Upload interactions."""

    LOC_PROFILE_NAME_INPUT = (By.ID, "profile-name-input")
    LOC_PROFILE_EMAIL_INPUT = (By.ID, "profile-email-input")
    LOC_PROFILE_EMAIL_ERROR = (By.ID, "profile-email-error")
    LOC_PROFILE_SAVE_BTN = (By.ID, "profile-save-btn")

    # File Uploads
    LOC_AVATAR_FILE_INPUT = (By.ID, "avatar-file-input")
    LOC_AVATAR_PREVIEW_IMG = (By.ID, "avatar-preview-img")
    LOC_AVATAR_STATUS = (By.ID, "avatar-upload-status")

    LOC_SESSIONS_DROPZONE = (By.ID, "sessions-dropzone")
    LOC_SESSIONS_FILE_INPUT = (By.ID, "sessions-file-input")
    LOC_FILE_UPLOAD_FEEDBACK = (By.ID, "file-upload-feedback")

    LOC_EXPORT_JSON_BTN = (By.ID, "export-json-btn")
    LOC_EXPORT_CSV_BTN = (By.ID, "export-csv-btn")

    LOC_SETTING_ERROR_SIMULATION = (By.ID, "setting-error-simulation")
    LOC_SETTING_AUTO_SYNC = (By.ID, "setting-auto-sync")

    def update_profile(self, name: str, email: str) -> None:
        """Update display name and email."""
        self.type_text(self.LOC_PROFILE_NAME_INPUT, name)
        self.type_text(self.LOC_PROFILE_EMAIL_INPUT, email)
        self.click(self.LOC_PROFILE_SAVE_BTN)

    def upload_avatar(self, absolute_filepath: str) -> None:
        """Upload an image file using the hidden file input."""
        elem = self.driver.find_element(*self.LOC_AVATAR_FILE_INPUT)
        elem.send_keys(str(absolute_filepath))

    def upload_sessions_file(self, absolute_filepath: str) -> None:
        """Upload a session backup file (.json or .csv)."""
        elem = self.driver.find_element(*self.LOC_SESSIONS_FILE_INPUT)
        elem.send_keys(str(absolute_filepath))

    def get_avatar_status_text(self) -> str:
        """Get avatar upload status message."""
        return self.find_element(self.LOC_AVATAR_STATUS).text

    def get_sessions_upload_feedback(self) -> str:
        """Get feedback text after sessions file upload."""
        return self.find_element(self.LOC_FILE_UPLOAD_FEEDBACK).text

    def toggle_error_simulation(self) -> None:
        """Toggle simulated network error mode."""
        self.click(self.LOC_SETTING_ERROR_SIMULATION)
