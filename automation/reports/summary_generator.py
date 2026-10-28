"""
GitHub Actions Step Summary Generator for FocusEcho
Generates summary.md formatted for $GITHUB_STEP_SUMMARY.
"""

from typing import List
from datetime import datetime
from automation.models.test_result import TestCaseResult
from automation.config.config import SUMMARY_DIR
from automation.utils.logger import logger

class SummaryGenerator:
    """Generates the markdown summary for GitHub Actions."""

    @classmethod
    def generate_summary(
        cls,
        results: List[TestCaseResult],
        base_url: str,
        build_status: str = "PASS",
        deploy_status: str = "PASS",
        execution_duration: float = 0.0
    ) -> str:
        total = len(results)
        passed = sum(1 for r in results if r.status == "Passed")
        failed = sum(1 for r in results if r.status == "Failed")
        skipped = sum(1 for r in results if r.status in ("Skipped", "Blocked"))
        pass_pct = (passed / total * 100) if total else 0
        now_str = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")

        # Module statistics
        modules = sorted(list(set(r.module for r in results)))
        mod_stats = []
        for mod in modules:
            m_tests = [r for r in results if r.module == mod]
            tot = len(m_tests)
            pas = sum(1 for r in m_tests if r.status == "Passed")
            rate = (pas / tot * 100) if tot else 0
            mod_stats.append((mod, tot, pas, tot - pas, rate))

        # Top Passing Modules (sorted descending by rate)
        top_passing = sorted(mod_stats, key=lambda x: x[4], reverse=True)[:5]
        top_passing_md = "\n".join(f"- **{m[0]}**: {m[4]:.1f}% ({m[2]}/{m[1]})" for m in top_passing)

        # Top Failed Modules (modules with failures)
        failed_mods = [m for m in mod_stats if m[3] > 0]
        failed_mods = sorted(failed_mods, key=lambda x: x[3], reverse=True)
        if failed_mods:
            top_failed_md = "\n".join(f"- **{m[0]}**: {m[3]} failures" for m in failed_mods)
        else:
            top_failed_md = "- None (All modules 100% passing)"

        # Failed tests list
        failed_tests = [r for r in results if r.status == "Failed"]
        if failed_tests:
            failed_tests_md = "\n".join(
                f"- `{r.test_id}`: **{r.test_name}** - *{r.error_message or 'Failure'}*"
                for r in failed_tests[:10]
            )
            if len(failed_tests) > 10:
                failed_tests_md += f"\n- ... and {len(failed_tests) - 10} more failures (see full report)."
        else:
            failed_tests_md = "- None"

        summary_md = f"""# Live GitHub Pages E2E Execution Summary

**Deployment URL:**
{base_url}

**Execution Date:**
{now_str}

**Build Status:**
{build_status}

**Deployment Status:**
{deploy_status}

**Total Test Cases:**
{total}

- **Executed:** {total}
- **Passed:** {passed}
- **Failed:** {failed}
- **Skipped:** {skipped}

**Pass Percentage:**
{pass_pct:.2f}%

**Execution Duration:**
{execution_duration:.2f} seconds

---

### Top Failed Modules:
{top_failed_md}

### Failed Tests:
{failed_tests_md}

### Top Passing Modules:
{top_passing_md}

---

### Artifacts Generated:
✓ Excel Reports (`Automation_Test_Report.xlsx`, `Passed_Test_Cases.xlsx`, `Failed_Test_Cases.xlsx`, `Summary_Report.xlsx`)
✓ HTML Reports (`execution-report.html`, `dashboard.html`)
✓ Screenshots (`Test Results/Screenshots/`)
✓ Logs (`Test Results/Logs/automation.log`)
✓ JSON Results (`execution-results.json`)
"""

        summary_file = SUMMARY_DIR / "summary.md"
        summary_file.write_text(summary_md, encoding="utf-8")
        logger.info(f"Summary markdown generated at {summary_file}")
        return summary_md
