"""
JSON Report Generator for FocusEcho Appium E2E Framework
"""

import json
from datetime import datetime
from pathlib import Path
from typing import Any

from config.test_config import (
    JSON_DIR, BUILD_NUMBER, GIT_COMMIT, BRANCH,
    DEVICE_NAME, ANDROID_VERSION, APP_VERSION
)


class JsonReporter:
    """Generates execution-results.json with full test metadata."""

    def __init__(self, results: list[dict[str, Any]]):
        self.results = results
        self.generated_at = datetime.now().isoformat()
        self.passed = [r for r in results if r["status"].upper() in ("PASS", "PASSED")]
        self.failed = [r for r in results if r["status"].upper() in ("FAIL", "FAILED")]
        self.skipped = [r for r in results if r["status"].upper() in ("SKIP", "SKIPPED")]
        self.blocked = [r for r in results if r["status"].upper() == "BLOCKED"]
        self.total = len(results)
        self.pass_rate = round((len(self.passed) / self.total * 100) if self.total else 0, 2)

    def generate(self) -> Path:
        data = {
            "meta": {
                "generated_at": self.generated_at,
                "build_number": BUILD_NUMBER,
                "git_commit": GIT_COMMIT,
                "branch": BRANCH,
                "app": {
                    "name": "FocusEcho AI",
                    "package": "com.focusecho.ai",
                    "version": APP_VERSION,
                },
                "device": {
                    "name": DEVICE_NAME,
                    "android_version": ANDROID_VERSION,
                },
            },
            "summary": {
                "total": self.total,
                "passed": len(self.passed),
                "failed": len(self.failed),
                "skipped": len(self.skipped),
                "blocked": len(self.blocked),
                "pass_rate_percent": self.pass_rate,
                "fail_rate_percent": round(100 - self.pass_rate, 2),
                "total_duration_seconds": round(
                    sum(r.get("duration", 0) for r in self.results), 2
                ),
            },
            "results": self.results,
            "failed_tests": self.failed,
        }

        out = JSON_DIR / "execution-results.json"
        out.write_text(json.dumps(data, indent=2, default=str), encoding="utf-8")
        print(f"✅ JSON report saved: {out}")
        return out


class SummaryReporter:
    """Generates summary.md for GitHub Actions step summary."""

    def __init__(self, results: list[dict[str, Any]]):
        self.results = results
        self.passed = [r for r in results if r["status"].upper() in ("PASS", "PASSED")]
        self.failed = [r for r in results if r["status"].upper() in ("FAIL", "FAILED")]
        self.skipped = [r for r in results if r["status"].upper() in ("SKIP", "SKIPPED")]
        self.blocked = [r for r in results if r["status"].upper() == "BLOCKED"]
        self.total = len(results)
        self.pass_rate = round((len(self.passed) / self.total * 100) if self.total else 0, 1)
        self.total_duration = round(sum(r.get("duration", 0) for r in results), 2)

    def generate(self) -> Path:
        from config.test_config import SUMMARY_DIR
        lines = [
            "# 🎯 FocusEcho AI — Android Appium E2E Execution Summary\n",
            f"| Property | Value |",
            f"|---|---|",
            f"| **Build Number** | `{BUILD_NUMBER}` |",
            f"| **Execution Date** | `{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}` |",
            f"| **Git Commit** | `{GIT_COMMIT}` |",
            f"| **Branch** | `{BRANCH}` |",
            f"| **Device** | `{DEVICE_NAME}` |",
            f"| **Android Version** | `{ANDROID_VERSION}` |",
            f"| **App Version** | `{APP_VERSION}` |",
            "",
            "## 📊 Execution Metrics",
            "",
            f"| Metric | Count |",
            f"|---|---|",
            f"| **Total Test Cases** | {self.total} |",
            f"| ✅ **Passed** | {len(self.passed)} |",
            f"| ❌ **Failed** | {len(self.failed)} |",
            f"| ⏭ **Skipped** | {len(self.skipped)} |",
            f"| 🚫 **Blocked** | {len(self.blocked)} |",
            f"| **Pass Rate** | `{self.pass_rate}%` |",
            f"| **Fail Rate** | `{round(100 - self.pass_rate, 1)}%` |",
            f"| **Execution Duration** | `{self.total_duration}s` |",
            "",
        ]

        if self.passed:
            lines.append("## ✅ PASSED TESTS (sample — top 20)")
            lines.append("")
            for r in self.passed[:20]:
                lines.append(f"- ✓ `{r.get('test_id','?')}` — {r.get('name','')}")
            if len(self.passed) > 20:
                lines.append(f"  ...and {len(self.passed) - 20} more passed tests")
            lines.append("")

        if self.failed:
            lines.append("## ❌ FAILED TESTS")
            lines.append("")
            for r in self.failed:
                lines.append(f"- ✗ `{r.get('test_id','?')}` — {r.get('name','')}")
                if r.get("error_message"):
                    lines.append(f"  > Reason: {r['error_message']}")
            lines.append("")

        if self.skipped:
            lines.append("## ⏭ SKIPPED TESTS")
            lines.append("")
            for r in self.skipped:
                lines.append(f"- `{r.get('test_id','?')}` — {r.get('name','')}")
            lines.append("")

        # Overall status line
        status = "✅ PIPELINE PASSED" if self.pass_rate >= 95 else "❌ PIPELINE FAILED"
        lines.append(f"\n---\n\n## {status}")
        lines.append(f"\nPass rate `{self.pass_rate}%` {'≥' if self.pass_rate >= 95 else '<'} required threshold `95%`")

        content = "\n".join(lines)
        out = SUMMARY_DIR / "summary.md"
        out.write_text(content, encoding="utf-8")
        print(f"✅ Summary saved: {out}")
        return out

    def write_github_step_summary(self) -> None:
        """Write to GITHUB_STEP_SUMMARY env file if running in CI."""
        import os
        summary_file = os.getenv("GITHUB_STEP_SUMMARY")
        if summary_file:
            out = self.generate()
            with open(summary_file, "a", encoding="utf-8") as f:
                f.write(out.read_text(encoding="utf-8"))
