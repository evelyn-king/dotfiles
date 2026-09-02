import runpy
import unittest
from pathlib import Path
from unittest.mock import patch

POLICY = runpy.run_path(Path(__file__).with_name("git-rewrite-policy.py"))
CHECK_COMMAND = POLICY["check_command"]


class GitRewritePolicyTests(unittest.TestCase):
    def check(self, command: str, branch: str = "feature") -> str | None:
        with patch.dict(
            CHECK_COMMAND.__globals__,
            {"get_current_branch": lambda _git_dir=None: branch},
        ):
            return CHECK_COMMAND(command)

    def test_blocks_quoted_policy_tokens(self) -> None:
        commands = [
            'git commit "--amend"',
            'git push origin "main"',
            "git push origin 'master'",
            'git push "--force" origin feature',
            'git push "--force-with-lease" origin feature',
            'git add "-A"',
            'git add "--all"',
        ]
        for command in commands:
            with self.subTest(command=command):
                self.assertIsNotNone(self.check(command))

    def test_reports_force_with_lease_precisely(self) -> None:
        self.assertEqual(
            self.check("git push --force-with-lease origin feature"),
            "git push --force-with-lease is not allowed",
        )

    def test_ignores_policy_text_inside_prose(self) -> None:
        commands = [
            'git commit -m "document git push --force to main"',
            'gh pr create --body "avoid git add -A"',
            'printf "%s\\n" "git commit --amend"',
        ]
        for command in commands:
            with self.subTest(command=command):
                self.assertIsNone(self.check(command))

    def test_checks_implicit_push_against_current_branch(self) -> None:
        self.assertIsNotNone(self.check("git push", branch="main"))
        self.assertIsNone(self.check("git push", branch="feature"))


if __name__ == "__main__":
    unittest.main()
