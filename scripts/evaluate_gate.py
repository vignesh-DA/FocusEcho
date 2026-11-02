import os
from pathlib import Path

checks = {
    "Backend": os.environ.get("BACKEND_RESULT", "failure"),
    "Flutter analyze": os.environ.get("FLUTTER_ANALYZE_RESULT", "failure"),
    "Flutter tests": os.environ.get("FLUTTER_TEST_RESULT", "failure"),
    "Extension": os.environ.get("EXTENSION_RESULT", "failure"),
}
passed = sum(result == "success" for result in checks.values())
total = len(checks)
threshold = float(os.environ.get("PASS_THRESHOLD_PERCENT", "100"))
pass_rate = passed * 100 / total
gate = pass_rate >= threshold
lines = ["## CI check results", "", "| Check | Result |", "|---|---|"]
lines += [f"| {name} | {result} |" for name, result in checks.items()]
status_str = "PASS" if gate else "FAIL"
lines += [
    "",
    f"Pass rate: **{passed}/{total} ({pass_rate:.0f}%)** — threshold: **{threshold:g}%** — **{status_str}**",
]
summary = "\n".join(lines) + "\n"
print(summary)

summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
if summary_path:
    Path(summary_path).write_text(summary, encoding="utf-8")

Path("test-results").mkdir(parents=True, exist_ok=True)
Path("test-results/ci-summary.md").write_text(summary, encoding="utf-8")
Path("test-results/ci-gate.txt").write_text(
    f"pass_rate={pass_rate:.0f}%\nthreshold={threshold:g}%\nresult={status_str}\n",
    encoding="utf-8",
)
raise SystemExit(0 if gate else 1)
