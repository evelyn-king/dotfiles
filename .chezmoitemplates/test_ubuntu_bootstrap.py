"""Exercise the rendered Ubuntu before-hook without privileges or package installs."""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parent.parent
CHEZMOI = shutil.which("chezmoi")


@unittest.skipUnless(CHEZMOI, "chezmoi is required to render the hook")
class UbuntuBootstrapTests(unittest.TestCase):
    def run_hook(self, *, distro="ubuntu", version="26.04", arch="amd64",
                 mise=True, help_status=0, apply_status=0):
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            config = temp / "chezmoi.toml"
            config.write_text("")
            data = {"chezmoi": {"os": "linux", "arch": arch,
                                "osRelease": {"id": distro, "versionID": version}}}
            rendered = subprocess.run(
                [CHEZMOI, "--config", str(config), "--source", str(SOURCE),
                 "--override-data", json.dumps(data), "execute-template", "--file",
                 str(SOURCE / "run_before_05-bootstrap-ubuntu.sh.tmpl")],
                check=True, capture_output=True, text=True,
            ).stdout
            hook = temp / "hook.sh"
            hook.write_text(rendered)
            log = temp / "calls"
            if mise:
                bin_dir = temp / ".local/bin"
                bin_dir.mkdir(parents=True)
                executable = bin_dir / "mise"
                executable.write_text(
                    "#!/bin/bash\n"
                    'printf "%s|%s|%s\\n" "${MISE_CONFIG_DIR:-}" '
                    '"${MISE_SYSTEM_PACKAGES_MANAGERS:-}" "$*" >> "$CALL_LOG"\n'
                    f'if [[ "$*" == *--help ]]; then exit {help_status}; fi\n'
                    f"exit {apply_status}\n"
                )
                executable.chmod(0o755)
            result = subprocess.run(
                ["/bin/bash", str(hook)], capture_output=True, text=True,
                env={"PATH": "/usr/bin:/bin", "HOME": str(temp),
                     "CALL_LOG": str(log)},
            )
            calls = log.read_text().splitlines() if log.exists() else []
            return result, calls

    def test_other_distributions_do_nothing(self):
        result, calls = self.run_hook(distro="debian")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])

    def test_unsupported_targets_fail_before_invoking_mise(self):
        for overrides in ({"version": "24.04"}, {"arch": "arm64"}):
            with self.subTest(**overrides):
                result, calls = self.run_hook(**overrides)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Ubuntu 26.04 on x86_64", result.stderr)
                self.assertEqual(calls, [])

    def test_missing_mise_is_actionable(self):
        result, calls = self.run_hook(mise=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("mise install hook", result.stderr)
        self.assertEqual(calls, [])

    def test_old_mise_does_not_attempt_provisioning(self):
        result, calls = self.run_hook(help_status=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("raise the mise pin", result.stderr)
        self.assertEqual(len(calls), 1)
        self.assertTrue(calls[0].endswith("--help"))

    def test_provisioning_uses_source_config_and_only_native_phases(self):
        result, calls = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 2)
        self.assertEqual(
            calls[1],
            f"{SOURCE / 'dot_config/mise'}|apt|"
            "--cd / bootstrap --only files,packages --yes",
        )

    def test_provisioning_failure_stops_apply(self):
        result, calls = self.run_hook(apply_status=17)
        self.assertEqual(result.returncode, 17)
        self.assertEqual(len(calls), 2)

    def test_declaration_changes_retrigger_tool_installation(self):
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            source = temp / "source"
            declarations = source / "dot_config/mise/conf.d"
            declarations.mkdir(parents=True)
            (source / ".chezmoitemplates").mkdir()
            (source / ".chezmoidata").mkdir()
            for relative in (
                ".chezmoidata/versions.yaml",
                ".chezmoitemplates/mise-config-hashes.tmpl",
                "run_onchange_after_mise-install.sh.tmpl",
                "dot_config/mise/mise.lock",
            ):
                shutil.copy(SOURCE / relative, source / relative)
            shutil.copytree(SOURCE / "dot_config/mise/conf.d", declarations,
                            dirs_exist_ok=True)
            config = temp / "chezmoi.toml"
            config.write_text("")

            def render():
                return subprocess.check_output(
                    [CHEZMOI, "--config", str(config), "--source", str(source),
                     "execute-template", "--file",
                     str(source / "run_onchange_after_mise-install.sh.tmpl")],
                )

            original = render()
            added = declarations / "30-extra.toml"
            added.write_text('[tools]\njq = "1.8.1"\n')
            with_addition = render()
            self.assertNotEqual(original, with_addition)
            added.write_text('[tools]\njq = "1.8.0"\n')
            self.assertNotEqual(with_addition, render())
            added.unlink()
            self.assertEqual(original, render())

            # A new mise release can resolve or install tools differently.
            versions = source / ".chezmoidata/versions.yaml"
            pinned = versions.read_text()
            versions.write_text(pinned.replace('  version: "', '  version: "0.', 1))
            self.assertNotEqual(original, render())


if __name__ == "__main__":
    unittest.main()
