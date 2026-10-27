import unittest

from pydantic import ValidationError

from app.schemas.focus_session import FocusSessionCreate, FocusSessionResponse, FocusSessionUpdate


class FocusSessionReflectionSchemaTests(unittest.TestCase):
    def test_create_and_response_preserve_reflection_fields(self):
        payload = {
            "id": "session-1",
            "user_id": "user-1",
            "start_time": "2026-10-27T09:00:00Z",
            "productive_app": "Docs",
            "intent": "Finish report",
            "focus_rating": 3,
            "drift_reason": "stuck",
            "parked_items": ["Check citation"],
        }
        created = FocusSessionCreate.model_validate(payload)
        self.assertEqual(created.model_dump()["parked_items"], ["Check citation"])
        response = FocusSessionResponse.model_validate({**payload, "created_at": "2026-10-27T09:00:00Z"})
        self.assertEqual(response.focus_rating, 3)
        self.assertEqual(response.drift_reason, "stuck")

    def test_update_accepts_partial_reflection_fields(self):
        update = FocusSessionUpdate.model_validate({"focus_rating": 5, "parked_items": ["Later"]})
        self.assertEqual(update.model_dump(exclude_none=True), {"focus_rating": 5, "parked_items": ["Later"]})

    def test_reflection_constraints_are_enforced(self):
        with self.assertRaises(ValidationError):
            FocusSessionUpdate.model_validate({"focus_rating": 6})
        with self.assertRaises(ValidationError):
            FocusSessionUpdate.model_validate({"drift_reason": "something_else"})
        with self.assertRaises(ValidationError):
            FocusSessionUpdate.model_validate({"parked_items": ["x" * 121]})
        with self.assertRaises(ValidationError):
            FocusSessionUpdate.model_validate({"parked_items": ["x"] * 21})


if __name__ == "__main__":
    unittest.main()
