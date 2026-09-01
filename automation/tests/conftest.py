"""
Root conftest.py — adds automation/ to sys.path so all imports resolve correctly
across all test files regardless of how pytest is invoked.
"""

import sys
from pathlib import Path

# Make sure 'automation/' is on the path (enables: from pages.xxx import ...)
automation_root = Path(__file__).parent.parent
if str(automation_root) not in sys.path:
    sys.path.insert(0, str(automation_root))

# Also import all runner-level fixtures so they are available here.
# Wrapped in try/except so the WEB (Selenium) suite under tests/web/ can run
# in environments where the Appium stack is not installed.
try:
    from runners.conftest import *  # noqa: F401, F403
except ImportError as _exc:  # pragma: no cover — Appium-free environments
    print(f"[conftest] Appium fixtures unavailable ({_exc}); web Selenium suite only.")

