"""API authorization and payload validation tests for session/event routes."""

import unittest
from unittest.mock import patch

from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import ValidationError
from starlette.requests import Request

from app.api import auth
from app.api.routes import events as events_routes
from app.api.routes import sessions as sessions_routes
from app.schemas.distraction_event import DistractionEventBatch
from app.schemas.focus_session import FocusSessionCreate, FocusSessionUpdate


_JWT_SECRET = "route-test-secret"
_USER_A = "user-a"
_USER_B = "user-b"


class _Query:
    def __init__(self, data=None):
        self.data = data
        self.inserted = None

    def select(self, *_args, **_kwargs):
        return self

    def eq(self, *_args, **_kwargs):
        return self

    def in_(self, *_args, **_kwargs):
        return self

    def maybe_single(self):
        return self

    def insert(self, row):
        self.inserted = row
        return self

    def update(self, _row):
        return self

    def upsert(self, _rows):
        return self

    def execute(self):
        return self


class _Client:
    def __init__(self, *, session_data=None):
        self.session_query = _Query(session_data)

    def table(self, name):
        if name == "focus_sessions":
            return self.session_query
        return _Query([])


def _session_payload(user_id=_USER_A):
    return {
        "id": "session-1",
        "user_id": user_id,
        "start_time": "2026-10-27T10:00:00Z",
        "productive_app": "com.example.notes",
    }


def _event_payload(session_id="session-1"):
    return {
        "id": "event-1",
        "session_id": session_id,
        "package_name": "youtube.com",
        "app_label": "YouTube",
        "triggered_at": "2026-10-27T10:00:00Z",
        "risk_score": "medium",
        "is_recovered": False,
    }


class SessionEventRouteTests(unittest.TestCase):
    def setUp(self):
        self.jwt_patch = patch("app.api.auth._JWT_SECRET", _JWT_SECRET)
        self.jwt_patch.start()
        self.addCleanup(self.jwt_patch.stop)

    def test_missing_token_is_rejected_by_protected_route_dependency(self):
        scope = {
            "type": "http", "asgi": {"version": "3.0"},
            "http_version": "1.1", "method": "POST", "scheme": "http",
            "path": "/api/v1/sessions/", "raw_path": b"/api/v1/sessions/",
            "query_string": b"", "headers": [], "client": ("test", 1),
            "server": ("test", 80), "root_path": "",
        }
        with self.assertRaises(HTTPException) as raised:
            auth._bearer(Request(scope)).send(None)
        self.assertEqual(raised.exception.status_code, 401)

    def test_sessions_and_events_endpoints_use_the_auth_dependency(self):
        expected = {
            ("/api/v1/sessions/", "POST"),
            ("/api/v1/sessions/{session_id}", "PATCH"),
            ("/api/v1/events/batch", "POST"),
        }
        registered = []
        for route in (*sessions_routes.router.routes, *events_routes.router.routes):
            for method in route.methods or ():
                if (route.path, method) in expected:
                    registered.append((route.path, method))
                    self.assertIn(
                        auth.require_auth,
                        [dependency.call for dependency in route.dependant.dependencies],
                    )
        self.assertEqual(set(registered), expected)

    def test_invalid_token_is_rejected_by_protected_route_dependency(self):
        with self.assertRaises(HTTPException) as raised:
            auth.require_auth(
                HTTPAuthorizationCredentials(scheme="Bearer", credentials="invalid")
            )
        self.assertEqual(raised.exception.status_code, 401)

    def test_create_rejects_session_id_owned_by_another_user(self):
        db = _Client(session_data={"id": "session-1", "user_id": _USER_B})
        with patch("app.api.routes.sessions._client", return_value=db):
            with self.assertRaises(HTTPException) as raised:
                sessions_routes.create_session(
                    FocusSessionCreate.model_validate(_session_payload()), _USER_A
                )
        self.assertEqual(raised.exception.status_code, 403)
        self.assertIsNone(db.session_query.inserted)

    def test_update_rejects_session_owned_by_another_user(self):
        db = _Client(session_data={"user_id": _USER_B})
        with patch("app.api.routes.sessions._client", return_value=db):
            with self.assertRaises(HTTPException) as raised:
                sessions_routes.update_session(
                    "session-1", _USER_A, FocusSessionUpdate(total_distractions=1)
                )
        self.assertEqual(raised.exception.status_code, 403)

    def test_501_item_event_batch_is_rejected_by_payload_schema(self):
        events = [_event_payload() for _ in range(501)]
        with self.assertRaises(ValidationError):
            DistractionEventBatch.model_validate({"user_id": _USER_A, "events": events})

    def test_malformed_session_payload_is_rejected_by_payload_schema(self):
        with self.assertRaises(ValidationError):
            FocusSessionCreate.model_validate({"id": "session-1", "user_id": _USER_A})

    def test_malformed_event_payload_is_rejected_by_payload_schema(self):
        with self.assertRaises(ValidationError):
            DistractionEventBatch.model_validate(
                {"user_id": _USER_A, "events": "not-an-array"}
            )


if __name__ == "__main__":
    unittest.main()
