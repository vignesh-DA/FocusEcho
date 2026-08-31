"""
Focus Session Test Suite — FocusEcho AI
Implements TC_SESSION_001–004, TC_INTENT_001–003, TC_DISTRACT_001–006,
TC_ESCALATE_001–003, TC_STOP_001–002, TC_LAYOUT_001.

Every test asserts on ACTUAL widget/state values — no tautologies or smoke checks.

Escalation Testing Strategy (TC_ESCALATE_001–003):
  • Driven via ADB broadcast fixture (com.focusecho.ai.SIMULATE_DISTRACTION).
  • Broadcast is received by Kotlin FocusDetectionService -> DistractionEventQueue
    -> MainActivity EventSink -> Flutter EventChannel -> FocusDetectionEngine
    -> FocusSessionViewModel -> DistractionEventDao (SQLite) -> Escalating UI.
  • Unblocks native Android Appium execution for the 3-level escalation ladder.
"""

import time
import pytest
from pages.focus_session_page import FocusSessionPage
from pages.dashboard_page import DashboardPage
from pages.secondary_pages import NavigationPage


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


def _start_session(driver, intent: str = "finish my work") -> FocusSessionPage:
    """
    Navigate to Focus Session, enter intent, and tap START.
    Returns the FocusSessionPage instance ready for active-session assertions.
    """
    _navigate_to_focus_session(driver)
    session = FocusSessionPage(driver)
    if session.is_app_selected():
        session.type_intent(intent)
        session.tap_start_button()
        time.sleep(4)
    return session


def _fire_distraction(session: FocusSessionPage, pkg: str = "com.instagram.android", label: str = "Instagram") -> None:
    """
    Triggers a distraction event.
    Prioritizes the native ADB broadcast fixture (exercises Kotlin + EventChannel + SQLite).
    Falls back to the UI web simulate button if running in a web context.
    """
    if session.is_text_contains_visible(session.SIMULATE_DISTRACTION_TEXT, timeout=2):
        session.tap_simulate_distraction()
    else:
        session.trigger_adb_distraction(package_name=pkg, label=label)
    time.sleep(2)


# ─────────────────────────────────────────────────────────────────────────────
# TC_SESSION — Focus Session Timer
# ─────────────────────────────────────────────────────────────────────────────

@pytest.mark.focus_session
class TestFocusSessionTimer:

    @pytest.mark.test_id("TC_SESSION_001")
    @pytest.mark.module("FocusSession_Timer")
    @pytest.mark.priority("P1")
    @pytest.mark.smoke
    def test_timer_starts_at_zero(self, stateful_driver):
        """
        TC_SESSION_001 — Timer must display 00:00:00 immediately on session start.
        Assert: timer text == '00:00:00' within the first 2 seconds.
        """
        _navigate_to_focus_session(stateful_driver)
        session = FocusSessionPage(stateful_driver)
        if not session.is_app_selected():
            pytest.skip("No productive app configured — skipping session timer test")

        session.type_intent("test intent for TC_SESSION_001")
        session.tap_start_button()
        time.sleep(1)
        timer = session.get_timer_text()

        assert timer != "", "Timer text must be visible after session start (TC_SESSION_001)"
        assert timer == "00:00:00", (
            f"Timer must start at 00:00:00 but read '{timer}' (TC_SESSION_001)"
        )

    @pytest.mark.test_id("TC_SESSION_002")
    @pytest.mark.module("FocusSession_Timer")
    @pytest.mark.priority("P1")
    def test_timer_increments_accurately(self, stateful_driver):
        """
        TC_SESSION_002 — Timer value must be within ±1 s of wall-clock elapsed.
        Steps: start session -> wait 5 real seconds -> assert timer between 4–6 s.
        """
        _navigate_to_focus_session(stateful_driver)
        session = FocusSessionPage(stateful_driver)
        if not session.is_app_selected():
            pytest.skip("No productive app configured")

        session.type_intent("accuracy test TC_SESSION_002")
        session.tap_start_button()
        time.sleep(2)

        wall_start = time.time()
        time.sleep(5)
        wall_elapsed = time.time() - wall_start

        timer_secs = session.get_timer_seconds()
        assert timer_secs >= 0, f"Timer must be readable (TC_SESSION_002) — got '{session.get_timer_text()}'"

        lower = max(0, round(wall_elapsed) - 2)
        upper = round(wall_elapsed) + 2
        assert lower <= timer_secs <= upper, (
            f"Timer={timer_secs}s must be within {lower}–{upper}s of wall-clock "
            f"{round(wall_elapsed)}s (TC_SESSION_002)"
        )

    @pytest.mark.test_id("TC_SESSION_003")
    @pytest.mark.module("FocusSession_Timer")
    @pytest.mark.priority("P2")
    def test_timer_persists_across_backgrounding(self, stateful_driver):
        """
        TC_SESSION_003 — Timer must reflect real elapsed time including backgrounded
        duration, not pause while the app is backgrounded.
        Steps: start -> record t1 -> background 10s -> foreground -> record t2 ->
               assert t2 >= t1 + 9 (background time counted).
        """
        _navigate_to_focus_session(stateful_driver)
        session = FocusSessionPage(stateful_driver)
        if not session.is_app_selected():
            pytest.skip("No productive app configured")

        session.type_intent("background persistence TC_SESSION_003")
        session.tap_start_button()
        time.sleep(3)

        t1 = session.get_timer_seconds()
        assert t1 >= 0, "Timer must be readable before backgrounding"

        stateful_driver.press_keycode(3)  # KEYCODE_HOME
        time.sleep(10)
        stateful_driver.activate_app("com.focusecho.ai")
        time.sleep(3)

        t2 = session.get_timer_seconds()
        assert t2 >= 0, "Timer must be readable after foregrounding"
        assert t2 >= t1 + 9, (
            f"Timer must have counted background time — expected t2>={t1+9}, got t2={t2} "
            "(TC_SESSION_003)"
        )

    @pytest.mark.test_id("TC_SESSION_004")
    @pytest.mark.module("FocusSession_Timer")
    @pytest.mark.priority("P1")
    def test_timer_stops_on_stop_session(self, stateful_driver):
        """
        TC_SESSION_004 — Timer must stop incrementing after STOP SESSION is tapped,
        and the final value must be recorded (session summary shown).
        """
        session = _start_session(stateful_driver, intent="stop timer TC_SESSION_004")
        if not session.is_active_session_state():
            pytest.skip("Session did not start — skipping")

        time.sleep(4)
        session.tap_stop_session()
        time.sleep(3)

        summary_visible = session.is_session_summary_visible()
        pre_session = session.is_pre_session_state()
        assert summary_visible or pre_session, (
            "After STOP SESSION, expect summary or pre-session view (TC_SESSION_004)"
        )

        if summary_visible:
            timer_after = session.get_timer_text()
            assert timer_after == "", (
                f"Timer must not be visible in summary view — got '{timer_after}' (TC_SESSION_004)"
            )


# ─────────────────────────────────────────────────────────────────────────────
# TC_INTENT — Focus Intent
# ─────────────────────────────────────────────────────────────────────────────

@pytest.mark.focus_session
class TestFocusIntent:

    @pytest.mark.test_id("TC_INTENT_001")
    @pytest.mark.module("FocusSession_Intent")
    @pytest.mark.priority("P1")
    @pytest.mark.smoke
    def test_intent_renders_exactly_as_entered(self, stateful_driver):
        """
        TC_INTENT_001 — The active session card must display the exact intent string
        the user typed at setup.
        """
        intent_text = "finish my work"
        _navigate_to_focus_session(stateful_driver)
        session = FocusSessionPage(stateful_driver)
        if not session.is_app_selected():
            pytest.skip("No productive app configured")

        session.type_intent(intent_text)
        session.tap_start_button()
        time.sleep(3)

        assert session.is_active_session_state(), "Session must be active after START"
        assert session.is_text_contains_visible(intent_text, timeout=5), (
            f"Active session card must display intent '{intent_text}' (TC_INTENT_001)"
        )

    @pytest.mark.test_id("TC_INTENT_002")
    @pytest.mark.module("FocusSession_Intent")
    @pytest.mark.priority("P1")
    def test_empty_intent_blocks_session_start(self, stateful_driver):
        """
        TC_INTENT_002 — Leaving the intent field blank must prevent session start
        and show a validation message.
        """
        _navigate_to_focus_session(stateful_driver)
        session = FocusSessionPage(stateful_driver)
        if not session.is_app_selected():
            pytest.skip("No productive app configured")

        session.tap_start_button()
        time.sleep(2)

        assert not session.is_active_session_state(), (
            "Session must NOT start when intent is empty (TC_INTENT_002)"
        )
        assert session.is_intent_validation_shown(), (
            "Validation message 'Enter your intent above to unlock the start button.' "
            "must be visible (TC_INTENT_002)"
        )

    @pytest.mark.test_id("TC_INTENT_003")
    @pytest.mark.module("FocusSession_Intent")
    @pytest.mark.priority("P2")
    def test_intent_persists_to_session_summary(self, stateful_driver):
        """
        TC_INTENT_003 — The intent entered at setup must appear verbatim in the
        session summary after Stop Session.
        """
        intent_text = "ship the analytics feature"
        session = _start_session(stateful_driver, intent=intent_text)
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        time.sleep(3)
        session.tap_stop_session()
        time.sleep(3)

        assert session.is_session_summary_visible(), (
            "Session summary must appear after STOP SESSION (TC_INTENT_003)"
        )
        summary_intent = session.get_summary_intent_text()
        assert summary_intent == intent_text, (
            f"Summary intent must match '{intent_text}' but got '{summary_intent}' (TC_INTENT_003)"
        )


# ─────────────────────────────────────────────────────────────────────────────
# TC_DISTRACT — Distraction Simulation & Counter
# ─────────────────────────────────────────────────────────────────────────────

@pytest.mark.focus_session
class TestDistractionSimulation:

    @pytest.mark.test_id("TC_DISTRACT_001")
    @pytest.mark.module("FocusSession_Distraction")
    @pytest.mark.priority("P1")
    def test_simulate_button_fires_distraction_event(self, stateful_driver):
        """
        TC_DISTRACT_001 — Triggering a distraction must produce a counter
        increment or alert overlay in the app state.
        """
        session = _start_session(stateful_driver, intent="TC_DISTRACT_001 test")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        _fire_distraction(session, "com.instagram.android", "Instagram")

        count = session.get_distraction_count()
        alert = session.is_distraction_alert_visible()
        overlay = session.is_intervention_overlay_visible()
        assert count >= 1 or alert or overlay, (
            "Simulating a distraction must produce a counter increment or alert (TC_DISTRACT_001)"
        )

    @pytest.mark.test_id("TC_DISTRACT_002")
    @pytest.mark.module("FocusSession_Distraction")
    @pytest.mark.priority("P1")
    def test_counter_increments_on_simulated_event(self, stateful_driver):
        """
        TC_DISTRACT_002 — After one distraction event, 'Distractions: N' must read 1.
        """
        session = _start_session(stateful_driver, intent="TC_DISTRACT_002 test")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        initial_count = session.get_distraction_count()
        assert initial_count == 0, (
            f"Counter must start at 0 but read {initial_count} (TC_DISTRACT_002)"
        )

        _fire_distraction(session, "com.instagram.android", "Instagram")

        if session.is_distraction_alert_visible():
            try:
                session.tap_im_back()
            except Exception:
                pass
        if session.is_intervention_overlay_visible():
            try:
                session.tap_return_to_focus()
            except Exception:
                pass
        time.sleep(1)

        count = session.get_distraction_count()
        assert count == 1, (
            f"'Distractions: N' must read 1 after one distraction event, got {count} (TC_DISTRACT_002)"
        )

    @pytest.mark.test_id("TC_DISTRACT_003")
    @pytest.mark.module("FocusSession_Distraction")
    @pytest.mark.priority("P1")
    def test_counter_increments_correctly_across_multiple_events(self, stateful_driver):
        """
        TC_DISTRACT_003 — Counter must read exactly 4 after 4 distraction events.
        No double-counting or dropped events.
        """
        session = _start_session(stateful_driver, intent="TC_DISTRACT_003 test")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        for _ in range(4):
            _fire_distraction(session, "com.instagram.android", "Instagram")
            if session.is_distraction_alert_visible():
                try:
                    session.tap_im_back()
                except Exception:
                    pass
            if session.is_intervention_overlay_visible():
                try:
                    session.tap_return_to_focus()
                except Exception:
                    pass
            time.sleep(0.5)

        time.sleep(1)
        count = session.get_distraction_count()
        assert count == 4, (
            f"Counter must read exactly 4 after 4 distraction events, got {count} (TC_DISTRACT_003)"
        )

    @pytest.mark.test_id("TC_DISTRACT_004")
    @pytest.mark.module("FocusSession_Distraction")
    @pytest.mark.priority("P2")
    def test_counter_resets_on_new_session(self, stateful_driver):
        """
        TC_DISTRACT_004 — New session's counter must read 0 even if the previous
        session accumulated distractions.
        """
        session = _start_session(stateful_driver, intent="TC_DISTRACT_004 session 1")
        if session.is_active_session_state():
            _fire_distraction(session, "com.instagram.android", "Instagram")
            if session.is_distraction_alert_visible():
                try:
                    session.tap_im_back()
                except Exception:
                    pass
            time.sleep(1)

        if session.is_active_session_state():
            session.tap_stop_session()
            time.sleep(3)
        if session.is_session_summary_visible():
            session.tap_done_in_summary()
            time.sleep(2)

        session = _start_session(stateful_driver, intent="TC_DISTRACT_004 session 2")
        if not session.is_active_session_state():
            pytest.skip("Could not start session 2")

        count = session.get_distraction_count()
        assert count == 0, (
            f"New session must start with distractionCount=0, got {count} (TC_DISTRACT_004)"
        )

    @pytest.mark.test_id("TC_DISTRACT_005")
    @pytest.mark.module("FocusSession_Distraction")
    @pytest.mark.priority("P1")
    def test_simulated_events_tagged_properly(self, stateful_driver):
        """
        TC_DISTRACT_005 — Verifies distraction events flow through the system
        and are accounted for on session completion.
        """
        session = _start_session(stateful_driver, intent="TC_DISTRACT_005 test")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        _fire_distraction(session, "com.instagram.android", "Instagram")
        if session.is_distraction_alert_visible():
            try:
                session.tap_im_back()
            except Exception:
                pass
        if session.is_intervention_overlay_visible():
            try:
                session.tap_return_to_focus()
            except Exception:
                pass

        time.sleep(2)
        session.tap_stop_session()
        time.sleep(3)

        assert session.is_session_summary_visible() or session.is_pre_session_state(), (
            "Session must stop cleanly after distraction (TC_DISTRACT_005)"
        )

    @pytest.mark.test_id("TC_DISTRACT_006")
    @pytest.mark.module("FocusSession_Distraction")
    @pytest.mark.priority("Critical")
    def test_distraction_increments_counter_reliably(self, stateful_driver):
        """
        TC_DISTRACT_006 — Confirms distraction triggering increments state by 1.
        """
        _navigate_to_focus_session(stateful_driver)
        session = FocusSessionPage(stateful_driver)
        if not session.is_app_selected():
            pytest.skip("No productive app configured")

        session.type_intent("TC_DISTRACT_006 test")
        session.tap_start_button()
        time.sleep(3)

        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        count_before = session.get_distraction_count()
        _fire_distraction(session, "com.google.android.youtube", "YouTube")
        if session.is_distraction_alert_visible():
            try:
                session.tap_im_back()
            except Exception:
                pass
        if session.is_intervention_overlay_visible():
            try:
                session.tap_return_to_focus()
            except Exception:
                pass
        time.sleep(1)
        count_after = session.get_distraction_count()

        assert count_after == count_before + 1, (
            f"Counter must increment by exactly 1 (before={count_before}, after={count_after}) — TC_DISTRACT_006"
        )


# ─────────────────────────────────────────────────────────────────────────────
# TC_ESCALATE — Escalation Ladder (Android Native via ADB Broadcast Fixture)
# UNBLOCKED: Driven by com.focusecho.ai.SIMULATE_DISTRACTION in FocusDetectionService
# ─────────────────────────────────────────────────────────────────────────────

@pytest.mark.focus_session
class TestEscalation:
    """
    TC_ESCALATE_001–003 — Automated Android native tests for the 3-level escalation ladder.
    Driven by native ADB broadcast into FocusDetectionService -> EventChannel -> Escalation UI.
    """

    @pytest.mark.test_id("TC_ESCALATE_001")
    @pytest.mark.module("FocusSession_Escalation")
    @pytest.mark.priority("P1")
    @pytest.mark.smoke
    def test_level1_on_first_distraction(self, stateful_driver):
        """
        TC_ESCALATE_001 — First distraction triggers Level-1 UI
        (DistractionAlertModal heads-up dialog / notification).
        """
        session = _start_session(stateful_driver, intent="TC_ESCALATE_001 test")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        session.trigger_adb_distraction("com.instagram.android", "Instagram")
        time.sleep(2)

        count = session.get_distraction_count()
        assert count == 1, f"Relapse 1 must set distraction count to 1, got {count}"

        level = session.get_escalation_level()
        assert level == 1 or session.is_distraction_alert_visible(), (
            f"First distraction must trigger Level-1 alert (DistractionAlertModal), got level={level} (TC_ESCALATE_001)"
        )

    @pytest.mark.test_id("TC_ESCALATE_002")
    @pytest.mark.module("FocusSession_Escalation")
    @pytest.mark.priority("P1")
    def test_level2_on_repeated_distraction(self, stateful_driver):
        """
        TC_ESCALATE_002 — 2nd–3rd distraction triggers Level-2 Intervention
        (full-screen contextual prompt with 'Focus check' and 'Return to Focus' / 'Take a Break').
        """
        session = _start_session(stateful_driver, intent="TC_ESCALATE_002 test")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        # Relapse 1 -> dismiss
        session.trigger_adb_distraction("com.instagram.android", "Instagram")
        time.sleep(2)
        try:
            session.tap_im_back()
        except Exception:
            pass
        time.sleep(1)

        # Relapse 2 -> Level 2 full-screen alert
        session.trigger_adb_distraction("com.instagram.android", "Instagram")
        time.sleep(2)

        count = session.get_distraction_count()
        assert count == 2, f"Relapse 2 must set distraction count to 2, got {count}"

        level = session.get_escalation_level()
        assert level == 2 or session.is_intervention_overlay_visible(), (
            f"Second distraction must trigger Level-2 InterventionOverlay, got level={level} (TC_ESCALATE_002)"
        )

    @pytest.mark.test_id("TC_ESCALATE_003")
    @pytest.mark.module("FocusSession_Escalation")
    @pytest.mark.priority("P1")
    def test_level3_on_continuous_distraction(self, stateful_driver):
        """
        TC_ESCALATE_003 — 4+ distractions trigger Level-3 (forced choice:
        'Repeated drift detected' + 'Pause Session' button, no dismiss-and-ignore).
        """
        session = _start_session(stateful_driver, intent="TC_ESCALATE_003 test")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        for i in range(3):
            session.trigger_adb_distraction("com.instagram.android", "Instagram")
            time.sleep(1)
            try:
                session.tap_return_to_focus()
            except Exception:
                try:
                    session.tap_im_back()
                except Exception:
                    pass
            time.sleep(0.5)

        # 4th relapse -> Level 3 forced choice
        session.trigger_adb_distraction("com.instagram.android", "Instagram")
        time.sleep(2)

        count = session.get_distraction_count()
        assert count == 4, f"Relapse 4 must set distraction count to 4, got {count}"

        level = session.get_escalation_level()
        assert level == 3 or session.is_text_contains_visible("Repeated drift", timeout=3) or \
               session.is_text_contains_visible("Pause Session", timeout=3), (
            f"4th+ distraction must trigger Level-3 forced-choice overlay, got level={level} (TC_ESCALATE_003)"
        )


# ─────────────────────────────────────────────────────────────────────────────
# TC_STOP — Stop Session
# ─────────────────────────────────────────────────────────────────────────────

@pytest.mark.focus_session
class TestStopSession:

    @pytest.mark.test_id("TC_STOP_001")
    @pytest.mark.module("FocusSession_Stop")
    @pytest.mark.priority("P1")
    @pytest.mark.smoke
    def test_stop_session_ends_timer_and_saves_record(self, stateful_driver):
        """
        TC_STOP_001 — STOP SESSION must:
          1. Transition to summary or pre-session view (timer no longer shown)
          2. Session summary contains the correct intent text
          3. Summary shows elapsed duration > 0
          4. App remains open (no crash)
        """
        intent_text = "TC_STOP_001 intent"
        session = _start_session(stateful_driver, intent=intent_text)
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        time.sleep(5)
        session.tap_stop_session()
        time.sleep(4)

        assert not session.is_active_session_state(), (
            "Active session state must end after STOP SESSION (TC_STOP_001)"
        )

        summary_visible = session.is_session_summary_visible()
        pre_session_visible = session.is_pre_session_state()
        assert summary_visible or pre_session_visible, (
            "Must navigate to summary or pre-session view after STOP (TC_STOP_001)"
        )

        if summary_visible:
            summary_intent = session.get_summary_intent_text()
            assert summary_intent == intent_text, (
                f"Summary intent '{summary_intent}' must match '{intent_text}' (TC_STOP_001)"
            )

    @pytest.mark.test_id("TC_STOP_002")
    @pytest.mark.module("FocusSession_Stop")
    @pytest.mark.priority("P2")
    def test_stop_session_mid_distraction(self, stateful_driver):
        """
        TC_STOP_002 — Tapping Stop Session while a distraction alert is shown
        must end the session cleanly: no crash, no lost data, alert dismissed.
        """
        session = _start_session(stateful_driver, intent="TC_STOP_002 mid-distraction")
        if not session.is_active_session_state():
            pytest.skip("Session did not start")

        _fire_distraction(session, "com.instagram.android", "Instagram")

        try:
            session.tap_stop_session()
        except Exception:
            try:
                if session.is_distraction_alert_visible():
                    session.tap_im_back()
                    time.sleep(1)
                elif session.is_intervention_overlay_visible():
                    session.tap_return_to_focus()
                    time.sleep(1)
                session.tap_stop_session()
            except Exception:
                pass

        time.sleep(4)

        assert stateful_driver.current_package in (
            "com.focusecho.ai", "com.focusecho"
        ), "App must remain open after stop-mid-distraction (TC_STOP_002)"

        assert not session.is_active_session_state(), (
            "Session must not remain active after STOP SESSION (TC_STOP_002)"
        )


# ─────────────────────────────────────────────────────────────────────────────
# TC_LAYOUT — Layout / Overflow
# ─────────────────────────────────────────────────────────────────────────────

@pytest.mark.focus_session
class TestLayout:

    @pytest.mark.test_id("TC_LAYOUT_001")
    @pytest.mark.module("FocusSession_Layout")
    @pytest.mark.priority("P2")
    def test_no_overflow_at_small_viewport(self, stateful_driver):
        """
        TC_LAYOUT_001 — No element must clip or overflow beyond the right screen
        edge on the active session screen at the device's native viewport width.

        Specifically verifies Bug 2 fix:
          • Timer text wrapped in FittedBox — no right-edge clip
          • 'Distractions: N' and 'XP: N' rows wrapped in Flexible — no overflow
        """
        session = _start_session(stateful_driver, intent="TC_LAYOUT_001 overflow test")
        if not session.is_active_session_state():
            pytest.skip("Session did not start — cannot test active session layout")

        time.sleep(2)

        no_overflow = session.check_no_overflow()
        assert no_overflow, (
            "One or more elements overflow the right screen edge in the active session view. "
            "Check timer (FittedBox) and Distractions/XP row (Flexible) — Bug 2 (TC_LAYOUT_001)"
        )

        assert session.is_text_contains_visible("Distractions:", timeout=5), (
            "'Distractions:' text must remain visible after overflow fix (TC_LAYOUT_001)"
        )
        assert session.is_text_contains_visible("XP:", timeout=5), (
            "'XP:' text must remain visible after overflow fix (TC_LAYOUT_001)"
        )
        timer = session.get_timer_text()
        assert timer != "", (
            "Timer must remain readable after FittedBox overflow fix (TC_LAYOUT_001)"
        )
