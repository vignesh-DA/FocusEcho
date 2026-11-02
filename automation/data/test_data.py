"""
Test Data Repository for FocusEcho E2E Testing
Centralized test data management for 400+ executable test cases.
"""

from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent

class TestData:
    """Static repository of test inputs, expectations, and edge cases."""

    # Authentication Test Data
    VALID_USERS = [
        {"email": "alex.dev@focusecho.ai", "otp": "123456", "name": "Alex", "role": "Pro"},
        {"email": "sarah.lead@focusecho.ai", "otp": "123456", "name": "Sarah", "role": "Pro"},
        {"email": "engineer.test@focusecho.ai", "otp": "654321", "name": "Engineer", "role": "Pro"}
    ]

    INVALID_EMAILS = [
        "",
        "plainaddress",
        "#@%^%#$@#$@#.com",
        "@example.com",
        "Joe Smith <email@example.com>",
        "email.example.com",
        "email@example@example.com",
        ".email@example.com",
        "email.@example.com",
        "email..email@example.com",
        "email@example.com (Joe Smith)",
        "email@example",
        "email@-example.com",
        "email@111.222.333.44444",
        "email@example..com",
        "Abc..123@example.com"
    ]

    INVALID_OTPS = [
        "",
        "12",
        "123",
        "1234",
        "12345",
        "abc",
        "abcdef",
        "!@#$%",
        "12 45"
    ]

    # Focus Timer Goals & Durations
    FOCUS_GOALS = [
        "Implement OAuth2 callback security layer",
        "Refactor Riverpod state providers for offline sync",
        "Profile memory footprint during continuous UsageStats polling",
        "Write integration tests for background audio ducking",
        "Design glassmorphic summary modal for Sprint 2 review"
    ]

    TIMER_PRESETS = [
        {"label": "25 min (Pomodoro)", "minutes": 25, "seconds": 1500},
        {"label": "15 min (Sprint)", "minutes": 15, "seconds": 900},
        {"label": "50 min (Deep Flow)", "minutes": 50, "seconds": 3000},
        {"label": "90 min (Ultra)", "minutes": 90, "seconds": 5400}
    ]

    # Parking Lot CRUD Test Cases
    PARKING_ITEMS = [
        {"text": "Investigate battery drain during 3-second native poll", "priority": "High"},
        {"text": "Check Groq rate limiting with 10 concurrent requests", "priority": "Medium"},
        {"text": "Update app icon with neon cyan outer border", "priority": "Low"},
        {"text": "Test dark mode contrast ratio against WCAG AAA standard", "priority": "High"},
        {"text": "Backup SQLite database prior to v2.5 schema migration", "priority": "Medium"}
    ]

    # Input Validation Edge Cases & XSS Payloads
    XSS_PAYLOADS = [
        "<script>alert('xss')</script>",
        "javascript:/*--></title></style></textarea></script><svg/onload=alert('xss')>",
        "<img src=x onerror=alert('xss')>",
        "<svg onload=alert(1)>",
        "'\"><script>console.log('xss')</script>"
    ]

    BOUNDARY_STRINGS = {
        "empty": "",
        "single_char": "A",
        "exact_max_goal": "A" * 120,
        "overflow_goal": "B" * 150,
        "unicode_chars": "⚡ FocusEcho 🎯 🚀 流 flow 🧘‍♂️ 100% 🎯",
        "sql_injection": "' OR '1'='1' --"
    }

    # Navigation Routes
    ROUTES = [
        {"hash": "dashboard", "title": "Dashboard Overview", "nav_id": "nav-dashboard"},
        {"hash": "timer", "title": "Deep Focus Timer", "nav_id": "nav-timer"},
        {"hash": "parking-lot", "title": "Mind Parking Lot", "nav_id": "nav-parking-lot"},
        {"hash": "analytics", "title": "Productivity & Drift Analytics", "nav_id": "nav-analytics"},
        {"hash": "coach", "title": "EchoCoach Behavioral Guidance", "nav_id": "nav-coach"},
        {"hash": "reflection", "title": "Post-Session Evaluation", "nav_id": "nav-reflection"},
        {"hash": "settings", "title": "System & Profile Settings", "nav_id": "nav-settings"}
    ]

    # Responsive Viewport Profiles
    VIEWPORTS = [
        {"name": "Mobile Small", "width": 375, "height": 667, "is_mobile": True},
        {"name": "Mobile Large", "width": 414, "height": 896, "is_mobile": True},
        {"name": "Tablet Portrait", "width": 768, "height": 1024, "is_mobile": False},
        {"name": "Desktop HD", "width": 1366, "height": 768, "is_mobile": False},
        {"name": "Desktop Full HD", "width": 1920, "height": 1080, "is_mobile": False}
    ]

    # Sample File Paths
    SAMPLE_AVATAR_PNG = DATA_DIR / "test_avatar.png"
    SAMPLE_SESSIONS_JSON = DATA_DIR / "sample_sessions.json"
