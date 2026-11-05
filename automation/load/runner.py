"""
FocusEcho Enterprise Load Testing Runner
Executes concurrent synthetic workloads against local test backend endpoints,
capturing request rates, error rates, and P50/P90/P95/P99 latency metrics.
"""

from __future__ import annotations

import os
import sys

try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

import time
import math
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Any
from unittest.mock import patch, MagicMock

# Ensure backend is on sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
BACKEND_DIR = PROJECT_ROOT / "backend"
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from fastapi.testclient import TestClient
from app.main import app
from app.api.auth import require_auth

# These are local in-process TestClient smoke budgets, not production SLAs.
# They include Python/TestClient/thread-pool overhead and use mocked persistence.
LOCAL_API_P95_BUDGET_MS = 1000.0
LOCAL_MAX_BATCH_P95_BUDGET_MS = 2000.0


@dataclass
class LoadTestMetric:
    test_id: str
    name: str
    target_endpoint: str
    concurrency: int
    total_requests: int
    duration_seconds: float = 0.0
    requests_per_sec: float = 0.0
    error_count: int = 0
    error_rate_pct: float = 0.0
    latencies_ms: list[float] = field(default_factory=list)
    p50_ms: float = 0.0
    p90_ms: float = 0.0
    p95_ms: float = 0.0
    p99_ms: float = 0.0
    max_ms: float = 0.0
    status: str = "Not Run"
    failure_reason: str | None = None


class _LoadMockQuery:
    def __init__(self, table_name: str, rows: dict[str, dict[str, dict]], lock: threading.Lock):
        self.table_name = table_name
        self._rows = rows
        self._lock = lock
        self._filters: dict[str, str] = {}
        self._in_ids: list[str] | None = None
        self._maybe_single = False
        self._operation = "select"
        self._payload = None

    def select(self, *_args, **_kwargs):
        return self

    def eq(self, column, value):
        self._filters[column] = value
        return self

    def in_(self, col: str, vals: list[str]):
        self._in_ids = vals
        return self

    def maybe_single(self):
        self._maybe_single = True
        return self

    def insert(self, row):
        self._operation = "insert"
        self._payload = row
        return self

    def update(self, row):
        self._operation = "update"
        self._payload = row
        return self

    def upsert(self, rows):
        self._operation = "upsert"
        self._payload = rows
        return self

    def execute(self):
        with self._lock:
            table = self._rows.setdefault(self.table_name, {})
            if self._operation == "insert":
                row = dict(self._payload)
                table[row["id"]] = row
                return MagicMock(data=[row])
            if self._operation == "update":
                matched = [row for row in table.values() if all(row.get(k) == v for k, v in self._filters.items())]
                for row in matched:
                    row.update(self._payload)
                return MagicMock(data=matched)
            if self._operation == "upsert":
                upserted = []
                for incoming in self._payload:
                    row = table.setdefault(incoming["id"], {})
                    row.update(incoming)
                    upserted.append(row)
                return MagicMock(data=upserted)

            matched = [row for row in table.values() if all(row.get(k) == v for k, v in self._filters.items())]
            if self._in_ids is not None:
                matched = [row for row in matched if row.get("id") in self._in_ids]
            if self._maybe_single:
                return MagicMock(data=matched[0] if matched else None)
            return MagicMock(data=[{"id": row["id"]} for row in matched])


class _LoadMockClient:
    def __init__(self):
        self._rows: dict[str, dict[str, dict]] = {"focus_sessions": {}, "distraction_events": {}}
        self._lock = threading.Lock()

    def table(self, name: str):
        return _LoadMockQuery(name, self._rows, self._lock)


def _calculate_percentiles(latencies: list[float]) -> tuple[float, float, float, float, float]:
    if not latencies:
        return 0.0, 0.0, 0.0, 0.0, 0.0
    s = sorted(latencies)
    n = len(s)
    p50 = s[max(0, math.ceil(n * 0.50) - 1)]
    p90 = s[max(0, math.ceil(n * 0.90) - 1)]
    p95 = s[max(0, math.ceil(n * 0.95) - 1)]
    p99 = s[max(0, math.ceil(n * 0.99) - 1)]
    max_lat = s[-1]
    return p50, p90, p95, p99, max_lat


def run_load_scenario(
    metric: LoadTestMetric,
    task_fn: Callable[[TestClient, int], bool],
    p95_threshold_ms: float = 300.0,
    max_error_rate_pct: float = 0.0,
) -> LoadTestMetric:
    client = TestClient(app)
    latencies: list[float] = []
    errors = 0

    start_time = time.perf_counter()
    with ThreadPoolExecutor(max_workers=metric.concurrency) as executor:
        futures = []
        for i in range(metric.total_requests):
            def execute_single(req_index: int):
                t0 = time.perf_counter()
                success = False
                try:
                    success = task_fn(client, req_index)
                except Exception:
                    success = False
                dt = (time.perf_counter() - t0) * 1000.0
                return success, dt

            futures.append(executor.submit(execute_single, i))

        for f in as_completed(futures):
            ok, dt = f.result()
            latencies.append(dt)
            if not ok:
                errors += 1

    total_time = time.perf_counter() - start_time
    metric.duration_seconds = round(total_time, 3)
    metric.requests_per_sec = round(metric.total_requests / total_time, 1) if total_time > 0 else 0.0
    metric.error_count = errors
    metric.error_rate_pct = round((errors / metric.total_requests) * 100.0, 2)
    metric.latencies_ms = latencies

    p50, p90, p95, p99, max_lat = _calculate_percentiles(latencies)
    metric.p50_ms = round(p50, 2)
    metric.p90_ms = round(p90, 2)
    metric.p95_ms = round(p95, 2)
    metric.p99_ms = round(p99, 2)
    metric.max_ms = round(max_lat, 2)

    if metric.error_rate_pct <= max_error_rate_pct and metric.p95_ms <= p95_threshold_ms:
        metric.status = "Pass"
    else:
        metric.status = "Fail"
        reasons = []
        if metric.error_rate_pct > max_error_rate_pct:
            reasons.append(f"Error rate {metric.error_rate_pct}% exceeded max {max_error_rate_pct}%")
        if metric.p95_ms > p95_threshold_ms:
            reasons.append(f"P95 latency {metric.p95_ms}ms exceeded threshold {p95_threshold_ms}ms")
        metric.failure_reason = "; ".join(reasons)

    return metric


def run_all_load_tests() -> list[LoadTestMetric]:
    print("=" * 70)
    print("⚡ FOCUSECHO LOCAL LOAD TESTING SUITE")
    print("=" * 70)

    results: list[LoadTestMetric] = []
    app.dependency_overrides[require_auth] = lambda: "test-user-id"
    mock_client = _LoadMockClient()

    # 1. LOAD-HEALTH-001: Baseline Health Check Concurrency
    m1 = LoadTestMetric(
        test_id="LOAD-HEALTH-001",
        name="Health endpoint baseline concurrency",
        target_endpoint="GET /health",
        concurrency=10,
        total_requests=100,
    )
    def task_health(c: TestClient, _i: int) -> bool:
        r = c.get("/health")
        return r.status_code == 200 and r.json().get("status") == "ok"

    res1 = run_load_scenario(m1, task_health, p95_threshold_ms=LOCAL_API_P95_BUDGET_MS)
    results.append(res1)
    print(f"[{res1.status}] {res1.test_id}: {res1.name} — RPS: {res1.requests_per_sec}, P95: {res1.p95_ms}ms, Errors: {res1.error_count}")

    # 2. LOAD-HEALTH-002: Burst Concurrency on Health
    m2 = LoadTestMetric(
        test_id="LOAD-HEALTH-002",
        name="Burst concurrency spike on health endpoint",
        target_endpoint="GET /health",
        concurrency=30,
        total_requests=150,
    )
    res2 = run_load_scenario(m2, task_health, p95_threshold_ms=LOCAL_API_P95_BUDGET_MS)
    results.append(res2)
    print(f"[{res2.status}] {res2.test_id}: {res2.name} — RPS: {res2.requests_per_sec}, P95: {res2.p95_ms}ms, Errors: {res2.error_count}")

    # 3. LOAD-SESSION-001: Concurrent Session Creation Writes
    m3 = LoadTestMetric(
        test_id="LOAD-SESSION-001",
        name="Concurrent focus session creation writes",
        target_endpoint="POST /api/v1/sessions/",
        concurrency=10,
        total_requests=50,
    )
    def task_session_create(c: TestClient, i: int) -> bool:
        payload = {
            "id": f"3fa85f64-5717-4562-b3fc-2c963f66{i:04d}",
            "user_id": "test-user-id",
            "start_time": "2026-11-04T18:00:00Z",
            "productive_app": "com.example.notes",
            "intent": f"Load test task {i}",
        }
        r = c.post("/api/v1/sessions/", json=payload)
        return r.status_code == 200

    patcher_sess = patch("app.api.routes.sessions._client", return_value=mock_client)
    patcher_sess.start()
    try:
        res3 = run_load_scenario(m3, task_session_create, p95_threshold_ms=LOCAL_API_P95_BUDGET_MS)
    finally:
        patcher_sess.stop()
    results.append(res3)
    print(f"[{res3.status}] {res3.test_id}: {res3.name} — RPS: {res3.requests_per_sec}, P95: {res3.p95_ms}ms, Errors: {res3.error_count}")

    # 4. LOAD-SESSION-002: Concurrent Session Reflection Updates
    m4 = LoadTestMetric(
        test_id="LOAD-SESSION-002",
        name="Concurrent session reflection updates",
        target_endpoint="PATCH /api/v1/sessions/{id}",
        concurrency=10,
        total_requests=50,
    )
    def task_session_update(c: TestClient, i: int) -> bool:
        sess_id = f"3fa85f64-5717-4562-b3fc-2c963f66{i:04d}"
        payload = {
            "focus_rating": 4,
            "drift_reason": "stuck",
            "parked_items": [f"parked thought {i}"],
        }
        r = c.patch(f"/api/v1/sessions/{sess_id}", json=payload)
        return r.status_code == 200

    patcher_sess.start()
    try:
        res4 = run_load_scenario(m4, task_session_update, p95_threshold_ms=LOCAL_API_P95_BUDGET_MS)
    finally:
        patcher_sess.stop()
    results.append(res4)
    print(f"[{res4.status}] {res4.test_id}: {res4.name} — RPS: {res4.requests_per_sec}, P95: {res4.p95_ms}ms, Errors: {res4.error_count}")

    # 5. LOAD-EVENT-001: Concurrent Event Batch Ingestion
    m5 = LoadTestMetric(
        test_id="LOAD-EVENT-001",
        name="Event batch ingestion throughput (20 items/batch)",
        target_endpoint="POST /api/v1/events/batch",
        concurrency=10,
        total_requests=50,
    )
    def task_event_batch(c: TestClient, i: int) -> bool:
        sess_id = f"3fa85f64-5717-4562-b3fc-2c963f66{i:04d}"
        events = [
            {
                "id": f"evt-{i}-{k:03d}",
                "session_id": sess_id,
                "triggered_at": "2026-11-04T18:05:00Z",
                "package_name": "com.instagram.android",
                "app_label": "Instagram",
                "risk_score": "high",
                "is_recovered": False,
            }
            for k in range(20)
        ]
        r = c.post("/api/v1/events/batch", json={"events": events, "user_id": "test-user-id"})
        return r.status_code == 200

    patcher_evt = patch("app.api.routes.events._client", return_value=mock_client)
    patcher_evt.start()
    try:
        res5 = run_load_scenario(m5, task_event_batch, p95_threshold_ms=LOCAL_API_P95_BUDGET_MS)
    finally:
        patcher_evt.stop()
    results.append(res5)
    print(f"[{res5.status}] {res5.test_id}: {res5.name} — RPS: {res5.requests_per_sec}, P95: {res5.p95_ms}ms, Errors: {res5.error_count}")

    # 6. LOAD-EVENT-002: Batch Ingestion Maximum Limit (500 items)
    m6 = LoadTestMetric(
        test_id="LOAD-EVENT-002",
        name="Maximum allowable event batch load (500 items)",
        target_endpoint="POST /api/v1/events/batch",
        concurrency=5,
        total_requests=10,
    )
    def task_max_batch(c: TestClient, i: int) -> bool:
        sess_id = f"3fa85f64-5717-4562-b3fc-2c963f66{i:04d}"
        events = [
            {
                "id": f"max-evt-{i}-{k:04d}",
                "session_id": sess_id,
                "triggered_at": "2026-11-04T18:05:00Z",
                "package_name": "com.social.app",
                "app_label": "SocialApp",
                "risk_score": "low",
                "is_recovered": False,
            }
            for k in range(500)
        ]
        r = c.post("/api/v1/events/batch", json={"events": events, "user_id": "test-user-id"})
        return r.status_code == 200

    patcher_evt.start()
    try:
        res6 = run_load_scenario(m6, task_max_batch, p95_threshold_ms=LOCAL_MAX_BATCH_P95_BUDGET_MS)
    finally:
        patcher_evt.stop()
    results.append(res6)
    print(f"[{res6.status}] {res6.test_id}: {res6.name} — RPS: {res6.requests_per_sec}, P95: {res6.p95_ms}ms, Errors: {res6.error_count}")

    # 7. LOAD-RETRY-001: Client Retry Resilience Under Contention
    m7 = LoadTestMetric(
        test_id="LOAD-RETRY-001",
        name="Client retry pattern resilience under concurrent load",
        target_endpoint="GET /health",
        concurrency=10,
        total_requests=30,
    )
    def task_retry_pattern(c: TestClient, _i: int) -> bool:
        for attempt in range(2):
            try:
                r = c.get("/health")
                if r.status_code == 200:
                    return True
            except Exception:
                time.sleep(0.01)
        return False

    res7 = run_load_scenario(m7, task_retry_pattern, p95_threshold_ms=LOCAL_API_P95_BUDGET_MS)
    results.append(res7)
    print(f"[{res7.status}] {res7.test_id}: {res7.name} — RPS: {res7.requests_per_sec}, P95: {res7.p95_ms}ms, Errors: {res7.error_count}")

    # 8. LOAD-PERF-001: Sustained High-Concurrency Health Baseline
    m8 = LoadTestMetric(
        test_id="LOAD-PERF-001",
        name="Sustained high-concurrency throughput check",
        target_endpoint="GET /health",
        concurrency=25,
        total_requests=250,
    )
    res8 = run_load_scenario(m8, task_health, p95_threshold_ms=LOCAL_API_P95_BUDGET_MS)
    results.append(res8)
    print(f"[{res8.status}] {res8.test_id}: {res8.name} — RPS: {res8.requests_per_sec}, P95: {res8.p95_ms}ms, Errors: {res8.error_count}")

    app.dependency_overrides.clear()

    print("=" * 70)
    passed_count = sum(1 for r in results if r.status == "Pass")
    failed_count = len(results) - passed_count
    print(f"LOAD SUITE SUMMARY: {passed_count}/{len(results)} passed; {failed_count} failed")
    print("=" * 70)
    if failed_count:
        raise SystemExit(1)
    return results


if __name__ == "__main__":
    run_all_load_tests()
