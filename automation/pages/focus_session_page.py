"""
FocusSessionPage — Page Object for Focus Session Screen (/focus-session)
"""

import time
from pages.base_page import BasePage


class FocusSessionPage(BasePage):
    """
    Focus Session Screen page object.
    Route: /focus-session
    States:
      1. Pre-session: App dropdown, START circle button
      2. Active session: Timer display, Distractions count, XP, STOP button
      3. Distraction alert modal overlay
    """

    # Pre-session
    READY_TO_FOCUS_TEXT = "Ready to Focus?"
    SELECT_APP_TEXT = "Select your productive app"
    NO_APPS_TEXT = "No apps selected. Go to Settings > App Selector."
    START_BUTTON_TEXT = "START"

    # Active session
    STOP_BUTTON_TEXT = "STOP SESSION"
    DISTRACTIONS_PREFIX = "Distractions:"
    XP_PREFIX = "XP:"
    SIMULATE_DISTRACTION_TEXT = "Simulate Distraction (Web Demo)"

    # Distraction alert (DistractionAlertModal)
    ALERT_TITLE = "Heads up"
    ALERT_BACK_BUTTON = "I'm Back! 🎯"
    ALERT_END_SESSION = "End Session"
    ALERT_SNOOZE = "Snooze"

    # Timer format: HH:MM:SS
    TIMER_CLASS = "android.widget.TextView"

    # ─────────────────────────────────────────────────────────────────────────
    # State Checks
    # ─────────────────────────────────────────────────────────────────────────

    def is_on_focus_session_screen(self) -> bool:
        return (
            self.is_text_visible(self.READY_TO_FOCUS_TEXT, timeout=8)
            or self.is_text_visible(self.STOP_BUTTON_TEXT, timeout=3)
        )

    def is_pre_session_state(self) -> bool:
        return self.is_text_visible(self.READY_TO_FOCUS_TEXT, timeout=5)

    def is_active_session_state(self) -> bool:
        return self.is_text_visible(self.STOP_BUTTON_TEXT, timeout=5)

    def is_start_button_visible(self) -> bool:
        return self.is_text_visible(self.START_BUTTON_TEXT, timeout=5)

    def is_start_button_enabled(self) -> bool:
        """START button is enabled only when an app is selected."""
        try:
            elem = self.find_by_text(self.START_BUTTON_TEXT)
            # Flutter GestureDetector — check if onTap is wired (non-null)
            # We check by background color change (enabled = accentBlue)
            # As a proxy, check if dropdown has a value selected
            return self.is_app_selected()
        except Exception:
            return False

    def is_app_selected(self) -> bool:
        """Return True if an app has been chosen in the dropdown."""
        # If no apps available, the "No apps selected" text appears
        return not self.is_text_visible(self.NO_APPS_TEXT, timeout=2)

    def is_no_apps_message_visible(self) -> bool:
        return self.is_text_visible(self.NO_APPS_TEXT, timeout=3)

    def get_timer_text(self) -> str:
        """Return the HH:MM:SS timer text."""
        try:
            # Timer text contains ":" chars in format 00:00:00
            texts = self.find_all_by_class("android.widget.TextView")
            for t in texts:
                text = t.text.strip()
                if len(text) == 8 and text.count(":") == 2:
                    return text
            return ""
        except Exception:
            return ""

    def get_distraction_count(self) -> int:
        try:
            elem = self.find_by_text_contains(self.DISTRACTIONS_PREFIX, timeout=5)
            text = elem.text.strip()  # e.g. "Distractions: 2"
            return int(text.split(":")[-1].strip())
        except Exception:
            return 0

    def get_session_xp(self) -> int:
        try:
            elem = self.find_by_text_contains(self.XP_PREFIX, timeout=5)
            text = elem.text.strip()  # e.g. "XP: 50"
            return int(text.split(":")[-1].strip())
        except Exception:
            return 0

    def get_productive_app_name(self) -> str:
        try:
            # During active session, app name shown in glassmorphism card
            texts = self.find_all_by_class("android.widget.TextView")
            # Skip timer, "Distractions:", "XP:" — get app name
            timer = self.get_timer_text()
            for t in texts:
                text = t.text.strip()
                if text and text != timer and ":" not in text and "STOP" not in text:
                    return text
            return ""
        except Exception:
            return ""

    def is_distraction_alert_visible(self) -> bool:
        return (
            self.is_text_contains_visible(self.ALERT_BACK_BUTTON, timeout=3)
            or self.is_text_contains_visible("focus check", timeout=3)
        )

    # ─────────────────────────────────────────────────────────────────────────
    # Actions
    # ─────────────────────────────────────────────────────────────────────────

    def select_app_from_dropdown(self, app_name: str) -> None:
        """Select a productive app from the dropdown."""
        try:
            # Tap dropdown
            dropdown = self.find_by_text(app_name, timeout=3)
            dropdown.click()
        except Exception:
            # Tap the DropdownButton widget
            dropdowns = self.find_all_by_class("android.widget.Spinner")
            if dropdowns:
                dropdowns[0].click()
                time.sleep(1)
                self.find_by_text(app_name).click()
        time.sleep(1)

    def tap_start_button(self) -> None:
        """Tap the START circle button to begin a focus session."""
        self.find_by_text(self.START_BUTTON_TEXT).click()
        time.sleep(3)

    def tap_stop_session(self) -> None:
        """Tap STOP SESSION to end the active session."""
        self.find_by_text(self.STOP_BUTTON_TEXT).click()
        time.sleep(2)

    def tap_im_back(self) -> None:
        """Respond to distraction alert — I'm Back!"""
        self.find_by_text_contains(self.ALERT_BACK_BUTTON).click()
        time.sleep(1)

    def tap_end_session_in_alert(self) -> None:
        """Tap 'End Session' inside distraction alert modal."""
        self.find_by_text(self.ALERT_END_SESSION).click()
        time.sleep(2)

    def tap_snooze_in_alert(self) -> None:
        """Tap 'Snooze' inside distraction alert modal."""
        self.find_by_text(self.ALERT_SNOOZE).click()
        time.sleep(1)

    def tap_back_button(self) -> None:
        """Tap the AppBar back button on pre-session screen."""
        self.press_back()

    def wait_for_timer_to_start(self, timeout: int = 10) -> bool:
        """Wait until timer shows a non-zero value."""
        start = time.time()
        while time.time() - start < timeout:
            timer = self.get_timer_text()
            if timer and timer != "00:00:00":
                return True
            time.sleep(1)
        return False

    def wait_seconds_into_session(self, seconds: int = 5) -> None:
        """Wait N seconds while a session is active."""
        time.sleep(seconds)
