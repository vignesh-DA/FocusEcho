"""
DashboardPage — Page Object for FocusEcho Dashboard Screen (/dashboard)
"""

import time
from pages.base_page import BasePage


class DashboardPage(BasePage):
    """
    Dashboard Screen page object.
    Route: /dashboard (Main shell tab 0 — Home)
    Key Elements:
      - Greeting: "Good morning/afternoon/evening, <name>"
      - Level title: "Focus Rookie" / "Consistency Pro" etc.
      - XP card: "<N> XP", LinearProgressIndicator
      - Stat cards: Sessions, Focus Min, Avoided
      - Streak card: "<N> Day Streak", Personal Best
      - "Start Focus Session →" ElevatedButton
      - "Recent Sessions" header + ListTile items
      - RefreshIndicator
      - Error banner (conditional)
    """

    # Text constants from dashboard_screen.dart + app_constants.dart
    START_FOCUS_BUTTON = "Start Focus Session →"
    RECENT_SESSIONS_HEADER = "Recent Sessions"
    NO_SESSIONS_TEXT = "No sessions today. Start one!"
    XP_SUFFIX = "XP"
    DAY_STREAK_SUFFIX = "Day Streak"
    PERSONAL_BEST_PREFIX = "Personal Best:"
    NEXT_LEVEL_PREFIX = "Next:"
    ERROR_ICON_DESC = "Warning"

    STAT_LABELS = ["Sessions", "Focus Min", "Avoided"]
    LEVEL_TITLES = ["Focus Rookie", "Consistency Pro", "Flow Master", "Zen Monk"]

    # ─────────────────────────────────────────────────────────────────────────
    # Assertions / State
    # ─────────────────────────────────────────────────────────────────────────

    def is_on_dashboard(self) -> bool:
        return self.is_text_visible(self.START_FOCUS_BUTTON, timeout=10)

    def get_greeting_text(self) -> str:
        """Returns the greeting text e.g. 'Good morning, there'"""
        for greet in ["Good morning", "Good afternoon", "Good evening"]:
            if self.is_text_contains_visible(greet, timeout=3):
                return self.find_by_text_contains(greet).text.strip()
        return ""

    def get_level_title(self) -> str:
        for title in self.LEVEL_TITLES:
            if self.is_text_visible(title, timeout=2):
                return title
        return ""

    def get_xp_text(self) -> str:
        """Returns the XP text like '0 XP'."""
        try:
            elems = self.find_all_by_text_contains(self.XP_SUFFIX)
            return elems[0].text.strip() if elems else ""
        except Exception:
            return ""

    def get_streak_text(self) -> str:
        """Returns streak text like '0 Day Streak'."""
        try:
            elem = self.find_by_text_contains(self.DAY_STREAK_SUFFIX, timeout=5)
            return elem.text.strip()
        except Exception:
            return ""

    def get_personal_best_text(self) -> str:
        try:
            elem = self.find_by_text_contains(self.PERSONAL_BEST_PREFIX, timeout=3)
            return elem.text.strip()
        except Exception:
            return ""

    def get_stat_value(self, label: str) -> str:
        """Get the value of a stat card by its label ('Sessions', 'Focus Min', 'Avoided')."""
        try:
            # Stat card: value above label — scan nearby text
            elem = self.find_by_text(label, timeout=5)
            # The value is in the same Container, look for sibling text
            parent = elem.find_element("xpath", "./..")
            children = parent.find_elements("xpath", "./*")
            for child in children:
                text = child.text.strip()
                if text and text != label and text.isdigit():
                    return text
            return ""
        except Exception:
            return ""

    def is_error_banner_visible(self) -> bool:
        return self.is_text_contains_visible("Warning", timeout=3) or \
               self.is_text_contains_visible("Error", timeout=3)

    def is_recent_sessions_header_visible(self) -> bool:
        return self.is_text_visible(self.RECENT_SESSIONS_HEADER, timeout=5)

    def is_no_sessions_message_visible(self) -> bool:
        return self.is_text_visible(self.NO_SESSIONS_TEXT, timeout=5)

    def is_start_focus_button_visible(self) -> bool:
        return self.is_text_visible(self.START_FOCUS_BUTTON, timeout=5)

    def is_start_focus_button_enabled(self) -> bool:
        elem = self.find_by_text(self.START_FOCUS_BUTTON)
        return self.is_element_enabled(elem)

    def get_session_count_from_stat(self) -> int:
        val = self.get_stat_value("Sessions")
        return int(val) if val.isdigit() else 0

    def count_recent_session_cards(self) -> int:
        """Count visible ListTile items in Recent Sessions."""
        items = self.find_all_by_class("android.widget.ListView")
        return len(items)

    def is_xp_progress_bar_visible(self) -> bool:
        return self.is_visible(
            self.find_by_class, "android.widget.ProgressBar", timeout=5
        )

    # ─────────────────────────────────────────────────────────────────────────
    # Actions
    # ─────────────────────────────────────────────────────────────────────────

    def tap_start_focus_session(self) -> None:
        """Navigate to Focus Session screen."""
        self.find_by_text(self.START_FOCUS_BUTTON).click()
        time.sleep(2)

    def pull_to_refresh(self) -> None:
        """Trigger dashboard refresh via pull-to-refresh gesture."""
        self.swipe_down(swipes=2)
        time.sleep(3)

    def scroll_to_recent_sessions(self) -> None:
        self.scroll_to_text(self.RECENT_SESSIONS_HEADER)

    def scroll_to_start_button(self) -> None:
        self.scroll_to_text(self.START_FOCUS_BUTTON)
