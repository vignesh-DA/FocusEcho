"""Guard the documented local database connection variable name."""

import unittest
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[2]
ENV_EXAMPLE = BACKEND_DIR / ".env.example"


class EnvironmentExampleTests(unittest.TestCase):
    def test_documents_supabase_db_as_optional_connection_string(self):
        content = ENV_EXAMPLE.read_text(encoding="utf-8")
        assignments = [
            line.strip()
            for line in content.splitlines()
            if line.strip() and not line.lstrip().startswith("#") and "=" in line
        ]

        db_assignments = [line for line in assignments if line.startswith("SUPABASE_DB=")]

        self.assertEqual(db_assignments, ["SUPABASE_DB=<postgresql-connection-string>"])
        self.assertNotIn("SUPABASE_DB_URL", content)
        self.assertIn("not used by the FocusEcho API at runtime", content)


if __name__ == "__main__":
    unittest.main()
