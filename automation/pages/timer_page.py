"""
Focus Timer Page Object for FocusEcho
Manages focus countdown, play/pause/resume/stop state machine, presets, and goal setting.
"""

from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class TimerPage(BasePage):
    """Page object for Focus Timer interactions."""

    LOC_TIMER_CLOCK = (By.ID, "timer-clock")
    LOC_TIMER_SUBTEXT = (By.ID, "timer-subtext")
    LOC_TIMER_STATE_PILL = (By.ID, "timer-state-pill")

    LOC_TIMER_START_BTN = (By.ID, "timer-start-btn")
    LOC_TIMER_PAUSE_BTN = (By.ID, "timer-pause-btn")
    LOC_TIMER_RESUME_BTN = (By.ID, "timer-resume-btn")
    LOC_TIMER_STOP_BTN = (By.ID, "timer-stop-btn")
    LOC_TIMER_RESET_BTN = (By.ID, "timer-reset-btn")

    LOC_PRESET_25M = (By.ID, "preset-25m")
    LOC_PRESET_15M = (By.ID, "preset-15m")
    LOC_PRESET_50M = (By.ID, "preset-50m")
    LOC_PRESET_90M = (By.ID, "preset-90m")

    LOC_SESSION_GOAL_INPUT = (By.ID, "session-goal-input")
    LOC_SESSION_CATEGORY_SELECT = (By.ID, "session-category-select")
    LOC_SESSION_ESCALATION_SELECT = (By.ID, "session-escalation-select")
    LOC_SESSION_GOAL_ERROR = (By.ID, "session-goal-error")

    def set_goal(self, goal: str) -> None:
        """Set the focus session intention."""
        self.type_text(self.LOC_SESSION_GOAL_INPUT, goal)

    def select_preset(self, minutes: int) -> None:
        """Select a quick duration preset."""
        preset_map = {
            15: self.LOC_PRESET_15M,
            25: self.LOC_PRESET_25M,
            50: self.LOC_PRESET_50M,
            90: self.LOC_PRESET_90M
        }
        if minutes in preset_map:
            self.click(preset_map[minutes])

    def start_focus(self, goal: str = None) -> None:
        """Start the focus timer."""
        if goal:
            self.set_goal(goal)
        self.click(self.LOC_TIMER_START_BTN)

    def pause_focus(self) -> None:
        """Pause the active focus timer."""
        self.click(self.LOC_TIMER_PAUSE_BTN)

    def resume_focus(self) -> None:
        """Resume the paused timer."""
        self.click(self.LOC_TIMER_RESUME_BTN)

    def stop_focus(self) -> None:
        """Stop and reset the timer."""
        self.click(self.LOC_TIMER_STOP_BTN)

    def get_clock_display(self) -> str:
        """Get the current MM:SS timer clock display."""
        return self.find_element(self.LOC_TIMER_CLOCK).text

    def get_timer_state(self) -> str:
        """Get current timer state pill text (IDLE, RUNNING, PAUSED, COMPLETED)."""
        return self.find_element(self.LOC_TIMER_STATE_PILL).text

    def get_goal_error(self) -> str:
        """Get validation error for empty goal input."""
        return self.find_element(self.LOC_SESSION_GOAL_ERROR).text
