"""
Page Objects for secondary FocusEcho screens:
  - AnalyticsPage
  - StreaksXpPage
  - SettingsPage
  - AppLimitsPage
  - NavigationPage (bottom nav bar helper)
"""

import time
from pages.base_page import BasePage


class AnalyticsPage(BasePage):
    """
    Analytics Screen (/analytics) — Tab 2 in bottom nav.
    Shows focus time charts and stats.
    """

    SCREEN_TITLE_CONTAINS = "Analytics"
    CHART_CLASS = "android.view.View"

    def is_on_analytics_screen(self) -> bool:
        return self.is_text_contains_visible(self.SCREEN_TITLE_CONTAINS, timeout=8)

    def is_chart_visible(self) -> bool:
        """Check if at least one chart view is rendered."""
        charts = self.find_all_by_class(self.CHART_CLASS)
        return len(charts) > 0

    def get_all_visible_texts(self) -> list[str]:
        texts = self.find_all_by_class("android.widget.TextView")
        return [t.text.strip() for t in texts if t.text.strip()]

    def tap_filter_button(self, label: str) -> None:
        """Tap a time range filter (e.g., 'Today', 'Week', 'Month')."""
        if self.is_text_visible(label, timeout=3):
            self.find_by_text(label).click()
            time.sleep(1)

    def scroll_down(self) -> None:
        self.swipe_up()

    def get_total_focus_minutes(self) -> str:
        for keyword in ["min", "hour", "minutes"]:
            if self.is_text_contains_visible(keyword, timeout=2):
                elem = self.find_by_text_contains(keyword)
                return elem.text.strip()
        return ""


class StreaksXpPage(BasePage):
    """
    Streaks & XP Screen (/streaks-xp) — Tab 3 in bottom nav.
    """

    LEVEL_TITLES = ["Focus Rookie", "Consistency Pro", "Flow Master", "Zen Monk"]
    DAY_STREAK_SUFFIX = "Day Streak"
    XP_TEXT = "XP"

    def is_on_streaks_screen(self) -> bool:
        return self.is_text_contains_visible(self.DAY_STREAK_SUFFIX, timeout=8) or \
               self.is_text_contains_visible("Streak", timeout=5)

    def get_streak_count(self) -> int:
        try:
            elem = self.find_by_text_contains(self.DAY_STREAK_SUFFIX, timeout=5)
            # e.g. "7 Day Streak" → 7
            return int(elem.text.strip().split()[0])
        except Exception:
            return 0

    def get_xp_value(self) -> int:
        try:
            elems = self.find_all_by_text_contains(self.XP_TEXT)
            for e in elems:
                text = e.text.strip()
                if "XP" in text:
                    val = text.replace("XP", "").strip()
                    if val.isdigit():
                        return int(val)
            return 0
        except Exception:
            return 0

    def get_current_level(self) -> str:
        for title in self.LEVEL_TITLES:
            if self.is_text_visible(title, timeout=2):
                return title
        return ""

    def scroll_down_badges(self) -> None:
        self.swipe_up()

    def get_all_badge_texts(self) -> list[str]:
        texts = self.find_all_by_class("android.widget.TextView")
        return [t.text.strip() for t in texts if t.text.strip()]


class SettingsPage(BasePage):
    """
    Settings Screen (/settings) — Tab 4 in bottom nav.
    """

    # Section headers
    FOCUS_PREFS_HEADER = "FOCUS PREFERENCES"
    SYNC_PRIVACY_HEADER = "SYNC & PRIVACY"
    NOTIFICATIONS_HEADER = "NOTIFICATIONS"
    ACCOUNT_HEADER = "ACCOUNT"
    ABOUT_HEADER = "ABOUT"

    # Tiles
    REMINDER_STRICTNESS = "Reminder strictness"
    RECOVERY_DURATION = "Recovery countdown duration"
    APP_LIMITS_TILE = "Per-app time limits"
    CLOUD_SYNC = "Cloud sync"
    ANALYTICS_SHARING = "Analytics sharing"
    LOCAL_ONLY_MODE = "Local only mode"
    EXPORT_DATA = "Export My Data"
    DELETE_DATA = "Delete My Data"
    NUDGE_NOTIFICATIONS = "Enable nudge notifications"
    STREAK_REMINDERS = "Enable streak reminders"
    DAILY_SUMMARY = "Daily summary time"
    SIGN_IN_GOOGLE = "Sign in with Google"
    SIGN_OUT = "Sign out"
    VERSION_TILE = "Version"
    PRIVACY_POLICY = "Privacy Policy"
    OPEN_SOURCE = "Open Source Licenses"
    APP_BAR_TITLE = "Settings"

    # Strictness values
    STRICTNESS_OPTIONS = ["Gentle", "Normal", "Strict"]

    # ─────────────────────────────────────────────────────────────────────────
    # State Checks
    # ─────────────────────────────────────────────────────────────────────────

    def is_on_settings_screen(self) -> bool:
        return self.is_text_visible(self.APP_BAR_TITLE, timeout=8)

    def is_cloud_sync_enabled(self) -> bool:
        try:
            toggle = self.find_by_xpath(
                f'//android.widget.TextView[@text="{self.CLOUD_SYNC}"]'
                f'/following-sibling::android.widget.Switch'
            )
            return self.is_element_checked(toggle)
        except Exception:
            return False

    def is_analytics_enabled(self) -> bool:
        try:
            toggle = self.find_by_xpath(
                f'//android.widget.TextView[@text="{self.ANALYTICS_SHARING}"]'
                f'/following-sibling::android.widget.Switch'
            )
            return self.is_element_checked(toggle)
        except Exception:
            return False

    def is_local_only_enabled(self) -> bool:
        try:
            toggle = self.find_by_xpath(
                f'//android.widget.TextView[@text="{self.LOCAL_ONLY_MODE}"]'
                f'/following-sibling::android.widget.Switch'
            )
            return self.is_element_checked(toggle)
        except Exception:
            return False

    def is_nudges_enabled(self) -> bool:
        try:
            toggle = self.find_by_xpath(
                f'//android.widget.TextView[@text="{self.NUDGE_NOTIFICATIONS}"]'
                f'/following-sibling::android.widget.Switch'
            )
            return self.is_element_checked(toggle)
        except Exception:
            return False

    def get_version_text(self) -> str:
        try:
            elem = self.find_by_text_contains("1.0.0", timeout=3)
            return elem.text.strip()
        except Exception:
            return ""

    def is_sign_in_google_tile_visible(self) -> bool:
        return self.is_text_visible(self.SIGN_IN_GOOGLE, timeout=5)

    def is_sign_out_tile_visible(self) -> bool:
        return self.is_text_visible(self.SIGN_OUT, timeout=5)

    # ─────────────────────────────────────────────────────────────────────────
    # Actions
    # ─────────────────────────────────────────────────────────────────────────

    def select_strictness(self, option: str) -> None:
        """Select a Reminder Strictness option from dropdown."""
        self.scroll_to_text(self.REMINDER_STRICTNESS)
        dropdowns = self.find_all_by_class("android.widget.Spinner")
        if dropdowns:
            dropdowns[0].click()
            time.sleep(1)
            self.find_by_text(option).click()
            time.sleep(1)

    def scroll_to_strictness(self) -> None:
        self.scroll_to_text(self.REMINDER_STRICTNESS)

    def toggle_cloud_sync(self) -> None:
        self.scroll_to_text(self.CLOUD_SYNC)
        self.find_by_text(self.CLOUD_SYNC).click()
        time.sleep(1)

    def toggle_analytics(self) -> None:
        self.scroll_to_text(self.ANALYTICS_SHARING)
        self.find_by_text(self.ANALYTICS_SHARING).click()
        time.sleep(1)

    def toggle_local_only(self) -> None:
        self.scroll_to_text(self.LOCAL_ONLY_MODE)
        self.find_by_text(self.LOCAL_ONLY_MODE).click()
        time.sleep(1)

    def toggle_nudge_notifications(self) -> None:
        self.scroll_to_text(self.NUDGE_NOTIFICATIONS)
        self.find_by_text(self.NUDGE_NOTIFICATIONS).click()
        time.sleep(1)

    def toggle_streak_reminders(self) -> None:
        self.scroll_to_text(self.STREAK_REMINDERS)
        self.find_by_text(self.STREAK_REMINDERS).click()
        time.sleep(1)

    def tap_per_app_limits(self) -> None:
        self.scroll_to_text(self.APP_LIMITS_TILE)
        self.find_by_text(self.APP_LIMITS_TILE).click()
        time.sleep(2)

    def tap_export_data(self) -> None:
        self.scroll_to_text(self.EXPORT_DATA)
        self.find_by_text(self.EXPORT_DATA).click()
        time.sleep(2)

    def tap_delete_data(self) -> None:
        self.scroll_to_text(self.DELETE_DATA)
        self.find_by_text(self.DELETE_DATA).click()
        time.sleep(2)

    def confirm_delete_data(self) -> None:
        """Confirm the delete data dialog."""
        self.find_by_text("Delete").click()
        time.sleep(3)

    def cancel_delete_data(self) -> None:
        """Cancel the delete data dialog."""
        self.find_by_text("Cancel").click()
        time.sleep(1)

    def tap_privacy_policy(self) -> None:
        self.scroll_to_text(self.PRIVACY_POLICY)
        self.find_by_text(self.PRIVACY_POLICY).click()
        time.sleep(2)

    def dismiss_privacy_policy_sheet(self) -> None:
        """Swipe down to dismiss the bottom sheet."""
        self.swipe_down()
        time.sleep(1)

    def tap_open_source_licenses(self) -> None:
        self.scroll_to_text(self.OPEN_SOURCE)
        self.find_by_text(self.OPEN_SOURCE).click()
        time.sleep(2)

    def tap_daily_summary_time(self) -> None:
        self.scroll_to_text(self.DAILY_SUMMARY)
        self.find_by_text(self.DAILY_SUMMARY).click()
        time.sleep(2)

    def dismiss_time_picker(self) -> None:
        for cancel_text in ["Cancel", "OK", "CANCEL"]:
            if self.is_text_visible(cancel_text, timeout=2):
                self.find_by_text(cancel_text).click()
                time.sleep(1)
                return
        self.press_back()

    def tap_sign_out(self) -> None:
        self.scroll_to_text(self.SIGN_OUT)
        self.find_by_text(self.SIGN_OUT).click()
        time.sleep(3)

    def tap_export_dialog_ok(self) -> None:
        self.find_by_text("OK").click()
        time.sleep(1)


class AppLimitsPage(BasePage):
    """
    App Limits Screen (/settings/app-limits).
    Shows per-app time limit configuration.
    """

    PAGE_TITLE_CONTAINS = "App Limits"
    CONFIGURE_SUBTITLE = "Configure"

    def is_on_app_limits_screen(self) -> bool:
        return self.is_text_contains_visible(self.PAGE_TITLE_CONTAINS, timeout=8)

    def get_all_app_entries(self) -> list:
        return self.find_all_by_class("android.widget.ListView")

    def scroll_app_list(self) -> None:
        self.swipe_up()

    def tap_back(self) -> None:
        self.press_back()


class NavigationPage(BasePage):
    """
    Bottom Navigation Bar helper for the main shell.
    Tabs: Home (dashboard), Analytics, Streaks, Settings
    """

    # Navigation destination labels from app_router.dart
    HOME_LABEL = "Home"
    ANALYTICS_LABEL = "Analytics"
    STREAKS_LABEL = "Streaks"
    SETTINGS_LABEL = "Settings"

    TAB_LABELS = ["Home", "Analytics", "Streaks", "Settings"]

    def tap_home(self) -> None:
        self.find_by_text(self.HOME_LABEL).click()
        time.sleep(2)

    def tap_analytics(self) -> None:
        self.find_by_text(self.ANALYTICS_LABEL).click()
        time.sleep(2)

    def tap_streaks(self) -> None:
        self.find_by_text(self.STREAKS_LABEL).click()
        time.sleep(2)

    def tap_settings(self) -> None:
        self.find_by_text(self.SETTINGS_LABEL).click()
        time.sleep(2)

    def is_bottom_nav_visible(self) -> bool:
        return self.is_text_visible(self.HOME_LABEL, timeout=5)

    def get_current_active_tab(self) -> str:
        """Return the label of the currently selected tab."""
        for label in self.TAB_LABELS:
            try:
                elem = self.find_by_text(label, timeout=2)
                # Selected icon has accentBlue color — check via content-desc or attribute
                if self.get_attribute(elem, "selected") == "true":
                    return label
            except Exception:
                pass
        return ""

    def navigate_all_tabs(self) -> dict:
        """Navigate to each tab and return {tab: loaded_successfully}."""
        results = {}
        for label in self.TAB_LABELS:
            self.find_by_text(label).click()
            time.sleep(2)
            results[label] = True
        return results
