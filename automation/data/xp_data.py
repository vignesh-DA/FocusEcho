"""
Extra constants and test data needed by secondary page methods.
Extends the existing test_data.py with additional constants.
"""

from data.test_data import (
    AuthData, OnboardingData, DashboardData, FocusSessionData,
    SettingsData, NavigationData, XPLevels, ValidationData,
    PerformanceThresholds, TEST_CASE_METADATA
)

# ─────────────────────────────────────────────────────────────────────────────
# XP Level thresholds (from app_constants.dart)
# ─────────────────────────────────────────────────────────────────────────────
class XPLevels:
    LEVEL_1_MAX = 100
    LEVEL_2_MAX = 300
    LEVEL_3_MAX = 600
    LEVEL_4_MAX = 1000
    LEVEL_5_MAX = 1500

    LEVEL_NAMES = {
        1: "Focus Rookie",
        2: "Focus Apprentice",
        3: "Focus Pro",
        4: "Focus Master",
        5: "Focus Legend",
    }

    @classmethod
    def get_level_for_xp(cls, xp: int) -> int:
        if xp < cls.LEVEL_1_MAX:  return 1
        if xp < cls.LEVEL_2_MAX:  return 2
        if xp < cls.LEVEL_3_MAX:  return 3
        if xp < cls.LEVEL_4_MAX:  return 4
        return 5

    @classmethod
    def get_name_for_xp(cls, xp: int) -> str:
        return cls.LEVEL_NAMES[cls.get_level_for_xp(xp)]
