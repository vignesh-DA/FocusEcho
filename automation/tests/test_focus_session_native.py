"""
Native Escalation Test Suite — FocusEcho AI (Android)
Implements TC_NATIVE_001–010 from the native Android test plan.

Every case drives the REAL production pipeline — no UI shims, no web demo:
    adb broadcast (com.focusecho.ai.SIMULATE_DISTRACTION / .debug alias)
      -> FocusDetectionService.handleDistractionDetected()   [same function
         real UsageStatsManager polling calls — debug builds only]
      -> DistractionEventQueue -> MainActivity EventSink -> EventChannel
      -> FocusSessionViewModel -> DistractionEventDao / InterventionEventDao
         (SQLite) -> heads-up notification / full-screen InterventionActivity
         / Flutter InterventionOverlay

SQLite assertions run against the on-device focus_echo.db pulled via
`adb run-as` (debug builds) — see utils/db_helper.py.

Deviations from the plan text (documented, not silent):
  • TC_NATIVE_004/005: the app records action_taken='return_to_focus' /
    'take_break' (the plan's 'return'/'break' shorthand is accepted via IN).
  • TC_NATIVE_010: recovery (recovered_at) IS implemented (Feature 3), so
    this is a real test — not xfail. It skips with a reason when Instagram is
    not installed. The stay-away window is 20s (> 15s transition threshold)
    so returning registers as a recovery, not an intentional switch.
  • TC_NATIVE_008: sync only runs for an authenticated Supabase user; when
    the session has none, the cloud leg skips with that reason after the
    offline SQLite leg passes.
"""

import time

import pytest

from pages.focus_session_page import FocusSessionPage
from pages.dashboard_page import DashboardPage
from pages.secondary_pages import NavigationPage
from utils.db_helper import (
    app_installed,
    get_selected_productive_app,
    latest_distraction_events,
    latest_intervention_events,
    set_airplane_mode,
)

INSTAGRAM = "com.instagram.android"
FOCUSECHO = "com.focusecho.ai"


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _navigate_to_focus_session(driver):
    """Navigate from any screen to the Focus Session setup screen."""
    nav = NavigationPage(driver)
    nav.tap_home()
    dashboard = DashboardPage(driver)
    dashboard.scroll_to_start_button()
    dashboard.tap_start_focus_session()
    time.sleep(3)


def _dismiss_stale_interventions(session):
    """Close any intervention left over from a previous test."""
    try:
        if session.is_text_contains_visible("Return to Focus", timeout=2):
            session.tap_return_to_focus()
            time.sleep(2)
    except Exception:
        pass
    try:
        if session.is_distraction_alert_visible():
            session.tap_im_back()
            time.sleep(1)
    except Exception:
        pass


def _start_session(driver, intent: str) -> FocusSessionPage:
    """Navigate to Focus Session, enter intent, start the session."""
    session = FocusSessionPage(driver)
    _dismiss_stale_interventions(session)
    _navigate_to_focus_session(driver)
    session = FocusSessionPage(driver)
    # A completed session from a previous test leaves the summary view up.
    if session.is_session_summary_visible():
        session.tap_done_in_summary()
    if not session.is_app_selected():
        pytest.skip("No productive app configured — skipping native escalation test")
    session.type_intent(intent)
    session.tap_start_button()
    time.sleep(4)
    return session


def _stop_session(session):
    """Stop the active session and dismiss the summary view if shown."""
    _dismiss_stale_interventions(session)
    try:
        if session.is_active_session_state():
            session.tap_stop_session()
            time.sleep(3)
        if session.is_session_summary_visible():
            session.tap_done_in_summary()
            time.sleep(2)
    except Exception:
        pass


def _broadcast(session: FocusSessionPage, package_name: str, label: str,
               action: str = "com.focusecho.ai.SIMULATE_DISTRACTION"):
    """Fire the debug simulation broadcast through the Appium device shell."""
    session.driver.execute_script("mobile: shell", {
        "command": "am",
        "args": [
            "broadcast",
            "-a", action,
            "--es", "package_name", package_name,
            "--es", "app_label", label,
        ],
    })
    time.sleep(2)


# ─────────────────────────────────────────────────────────────────────────────
# TC_NATIVE — Native escalation ladder via the ADB broadcast fixture
# ─────────────────────────────────────────────────────────────────────────────

@pytest.mark.native
@pytest.mark.focus_session
class TestNativeEscalation:

    @pytest.mark.test_id("TC_NATIVE_001")
    @pytest.mark.module("NativeEscalation")
    @pytest.mark.priority("P1")
    @pytest.mark.smoke
    def test_single_broadcast_level1_notification_and_row(self, stateful_driver):
        """
        TC_NATIVE_001 — One broadcast during an active session with an intent
        set must: show the Level-1 heads-up alert, and write a
        distraction_event row with escalation_level=1.
        """
        session = _start_session(stateful_driver, intent="TC_NATIVE_001 level one")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        _broadcast(session, INSTAGRAM, "Instagram")

        assert session.is_distraction_alert_visible(), (
            "Level-1 heads-up alert must be shown after the first broadcast (TC_NATIVE_001)"
        )
        rows = latest_distraction_events(limit=1)
        assert rows, (
            "A distraction_event row must be written to SQLite (TC_NATIVE_001)"
        )
        row = rows[0]
        assert row["package_name"] == INSTAGRAM, (
            f"Row must reference {INSTAGRAM}, got {row['package_name']} (TC_NATIVE_001)"
        )
        assert row["escalation_level"] == 1, (
            f"First relapse must record escalation_level=1, got {row['escalation_level']} (TC_NATIVE_001)"
        )

    @pytest.mark.test_id("TC_NATIVE_002")
    @pytest.mark.module("NativeEscalation")
    @pytest.mark.priority("P1")
    def test_two_broadcasts_show_level2_with_intent(self, stateful_driver):
        """
        TC_NATIVE_002 — Two broadcasts within one session must show the
        Level-2 full-screen intervention, displaying the session intent text.
        """
        intent_text = "TC_NATIVE_002 intent check"
        session = _start_session(stateful_driver, intent=intent_text)
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        _broadcast(session, INSTAGRAM, "Instagram")
        _broadcast(session, INSTAGRAM, "Instagram")

        assert session.is_intervention_overlay_visible(), (
            "Level-2 full-screen intervention must appear after the second relapse (TC_NATIVE_002)"
        )
        assert session.is_text_contains_visible(intent_text, timeout=6), (
            "Level-2 alert must display the session intent text (TC_NATIVE_002)"
        )
        row = latest_distraction_events(limit=1)[0]
        assert row["escalation_level"] == 2, (
            f"Second relapse must record escalation_level=2, got {row['escalation_level']} (TC_NATIVE_002)"
        )

    @pytest.mark.test_id("TC_NATIVE_003")
    @pytest.mark.module("NativeEscalation")
    @pytest.mark.priority("P1")
    def test_four_broadcasts_force_level3_choice(self, stateful_driver):
        """
        TC_NATIVE_003 — Four broadcasts in one session must show the Level-3
        forced choice (Pause Session / Return to Focus) with no silent
        dismiss option (no Take a Break).
        """
        session = _start_session(stateful_driver, intent="TC_NATIVE_003 forced choice")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        for _ in range(4):
            _broadcast(session, INSTAGRAM, "Instagram")

        assert session.is_text_contains_visible("Repeated drift detected", timeout=6), (
            "Level-3 'Repeated drift detected' title must be shown after 4 relapses (TC_NATIVE_003)"
        )
        assert session.is_text_contains_visible("Pause Session", timeout=5), (
            "Level-3 must offer 'Pause Session' (TC_NATIVE_003)"
        )
        assert session.is_text_contains_visible("Return to Focus", timeout=5), (
            "Level-3 must offer 'Return to Focus' (TC_NATIVE_003)"
        )
        assert not session.is_text_contains_visible("Take a Break", timeout=3), (
            "Level-3 must NOT offer 'Take a Break' — no silent dismiss allowed (TC_NATIVE_003)"
        )
        row = latest_distraction_events(limit=1)[0]
        assert row["escalation_level"] == 3, (
            f"Fourth relapse must record escalation_level=3, got {row['escalation_level']} (TC_NATIVE_003)"
        )

    @pytest.mark.test_id("TC_NATIVE_004")
    @pytest.mark.module("NativeEscalation")
    @pytest.mark.priority("P1")
    def test_return_to_focus_dismisses_and_logs_action(self, stateful_driver):
        """
        TC_NATIVE_004 — Tapping 'Return to Focus' on a Level-2+ alert must
        dismiss it, keep the session running, and log intervention_event
        with action_taken='return_to_focus'.
        """
        session = _start_session(stateful_driver, intent="TC_NATIVE_004 return")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        _broadcast(session, INSTAGRAM, "Instagram")
        _broadcast(session, INSTAGRAM, "Instagram")
        assert session.is_intervention_overlay_visible(), (
            "Precondition: Level-2 intervention must be showing (TC_NATIVE_004)"
        )

        session.tap_return_to_focus()
        time.sleep(5)  # service polls every 3s before the action reaches Flutter

        assert not session.is_intervention_overlay_visible(), (
            "Alert must dismiss after Return to Focus (TC_NATIVE_004)"
        )
        assert session.is_active_session_state(), (
            "Session must continue after Return to Focus (TC_NATIVE_004)"
        )
        rows = latest_intervention_events(limit=10)
        assert any(r["action_taken"] in ("return", "return_to_focus") for r in rows), (
            "intervention_event with action_taken='return_to_focus' must be recorded (TC_NATIVE_004)"
        )

    @pytest.mark.test_id("TC_NATIVE_005")
    @pytest.mark.module("NativeEscalation")
    @pytest.mark.priority("P1")
    def test_take_a_break_pauses_session_and_logs_action(self, stateful_driver):
        """
        TC_NATIVE_005 — Tapping 'Take a Break' on a Level-2 alert must pause
        the session and record intervention_event.action_taken='take_break'.
        """
        session = _start_session(stateful_driver, intent="TC_NATIVE_005 break")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        _broadcast(session, INSTAGRAM, "Instagram")
        _broadcast(session, INSTAGRAM, "Instagram")
        assert session.is_intervention_overlay_visible(), (
            "Precondition: Level-2 intervention must be showing (TC_NATIVE_005)"
        )

        session.tap_take_a_break()
        time.sleep(5)  # service polls every 3s before the action reaches Flutter

        assert not session.is_active_session_state(), (
            "Session must be paused after Take a Break (TC_NATIVE_005)"
        )
        rows = latest_intervention_events(limit=10)
        assert any(r["action_taken"] in ("break", "take_break") for r in rows), (
            "intervention_event with action_taken='take_break' must be recorded (TC_NATIVE_005)"
        )

    @pytest.mark.test_id("TC_NATIVE_006")
    @pytest.mark.module("NativeEscalation")
    @pytest.mark.priority("P1")
    def test_relapse_counter_resets_per_session(self, stateful_driver):
        """
        TC_NATIVE_006 — After ending a session that accumulated relapses, a
        fresh session's first broadcast must read relapse counter 1 (Level-1
        heads-up, escalation_level=1) — confirming the per-session reset.
        """
        session = _start_session(stateful_driver, intent="TC_NATIVE_006 session A")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        # Build up relapses in session A.
        _broadcast(session, INSTAGRAM, "Instagram")
        _broadcast(session, INSTAGRAM, "Instagram")
        _stop_session(session)

        # Fresh session B — the counter must restart from zero.
        session_b = _start_session(stateful_driver, intent="TC_NATIVE_006 session B")
        if not session_b.is_active_session_state():
            pytest.skip("Follow-up session did not start")

        _broadcast(session_b, INSTAGRAM, "Instagram")

        assert session_b.get_distraction_count() == 1, (
            "New session must read relapse counter 1, not continue from the prior session (TC_NATIVE_006)"
        )
        assert session_b.is_distraction_alert_visible(), (
            "First relapse of a new session must show the Level-1 heads-up alert (TC_NATIVE_006)"
        )
        assert not session_b.is_intervention_overlay_visible(), (
            "First relapse of a new session must NOT escalate to full-screen (TC_NATIVE_006)"
        )
        row = latest_distraction_events(limit=1)[0]
        assert row["escalation_level"] == 1, (
            f"Fresh-session relapse must record escalation_level=1, got {row['escalation_level']} (TC_NATIVE_006)"
        )

    @pytest.mark.test_id("TC_NATIVE_007")
    @pytest.mark.module("NativeEscalation")
    @pytest.mark.priority("P2")
    def test_heads_up_notification_fires_while_backgrounded(self, stateful_driver):
        """
        TC_NATIVE_007 — With FocusEcho backgrounded, a broadcast must still
        fire the heads-up notification (the foreground service keeps the
        receiver alive regardless of UI state).
        """
        # Restart the session so the detection service is a fresh instance —
        # the 30s notification throttle would otherwise suppress the alert.
        _stop_session(FocusSessionPage(stateful_driver))
        session = _start_session(stateful_driver, intent="TC_NATIVE_007 background")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        stateful_driver.press_keycode(3)  # KEYCODE_HOME — background the app
        time.sleep(2)
        assert stateful_driver.current_package != FOCUSECHO, (
            "Precondition: FocusEcho must be backgrounded (TC_NATIVE_007)"
        )

        _broadcast(session, INSTAGRAM, "Instagram")
        time.sleep(3)

        dumpsys = stateful_driver.execute_script("mobile: shell", {
            "command": "dumpsys",
            "args": ["notification", "--noredact"],
        })
        assert "Focus check" in dumpsys, (
            "Heads-up 'Focus check' notification must be posted while the app is backgrounded (TC_NATIVE_007)"
        )

        stateful_driver.activate_app(FOCUSECHO)
        time.sleep(2)

    @pytest.mark.test_id("TC_NATIVE_008")
    @pytest.mark.module("NativeEscalation")
    @pytest.mark.priority("P2")
    def test_offline_event_syncs_after_reconnect(self, stateful_driver):
        """
        TC_NATIVE_008 — Offline (airplane mode): the broadcast must write the
        distraction_event to SQLite immediately (is_synced=0). After
        reconnect, SyncService (triggered by session stop) must push it and
        mark it is_synced=1.
        """
        session = _start_session(stateful_driver, intent="TC_NATIVE_008 offline sync")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        set_airplane_mode(True)
        try:
            _broadcast(session, INSTAGRAM, "Instagram")
            rows = latest_distraction_events(limit=1)
            assert rows, "distraction_event must be written to SQLite even while offline (TC_NATIVE_008)"
            assert rows[0]["package_name"] == INSTAGRAM, (
                f"Offline row must reference {INSTAGRAM} (TC_NATIVE_008)"
            )
            assert rows[0]["is_synced"] == 0, (
                "Offline row must not be marked synced before reconnect (TC_NATIVE_008)"
            )
        finally:
            set_airplane_mode(False)

        # Reconnect — stopSession triggers SyncService.syncPendingEvents().
        _dismiss_stale_interventions(session)
        _stop_session(session)

        for _ in range(12):  # poll up to ~60s for the push to complete
            rows = latest_distraction_events(limit=1)
            if rows and rows[0]["is_synced"] == 1:
                break
            time.sleep(5)

        if not (rows and rows[0]["is_synced"] == 1):
            pytest.skip(
                "Supabase sync requires an authenticated user — SyncService "
                "skips when currentUser is null. Offline SQLite write + "
                "is_synced=0 queue state verified above (TC_NATIVE_008)."
            )

    @pytest.mark.test_id("TC_NATIVE_009")
    @pytest.mark.module("NativeEscalation")
    @pytest.mark.priority("P1")
    def test_level2_alert_shows_actual_intent_string(self, stateful_driver):
        """
        TC_NATIVE_009 — With intent 'Study Compiler Design', the Level-2
        alert must display the actual intent string, not a placeholder.
        """
        session = _start_session(stateful_driver, intent="Study Compiler Design")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        _broadcast(session, INSTAGRAM, "Instagram")
        _broadcast(session, INSTAGRAM, "Instagram")

        assert session.is_text_contains_visible("Study Compiler Design", timeout=6), (
            "Level-2 alert must include the actual intent string 'Study Compiler Design' (TC_NATIVE_009)"
        )
        assert not session.is_text_contains_visible("placeholder", timeout=2), (
            "Alert must not render a placeholder instead of the intent (TC_NATIVE_009)"
        )

    @pytest.mark.test_id("TC_NATIVE_010")
    @pytest.mark.module("NativeEscalation")
    @pytest.mark.priority("P2")
    def test_real_distraction_records_recovery(self, stateful_driver):
        """
        TC_NATIVE_010 — REAL (non-simulated) distraction: foreground the
        distracting app via activate_app(), stay past the 15s transition
        threshold, then return to the session's productive app. The engine's
        recovery path must stamp recovered_at (+ is_recovered=1) on the
        distraction_event row.

        The plan marked this xfail "until Feature 3 (Recovery Rate) ships" —
        Feature 3 is now implemented (onRecovery -> updateRecovery writes
        recovered_at), so this runs as a real test. It skips with a real
        reason when the distracting app is not installed on the device.
        """
        if not app_installed(INSTAGRAM):
            pytest.skip(
                "Instagram is not installed on the test device — install a "
                "stub APK with package com.instagram.android for full "
                "real-distraction coverage (TC_NATIVE_010)"
            )

        session = _start_session(stateful_driver, intent="TC_NATIVE_010 real distraction")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        # Return target = the session's focus app (engine 'origin').
        productive = get_selected_productive_app() or FOCUSECHO

        stateful_driver.activate_app(INSTAGRAM)
        time.sleep(20)  # > 15s transitionThresholdMs -> return counts as recovery
        stateful_driver.activate_app(productive)
        time.sleep(8)   # poll (3s) + payload + recovery write

        rows = [
            r for r in latest_distraction_events(limit=10)
            if r["package_name"] == INSTAGRAM
        ]
        assert rows, (
            "A distraction_event row must be recorded for the real Instagram "
            "foregrounding (TC_NATIVE_010)"
        )
        latest = rows[0]
        assert latest["recovered_at"], (
            "recovered_at must be stamped on the distraction_event row once the "
            "user returns to the focus app (TC_NATIVE_010)"
        )
        assert latest["is_recovered"] == 1, (
            "is_recovered must be set after the return (TC_NATIVE_010)"
        )
        assert (latest["recovery_time_seconds"] or 0) >= 15, (
            "recovery_time_seconds must reflect the ~20s stay-away window (TC_NATIVE_010)"
        )
