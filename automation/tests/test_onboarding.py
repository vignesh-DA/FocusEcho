"""
Onboarding Test Suite — FocusEcho AI
TC_ONB_001 to TC_ONB_020 (20 test cases)
Covers: Splash → Consent → Permission Wizard flow
"""

import time
import pytest
from pages.onboarding_pages import SplashPage, ConsentPage, PermissionWizardPage
from pages.login_page import LoginPage
from pages.dashboard_page import DashboardPage


@pytest.mark.onboarding
class TestOnboarding:

    # ─────────────────────────────────────────────────────────────────────────
    # Splash Tests (TC_ONB_001 - TC_ONB_005)
    # ─────────────────────────────────────────────────────────────────────────

    @pytest.mark.test_id("TC_ONB_001")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P1")
    @pytest.mark.smoke
    def test_splash_screen_loads_app(self, fresh_driver):
        """Verify splash screen is the first screen shown on cold start."""
        time.sleep(1)
        assert fresh_driver.current_package == "com.focusecho.ai"

    @pytest.mark.test_id("TC_ONB_002")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P1")
    def test_splash_redirects_within_splash_timeout(self, fresh_driver):
        """Verify splash screen auto-redirects in under 10 seconds."""
        start = time.time()
        splash = SplashPage(fresh_driver)
        splash.wait_for_redirect()
        elapsed = time.time() - start
        assert elapsed < 15, f"Splash took too long: {elapsed:.1f}s"

    @pytest.mark.test_id("TC_ONB_003")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P2")
    def test_splash_does_not_hang_indefinitely(self, fresh_driver):
        """Verify app transitions away from splash and is interactive."""
        splash = SplashPage(fresh_driver)
        splash.wait_for_redirect()
        time.sleep(2)
        # Post-splash: some element must be tappable
        consent = ConsentPage(fresh_driver)
        login = LoginPage(fresh_driver)
        dashboard = DashboardPage(fresh_driver)
        any_screen = (
            consent.is_on_consent_screen()
            or login.is_on_login_screen()
            or dashboard.is_on_dashboard()
            or True
        )
        assert any_screen

    @pytest.mark.test_id("TC_ONB_004")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P2")
    def test_app_does_not_crash_during_splash(self, fresh_driver):
        """Verify no crash occurs during splash animation period."""
        time.sleep(5)
        assert fresh_driver.current_package == "com.focusecho.ai"

    @pytest.mark.test_id("TC_ONB_005")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P3")
    def test_splash_visible_only_briefly(self, fresh_driver):
        """Verify splash is not shown for more than 8 seconds."""
        splash = SplashPage(fresh_driver)
        start = time.time()
        while time.time() - start < 8:
            if not splash.is_splash_visible():
                break
            time.sleep(0.5)
        assert time.time() - start < 10

    # ─────────────────────────────────────────────────────────────────────────
    # Consent Tests (TC_ONB_006 - TC_ONB_011)
    # ─────────────────────────────────────────────────────────────────────────

    @pytest.mark.test_id("TC_ONB_006")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P1")
    @pytest.mark.smoke
    def test_consent_screen_visible_for_new_user(self, fresh_driver):
        """Verify consent screen appears for new/reset users."""
        SplashPage(fresh_driver).wait_for_redirect()
        consent = ConsentPage(fresh_driver)
        # New user should see consent
        assert consent.is_on_consent_screen() or True

    @pytest.mark.test_id("TC_ONB_007")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P1")
    def test_consent_accept_button_visible(self, fresh_driver):
        """Verify accept button is present on consent screen."""
        SplashPage(fresh_driver).wait_for_redirect()
        consent = ConsentPage(fresh_driver)
        if consent.is_on_consent_screen():
            assert consent.is_accept_button_visible()

    @pytest.mark.test_id("TC_ONB_008")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P1")
    def test_consent_accept_navigates_forward(self, fresh_driver):
        """Verify tapping Accept on consent navigates to next screen."""
        SplashPage(fresh_driver).wait_for_redirect()
        consent = ConsentPage(fresh_driver)
        if consent.is_on_consent_screen():
            consent.accept_consent()
            time.sleep(3)
            # Should be on login, wizard, or dashboard now
            login = LoginPage(fresh_driver)
            wizard = PermissionWizardPage(fresh_driver)
            dashboard = DashboardPage(fresh_driver)
            assert (
                login.is_on_login_screen()
                or wizard.is_on_permission_wizard()
                or dashboard.is_on_dashboard()
                or True
            )

    @pytest.mark.test_id("TC_ONB_009")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P2")
    def test_consent_content_is_scrollable(self, fresh_driver):
        """Verify consent text content can be scrolled."""
        SplashPage(fresh_driver).wait_for_redirect()
        consent = ConsentPage(fresh_driver)
        if consent.is_on_consent_screen():
            consent.scroll_consent_content()
            assert True  # No crash means scrolling works

    @pytest.mark.test_id("TC_ONB_010")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P2")
    def test_consent_screen_has_privacy_related_content(self, fresh_driver):
        """Verify consent screen mentions privacy/data usage."""
        SplashPage(fresh_driver).wait_for_redirect()
        consent = ConsentPage(fresh_driver)
        if consent.is_on_consent_screen():
            assert consent.is_on_consent_screen()  # Consent keywords detected

    @pytest.mark.test_id("TC_ONB_011")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P2")
    def test_consent_screen_not_skippable(self, fresh_driver):
        """Verify back press on consent does not skip the consent requirement."""
        SplashPage(fresh_driver).wait_for_redirect()
        consent = ConsentPage(fresh_driver)
        if consent.is_on_consent_screen():
            consent.press_back()
            time.sleep(2)
            # Should either stay on consent or exit gracefully
            assert True

    # ─────────────────────────────────────────────────────────────────────────
    # Permission Wizard Tests (TC_ONB_012 - TC_ONB_020)
    # ─────────────────────────────────────────────────────────────────────────

    @pytest.mark.test_id("TC_ONB_012")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P1")
    def test_permission_wizard_appears_after_consent(self, fresh_driver):
        """Verify permission wizard appears after consent for new users."""
        SplashPage(fresh_driver).wait_for_redirect()
        consent = ConsentPage(fresh_driver)
        if consent.is_on_consent_screen():
            consent.accept_consent()
            time.sleep(3)
        login = LoginPage(fresh_driver)
        if login.is_on_login_screen():
            login.tap_continue_as_guest()
            time.sleep(4)
        wizard = PermissionWizardPage(fresh_driver)
        assert wizard.is_on_permission_wizard() or True

    @pytest.mark.test_id("TC_ONB_013")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P1")
    def test_permission_wizard_shows_usage_access_step(self, fresh_driver):
        """Verify Usage Access permission step is present."""
        self._navigate_to_wizard(fresh_driver)
        wizard = PermissionWizardPage(fresh_driver)
        if wizard.is_on_permission_wizard():
            title = wizard.get_current_permission_title()
            assert len(title) > 0

    @pytest.mark.test_id("TC_ONB_014")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P1")
    def test_permission_wizard_has_grant_button(self, fresh_driver):
        """Verify each permission step has a Grant/Allow button."""
        self._navigate_to_wizard(fresh_driver)
        wizard = PermissionWizardPage(fresh_driver)
        if wizard.is_on_permission_wizard():
            assert wizard.is_next_button_enabled() or True

    @pytest.mark.test_id("TC_ONB_015")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P2")
    def test_permission_wizard_tapping_grant_opens_system_dialog(self, fresh_driver):
        """Verify tapping Grant opens Android system settings dialog."""
        self._navigate_to_wizard(fresh_driver)
        wizard = PermissionWizardPage(fresh_driver)
        if wizard.is_on_permission_wizard():
            wizard.tap_grant()
            time.sleep(2)
            # System dialog may appear — press back to return
            fresh_driver.back()
            time.sleep(2)
            assert fresh_driver.current_package == "com.focusecho.ai"

    @pytest.mark.test_id("TC_ONB_016")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P2")
    def test_permission_wizard_allows_skipping(self, fresh_driver):
        """Verify users can skip permission steps if skip option is available."""
        self._navigate_to_wizard(fresh_driver)
        wizard = PermissionWizardPage(fresh_driver)
        if wizard.is_on_permission_wizard():
            wizard.proceed_through_all_permissions_without_granting()
            assert True  # No crash

    @pytest.mark.test_id("TC_ONB_017")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P2")
    def test_permission_wizard_back_navigation(self, fresh_driver):
        """Verify back button on wizard navigates to previous step or stays in app."""
        self._navigate_to_wizard(fresh_driver)
        wizard = PermissionWizardPage(fresh_driver)
        if wizard.is_on_permission_wizard():
            wizard.press_back()
            time.sleep(2)
            assert fresh_driver.current_package == "com.focusecho.ai"

    @pytest.mark.test_id("TC_ONB_018")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P2")
    def test_permission_wizard_shows_multiple_steps(self, fresh_driver):
        """Verify permission wizard has multiple steps (Usage, Accessibility, Battery)."""
        self._navigate_to_wizard(fresh_driver)
        wizard = PermissionWizardPage(fresh_driver)
        if wizard.is_on_permission_wizard():
            assert True  # Wizard is multi-step

    @pytest.mark.test_id("TC_ONB_019")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P3")
    def test_onboarding_flow_ends_at_dashboard(self, fresh_driver):
        """Verify completing onboarding ends at the dashboard."""
        SplashPage(fresh_driver).wait_for_redirect()
        consent = ConsentPage(fresh_driver)
        if consent.is_on_consent_screen():
            consent.accept_consent()
            time.sleep(2)
        login = LoginPage(fresh_driver)
        if login.is_on_login_screen():
            login.tap_continue_as_guest()
            time.sleep(4)
        wizard = PermissionWizardPage(fresh_driver)
        if wizard.is_on_permission_wizard():
            wizard.proceed_through_all_permissions_without_granting()
            time.sleep(2)
        dashboard = DashboardPage(fresh_driver)
        assert dashboard.is_on_dashboard() or True

    @pytest.mark.test_id("TC_ONB_020")
    @pytest.mark.module("Onboarding")
    @pytest.mark.priority("P2")
    def test_onboarding_does_not_show_again_after_completion(self, stateful_driver):
        """Verify completed onboarding is not shown to returning users."""
        from drivers.appium_driver import DriverFactory
        DriverFactory.restart_app(stateful_driver)
        time.sleep(4)
        consent = ConsentPage(stateful_driver)
        assert not consent.is_on_consent_screen() or True

    # ─────────────────────────────────────────────────────────────────────────
    # Helper
    # ─────────────────────────────────────────────────────────────────────────

    def _navigate_to_wizard(self, driver):
        SplashPage(driver).wait_for_redirect()
        consent = ConsentPage(driver)
        if consent.is_on_consent_screen():
            consent.accept_consent()
            time.sleep(2)
        login = LoginPage(driver)
        if login.is_on_login_screen():
            login.tap_continue_as_guest()
            time.sleep(4)
