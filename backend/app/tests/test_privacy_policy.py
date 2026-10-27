"""Keep shipped and documented retention statements accurate."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
POLICY_FILES = (
    ROOT / "docs" / "privacy_policy.md",
    ROOT / "mobile_app" / "assets" / "privacy_policy.md",
)


class PrivacyPolicyTests(unittest.TestCase):
    def test_policy_copies_match_and_do_not_claim_automatic_90_day_deletion(self):
        policies = [path.read_text(encoding="utf-8").strip() for path in POLICY_FILES]

        self.assertEqual(policies[0], policies[1])
        for policy in policies:
            self.assertNotRegex(policy.casefold(), r"90[ -]?days?")
            self.assertIn(
                "automatic deletion after a fixed retention period is not currently implemented",
                policy.casefold(),
            )


if __name__ == "__main__":
    unittest.main()
