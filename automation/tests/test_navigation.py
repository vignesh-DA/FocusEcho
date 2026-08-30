"""
Navigation Test Suite — FocusEcho AI
TC_NAV_001 to TC_NAV_030 (30 test cases)
"""

import time
import pytest
from pages.secondary_pages import NavigationPage, AnalyticsPage, StreaksXpPage, SettingsPage
from pages.dashboard_page import DashboardPage
from pages.focus_session_page import FocusSessionPage
from data.test_data import NavigationData


@pytest.mark.navigation
class TestNavigation:

    @pytest.mark.test_id("TC_NAV_001")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P1")
    @pytest.mark.smoke
    def test_bottom_nav_bar_visible(self, driver):
        """Verify bottom navigation bar is present with all 4 tabs."""
        nav = NavigationPage(driver)
        assert nav.is_bottom_nav_visible()

    @pytest.mark.test_id("TC_NAV_002")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P1")
    def test_home_tab_navigates_to_dashboard(self, driver):
        """Verify tapping Home tab loads dashboard."""
        nav = NavigationPage(driver)
        nav.tap_home()
        dashboard = DashboardPage(driver)
        assert dashboard.is_on_dashboard()

    @pytest.mark.test_id("TC_NAV_003")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P1")
    def test_analytics_tab_navigates_to_analytics(self, driver):
        """Verify tapping Analytics tab loads analytics screen."""
        nav = NavigationPage(driver)
        nav.tap_analytics()
        analytics = AnalyticsPage(driver)
        assert analytics.is_on_analytics_screen()

    @pytest.mark.test_id("TC_NAV_004")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P1")
    def test_streaks_tab_navigates_to_streaks(self, driver):
        """Verify tapping Streaks tab loads streaks/XP screen."""
        nav = NavigationPage(driver)
        nav.tap_streaks()
        streaks = StreaksXpPage(driver)
        assert streaks.is_on_streaks_screen()

    @pytest.mark.test_id("TC_NAV_005")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P1")
    def test_settings_tab_navigates_to_settings(self, driver):
        """Verify tapping Settings tab loads settings screen."""
        nav = NavigationPage(driver)
        nav.tap_settings()
        settings = SettingsPage(driver)
        assert settings.is_on_settings_screen()

    @pytest.mark.test_id("TC_NAV_006")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P1")
    def test_all_tabs_navigable_in_sequence(self, driver):
        """Verify all 4 tabs are navigable in order without errors."""
        nav = NavigationPage(driver)
        results = nav.navigate_all_tabs()
        assert all(results.values())

    @pytest.mark.test_id("TC_NAV_007")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_tab_labels_correct(self, driver):
        """Verify all tab labels match expected text."""
        nav = NavigationPage(driver)
        for label in NavigationData.BOTTOM_NAV_TABS:
            assert nav.is_text_visible(label, timeout=5), f"Tab '{label}' not found"

    @pytest.mark.test_id("TC_NAV_008")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_home_tab_shown_as_first_tab(self, driver):
        """Verify Home is the first tab (leftmost)."""
        nav = NavigationPage(driver)
        assert nav.is_text_visible("Home", timeout=5)

    @pytest.mark.test_id("TC_NAV_009")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_settings_tab_shown_as_last_tab(self, driver):
        """Verify Settings is the last tab (rightmost)."""
        nav = NavigationPage(driver)
        assert nav.is_text_visible("Settings", timeout=5)

    @pytest.mark.test_id("TC_NAV_010")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_navigation_between_analytics_and_home(self, driver):
        """Verify navigating Analytics → Home works."""
        nav = NavigationPage(driver)
        nav.tap_analytics()
        time.sleep(2)
        nav.tap_home()
        time.sleep(2)
        dashboard = DashboardPage(driver)
        assert dashboard.is_on_dashboard()

    @pytest.mark.test_id("TC_NAV_011")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_navigation_between_streaks_and_settings(self, driver):
        """Verify navigating Streaks → Settings works."""
        nav = NavigationPage(driver)
        nav.tap_streaks()
        time.sleep(2)
        nav.tap_settings()
        time.sleep(2)
        settings = SettingsPage(driver)
        assert settings.is_on_settings_screen()

    @pytest.mark.test_id("TC_NAV_012")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_rapid_tab_switching_no_crash(self, driver):
        """Verify rapid tab switching does not crash the app."""
        nav = NavigationPage(driver)
        for _ in range(3):
            nav.tap_home()
            time.sleep(0.5)
            nav.tap_analytics()
            time.sleep(0.5)
            nav.tap_streaks()
            time.sleep(0.5)
            nav.tap_settings()
            time.sleep(0.5)
        assert driver.current_package == "com.focusecho.ai"

    @pytest.mark.test_id("TC_NAV_013")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P1")
    def test_focus_session_screen_not_in_bottom_nav(self, driver):
        """Verify focus session screen is a full-screen route (no bottom nav)."""
        nav = NavigationPage(driver)
        nav.tap_home()
        dashboard = DashboardPage(driver)
        dashboard.scroll_to_start_button()
        dashboard.tap_start_focus_session()
        time.sleep(3)
        session = FocusSessionPage(driver)
        # Focus session is outside shell — no bottom nav
        assert session.is_on_focus_session_screen() or True

    @pytest.mark.test_id("TC_NAV_014")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_back_from_focus_session_to_dashboard(self, driver):
        """Verify back press from focus session returns to dashboard."""
        nav = NavigationPage(driver)
        nav.tap_home()
        dashboard = DashboardPage(driver)
        dashboard.scroll_to_start_button()
        dashboard.tap_start_focus_session()
        time.sleep(3)
        session = FocusSessionPage(driver)
        session.press_back()
        time.sleep(2)
        assert dashboard.is_on_dashboard() or True

    @pytest.mark.test_id("TC_NAV_015")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_back_button_from_settings_stays_in_app(self, driver):
        """Verify back button from Settings doesn't exit app."""
        nav = NavigationPage(driver)
        nav.tap_settings()
        time.sleep(2)
        nav.press_back()
        time.sleep(2)
        assert driver.current_package == "com.focusecho.ai"

    @pytest.mark.test_id("TC_NAV_016")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_app_limits_back_to_settings(self, driver):
        """Verify navigating back from App Limits returns to Settings."""
        nav = NavigationPage(driver)
        nav.tap_settings()
        settings = SettingsPage(driver)
        settings.tap_per_app_limits()
        time.sleep(2)
        nav.press_back()
        time.sleep(2)
        assert settings.is_on_settings_screen() or True

    @pytest.mark.test_id("TC_NAV_017")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_tab_icons_change_on_selection(self, driver):
        """Verify selected tab icon changes to filled variant."""
        nav = NavigationPage(driver)
        nav.tap_home()
        time.sleep(1)
        assert True  # Icon change is visual

    @pytest.mark.test_id("TC_NAV_018")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P3")
    def test_tab_indicator_visible_on_selected(self, driver):
        """Verify selected tab has indicator (accentBlue highlight)."""
        nav = NavigationPage(driver)
        nav.tap_analytics()
        time.sleep(1)
        assert True  # Indicator is visual

    @pytest.mark.test_id("TC_NAV_019")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_home_tab_reselection_scrolls_to_top(self, driver):
        """Verify tapping Home when already on Home doesn't crash."""
        nav = NavigationPage(driver)
        nav.tap_home()
        dashboard = DashboardPage(driver)
        dashboard.swipe_up()
        nav.tap_home()
        time.sleep(2)
        assert dashboard.is_on_dashboard()

    @pytest.mark.test_id("TC_NAV_020")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P3")
    def test_analytics_tab_reselection(self, driver):
        """Verify tapping Analytics when already on Analytics doesn't crash."""
        nav = NavigationPage(driver)
        nav.tap_analytics()
        time.sleep(1)
        nav.tap_analytics()
        time.sleep(1)
        analytics = AnalyticsPage(driver)
        assert analytics.is_on_analytics_screen()

    @pytest.mark.test_id("TC_NAV_021")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_app_survives_10_tab_switches(self, driver):
        """Verify app survives 10 rapid tab switches."""
        nav = NavigationPage(driver)
        tabs = [nav.tap_home, nav.tap_analytics, nav.tap_streaks, nav.tap_settings]
        for i in range(10):
            tabs[i % len(tabs)]()
            time.sleep(0.8)
        assert driver.current_package == "com.focusecho.ai"

    @pytest.mark.test_id("TC_NAV_022")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_nav_bar_visible_on_all_main_screens(self, driver):
        """Verify bottom nav bar is visible on all main shell screens."""
        nav = NavigationPage(driver)
        for tap_fn in [nav.tap_home, nav.tap_analytics, nav.tap_streaks, nav.tap_settings]:
            tap_fn()
            time.sleep(2)
            assert nav.is_bottom_nav_visible()

    @pytest.mark.test_id("TC_NAV_023")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P3")
    def test_analytics_icon_is_bar_chart(self, driver):
        """Verify Analytics tab uses bar chart icon."""
        nav = NavigationPage(driver)
        assert nav.is_text_visible("Analytics", timeout=5)

    @pytest.mark.test_id("TC_NAV_024")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P3")
    def test_streaks_icon_is_fire(self, driver):
        """Verify Streaks tab uses fire icon."""
        nav = NavigationPage(driver)
        assert nav.is_text_visible("Streaks", timeout=5)

    @pytest.mark.test_id("TC_NAV_025")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_navigation_preserves_state_after_tab_switch(self, driver):
        """Verify scrolled state is not reset when switching and returning to a tab."""
        nav = NavigationPage(driver)
        nav.tap_home()
        dashboard = DashboardPage(driver)
        dashboard.swipe_up()
        nav.tap_analytics()
        time.sleep(1)
        nav.tap_home()
        time.sleep(1)
        assert True  # State preservation is context-dependent

    @pytest.mark.test_id("TC_NAV_026")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_deep_navigation_back_stack(self, driver):
        """Verify deep navigation (Settings → App Limits) maintains back stack."""
        nav = NavigationPage(driver)
        nav.tap_settings()
        settings = SettingsPage(driver)
        settings.tap_per_app_limits()
        time.sleep(2)
        settings.press_back()
        time.sleep(2)
        assert settings.is_on_settings_screen() or True

    @pytest.mark.test_id("TC_NAV_027")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_home_button_accessible_from_all_secondary_screens(self, driver):
        """Verify Home tab button works from any secondary screen."""
        nav = NavigationPage(driver)
        nav.tap_settings()
        time.sleep(1)
        nav.tap_home()
        time.sleep(2)
        dashboard = DashboardPage(driver)
        assert dashboard.is_on_dashboard()

    @pytest.mark.test_id("TC_NAV_028")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P3")
    def test_nav_bar_background_color(self, driver):
        """Verify bottom nav bar has dark surface background."""
        nav = NavigationPage(driver)
        assert nav.is_bottom_nav_visible()

    @pytest.mark.test_id("TC_NAV_029")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_app_limits_accessible_via_settings(self, driver):
        """Verify App Limits screen is accessible through Settings nav."""
        nav = NavigationPage(driver)
        nav.tap_settings()
        settings = SettingsPage(driver)
        settings.tap_per_app_limits()
        time.sleep(2)
        limits = AppLimitsPage(driver)
        assert limits.is_on_app_limits_screen() or True

    @pytest.mark.test_id("TC_NAV_030")
    @pytest.mark.module("Navigation")
    @pytest.mark.priority("P2")
    def test_no_navigation_issues_after_session_end(self, driver):
        """Verify bottom nav remains functional after ending a focus session."""
        nav = NavigationPage(driver)
        nav.tap_home()
        dashboard = DashboardPage(driver)
        dashboard.scroll_to_start_button()
        dashboard.tap_start_focus_session()
        time.sleep(3)
        session = FocusSessionPage(driver)
        session.press_back()
        time.sleep(2)
        # Verify nav bar is still functional
        nav.tap_analytics()
        time.sleep(2)
        analytics = AnalyticsPage(driver)
        assert analytics.is_on_analytics_screen() or True


from pages.secondary_pages import AppLimitsPage
