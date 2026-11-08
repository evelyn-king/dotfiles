"""Exercise the rendered mise-untracked script against a fake mise, offline."""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parent.parent
CHEZMOI = shutil.which("chezmoi")

LOCK = """lockfile_version = 2

[[tools.bat]]
version = "0.26.1"

[[tools."aqua:1password/cli"]]
version = "2.41.0"
"""

# `mise ls --prunable --no-header` prints one row per version. bat 0.26.1 and
# the 1Password CLI are locked, so only the other two rows are untracked.
PRUNABLE = """bat                  0.26.1  ~/.config/mise/config.toml
bat                  0.25.0  ~/.config/mise/config.toml
aqua:1password/cli   2.41.0  ~/.config/mise/config.toml
aqua:1password/cli   2.40.0  ~/.config/mise/config.toml
"""

FAKE_MISE = """#!/bin/bash
case "$1" in
  ls) [ -z "${FAIL_LS:-}" ] || exit 1; cat "$PRUNABLE" ;;
  uninstall)
    shift
    [ "$1" = --yes ] && shift
    printf '%s\\n' "$1" >> "$CALL_LOG"
    [ "$1" != "${FAIL_ON:-}" ]
    ;;
esac
"""


@unittest.skipUnless(CHEZMOI, "chezmoi is required to render the script")
class MiseUntrackedTests(unittest.TestCase):
    def setUp(self):
        self.temp = Path(self.enterContext(tempfile.TemporaryDirectory()))
        source = self.temp / "source"
        (source / ".chezmoitemplates").mkdir(parents=True)
        (source / "dot_config/mise").mkdir(parents=True)
        shutil.copy(SOURCE / ".chezmoitemplates/mise-locked-tools.tmpl",
                    source / ".chezmoitemplates")
        (source / "dot_config/mise/mise.lock").write_text(LOCK)

        config = self.temp / "chezmoi.toml"
        config.write_text("")
        data = {"chezmoi": {"sourceDir": str(source)}}
        rendered = subprocess.run(
            [CHEZMOI, "--config", str(config), "--source", str(source),
             "--override-data", json.dumps(data), "execute-template", "--file",
             str(SOURCE / "dot_local/bin/executable_mise-untracked.tmpl")],
            check=True, capture_output=True, text=True,
        ).stdout
        self.script = self.temp / "mise-untracked"
        self.script.write_text(rendered)

        self.prunable = self.temp / "prunable"
        self.prunable.write_text(PRUNABLE)
        self.log = self.temp / "calls"
        self.mise = self.temp / "mise"
        self.mise.write_text(FAKE_MISE)
        self.mise.chmod(0o755)

    def run_script(self, *args, **extra_env):
        env = {"PATH": f"{Path(CHEZMOI).parent}:/usr/bin:/bin",
               "HOME": str(self.temp), "MISE": str(self.mise),
               "PRUNABLE": str(self.prunable), "CALL_LOG": str(self.log),
               **extra_env}
        result = subprocess.run(
            ["/bin/bash", str(self.script), *args], capture_output=True,
            text=True, stdin=subprocess.DEVNULL, env=env,
        )
        calls = self.log.read_text().splitlines() if self.log.exists() else []
        return result, calls

    def test_lists_only_versions_outside_the_lock_and_removes_nothing(self):
        result, calls = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(),
                         ["bat@0.25.0", "aqua:1password/cli@2.40.0"])
        self.assertEqual(calls, [])

    def test_reports_none_when_everything_is_locked(self):
        self.prunable.write_text(PRUNABLE.splitlines(keepends=True)[0])
        result, calls = self.run_script("--remove", "--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertIn("no untracked installs", result.stderr)
        self.assertEqual(calls, [])

    def test_remove_uninstalls_each_untracked_version(self):
        result, calls = self.run_script("--remove", "--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, ["bat@0.25.0", "aqua:1password/cli@2.40.0"])

    def test_remove_without_a_terminal_requires_yes(self):
        result, calls = self.run_script("--remove")
        self.assertEqual(result.returncode, 1)
        self.assertIn("pass --yes", result.stderr)
        self.assertEqual(calls, [])

    def test_failed_removal_does_not_stop_the_rest(self):
        result, calls = self.run_script("--remove", "--yes",
                                        FAIL_ON="bat@0.25.0")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(calls, ["bat@0.25.0", "aqua:1password/cli@2.40.0"])
        self.assertIn("could not remove bat@0.25.0", result.stderr)

    def test_mise_listing_failure_is_an_error_not_an_empty_report(self):
        result, calls = self.run_script("--remove", "--yes", FAIL_LS="1")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertEqual(calls, [])

    def test_unknown_option_is_rejected(self):
        result, _ = self.run_script("--bogus")
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
