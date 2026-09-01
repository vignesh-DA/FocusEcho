"""
DB Helper — pull and query FocusEcho's on-device SQLite database
(focus_echo.db) via `adb run-as` (debug builds only).

Used by the TC_NATIVE_* suite to assert on real DistractionEventDao /
InterventionEventDao writes — the SQLite database is the source of truth for
relapse history, escalation levels, intervention actions, and sync state.
"""

import json
import re
import sqlite3
import subprocess
import tempfile
import time
from pathlib import Path

APP_PACKAGE = "com.focusecho.ai"
DB_NAME = "focus_echo.db"


def _adb_text(args, timeout=15):
    """Run an adb command and return decoded stdout. Raises on failure."""
    result = subprocess.run(
        ["adb", *args], capture_output=True, text=True, timeout=timeout
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"adb {' '.join(args)} failed: {result.stderr.strip() or result.stdout.strip()}"
        )
    return result.stdout


def _adb_bytes(args, timeout=15):
    """Run an adb command and return raw stdout bytes (binary-safe)."""
    result = subprocess.run(["adb", *args], capture_output=True, timeout=timeout)
    if result.returncode != 0:
        raise RuntimeError(f"adb {' '.join(args)} failed")
    return result.stdout


def pull_db(package: str = APP_PACKAGE) -> Path:
    """
    Copy focus_echo.db (plus -wal/-shm sidecars when present) out of the
    app's private storage using run-as and return the local file path.
    Requires a debug build (run-as is blocked on release builds).
    """
    out_dir = Path(tempfile.mkdtemp(prefix="focusecho_db_"))
    remote = f"/data/data/{package}/app_flutter/{DB_NAME}"
    local_db = out_dir / DB_NAME
    local_db.write_bytes(_adb_bytes(["exec-out", "run-as", package, "cat", remote]))
    for suffix in ("-wal", "-shm"):
        probe = subprocess.run(
            ["adb", "shell", "run-as", package, "test", "-f", remote + suffix],
            capture_output=True, timeout=15,
        )
        if probe.returncode == 0:
            (out_dir / (DB_NAME + suffix)).write_bytes(
                _adb_bytes(["exec-out", "run-as", package, "cat", remote + suffix])
            )
    return local_db


def query(sql: str, params: tuple = (), package: str = APP_PACKAGE) -> list:
    """Pull the DB and run a read-only query, returning rows as dicts."""
    db_path = pull_db(package)
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        return [dict(r) for r in conn.execute(sql, params).fetchall()]
    finally:
        conn.close()


def latest_distraction_events(limit: int = 10, package: str = APP_PACKAGE) -> list:
    """Most recent real distraction rows (event_type='distraction'), newest first."""
    return query(
        "SELECT * FROM distraction_events WHERE event_type = 'distraction' "
        "ORDER BY triggered_at DESC LIMIT ?",
        (limit,), package,
    )


def latest_intervention_events(limit: int = 10, package: str = APP_PACKAGE) -> list:
    """Most recent intervention rows, newest first."""
    return query(
        "SELECT * FROM intervention_events ORDER BY timestamp DESC LIMIT ?",
        (limit,), package,
    )


def app_installed(package: str) -> bool:
    """True when [package] is installed on the connected device."""
    try:
        return package in _adb_text(["shell", "pm", "list", "packages", package])
    except Exception:
        return False


def set_airplane_mode(enabled: bool) -> None:
    """Toggle airplane mode (emulator/CI devices)."""
    _adb_text(["shell", "cmd", "connectivity", "airplane-mode",
               "enable" if enabled else "disable"], timeout=20)
    time.sleep(3)


def get_selected_productive_app(package: str = APP_PACKAGE):
    """
    Read the selected productive app package from FlutterSharedPreferences
    (used by TC_NATIVE_010 to return to the session's focus app).
    Returns the first configured productive app or None.
    """
    try:
        xml = _adb_text([
            "shell", "run-as", package, "cat",
            f"/data/data/{package}/shared_prefs/FlutterSharedPreferences.xml",
        ])
        match = re.search(r'name="flutter\.productive_apps">(.*?)</string>', xml)
        if not match:
            return None
        apps = json.loads(match.group(1).replace("&quot;", '"'))
        return apps[0] if apps else None
    except Exception:
        return None
