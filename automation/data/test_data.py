"""
Test Data for FocusEcho E2E Automation
Centralised data used across all test modules.
"""

from typing import Any


class AuthData:
    """Authentication test data."""
    GUEST_MODE = "guest"
    GOOGLE_BUTTON_TEXT = "Continue with Google"
    GUEST_BUTTON_TEXT = "Continue as Guest"
    VALID_EMAIL_FORMAT = "test@example.com"
    INVALID_EMAIL_FORMATS = [
        "notanemail",
        "@nodomain.com",
        "no-at-sign",
        "spaces in@email.com",
        "",
        " ",
        "a" * 300 + "@test.com",  # Extremely long email
    ]


class OnboardingData:
    """Onboarding flow test data."""
    CONSENT_ACCEPT_TEXTS = ["Accept", "I Agree", "Agree", "Continue"]
    PERMISSION_STEPS = ["Usage Access", "Accessibility Service", "Battery Optimization"]
    EXPECTED_SPLASH_TEXTS = ["Focus Echo", "FocusEcho"]


class DashboardData:
    """Dashboard screen test data."""
    GREETING_PREFIXES = ["Good morning", "Good afternoon", "Good evening"]
    LEVEL_TITLES = ["Focus Rookie", "Consistency Pro", "Flow Master", "Zen Monk"]
    STAT_LABELS = ["Sessions", "Focus Min", "Avoided"]
    XP_SUFFIX = "XP"
    STREAK_SUFFIX = "Day Streak"
    PERSONAL_BEST_PREFIX = "Personal Best:"
    START_BUTTON = "Start Focus Session →"
    RECENT_SESSIONS_HEADER = "Recent Sessions"
    EMPTY_STATE_TEXT = "No sessions today. Start one!"


class FocusSessionData:
    """Focus Session screen test data."""
    READY_TEXT = "Ready to Focus?"
    SELECT_APP_TEXT = "Select your productive app"
    START_TEXT = "START"
    STOP_TEXT = "STOP SESSION"
    MOCK_APP_NAMES = [
        "com.google.android.apps.docs",
        "com.microsoft.office.word",
        "com.notion.id",
    ]
    DISTRACTION_PACKAGES = [
        "com.instagram.android",
        "com.twitter.android",
        "com.facebook.katana",
        "com.snapchat.android",
        "com.zhiliaoapp.musically",
    ]


class SettingsData:
    """Settings screen test data."""
    STRICTNESS_OPTIONS = ["Gentle", "Normal", "Strict"]
    RECOVERY_MIN = 5
    RECOVERY_MAX = 30
    DEFAULT_RECOVERY = 10
    APP_BAR_TITLE = "Settings"
    VERSION_TEXT = "1.0.0"

    # Tile text labels
    RECOVERY_DURATION = "Recovery countdown duration"
    APP_LIMITS_TILE = "Per-app time limits"
    EXPORT_DATA = "Export My Data"
    DELETE_DATA = "Delete My Data"
    PRIVACY_POLICY = "Privacy Policy"
    OPEN_SOURCE = "Open Source Licenses"

    # Dialog texts
    EXPORT_DIALOG_TITLE = "Export My Data"
    DELETE_DIALOG_TITLE = "Delete My Data"
    DELETE_WARNING_CONTAINS = "cannot be undone"

    # Toggle labels
    CLOUD_SYNC = "Cloud sync"
    ANALYTICS_SHARING = "Analytics sharing"
    LOCAL_ONLY = "Local only mode"
    NUDGES = "Enable nudge notifications"
    STREAK_REMINDERS = "Enable streak reminders"


class NavigationData:
    """Navigation test data."""
    BOTTOM_NAV_TABS = ["Home", "Analytics", "Streaks", "Settings"]
    ROUTES = {
        "splash": "/splash",
        "consent": "/consent",
        "permission_wizard": "/permission-wizard",
        "login": "/login",
        "dashboard": "/dashboard",
        "focus_session": "/focus-session",
        "analytics": "/analytics",
        "streaks_xp": "/streaks-xp",
        "settings": "/settings",
        "app_limits": "/settings/app-limits",
    }


class ValidationData:
    """Input validation edge cases."""
    EMPTY_STRING = ""
    SINGLE_SPACE = " "
    WHITESPACE_ONLY = "   "
    SPECIAL_CHARS = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
    VERY_LONG_STRING = "A" * 500
    UNICODE_TEXT = "测试用例 テスト Тест"
    EMOJI_TEXT = "🎯🔥⚡💪🧠"
    SQL_INJECTION = "'; DROP TABLE users; --"
    XSS_PAYLOAD = "<script>alert('xss')</script>"
    NEGATIVE_NUMBER = "-1"
    ZERO = "0"
    MAX_INT = "2147483647"
    FLOAT_VALUE = "3.14"


class ErrorData:
    """Error scenario test data."""
    NETWORK_ERROR_KEYWORDS = ["error", "failed", "retry", "offline", "network"]
    SUCCESS_SNACKBAR_KEYWORDS = ["success", "saved", "updated", "done"]
    WARNING_KEYWORDS = ["warning", "caution", "attention"]


class PerformanceThresholds:
    """Performance test thresholds."""
    SPLASH_MAX_SECONDS = 5.0
    SCREEN_LOAD_MAX_SECONDS = 3.0
    TAP_RESPONSE_MAX_SECONDS = 1.0
    SCROLL_FRAME_THRESHOLD = 60  # FPS minimum
    ANIMATION_MAX_SECONDS = 1.5


class XPLevels:
    """XP level boundaries from app_constants.dart."""
    LEVEL_1_MAX = 499
    LEVEL_2_MIN = 500
    LEVEL_2_MAX = 1499
    LEVEL_3_MIN = 1500
    LEVEL_3_MAX = 3499
    LEVEL_4_MIN = 3500
    RECOVERY_XP = 25
    FAILURE_PENALTY = -10
    STREAK_BONUS_7_DAYS = 100


# ─────────────────────────────────────────────────────────────────────────────
# Test Case Registry — used for Excel report generation
# ─────────────────────────────────────────────────────────────────────────────

TEST_CASE_METADATA: dict[str, dict[str, Any]] = {
    # AUTH (40)
    "TC_AUTH_001": {"module": "Auth", "name": "Splash screen loads successfully", "priority": "P1"},
    "TC_AUTH_002": {"module": "Auth", "name": "Splash auto-redirects to consent", "priority": "P1"},
    "TC_AUTH_003": {"module": "Auth", "name": "Login screen visible after consent", "priority": "P1"},
    "TC_AUTH_004": {"module": "Auth", "name": "Login title text is correct", "priority": "P2"},
    "TC_AUTH_005": {"module": "Auth", "name": "Google sign-in button visible", "priority": "P1"},
    "TC_AUTH_006": {"module": "Auth", "name": "Continue as Guest button visible", "priority": "P1"},
    "TC_AUTH_007": {"module": "Auth", "name": "Google button enabled (not loading)", "priority": "P2"},
    "TC_AUTH_008": {"module": "Auth", "name": "Guest button enabled", "priority": "P2"},
    "TC_AUTH_009": {"module": "Auth", "name": "Tap Google initiates OAuth flow", "priority": "P1"},
    "TC_AUTH_010": {"module": "Auth", "name": "Dismissing Google OAuth returns to login", "priority": "P1"},
    "TC_AUTH_011": {"module": "Auth", "name": "Guest login navigates to permissions/dashboard", "priority": "P1"},
    "TC_AUTH_012": {"module": "Auth", "name": "Guest mode skips auth", "priority": "P2"},
    "TC_AUTH_013": {"module": "Auth", "name": "Loading indicator shown during sign-in", "priority": "P2"},
    "TC_AUTH_014": {"module": "Auth", "name": "App does not crash on repeated tap", "priority": "P2"},
    "TC_AUTH_015": {"module": "Auth", "name": "Back press on login doesn't exit app abruptly", "priority": "P3"},
    "TC_AUTH_016": {"module": "Auth", "name": "Login subtitle text is accurate", "priority": "P3"},
    "TC_AUTH_017": {"module": "Auth", "name": "App remembers guest session on restart", "priority": "P1"},
    "TC_AUTH_018": {"module": "Auth", "name": "Signed-in user directed to dashboard", "priority": "P1"},
    "TC_AUTH_019": {"module": "Auth", "name": "Session persists after app backgrounded", "priority": "P2"},
    "TC_AUTH_020": {"module": "Auth", "name": "App starts from splash every fresh install", "priority": "P1"},
    "TC_AUTH_021": {"module": "Auth", "name": "Sign-out from Settings works", "priority": "P1"},
    "TC_AUTH_022": {"module": "Auth", "name": "Post sign-out redirected to consent", "priority": "P1"},
    "TC_AUTH_023": {"module": "Auth", "name": "Sign-in button not clickable during loading", "priority": "P2"},
    "TC_AUTH_024": {"module": "Auth", "name": "Guest user can sign in later from Settings", "priority": "P2"},
    "TC_AUTH_025": {"module": "Auth", "name": "Multiple tap on guest doesn't cause crash", "priority": "P3"},
    "TC_AUTH_026": {"module": "Auth", "name": "Login screen renders without errors on cold start", "priority": "P1"},
    "TC_AUTH_027": {"module": "Auth", "name": "Google icon rendered in sign-in button", "priority": "P3"},
    "TC_AUTH_028": {"module": "Auth", "name": "Auth state change listener fires on sign in", "priority": "P2"},
    "TC_AUTH_029": {"module": "Auth", "name": "Permission check runs after login", "priority": "P1"},
    "TC_AUTH_030": {"module": "Auth", "name": "User with all permissions goes to dashboard", "priority": "P1"},
    "TC_AUTH_031": {"module": "Auth", "name": "User without permissions goes to wizard", "priority": "P1"},
    "TC_AUTH_032": {"module": "Auth", "name": "Consent not given redirects to consent screen", "priority": "P1"},
    "TC_AUTH_033": {"module": "Auth", "name": "Consent given skips consent screen", "priority": "P1"},
    "TC_AUTH_034": {"module": "Auth", "name": "App does not show login on re-open when authenticated", "priority": "P2"},
    "TC_AUTH_035": {"module": "Auth", "name": "Auth flow completes within 10 seconds", "priority": "P2"},
    "TC_AUTH_036": {"module": "Auth", "name": "Lock icon rendered on login screen", "priority": "P3"},
    "TC_AUTH_037": {"module": "Auth", "name": "Login background gradient visible", "priority": "P3"},
    "TC_AUTH_038": {"module": "Auth", "name": "Scroll on login screen works", "priority": "P3"},
    "TC_AUTH_039": {"module": "Auth", "name": "Keyboard does not appear automatically on login", "priority": "P3"},
    "TC_AUTH_040": {"module": "Auth", "name": "App recovers from network error during sign-in", "priority": "P2"},
}
