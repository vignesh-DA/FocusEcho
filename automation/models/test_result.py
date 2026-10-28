"""
Data Model for FocusEcho Test Case Execution and Reporting
Captures every required metric: ID, Module, Priority, Preconditions, Steps,
Expected/Actual Results, Status, Timings, and Artifact references.
"""

from dataclasses import dataclass, field
from typing import List, Optional

@dataclass
class TestCaseResult:
    """Represents the complete lifecycle of a single executed Selenium test case."""
    test_id: str
    module: str
    test_name: str
    priority: str  # Critical, High, Medium, Low
    preconditions: str
    test_steps: List[str]
    expected_result: str
    actual_result: str = ""
    status: str = "Passed"  # Passed, Failed, Skipped, Blocked
    execution_time: float = 0.0
    error_message: Optional[str] = None
    stack_trace: Optional[str] = None
    screenshot_path: Optional[str] = None
    console_logs: List[dict] = field(default_factory=list)

    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "test_id": self.test_id,
            "module": self.module,
            "test_name": self.test_name,
            "priority": self.priority,
            "preconditions": self.preconditions,
            "test_steps": self.test_steps,
            "expected_result": self.expected_result,
            "actual_result": self.actual_result,
            "status": self.status,
            "execution_time": round(self.execution_time, 3),
            "error_message": self.error_message,
            "stack_trace": self.stack_trace,
            "screenshot_path": self.screenshot_path,
            "console_logs": self.console_logs
        }
