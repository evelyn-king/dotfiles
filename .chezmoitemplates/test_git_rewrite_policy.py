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
            'git reset "--hard"',
            'git "rebase" main',
            'git push origin "main"',
            "git push origin 'master'",
            'git push origin "+feature"',
            'git push "--force" origin feature',
            'git push "--force-with-lease" origin feature',
            'git "add" "."',
            'git add "-A"',
            'git add "--all"',
        ]
        for command in commands:
            with self.subTest(command=command):
                self.assertIsNotNone(self.check(command))

    def test_blocks_direct_history_rewrites(self) -> None:
        commands = [
            "git reset --hard",
            "git -C other-repo reset HEAD --hard",
            "git rebase main",
            "git -C other-repo rebase --onto main feature",
        ]
        for command in commands:
            with self.subTest(command=command):
                self.assertIsNotNone(self.check(command))

    def test_blocks_broad_staging(self) -> None:
        commands = [
            "git add .",
            "git add -- .",
            "git add file.txt .",
            "git add -A",
            "git add --all",
        ]
        for command in commands:
            with self.subTest(command=command):
                self.assertIsNotNone(self.check(command))

        self.assertIsNone(self.check("git add ./specific-file"))

    def test_blocks_force_refspecs(self) -> None:
        commands = [
            "git push origin +feature",
            "git push origin +HEAD:feature",
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

    def test_checks_head_push_against_current_branch(self) -> None:
        self.assertIsNotNone(self.check("git push origin HEAD", branch="main"))
        self.assertIsNotNone(self.check('git push origin "HEAD"', branch="master"))
        self.assertIsNone(self.check("git push origin HEAD", branch="feature"))

    def test_documents_advisory_limits(self) -> None:
        commands = [
            'bash -c "git reset --hard"',
            "eval 'git push --force origin main'",
            "git force-push-alias",
        ]
        for command in commands:
            with self.subTest(command=command):
                self.assertIsNone(self.check(command))


if __name__ == "__main__":
    unittest.main()
