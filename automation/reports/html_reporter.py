"""
HTML Report Generator for FocusEcho E2E Selenium Framework
Generates high-fidelity glassmorphic HTML reports:
1. execution-report.html (Detailed test-level breakdown with search, filters, modals)
2. dashboard.html (Executive dashboard with KPI tiles, charts, and metrics)
"""

from typing import List
from datetime import datetime
from automation.models.test_result import TestCaseResult
from automation.config.config import HTML_DIR
from automation.utils.logger import logger

class HTMLReporter:
    """Creates modern standalone HTML test reports."""

    @classmethod
    def generate_all(cls, results: List[TestCaseResult], base_url: str) -> None:
        cls.generate_execution_report(results, base_url)
        cls.generate_dashboard(results, base_url)
        logger.info(f"Generated HTML reports in {HTML_DIR}")

    @classmethod
    def generate_execution_report(cls, results: List[TestCaseResult], base_url: str) -> None:
        total = len(results)
        passed = sum(1 for r in results if r.status == "Passed")
        failed = sum(1 for r in results if r.status == "Failed")
        skipped = sum(1 for r in results if r.status in ("Skipped", "Blocked"))
        pass_pct = (passed / total * 100) if total else 0
        total_time = sum(r.execution_time for r in results)
        now_str = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")

        rows_html = []
        for r in results:
            status_class = r.status.lower()
            err_details = ""
            if r.status == "Failed":
                err_details = f"<div class='err-box'><strong>Error:</strong> {r.error_message or ''}<pre>{r.stack_trace or ''}</pre></div>"

            steps_html = "<ol>" + "".join(f"<li>{s}</li>" for s in r.test_steps) + "</ol>"
            
            rows_html.append(f"""
            <tr class="test-row status-{status_class}" data-status="{r.status}" data-module="{r.module}" data-priority="{r.priority}">
                <td><code>{r.test_id}</code></td>
                <td><span class="badge badge-module">{r.module}</span></td>
                <td>
                    <strong>{r.test_name}</strong>
                    <div class="steps-details">{steps_html}</div>
                    {err_details}
                </td>
                <td><span class="badge badge-priority-{r.priority.lower()}">{r.priority}</span></td>
                <td><span class="pill pill-{status_class}">{r.status}</span></td>
                <td>{r.execution_time:.3f}s</td>
            </tr>
            """)

        html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>FocusEcho E2E Execution Report</title>
    <style>
        :root {{
            --bg-primary: #0a0b10;
            --surface-glass: rgba(22, 26, 43, 0.75);
            --border-glass: rgba(255, 255, 255, 0.08);
            --accent-cyan: #00f2fe;
            --accent-purple: #9d4edd;
            --color-success: #10b981;
            --color-danger: #ef4444;
            --color-warning: #f59e0b;
            --text-primary: #f8fafc;
            --text-muted: #94a3b8;
        }}
        * {{ margin:0; padding:0; box-sizing:border-box; }}
        body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg-primary); color: var(--text-primary); padding: 24px; }}
        .header {{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; border-bottom: 1px solid var(--border-glass); padding-bottom: 16px; }}
        .title-wrap h1 {{ font-size: 1.6rem; background: linear-gradient(135deg, #00f2fe, #9d4edd); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }}
        .title-wrap p {{ color: var(--text-muted); font-size: 0.88rem; }}
        .kpi-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 16px; margin-bottom: 24px; }}
        .kpi-card {{ background: var(--surface-glass); border: 1px solid var(--border-glass); border-radius: 12px; padding: 16px; text-align: center; }}
        .kpi-val {{ font-size: 1.8rem; font-weight: 800; }}
        .kpi-label {{ font-size: 0.78rem; color: var(--text-muted); text-transform: uppercase; }}
        .controls {{ display: flex; gap: 12px; margin-bottom: 18px; }}
        .search-box {{ flex: 1; padding: 10px 14px; background: rgba(15,23,42,0.8); border: 1px solid var(--border-glass); border-radius: 8px; color: #fff; }}
        .table-wrap {{ background: var(--surface-glass); border: 1px solid var(--border-glass); border-radius: 12px; overflow-x: auto; }}
        table {{ width: 100%; border-collapse: collapse; font-size: 0.88rem; }}
        th, td {{ padding: 12px 14px; text-align: left; border-bottom: 1px solid var(--border-glass); vertical-align: top; }}
        th {{ background: rgba(0,0,0,0.3); color: var(--text-muted); font-weight: 600; }}
        .pill {{ padding: 3px 8px; border-radius: 9999px; font-size: 0.75rem; font-weight: 700; }}
        .pill-passed {{ background: rgba(16,185,129,0.2); color: var(--color-success); border: 1px solid var(--color-success); }}
        .pill-failed {{ background: rgba(239,68,68,0.2); color: var(--color-danger); border: 1px solid var(--color-danger); }}
        .pill-skipped {{ background: rgba(245,158,11,0.2); color: var(--color-warning); border: 1px solid var(--color-warning); }}
        .badge {{ padding: 2px 6px; border-radius: 6px; font-size: 0.7rem; }}
        .badge-module {{ background: rgba(255,255,255,0.08); color: var(--accent-cyan); }}
        .badge-priority-critical {{ background: rgba(239,68,68,0.2); color: #fca5a5; }}
        .badge-priority-high {{ background: rgba(245,158,11,0.2); color: #fde047; }}
        .badge-priority-medium {{ background: rgba(59,130,246,0.2); color: #93c5fd; }}
        .badge-priority-low {{ background: rgba(100,116,139,0.2); color: #cbd5e1; }}
        .steps-details {{ font-size: 0.78rem; color: var(--text-muted); margin-top: 4px; }}
        .steps-details ol {{ margin-left: 18px; }}
        .err-box {{ background: rgba(239,68,68,0.1); border: 1px solid rgba(239,68,68,0.3); border-radius: 6px; padding: 8px; margin-top: 6px; font-size: 0.8rem; color: #fca5a5; }}
        pre {{ white-space: pre-wrap; font-family: monospace; font-size: 0.75rem; margin-top: 4px; max-height: 120px; overflow-y: auto; }}
    </style>
</head>
<body>
    <div class="header">
        <div class="title-wrap">
            <h1>⚡ FocusEcho Live E2E Execution Report</h1>
            <p>Target: <code>{base_url}</code> | Executed: {now_str}</p>
        </div>
    </div>

    <div class="kpi-grid">
        <div class="kpi-card"><div class="kpi-val">{total}</div><div class="kpi-label">Total Test Cases</div></div>
        <div class="kpi-card"><div class="kpi-val" style="color:var(--color-success)">{passed}</div><div class="kpi-label">Passed</div></div>
        <div class="kpi-card"><div class="kpi-val" style="color:var(--color-danger)">{failed}</div><div class="kpi-label">Failed</div></div>
        <div class="kpi-card"><div class="kpi-val" style="color:var(--color-warning)">{skipped}</div><div class="kpi-label">Skipped</div></div>
        <div class="kpi-card"><div class="kpi-val" style="color:var(--accent-cyan)">{pass_pct:.1f}%</div><div class="kpi-label">Pass Rate</div></div>
        <div class="kpi-card"><div class="kpi-val">{total_time:.2f}s</div><div class="kpi-label">Total Duration</div></div>
    </div>

    <div class="controls">
        <input type="text" id="filter-input" class="search-box" placeholder="Search by Test ID, Module, Name, or Error...">
    </div>

    <div class="table-wrap">
        <table id="test-table">
            <thead>
                <tr>
                    <th>Test ID</th>
                    <th>Module</th>
                    <th>Test Name & Steps</th>
                    <th>Priority</th>
                    <th>Status</th>
                    <th>Duration</th>
                </tr>
            </thead>
            <tbody>
                {''.join(rows_html)}
            </tbody>
        </table>
    </div>

    <script>
        document.getElementById('filter-input').addEventListener('input', function(e) {{
            const q = e.target.value.toLowerCase();
            document.querySelectorAll('#test-table tbody tr').forEach(row => {{
                row.style.display = row.textContent.toLowerCase().includes(q) ? '' : 'none';
            }});
        }});
    </script>
</body>
</html>"""
        (HTML_DIR / "execution-report.html").write_text(html_content, encoding="utf-8")

    @classmethod
    def generate_dashboard(cls, results: List[TestCaseResult], base_url: str) -> None:
        total = len(results)
        passed = sum(1 for r in results if r.status == "Passed")
        failed = sum(1 for r in results if r.status == "Failed")
        pass_pct = (passed / total * 100) if total else 0

        modules = sorted(list(set(r.module for r in results)))
        mod_bars = []
        for mod in modules:
            mod_tests = [r for r in results if r.module == mod]
            tot = len(mod_tests)
            pas = sum(1 for r in mod_tests if r.status == "Passed")
            rate = (pas / tot * 100) if tot else 0
            mod_bars.append(f"""
            <div style="margin-bottom: 12px;">
                <div style="display:flex; justify-content:space-between; font-size:0.85rem; margin-bottom:4px;">
                    <span>{mod} ({pas}/{tot})</span>
                    <span style="font-weight:700; color:{'#10b981' if rate >= 95 else '#ef4444'}">{rate:.1f}%</span>
                </div>
                <div style="background:rgba(255,255,255,0.08); height:8px; border-radius:4px; overflow:hidden;">
                    <div style="width:{rate}%; height:100%; background:linear-gradient(90deg, #00f2fe, #9d4edd);"></div>
                </div>
            </div>
            """)

        html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>FocusEcho Quality Intelligence Dashboard</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; background:#0a0b10; color:#f8fafc; padding:32px; }}
        .grid {{ display:grid; grid-template-columns: 1fr 1fr; gap:24px; margin-top:24px; }}
        .card {{ background:rgba(22,26,43,0.75); border:1px solid rgba(255,255,255,0.08); border-radius:14px; padding:24px; }}
        h1 {{ font-size:1.8rem; background:linear-gradient(135deg, #00f2fe, #9d4edd); -webkit-background-clip:text; -webkit-text-fill-color:transparent; }}
        .rate-circle {{ font-size:3.5rem; font-weight:800; color:#10b981; text-align:center; padding:20px 0; }}
    </style>
</head>
<body>
    <h1>📊 FocusEcho E2E Quality Dashboard</h1>
    <p style="color:#94a3b8;">Deployment: <code>{base_url}</code> | Target Pass Threshold: 95.0%</p>

    <div class="grid">
        <div class="card">
            <h3>Overall Pass Health</h3>
            <div class="rate-circle">{pass_pct:.1f}%</div>
            <p style="text-align:center; color:#94a3b8;">{passed} Passed out of {total} Total Tests ({failed} Failures)</p>
        </div>
        <div class="card">
            <h3>Module Pass Breakdown</h3>
            {''.join(mod_bars)}
        </div>
    </div>
</body>
</html>"""
        (HTML_DIR / "dashboard.html").write_text(html_content, encoding="utf-8")
