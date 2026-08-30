"""
Appium Configuration for FocusEcho AI Android Automation
Package: com.focusecho.ai
Appium version: 2.x with UiAutomator2 driver
"""

import os

# ─────────────────────────────────────────────────────────────────────────────
# Appium Server
# ─────────────────────────────────────────────────────────────────────────────
APPIUM_SERVER_URL = os.getenv("APPIUM_SERVER_URL", "http://127.0.0.1:4723")
APPIUM_SERVER_HOST = os.getenv("APPIUM_HOST", "127.0.0.1")
APPIUM_SERVER_PORT = int(os.getenv("APPIUM_PORT", "4723"))

# ─────────────────────────────────────────────────────────────────────────────
# Application Under Test
# ─────────────────────────────────────────────────────────────────────────────
APP_PACKAGE = "com.focusecho.ai"
APP_ACTIVITY = "com.focusecho.ai.MainActivity"
APK_PATH = os.getenv(
    "APK_PATH",
    os.path.join(
        os.path.dirname(__file__),
        "..",
        "..",
        "mobile_app",
        "build",
        "app",
        "outputs",
        "flutter-apk",
        "app-debug.apk",
    ),
)

# ─────────────────────────────────────────────────────────────────────────────
# Device / Emulator
# ─────────────────────────────────────────────────────────────────────────────
DEVICE_NAME = os.getenv("DEVICE_NAME", "emulator-5554")
PLATFORM_VERSION = os.getenv("PLATFORM_VERSION", "13.0")  # Android 13 / API 33
AVD_NAME = os.getenv("AVD_NAME", "FocusEcho_AVD")

# ─────────────────────────────────────────────────────────────────────────────
# Desired Capabilities (Appium 2 / W3C format)
# ─────────────────────────────────────────────────────────────────────────────
DESIRED_CAPABILITIES = {
    "platformName": "Android",
    "appium:deviceName": DEVICE_NAME,
    "appium:platformVersion": PLATFORM_VERSION,
    "appium:automationName": "UiAutomator2",
    "appium:appPackage": APP_PACKAGE,
    "appium:appActivity": APP_ACTIVITY,
    "appium:app": os.path.abspath(APK_PATH),
    "appium:noReset": False,
    "appium:fullReset": False,
    "appium:autoGrantPermissions": True,
    "appium:newCommandTimeout": 120,
    "appium:androidInstallTimeout": 90000,
    "appium:adbExecTimeout": 60000,
    "appium:uiautomator2ServerLaunchTimeout": 60000,
    "appium:uiautomator2ServerInstallTimeout": 60000,
    "appium:skipServerInstallation": False,
    "appium:ignoreHiddenApiPolicyError": True,
    "appium:disableWindowAnimation": True,
    # Screenshot settings
    "appium:screenshotQuality": 2,
    # Flutter-specific: use accessibility IDs set via semantics labels
    "appium:settings[waitForIdleTimeout]": 10000,
    "appium:settings[waitForSelectorTimeout]": 10000,
}

# ─────────────────────────────────────────────────────────────────────────────
# No-Reset capabilities (for tests that need pre-existing state)
# ─────────────────────────────────────────────────────────────────────────────
DESIRED_CAPABILITIES_NO_RESET = {
    **DESIRED_CAPABILITIES,
    "appium:noReset": True,
    "appium:fullReset": False,
}

# ─────────────────────────────────────────────────────────────────────────────
# Appium Service Config (when started programmatically)
# ─────────────────────────────────────────────────────────────────────────────
APPIUM_SERVICE_CONFIG = {
    "host": APPIUM_SERVER_HOST,
    "port": APPIUM_SERVER_PORT,
    "args": [
        "--relaxed-security",
        "--log-level", "info",
    ],
}
