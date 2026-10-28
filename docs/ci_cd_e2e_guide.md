# ⚡ FocusEcho CI/CD Deployment & Live E2E Testing Guide

This guide details the complete implementation of **Phase 7: Complete CI/CD Deployment + Live E2E Testing** for the **FocusEcho** platform.

---

## 🛠️ Repository Configuration for GitHub Pages

To enable automated deployment and verification on every push, configure your GitHub repository settings:

### 1. GitHub Pages Configuration
1. Navigate to: `https://github.com/vignesh-DA/FocusEcho/settings/pages`
2. **Build and deployment Source**: Select **`GitHub Actions`** (Not Deploy from a branch).
3. Under Custom Domain (if applicable): Leave default `https://vignesh-DA.github.io/FocusEcho/`.

### 2. Workflow Permissions
1. Navigate to: `https://github.com/vignesh-DA/FocusEcho/settings/actions`
2. Scroll to **Workflow permissions**:
   - Select **Read and write permissions**.
   - Check **Allow GitHub Actions to create and approve pull requests**.
3. Save changes.

### 3. Repository Variables & Secrets
Under `Settings` > `Secrets and variables` > `Actions`:
- **Repository Variables**:
  - `BASE_URL`: (Optional) `https://vignesh-DA.github.io/FocusEcho/` (Default fallback is automatically generated from repository owner and repository name).

---

## 🔄 13-Stage CI/CD Pipeline Architecture

The workflow `.github/workflows/deploy-and-test.yml` executes end-to-end on every `push`, `pull_request` to `main`, or manual `workflow_dispatch`:

```text
Build Application ──> Static Analysis ──> Deploy to GitHub Pages
                                                 │
                                                 ▼
Verify Deployment ◄── Wait for Deployment ◄──────┘
       │
       ▼
Run Selenium E2E Tests (470+ Cases)
       │
       ▼
Generate HTML/JSON Reports ──> Generate Excel Reports ──> Upload Artifacts ──> Publish Summary ──> Store Historical
```

### Stage Details:
1. **Stage 1: Repository Checkout**: Checks out full repository source tree with depth.
2. **Stage 2: Dependency Installation**: Installs Python 3.12, Selenium 4.48, Openpyxl, Requests, and BeautifulSoup4.
3. **Stage 3: Build Application**: Runs `python scripts/build_web.py` to compile the FocusEcho live web platform into `dist/`.
4. **Stage 4: Static Analysis**: Verifies HTML structure, stylesheet availability, and JavaScript bundle integrity.
5. **Stage 5: Deploy to GitHub Pages**: Uses official `actions/upload-pages-artifact@v3` and `actions/deploy-pages@v4` to publish `dist/` directly to the live GitHub Pages CDN.
6. **Stage 6: Wait for Deployment**: Delays for DNS and CDN edge caching to propagate.
7. **Stage 7: Deployment Verification**: Runs `automation.utils.deployment_verifier` to confirm HTTP 200, CSS/JS loading, and DOM rendering on the live URL. Fails the pipeline if unavailable.
8. **Stage 8: Run Selenium E2E Tests**: Launches headless Chrome to execute all 470+ test cases against the live deployment URL.
9. **Stage 9: Generate Reports**: Produces `execution-report.html`, `dashboard.html`, and `execution-results.json`.
10. **Stage 10: Generate Excel Reports**: Produces `Automation_Test_Report.xlsx` (6 sheets: Executed, Passed, Failed, Skipped, Metrics, Defects), `Passed_Test_Cases.xlsx`, `Failed_Test_Cases.xlsx`, and `Summary_Report.xlsx`.
11. **Stage 11: Upload Artifacts**: Uploads all reports, failure screenshots, and execution logs with 30-day retention.
12. **Stage 12: Publish Summary**: Appends live execution metrics, pass percentages, and failure diagnostics to `$GITHUB_STEP_SUMMARY`.
13. **Stage 13: Store Historical Results**: Preserves timestamped execution evidence in `.historical_results/`.

---

## 💻 Local Execution Guide

### Running All 470+ Tests Locally:
```bash
# 1. Build the web app
python scripts/build_web.py

# 2. Run master automation orchestrator
python -m automation.runner
```

### Running Specific Test Suites:
```bash
# Run Authentication suite (40 tests)
python -c "from automation.drivers.driver_factory import DriverFactory; from automation.tests.test_01_authentication import run_tests; d = DriverFactory.create_driver(); run_tests(d); d.quit()"

# Run Forms suite (50 tests)
python -c "from automation.drivers.driver_factory import DriverFactory; from automation.tests.test_05_forms import run_tests; d = DriverFactory.create_driver(); run_tests(d); d.quit()"

# Run Regression suite (50 tests)
python -c "from automation.drivers.driver_factory import DriverFactory; from automation.tests.test_14_regression import run_tests; d = DriverFactory.create_driver(); run_tests(d); d.quit()"
```

---

## 🔍 Troubleshooting & FAQ

### Q1: Why did Stage 7 Deployment Verification time out?
- Ensure that GitHub Pages is enabled under repository settings and set to source **GitHub Actions**.
- Check if GitHub Actions has sufficient permissions (`pages: write`, `id-token: write`).

### Q2: What happens if a test case fails?
- The framework automatically captures a full-page screenshot to `Test Results/Screenshots/<test-id>_failed_<timestamp>.png`.
- Captured browser console logs and Python stack traces are recorded in `Test Results/JSON/execution-results.json` and `Test Results/Excel/Automation_Test_Report.xlsx` (Sheet 3: Failed Tests and Sheet 6: Defect Summary).

### Q3: How is the Pass/Fail decision evaluated?
- Quality Gate:
  - Total Pass Percentage must be **≥95.0%**.
  - Critical Priority Failures must be **≤5.0%**.
- If these conditions are met, the workflow passes with exit code `0`.
