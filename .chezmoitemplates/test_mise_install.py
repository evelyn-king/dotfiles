"""Exercise the rendered mise install hook against a fake release, offline."""

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parent.parent
CHEZMOI = shutil.which("chezmoi")
VERSION = "9.9.9"

FAKE_MISE = f"""#!/bin/bash
case "$1" in
  --version) echo "{VERSION} linux-x64 (fake)" ;;
  completion) echo "# $2 completion" ;;
esac
"""

# Serve the local release for `curl -o <file> <url>` and record the URL.
FAKE_CURL = """#!/bin/bash
out=
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out=$2; shift ;;
    https://*) printf '%s\\n' "$1" >> "$CALL_LOG" ;;
  esac
  shift
done
cp "$RELEASE" "$out"
"""


@unittest.skipUnless(CHEZMOI, "chezmoi is required to render the hook")
class MiseInstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.home = self.temp / "home"
        self.home.mkdir()
        self.log = self.temp / "calls"

        staging = self.temp / "staging/mise"
        (staging / "bin").mkdir(parents=True)
        (staging / "man/man1").mkdir(parents=True)
        (staging / "bin/mise").write_text(FAKE_MISE)
        (staging / "bin/mise").chmod(0o755)
        (staging / "man/man1/mise.1").write_text(".TH MISE 1\n")
        self.release = self.temp / "release.tar.gz"
        with tarfile.open(self.release, "w:gz") as archive:
            archive.add(staging, arcname="mise")
        self.sha256 = hashlib.sha256(self.release.read_bytes()).hexdigest()

        fakebin = self.temp / "fakebin"
        fakebin.mkdir()
        (fakebin / "curl").write_text(FAKE_CURL)
        (fakebin / "curl").chmod(0o755)
        self.path = f"{fakebin}:/usr/bin:/bin"

    def run_hook(self, *, os="linux", arch="amd64", sha256=None):
        config = self.temp / "chezmoi.toml"
        config.write_text("")
        digest = sha256 or self.sha256
        data = {
            "chezmoi": {"os": os, "arch": arch},
            "mise": {"version": VERSION,
                     "sha256": {"linux-x64": digest, "macos-arm64": digest}},
        }
        rendered = subprocess.run(
            [CHEZMOI, "--config", str(config), "--source", str(SOURCE),
             "--override-data", json.dumps(data), "execute-template", "--file",
             str(SOURCE / "run_before_00-install-mise.sh.tmpl")],
            check=True, capture_output=True, text=True,
        ).stdout
        hook = self.temp / "hook.sh"
        hook.write_text(rendered)
        result = subprocess.run(
            ["/bin/bash", str(hook)], capture_output=True, text=True,
            env={"PATH": self.path, "HOME": str(self.home),
                 "CALL_LOG": str(self.log), "RELEASE": str(self.release)},
        )
        calls = self.log.read_text().splitlines() if self.log.exists() else []
        return result, calls

    @property
    def mise(self):
        return self.home / ".local/bin/mise"

    def test_fresh_install_places_binary_man_page_and_completions(self):
        result, calls = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [
            f"https://github.com/jdx/mise/releases/download/v{VERSION}/"
            f"mise-v{VERSION}-linux-x64.tar.gz",
        ])
        self.assertTrue(self.mise.stat().st_mode & 0o111)
        data = self.home / ".local/share"
        self.assertTrue((data / "man/man1/mise.1").is_file())
        self.assertEqual((data / "zsh/site-functions/_mise").read_text(),
                         "# zsh completion\n")
        self.assertEqual((data / "bash-completion/completions/mise").read_text(),
                         "# bash completion\n")
        instructions = self.home / ".local/lib/mise/mise-self-update-instructions.toml"
        self.assertIn(".chezmoidata/versions.yaml", instructions.read_text())

    def test_pinned_version_already_installed_skips_download(self):
        self.run_hook()
        self.log.unlink()
        result, calls = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])

    def test_other_version_is_replaced(self):
        self.mise.parent.mkdir(parents=True)
        self.mise.write_text('#!/bin/bash\necho "1.0.0 linux-x64"\n')
        self.mise.chmod(0o755)
        result, calls = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 1)
        self.assertIn(VERSION, self.mise.read_text())

    def test_macos_downloads_macos_archive(self):
        result, calls = self.run_hook(os="darwin", arch="arm64")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(calls[0].endswith(f"mise-v{VERSION}-macos-arm64.tar.gz"))

    def test_checksum_mismatch_installs_nothing(self):
        result, calls = self.run_hook(sha256="0" * 64)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checksum mismatch", result.stderr)
        self.assertEqual(len(calls), 1)
        self.assertFalse(self.mise.exists())

    def test_unpinned_platform_does_nothing(self):
        result, calls = self.run_hook(arch="arm64")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no pinned release", result.stderr)
        self.assertEqual(calls, [])
        self.assertFalse(self.mise.exists())


if __name__ == "__main__":
    unittest.main()
