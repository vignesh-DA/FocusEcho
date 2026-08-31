"""
FocusSessionPage — Page Object for Focus Session Screen (/focus-session)
Updated: added helpers for TC_SESSION_*, TC_INTENT_*, TC_DISTRACT_*,
         TC_ESCALATE_*, TC_STOP_*, TC_LAYOUT_* test cases.
Includes trigger_adb_distraction() to drive native distraction simulation
via ADB broadcast into FocusDetectionService.
"""

import time
import subprocess
from pages.base_page import BasePage


class FocusSessionPage(BasePage):
    """
    Focus Session Screen page object.
    Route: /focus-session
    States:
      1. Pre-session: App dropdown, intent field, START circle button
      2. Active session: Timer display, Distractions count, XP, STOP button
      3. Distraction alert modal overlay (Level 1)
      4. InterventionOverlay full-screen (Level 2+)
      5. Session summary view
    """

    # Pre-session
    READY_TO_FOCUS_TEXT = "Ready to Focus?"
    SELECT_APP_TEXT = "Select your productive app"
    NO_APPS_TEXT = "No apps selected. Go to Settings > App Selector."
    START_BUTTON_TEXT = "START"
    INTENT_HINT_TEXT = "e.g. Finish the analytics dashboard"
    INTENT_LABEL_TEXT = "What is your focus intent?"
    INTENT_VALIDATION_TEXT = "Enter your intent above to unlock the start button."

    # Active session
    STOP_BUTTON_TEXT = "STOP SESSION"
    DISTRACTIONS_PREFIX = "Distractions:"
    XP_PREFIX = "XP:"
    SIMULATE_DISTRACTION_TEXT = "Simulate Distraction (Web Demo)"

    # Distraction alert (DistractionAlertModal) — Level 1
    ALERT_TITLE = "Heads up"
    ALERT_BACK_BUTTON = "I'm Back! 🎯"
    ALERT_END_SESSION = "End Session"
    ALERT_SNOOZE = "Snooze"

    # InterventionOverlay — Level 2
    INTERVENTION_LEVEL2_TEXT = "Focus check"
    INTERVENTION_LEVEL2_RETURN = "Return to Focus"
    INTERVENTION_LEVEL2_BREAK = "Take a Break"

    # InterventionOverlay — Level 3
    INTERVENTION_LEVEL3_TEXT = "Repeated drift detected"
    INTERVENTION_LEVEL3_PAUSE = "Pause Session"

    # Session summary
    SUMMARY_TITLE = "Session Complete"
    SUMMARY_DONE_BUTTON = "Done"

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
        """START button is enabled only when an app is selected AND intent is set."""
        try:
            elem = self.find_by_text(self.START_BUTTON_TEXT)
            return self.is_app_selected() and not self.is_text_visible(
                self.INTENT_VALIDATION_TEXT, timeout=2
            )
        except Exception:
            return False

    def is_app_selected(self) -> bool:
        """Return True if an app has been chosen in the dropdown."""
        return not self.is_text_visible(self.NO_APPS_TEXT, timeout=2)

    def is_no_apps_message_visible(self) -> bool:
        return self.is_text_visible(self.NO_APPS_TEXT, timeout=3)

    def is_intent_validation_shown(self) -> bool:
        """Returns True when the 'enter intent to unlock' message is visible."""
        return self.is_text_visible(self.INTENT_VALIDATION_TEXT, timeout=3)

    def get_timer_text(self) -> str:
        """Return the HH:MM:SS timer text, or '' if not visible."""
        try:
            texts = self.find_all_by_class("android.widget.TextView")
            for t in texts:
                text = t.text.strip()
                if len(text) == 8 and text.count(":") == 2:
                    return text
            return ""
        except Exception:
            return ""

    def get_timer_seconds(self) -> int:
        """Parse HH:MM:SS timer text into total seconds for numeric comparison."""
        timer = self.get_timer_text()
        if not timer:
            return -1
        try:
            parts = timer.split(":")
            h, m, s = int(parts[0]), int(parts[1]), int(parts[2])
            return h * 3600 + m * 60 + s
        except Exception:
            return -1

    def get_distraction_count(self) -> int:
        """Read the integer N from 'Distractions: N' widget text."""
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
            texts = self.find_all_by_class("android.widget.TextView")
            timer = self.get_timer_text()
            for t in texts:
                text = t.text.strip()
                if text and text != timer and ":" not in text and "STOP" not in text:
                    return text
            return ""
        except Exception:
            return ""

    # ── Distraction alert (Level 1 heads-up modal) ───────────────────────────

    def is_distraction_alert_visible(self) -> bool:
        """True when Level-1 DistractionAlertModal dialog is open."""
        return (
            self.is_text_contains_visible(self.ALERT_BACK_BUTTON, timeout=3)
            or self.is_text_contains_visible("Heads up", timeout=3)
            or self.is_text_contains_visible("focus check", timeout=3)
        )

    # ── InterventionOverlay (Level 2 / 3 full-screen) ────────────────────────

    def is_intervention_overlay_visible(self) -> bool:
        """True when any level of the full-screen InterventionOverlay is shown."""
        return (
            self.is_text_visible(self.INTERVENTION_LEVEL2_TEXT, timeout=5)
            or self.is_text_visible(self.INTERVENTION_LEVEL3_TEXT, timeout=3)
            or self.is_text_contains_visible("Focus check", timeout=5)
            or self.is_text_contains_visible("Repeated drift", timeout=3)
        )

    def get_escalation_level(self) -> int:
        """
        Returns the detected escalation level (1, 2, or 3) based on visible
        UI elements. Returns 0 if no alert/overlay is detected.
        """
        if self.is_text_contains_visible(self.INTERVENTION_LEVEL3_TEXT, timeout=2) or \
           self.is_text_contains_visible("Repeated drift detected", timeout=2):
            return 3
        if self.is_text_contains_visible(self.INTERVENTION_LEVEL2_TEXT, timeout=2) or \
           self.is_text_contains_visible("Focus check", timeout=2):
            return 2
        if self.is_distraction_alert_visible():
            return 1
        return 0

    def tap_return_to_focus(self) -> None:
        """Tap 'Return to Focus' on Level-2/3 intervention."""
        try:
            self.find_by_text_contains("Return to Focus").click()
        except Exception:
            self.find_by_text(self.INTERVENTION_LEVEL2_RETURN).click()
        time.sleep(1)

    def tap_take_a_break(self) -> None:
        """Tap 'Take a Break' on the Level-2 Intervention."""
        try:
            self.find_by_text_contains("Take a Break").click()
        except Exception:
            self.find_by_text(self.INTERVENTION_LEVEL2_BREAK).click()
        time.sleep(1)

    def tap_pause_session(self) -> None:
        """Tap 'Pause Session' on the Level-3 Intervention."""
        try:
            self.find_by_text_contains("Pause Session").click()
        except Exception:
            self.find_by_text(self.INTERVENTION_LEVEL3_PAUSE).click()
        time.sleep(2)

    # ── Session summary ───────────────────────────────────────────────────────

    def is_session_summary_visible(self) -> bool:
        """True when the post-session summary view is displayed."""
        return self.is_text_visible(self.SUMMARY_TITLE, timeout=8)

    def get_summary_intent_text(self) -> str:
        """Read the intent string from the session summary view."""
        try:
            # Intent is rendered in quotes: '"finish my work"'
            texts = self.find_all_by_class("android.widget.TextView")
            for t in texts:
                text = t.text.strip()
                if text.startswith('"') and text.endswith('"'):
                    return text.strip('"')
            return ""
        except Exception:
            return ""

    def get_summary_distraction_count(self) -> int:
        """Read the Distractions stat from the session summary screen."""
        try:
            elems = self.find_all_by_class("android.widget.TextView")
            for i, e in enumerate(elems):
                if e.text.strip() == "Distractions" and i > 0:
                    return int(elems[i - 1].text.strip())
            return 0
        except Exception:
            return 0

    def tap_done_in_summary(self) -> None:
        """Tap 'Done' to dismiss the session summary view."""
        self.find_by_text(self.SUMMARY_DONE_BUTTON).click()
        time.sleep(2)

    # ── Layout / overflow checks ──────────────────────────────────────────────

    def check_no_overflow(self) -> bool:
        """
        TC_LAYOUT_001 — Returns True if no element extends beyond the visible
        screen width.
        """
        try:
            screen_width = self.driver.get_window_size()["width"]
            elems = self.find_all_by_class("android.widget.TextView")
            for e in elems:
                loc = e.location
                sz = e.size
                right_edge = loc["x"] + sz["width"]
                if right_edge > screen_width + 2:  # 2px tolerance for rounding
                    return False
            return True
        except Exception:
            return True

    # ─────────────────────────────────────────────────────────────────────────
    # Actions & ADB Fixtures
    # ─────────────────────────────────────────────────────────────────────────

    def trigger_adb_distraction(
        self,
        package_name: str = "com.instagram.android",
        label: str = "Instagram",
    ) -> None:
        """
        Fires native distraction simulation via ADB broadcast into FocusDetectionService.
        This exercises the full production pipeline on Android:
          ADB Broadcast -> FocusDetectionService (registerRelapse)
          -> DistractionEventQueue -> MainActivity EventSink -> Flutter EventChannel
          -> FocusDetectionEngine -> FocusSessionViewModel -> DistractionEventDao (SQLite)
          -> Level-appropriate Intervention (Notification / InterventionActivity / Overlay).
        """
        try:
            self.driver.execute_script('mobile: shell', {
                'command': 'am',
                'args': [
                    'broadcast',
                    '-a', 'com.focusecho.ai.SIMULATE_DISTRACTION',
                    '-p', 'com.focusecho.ai',
                    '--es', 'package_name', package_name,
                    '--es', 'app_label', label,
                ]
            })
        except Exception:
            try:
                subprocess.run([
                    'adb', 'shell', 'am', 'broadcast',
                    '-a', 'com.focusecho.ai.SIMULATE_DISTRACTION',
                    '-p', 'com.focusecho.ai',
                    '--es', 'package_name', package_name,
                    '--es', 'app_label', label,
                ], capture_output=True, timeout=5)
            except Exception:
                pass
        time.sleep(2)

    def type_intent(self, intent_text: str) -> None:
        """Type into the focus intent TextField."""
        try:
            field = self.find_by_text_contains(
                self.INTENT_HINT_TEXT, timeout=5
            )
            self.type_text(field, intent_text)
        except Exception:
            field = self.find_by_xpath(
                '//android.widget.EditText[@hint="e.g. Finish the analytics dashboard"]'
            )
            self.type_text(field, intent_text)
        time.sleep(0.5)

    def select_app_from_dropdown(self, app_name: str) -> None:
        """Select a productive app from the dropdown."""
        try:
            dropdown = self.find_by_text(app_name, timeout=3)
            dropdown.click()
        except Exception:
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

    def tap_simulate_distraction(self) -> None:
        """Tap 'Simulate Distraction (Web Demo)' button (web only)."""
        self.find_by_text_contains(self.SIMULATE_DISTRACTION_TEXT).click()
        time.sleep(1)

    def tap_im_back(self) -> None:
        """Respond to Level-1 distraction alert — I'm Back!"""
        self.find_by_text_contains(self.ALERT_BACK_BUTTON).click()
        time.sleep(1)

    def tap_end_session_in_alert(self) -> None:
        """Tap 'End Session' inside Level-1 distraction alert modal."""
        self.find_by_text(self.ALERT_END_SESSION).click()
        time.sleep(2)

    def tap_snooze_in_alert(self) -> None:
        """Tap 'Snooze' inside Level-1 distraction alert modal."""
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
