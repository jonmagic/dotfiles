import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bin" / "update-software"


class UpdateSoftwareTests(unittest.TestCase):
    def run_updater(self, failure="", args=("--all",)):
        with tempfile.TemporaryDirectory(prefix="update-software-test-") as directory:
            root = Path(directory)
            bins = root / "bin"
            bins.mkdir()
            dotfiles = root / ".dotfiles"
            (dotfiles / "bin").mkdir(parents=True)
            (dotfiles / "brew").mkdir()
            (dotfiles / "brew" / "Brewfile").write_text('brew "example/tools/tool"\n')
            stub = """#!/bin/sh
name=${0##*/}
echo "$name $*" >> "$CALL_LOG"
case "$name:$*" in
  "brew:trust --help") exit 0 ;;
  "brew:info --json=v2 --formula tool")
    echo '{"formulae":[{"tap":"homebrew/core"}]}'; exit 0 ;;
  "brew:outdated --formula")
    [ "$FAILURE" = formula-list ] && exit 9
    [ "$FAILURE" = formula-upgrade ] && echo tool
    [ "$FAILURE" = pinned ] && printf 'tool\\nexample/tools/pinned-tool\\n'
    exit 0 ;;
  "brew:list --pinned")
    [ "$FAILURE" = pinned ] && printf 'tool\\npinned-tool\\n'
    exit 0 ;;
  "brew:outdated --cask")
    [ "$FAILURE" = cask-list ] && exit 9
    [ "$FAILURE" = cask-upgrade ] && echo application
    exit 0 ;;
  "brew:update") [ "$FAILURE" = brew-update ] && exit 9 ;;
  "brew:upgrade --formula tool") exit 9 ;;
  "brew:upgrade --cask application") exit 9 ;;
  "brew:trust --formula example/tools/tool") [ "$FAILURE" = trust ] && exit 9 ;;
  "npm:update -g") [ "$FAILURE" = npm ] && exit 9 ;;
  "mas:outdated") [ "$FAILURE" = sudo ] && echo '123 Application (1 -> 2)' ;;
  "sudo:"*) exit 1 ;;
  "llm:prompt"*) cat >/dev/null; [ "$FAILURE" = analysis ] && exit 7 ;;
esac
exit 0
"""
            for command in ("brew", "npm", "mise", "gh", "mas", "sudo"):
                path = bins / command
                path.write_text(stub)
                path.chmod(0o755)
            wrapper = dotfiles / "bin" / "llm"
            wrapper.write_text(stub)
            wrapper.chmod(0o755)
            log = root / "calls"
            env = dict(os.environ, HOME=str(root), PATH=f"{bins}:/usr/bin:/bin",
                       CALL_LOG=str(log), FAILURE=failure)
            result = subprocess.run(["/bin/zsh", str(SCRIPT), *args], env=env,
                                    stdin=subprocess.DEVNULL, capture_output=True,
                                    text=True, timeout=15)
            return result, log.read_text()

    def test_success(self):
        result, calls = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("llm prompt --no-log --no-stream -m ", calls)
        self.assertNotIn("bundle cleanup", calls)

    def test_update_failures_survive_successful_analysis(self):
        for failure in ("brew-update", "formula-list", "formula-upgrade",
                        "cask-list", "cask-upgrade", "trust", "npm", "sudo"):
            with self.subTest(failure=failure):
                result, calls = self.run_updater(failure)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("One or more software update steps failed.", result.stdout)
                self.assertIn("llm prompt ", calls)
                if failure == "brew-update":
                    self.assertNotIn("All Homebrew formulae are up to date.", result.stdout)
                if failure == "sudo":
                    self.assertIn("sudo -n -v", calls)

    def test_analysis_failure(self):
        result, _ = self.run_updater("analysis")
        self.assertEqual(result.returncode, 7, result.stdout + result.stderr)

    def test_safe_mode_still_defers_broad_updates(self):
        result, calls = self.run_updater(args=("--safe",))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("npm update -g", calls)
        self.assertIn("llm ensure-copilot-plugin", calls)

    def test_pinned_formulae_are_reported_without_upgrade(self):
        result, calls = self.run_updater("pinned")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Skipping pinned Homebrew formula: tool", result.stdout)
        self.assertIn("Skipping pinned Homebrew formula: example/tools/pinned-tool", result.stdout)
        self.assertNotIn("brew upgrade --formula", calls)


if __name__ == "__main__":
    unittest.main(verbosity=2)
