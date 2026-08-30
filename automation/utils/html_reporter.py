"""
HTML Report Generator for FocusEcho Appium E2E Framework
Generates: execution-report.html, dashboard.html, trends.html
Uses Jinja2 templates with embedded Chart.js for visualizations.
"""

import json
from datetime import datetime
from pathlib import Path
from typing import Any

from config.test_config import (
    HTML_DIR, SCREENSHOTS_DIR, BUILD_NUMBER, GIT_COMMIT,
    BRANCH, DEVICE_NAME, ANDROID_VERSION, APP_VERSION
)


# ─────────────────────────────────────────────────────────────────────────────
# Main execution report HTML template
# ─────────────────────────────────────────────────────────────────────────────
EXECUTION_REPORT_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>FocusEcho AI — E2E Automation Report</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Segoe UI', system-ui, sans-serif; background: #0f172a; color: #e2e8f0; }
  .header { background: linear-gradient(135deg, #1e3a5f, #0f172a); padding: 40px; text-align: center; border-bottom: 1px solid #1e293b; }
  .header h1 { font-size: 2.2rem; color: #60a5fa; letter-spacing: -0.5px; }
  .header .meta { color: #64748b; margin-top: 8px; font-size: 0.95rem; }
  .container { max-width: 1400px; margin: 0 auto; padding: 30px 20px; }
  .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 20px; margin-bottom: 30px; }
  .stat-card { background: #1e293b; border-radius: 16px; padding: 24px; text-align: center; border: 1px solid #334155; }
  .stat-card .value { font-size: 2.5rem; font-weight: 700; }
  .stat-card .label { color: #94a3b8; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 1px; margin-top: 4px; }
  .green { color: #4ade80; } .red { color: #f87171; } .yellow { color: #fbbf24; } .blue { color: #60a5fa; } .gray { color: #94a3b8; }
  .section { background: #1e293b; border-radius: 16px; padding: 24px; margin-bottom: 24px; border: 1px solid #334155; }
  .section h2 { font-size: 1.2rem; color: #e2e8f0; margin-bottom: 16px; padding-bottom: 12px; border-bottom: 1px solid #334155; }
  table { width: 100%; border-collapse: collapse; font-size: 0.88rem; }
  th { background: #0f172a; color: #60a5fa; text-align: left; padding: 12px 16px; font-weight: 600; font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.5px; }
  td { padding: 10px 16px; border-bottom: 1px solid #1e293b; color: #cbd5e1; vertical-align: top; }
  tr:hover td { background: #0f172a; }
  .badge { display: inline-block; padding: 3px 10px; border-radius: 20px; font-size: 0.75rem; font-weight: 600; }
  .badge-pass { background: #14532d; color: #4ade80; }
  .badge-fail { background: #7f1d1d; color: #f87171; }
  .badge-skip { background: #78350f; color: #fbbf24; }
  .badge-block { background: #1f2937; color: #9ca3af; }
  .priority-p1 { color: #f87171; font-weight: 600; }
  .priority-p2 { color: #fbbf24; }
  .priority-p3 { color: #94a3b8; }
  .error-cell { color: #f87171; font-size: 0.82rem; max-width: 300px; word-break: break-word; }
  .chart-container { height: 300px; margin-bottom: 20px; }
  .build-info { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; margin-bottom: 20px; }
  .info-item { background: #0f172a; border-radius: 10px; padding: 14px; }
  .info-item .key { color: #64748b; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 1px; }
  .info-item .val { color: #e2e8f0; font-size: 1rem; font-weight: 600; margin-top: 4px; }
  .pass-bar { background: #1e293b; height: 12px; border-radius: 6px; overflow: hidden; margin: 8px 0; }
  .pass-fill { height: 100%; background: linear-gradient(90deg, #16a34a, #4ade80); border-radius: 6px; transition: width 1s; }
  .tabs { display: flex; gap: 8px; margin-bottom: 20px; flex-wrap: wrap; }
  .tab-btn { background: #1e293b; border: 1px solid #334155; color: #94a3b8; padding: 8px 16px; border-radius: 8px; cursor: pointer; font-size: 0.85rem; transition: all 0.2s; }
  .tab-btn.active, .tab-btn:hover { background: #3b82f6; color: white; border-color: #3b82f6; }
  .tab-content { display: none; } .tab-content.active { display: block; }
  .screenshot-thumb { max-width: 80px; max-height: 50px; border-radius: 4px; cursor: pointer; opacity: 0.8; transition: opacity 0.2s; }
  .screenshot-thumb:hover { opacity: 1; }
  footer { text-align: center; color: #475569; font-size: 0.82rem; padding: 30px; border-top: 1px solid #1e293b; margin-top: 40px; }
</style>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
</head>
<body>
<div class="header">
  <h1>🎯 FocusEcho AI — E2E Automation Report</h1>
  <div class="meta">
    Build: <strong>{{ build_number }}</strong> &nbsp;|&nbsp;
    Branch: <strong>{{ branch }}</strong> &nbsp;|&nbsp;
    Commit: <code>{{ git_commit }}</code> &nbsp;|&nbsp;
    Generated: {{ generated_at }}
  </div>
  <div style="margin-top:12px;">
    <div class="pass-bar" style="max-width:400px;margin:auto;">
      <div class="pass-fill" style="width:{{ pass_rate }}%;"></div>
    </div>
    <div style="color:#94a3b8;margin-top:6px;font-size:0.9rem;">Pass Rate: <strong style="color:#4ade80;">{{ pass_rate }}%</strong></div>
  </div>
</div>

<div class="container">

  <!-- Stats Grid -->
  <div class="stats-grid">
    <div class="stat-card"><div class="value blue">{{ total }}</div><div class="label">Total Tests</div></div>
    <div class="stat-card"><div class="value green">{{ passed_count }}</div><div class="label">Passed</div></div>
    <div class="stat-card"><div class="value red">{{ failed_count }}</div><div class="label">Failed</div></div>
    <div class="stat-card"><div class="value yellow">{{ skipped_count }}</div><div class="label">Skipped</div></div>
    <div class="stat-card"><div class="value gray">{{ blocked_count }}</div><div class="label">Blocked</div></div>
    <div class="stat-card"><div class="value blue">{{ duration }}s</div><div class="label">Duration</div></div>
  </div>

  <!-- Build Info -->
  <div class="section">
    <h2>📱 Build & Device Information</h2>
    <div class="build-info">
      <div class="info-item"><div class="key">App Name</div><div class="val">FocusEcho AI</div></div>
      <div class="info-item"><div class="key">App Version</div><div class="val">{{ app_version }}</div></div>
      <div class="info-item"><div class="key">Device</div><div class="val">{{ device_name }}</div></div>
      <div class="info-item"><div class="key">Android</div><div class="val">{{ android_version }}</div></div>
      <div class="info-item"><div class="key">Build #</div><div class="val">{{ build_number }}</div></div>
      <div class="info-item"><div class="key">Branch</div><div class="val">{{ branch }}</div></div>
    </div>
  </div>

  <!-- Charts -->
  <div class="section">
    <h2>📊 Test Results Visualization</h2>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:24px;">
      <div><canvas id="statusChart"></canvas></div>
      <div><canvas id="moduleChart"></canvas></div>
    </div>
  </div>

  <!-- Test Results Table with Tabs -->
  <div class="section">
    <h2>🧪 Test Results</h2>
    <div class="tabs">
      <button class="tab-btn active" onclick="showTab('all')">All ({{ total }})</button>
      <button class="tab-btn" onclick="showTab('passed')">✅ Passed ({{ passed_count }})</button>
      <button class="tab-btn" onclick="showTab('failed')">❌ Failed ({{ failed_count }})</button>
      <button class="tab-btn" onclick="showTab('skipped')">⏭ Skipped ({{ skipped_count }})</button>
    </div>

    <div id="tab-all" class="tab-content active">
      <table>
        <thead><tr>
          <th>Test ID</th><th>Module</th><th>Test Name</th><th>Priority</th>
          <th>Status</th><th>Duration</th><th>Error</th><th>Screenshot</th>
        </tr></thead>
        <tbody>
          {% for r in all_results %}
          <tr>
            <td style="font-family:monospace;color:#93c5fd;">{{ r.test_id }}</td>
            <td>{{ r.module }}</td>
            <td>{{ r.name }}</td>
            <td class="priority-{{ r.priority.lower() }}">{{ r.priority }}</td>
            <td><span class="badge badge-{{ r.status.lower() }}">{{ r.status }}</span></td>
            <td>{{ "%.2f"|format(r.duration) }}s</td>
            <td class="error-cell">{{ r.error_message or '' }}</td>
            <td>{% if r.screenshot_path %}<img src="{{ r.screenshot_path }}" class="screenshot-thumb" onclick="window.open(this.src)" alt="screenshot">{% endif %}</td>
          </tr>
          {% endfor %}
        </tbody>
      </table>
    </div>

    <div id="tab-passed" class="tab-content">
      <table>
        <thead><tr><th>Test ID</th><th>Module</th><th>Test Name</th><th>Priority</th><th>Duration</th></tr></thead>
        <tbody>
          {% for r in passed_results %}
          <tr>
            <td style="font-family:monospace;color:#93c5fd;">{{ r.test_id }}</td>
            <td>{{ r.module }}</td><td>{{ r.name }}</td>
            <td class="priority-{{ r.priority.lower() }}">{{ r.priority }}</td>
            <td>{{ "%.2f"|format(r.duration) }}s</td>
          </tr>
          {% endfor %}
        </tbody>
      </table>
    </div>

    <div id="tab-failed" class="tab-content">
      <table>
        <thead><tr><th>Test ID</th><th>Module</th><th>Test Name</th><th>Priority</th><th>Error</th></tr></thead>
        <tbody>
          {% for r in failed_results %}
          <tr>
            <td style="font-family:monospace;color:#93c5fd;">{{ r.test_id }}</td>
            <td>{{ r.module }}</td><td>{{ r.name }}</td>
            <td class="priority-{{ r.priority.lower() }}">{{ r.priority }}</td>
            <td class="error-cell">{{ r.error_message or '' }}</td>
          </tr>
          {% endfor %}
        </tbody>
      </table>
    </div>

    <div id="tab-skipped" class="tab-content">
      <table>
        <thead><tr><th>Test ID</th><th>Module</th><th>Test Name</th><th>Priority</th></tr></thead>
        <tbody>
          {% for r in skipped_results %}
          <tr>
            <td style="font-family:monospace;color:#93c5fd;">{{ r.test_id }}</td>
            <td>{{ r.module }}</td><td>{{ r.name }}</td>
            <td class="priority-{{ r.priority.lower() }}">{{ r.priority }}</td>
          </tr>
          {% endfor %}
        </tbody>
      </table>
    </div>
  </div>

</div>

<footer>
  FocusEcho AI Automation Framework &nbsp;|&nbsp; Report generated {{ generated_at }} &nbsp;|&nbsp;
  Build {{ build_number }} &nbsp;|&nbsp; 🤖 Powered by Appium + pytest
</footer>

<script>
function showTab(name) {
  document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  document.getElementById('tab-' + name).classList.add('active');
  event.target.classList.add('active');
}

const statusCtx = document.getElementById('statusChart').getContext('2d');
new Chart(statusCtx, {
  type: 'doughnut',
  data: {
    labels: ['Passed', 'Failed', 'Skipped', 'Blocked'],
    datasets: [{ data: [{{ passed_count }}, {{ failed_count }}, {{ skipped_count }}, {{ blocked_count }}],
      backgroundColor: ['#16a34a', '#dc2626', '#d97706', '#6b7280'],
      borderColor: '#1e293b', borderWidth: 3 }]
  },
  options: { plugins: { legend: { labels: { color: '#e2e8f0' } } }, responsive: true }
});

const moduleCtx = document.getElementById('moduleChart').getContext('2d');
new Chart(moduleCtx, {
  type: 'bar',
  data: {
    labels: {{ module_labels | tojson }},
    datasets: [
      { label: 'Passed', data: {{ module_passed | tojson }}, backgroundColor: '#16a34a' },
      { label: 'Failed', data: {{ module_failed | tojson }}, backgroundColor: '#dc2626' }
    ]
  },
  options: {
    indexAxis: 'y', plugins: { legend: { labels: { color: '#e2e8f0' } } },
    scales: { x: { ticks: { color: '#94a3b8' } }, y: { ticks: { color: '#94a3b8' } } },
    responsive: true
  }
});
</script>
</body>
</html>"""


class HtmlReporter:
    """Generates HTML execution reports."""

    def __init__(self, results: list[dict[str, Any]]):
        self.results = results
        self.generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.passed = [r for r in results if r["status"].upper() in ("PASS", "PASSED")]
        self.failed = [r for r in results if r["status"].upper() in ("FAIL", "FAILED")]
        self.skipped = [r for r in results if r["status"].upper() in ("SKIP", "SKIPPED")]
        self.blocked = [r for r in results if r["status"].upper() == "BLOCKED"]
        self.total = len(results)
        self.pass_rate = round((len(self.passed) / self.total * 100) if self.total else 0, 1)
        self.total_duration = round(sum(r.get("duration", 0) for r in results), 2)

    def generate(self) -> dict[str, Path]:
        """Generate all HTML reports. Returns dict of report paths."""
        paths = {}
        paths["execution"] = self._generate_execution_report()
        paths["dashboard"] = self._generate_dashboard()
        paths["trends"] = self._generate_trends()
        return paths

    def _generate_execution_report(self) -> Path:
        # Compute module-level data for charts
        modules: dict[str, dict] = {}
        for r in self.results:
            mod = r.get("module", "Unknown")
            if mod not in modules:
                modules[mod] = {"passed": 0, "failed": 0}
            status = r.get("status", "").upper()
            if status in ("PASS", "PASSED"):
                modules[mod]["passed"] += 1
            elif status in ("FAIL", "FAILED"):
                modules[mod]["failed"] += 1

        # Simple template rendering (no Jinja2 dependency for portability)
        html = EXECUTION_REPORT_TEMPLATE
        html = self._render(html, {
            "build_number": BUILD_NUMBER,
            "branch": BRANCH,
            "git_commit": GIT_COMMIT,
            "generated_at": self.generated_at,
            "pass_rate": self.pass_rate,
            "total": self.total,
            "passed_count": len(self.passed),
            "failed_count": len(self.failed),
            "skipped_count": len(self.skipped),
            "blocked_count": len(self.blocked),
            "duration": self.total_duration,
            "app_version": APP_VERSION,
            "device_name": DEVICE_NAME,
            "android_version": ANDROID_VERSION,
            "module_labels": json.dumps(list(modules.keys())),
            "module_passed": json.dumps([v["passed"] for v in modules.values()]),
            "module_failed": json.dumps([v["failed"] for v in modules.values()]),
        })

        # Render result rows
        all_rows = self._render_result_rows(self.results)
        passed_rows = self._render_passed_rows(self.passed)
        failed_rows = self._render_failed_rows(self.failed)
        skipped_rows = self._render_skipped_rows(self.skipped)

        html = html.replace("{% for r in all_results %}{% endfor %}", all_rows)
        html = html.replace("{% for r in passed_results %}{% endfor %}", passed_rows)
        html = html.replace("{% for r in failed_results %}{% endfor %}", failed_rows)
        html = html.replace("{% for r in skipped_results %}{% endfor %}", skipped_rows)

        # Use Jinja2 if available
        try:
            from jinja2 import Environment
            env = Environment()
            template = env.from_string(EXECUTION_REPORT_TEMPLATE)
            html = template.render(
                build_number=BUILD_NUMBER, branch=BRANCH, git_commit=GIT_COMMIT,
                generated_at=self.generated_at, pass_rate=self.pass_rate,
                total=self.total, passed_count=len(self.passed),
                failed_count=len(self.failed), skipped_count=len(self.skipped),
                blocked_count=len(self.blocked), duration=self.total_duration,
                app_version=APP_VERSION, device_name=DEVICE_NAME,
                android_version=ANDROID_VERSION,
                module_labels=list(modules.keys()),
                module_passed=[v["passed"] for v in modules.values()],
                module_failed=[v["failed"] for v in modules.values()],
                all_results=self.results, passed_results=self.passed,
                failed_results=self.failed, skipped_results=self.skipped,
            )
        except Exception:
            pass  # Fall back to pre-rendered string

        out = HTML_DIR / "execution-report.html"
        out.write_text(html, encoding="utf-8")
        print(f"✅ HTML report saved: {out}")
        return out

    def _generate_dashboard(self) -> Path:
        html = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8">
<title>FocusEcho — Dashboard</title>
<style>
body{{font-family:'Segoe UI',sans-serif;background:#0f172a;color:#e2e8f0;margin:0;padding:40px;}}
h1{{color:#60a5fa;margin-bottom:20px;}}
.grid{{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;max-width:800px;}}
.card{{background:#1e293b;border-radius:12px;padding:24px;text-align:center;border:1px solid #334155;}}
.value{{font-size:2.4rem;font-weight:700;}}
.label{{color:#64748b;font-size:0.8rem;text-transform:uppercase;letter-spacing:1px;margin-top:4px;}}
.green{{color:#4ade80;}}.red{{color:#f87171;}}.blue{{color:#60a5fa;}}.yellow{{color:#fbbf24;}}
</style></head><body>
<h1>🎯 FocusEcho AI — Test Dashboard</h1>
<p style="color:#64748b;margin-bottom:24px;">Build {BUILD_NUMBER} | Generated {self.generated_at}</p>
<div class="grid">
  <div class="card"><div class="value blue">{self.total}</div><div class="label">Total</div></div>
  <div class="card"><div class="value green">{len(self.passed)}</div><div class="label">Passed</div></div>
  <div class="card"><div class="value red">{len(self.failed)}</div><div class="label">Failed</div></div>
  <div class="card"><div class="value yellow">{len(self.skipped)}</div><div class="label">Skipped</div></div>
  <div class="card"><div class="value blue">{self.pass_rate}%</div><div class="label">Pass Rate</div></div>
  <div class="card"><div class="value blue">{self.total_duration}s</div><div class="label">Duration</div></div>
</div>
<p style="margin-top:30px;"><a href="execution-report.html" style="color:#60a5fa;">→ Full Execution Report</a></p>
</body></html>"""
        out = HTML_DIR / "dashboard.html"
        out.write_text(html, encoding="utf-8")
        return out

    def _generate_trends(self) -> Path:
        html = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8">
<title>FocusEcho — Test Trends</title>
<style>body{{font-family:'Segoe UI',sans-serif;background:#0f172a;color:#e2e8f0;margin:0;padding:40px;}}</style>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
</head><body>
<h1 style="color:#60a5fa;">📈 Historical Test Trends</h1>
<p style="color:#64748b;">Trends are accumulated across builds. Current build: {BUILD_NUMBER}</p>
<canvas id="trend" style="max-width:800px;"></canvas>
<script>
new Chart(document.getElementById('trend'), {{
  type: 'line',
  data: {{
    labels: ['Build {BUILD_NUMBER}'],
    datasets: [
      {{label:'Passed', data:[{len(self.passed)}], borderColor:'#16a34a', fill:false}},
      {{label:'Failed', data:[{len(self.failed)}], borderColor:'#dc2626', fill:false}}
    ]
  }},
  options:{{plugins:{{legend:{{labels:{{color:'#e2e8f0'}}}}}}, scales:{{x:{{ticks:{{color:'#94a3b8'}}}},y:{{ticks:{{color:'#94a3b8'}}}}}}}}
}});
</script>
</body></html>"""
        out = HTML_DIR / "trends.html"
        out.write_text(html, encoding="utf-8")
        return out

    def _render(self, template: str, ctx: dict) -> str:
        for k, v in ctx.items():
            template = template.replace(f"{{{{ {k} }}}}", str(v))
        return template

    def _render_result_rows(self, results: list) -> str:
        rows = ""
        for r in results:
            status = r.get("status", "")
            badge_class = f"badge-{status.lower()}"
            screenshot = r.get("screenshot_path", "")
            img = f'<img src="{screenshot}" class="screenshot-thumb" onclick="window.open(this.src)" alt="ss">' if screenshot else ""
            rows += (
                f"<tr>"
                f"<td style='font-family:monospace;color:#93c5fd;'>{r.get('test_id','')}</td>"
                f"<td>{r.get('module','')}</td>"
                f"<td>{r.get('name','')}</td>"
                f"<td class='priority-{r.get('priority','').lower()}'>{r.get('priority','')}</td>"
                f"<td><span class='badge {badge_class}'>{status}</span></td>"
                f"<td>{r.get('duration',0):.2f}s</td>"
                f"<td class='error-cell'>{r.get('error_message','')}</td>"
                f"<td>{img}</td>"
                f"</tr>"
            )
        return rows

    def _render_passed_rows(self, results: list) -> str:
        rows = ""
        for r in results:
            rows += (
                f"<tr>"
                f"<td style='font-family:monospace;color:#93c5fd;'>{r.get('test_id','')}</td>"
                f"<td>{r.get('module','')}</td>"
                f"<td>{r.get('name','')}</td>"
                f"<td class='priority-{r.get('priority','').lower()}'>{r.get('priority','')}</td>"
                f"<td>{r.get('duration',0):.2f}s</td>"
                f"</tr>"
            )
        return rows

    def _render_failed_rows(self, results: list) -> str:
        rows = ""
        for r in results:
            rows += (
                f"<tr>"
                f"<td style='font-family:monospace;color:#93c5fd;'>{r.get('test_id','')}</td>"
                f"<td>{r.get('module','')}</td>"
                f"<td>{r.get('name','')}</td>"
                f"<td class='priority-{r.get('priority','').lower()}'>{r.get('priority','')}</td>"
                f"<td class='error-cell'>{r.get('error_message','')}</td>"
                f"</tr>"
            )
        return rows

    def _render_skipped_rows(self, results: list) -> str:
        rows = ""
        for r in results:
            rows += (
                f"<tr>"
                f"<td style='font-family:monospace;color:#93c5fd;'>{r.get('test_id','')}</td>"
                f"<td>{r.get('module','')}</td>"
                f"<td>{r.get('name','')}</td>"
                f"<td class='priority-{r.get('priority','').lower()}'>{r.get('priority','')}</td>"
                f"</tr>"
            )
        return rows
