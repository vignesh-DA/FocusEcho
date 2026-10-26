"""
Demonstrates EchoCoach v1 live invocation vs deterministic offline fallback.
Prints:
- Execution mode (Live LLM vs Offline Fallback)
- Model name
- Response time in milliseconds
- Exact raw JSON response
"""
import json
import os
import sys
import time
from dotenv import load_dotenv

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

load_dotenv(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".env")))

from app.services.ai_coach_service import AiCoachService
from app.tests.test_coach_service import MockSupabaseClient


def run_demo(api_key: str | None = None, model_name: str | None = None):
    print("=" * 70)
    print("ECHOCOACH v1 INVOCATION DEMO")
    print("=" * 70)

    # 1. Setup mock session & distraction events
    session_id = "session-demo-001"
    authed_user = "user-demo-456"

    mock_db = MockSupabaseClient(
        session_data={
            "id": session_id,
            "user_id": authed_user,
            "start_time": "2026-10-26T10:00:00Z",
            "end_time": "2026-10-26T10:30:00Z",
            "intent": "Write auth test cases",
            "focus_score": 78.0,
        },
        events_data=[
            {
                "package_name": "youtube.com",
                "app_label": "YouTube",
                "triggered_at": "2026-10-26T10:14:30Z",
                "recovery_time_seconds": 18,
            }
        ],
        total_sessions=6,  # > 5 sessions: pattern analysis enabled
    )

    service = AiCoachService(supabase_client=mock_db)
    if api_key is not None:
        service.api_key = api_key
    if model_name is not None:
        service.model = model_name

    mode_label = f"LIVE API ({service.model})" if service.api_key else "OFFLINE DETERMINISTIC FALLBACK"
    print(f"Mode:          {mode_label}")
    print(f"Model:         {service.model if service.api_key else 'RuleEngine-Fallback'}")
    print(f"Session ID:    {session_id}")
    print(f"User ID:       {authed_user}")
    print("-" * 70)

    start_t = time.perf_counter()
    response = service.generate_session_debrief(session_id, authed_user)
    elapsed_ms = (time.perf_counter() - start_t) * 1000

    print(f"Latency (ms):  {elapsed_ms:.2f}")
    print(f"Is Fallback:   {response.is_fallback}")
    print(f"Is Cached:     {response.is_cached}")
    print("\nRAW JSON OUTPUT:")
    print(json.dumps(response.model_dump(), indent=2))
    print("=" * 70)
    return response, elapsed_ms


if __name__ == "__main__":
    key = os.getenv("GROQ_API_KEY", "")
    model = os.getenv("COACH_LLM_MODEL", "")
    run_demo(api_key=key, model_name=model)
