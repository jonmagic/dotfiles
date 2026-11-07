import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bin" / "update-software"
NPM_REGISTRY = "https://pkgs.dev.azure.com/github-cfs/GitHubCFS/_packaging/github-cfs-oss/npm/registry/"
PYPI_INDEX = "https://pkgs.dev.azure.com/github-cfs/GitHubCFS/_packaging/github-cfs-pypi/pypi/simple/"
PLUGIN_SPEC = "git+https://github.com/jmdaly/llm-github-copilot.git@e4a37e2c8d105a7a26dea06569ea369c5862b42d"


class UpdateSoftwareTests(unittest.TestCase):
    def run_updater(self, failure="", args=("--all",), gh_available=True):
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
  "gh:cfs -- "*)
    [ "$FAILURE" = cfs ] && { echo 'CFS authentication failed' >&2; exit 13; }
    shift 2
    export WRAPPED=1
    exec "$@" ;;
  "npm:prefix -g")
    [ "$FAILURE" = prefix ] && exit 8
    [ "$WRAPPED" = 1 ] && echo /wrong-prefix || echo "$HOME/global-node"
    exit 0 ;;
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
  "npm:update -g"*) [ "$FAILURE" = npm ] && exit 9 ;;
  "npm:install -g @github/copilot@prerelease"*) [ "$FAILURE" = copilot ] && exit 9 ;;
  "mas:outdated") [ "$FAILURE" = sudo ] && echo '123 Application (1 -> 2)' ;;
  "sudo:"*) exit 1 ;;
  "llm:prompt"*) cat >/dev/null; [ "$FAILURE" = analysis ] && exit 7 ;;
esac
exit 0
"""
            for command in ("brew", "npm", "mise", "gh", "mas", "sudo"):
                if command == "gh" and not gh_available:
                    continue
                path = bins / command
                path.write_text(stub)
                path.chmod(0o755)
            wrapper = dotfiles / "bin" / "llm"
            wrapper.write_text(stub)
            wrapper.chmod(0o755)
            azure = dotfiles / "bin" / "ensure-azure-mcp"
            azure.write_text(stub)
            azure.chmod(0o755)
            log = root / "calls"
            env = dict(os.environ, HOME=str(root), PATH=f"{bins}:/usr/bin:/bin",
                       CALL_LOG=str(log), FAILURE=failure, WRAPPED="0")
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
                        "cask-list", "cask-upgrade", "trust", "npm", "copilot", "sudo"):
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

    def test_npm_children_use_cfs_and_preserve_global_prefix(self):
        for mode in ("--safe", "--all"):
            with self.subTest(mode=mode):
                result, calls = self.run_updater(args=(mode,))
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                installs = [line for line in calls.splitlines()
                            if line.startswith(("npm install", "npm update"))]
                self.assertEqual(len(installs), 2 if mode == "--all" else 1)
                self.assertIn("npm install -g @github/copilot@prerelease", calls)
                for line in installs:
                    self.assertIn(f"--registry={NPM_REGISTRY}", line)
                    self.assertIn("--replace-registry-host=npmjs", line)
                    self.assertIn("/global-node", line)
                    self.assertNotIn("/wrong-prefix", line)
                    self.assertIn("gh cfs -- " + line, calls)

    def test_cfs_failures_do_not_fall_back_to_npm(self):
        for failure, gh_available in (("cfs", True), ("prefix", True), ("", False)):
            with self.subTest(failure=failure, gh_available=gh_available):
                result, calls = self.run_updater(failure, gh_available=gh_available)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertNotIn("\nnpm install", calls)
                self.assertNotIn("\nnpm update", calls)
                self.assertIn("One or more software update steps failed.", result.stdout)

    def test_pinned_formulae_are_reported_without_upgrade(self):
        result, calls = self.run_updater("pinned")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Skipping pinned Homebrew formula: tool", result.stdout)
        self.assertIn("Skipping pinned Homebrew formula: example/tools/pinned-tool", result.stdout)
        self.assertNotIn("brew upgrade --formula", calls)


class PluginSourceTests(unittest.TestCase):
    def run_plugin(self, command, installed=False, cfs_failure=False,
                   uv_available=True, valid_shebang=True):
        with tempfile.TemporaryDirectory(prefix="llm-cfs-test-") as directory:
            root = Path(directory)
            bins = root / "bin"
            bins.mkdir()
            log = root / "calls"
            python = Path("/bin/sh")
            llm = bins / "llm"
            llm.write_text(("#!/bin/sh\n" if valid_shebang else "#!/usr/bin/env python\n") + """
echo "llm $*" >> "$CALL_LOG"
if [ "$1" = plugins ] && [ "$INSTALLED" = 1 ]; then
  echo '[{"name": "llm-github-copilot"}]'
fi
""")
            llm.chmod(0o755)
            gh = bins / "gh"
            gh.write_text("""#!/bin/sh
echo "gh $*" >> "$CALL_LOG"
[ "$CFS_FAILURE" = 1 ] && { echo 'CFS feed access failed' >&2; exit 13; }
[ "$1" = cfs ] && [ "$2" = -- ] || exit 99
shift 2
exec "$@"
""")
            gh.chmod(0o755)
            if uv_available:
                uv = bins / "uv"
                uv.write_text("""#!/bin/sh
echo "uv $*" >> "$CALL_LOG"
""")
                uv.chmod(0o755)
            env = dict(os.environ, HOME=str(root), PATH=f"{bins}:/usr/bin:/bin",
                       LLM_BIN=str(llm), CALL_LOG=str(log),
                       INSTALLED=str(int(installed)), CFS_FAILURE=str(int(cfs_failure)))
            result = subprocess.run(["/bin/bash", str(SCRIPT.parent / "llm"), command],
                                    env=env, capture_output=True, text=True, timeout=15)
            return result, log.read_text() if log.exists() else "", str(python)

    def test_plugin_installs_into_llm_environment_through_cfs(self):
        for command in ("ensure-copilot-plugin", "upgrade-copilot-plugin"):
            with self.subTest(command=command):
                result, calls, python = self.run_plugin(command)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                child = next(line for line in calls.splitlines() if line.startswith("uv "))
                self.assertIn("gh cfs -- " + child, calls)
                self.assertIn("uv --no-config --no-cache --no-python-downloads pip install", child)
                self.assertIn(f"--python {python}", child)
                self.assertIn(f"--default-index {PYPI_INDEX}", child)
                self.assertIn(PLUGIN_SPEC, child)
                self.assertEqual("--reinstall-package llm-github-copilot" in child,
                                 command == "upgrade-copilot-plugin")
                self.assertNotIn("llm install", calls)
                self.assertNotIn("llm uninstall", calls)

    def test_ensure_keeps_existing_plugin_without_fetching(self):
        result, calls, _ = self.run_plugin("ensure-copilot-plugin", installed=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("gh cfs", calls)
        self.assertNotIn("uv ", calls)

    def test_failed_install_preserves_plugin_and_has_no_fallback(self):
        for options, expected_status in (({"cfs_failure": True}, 13),
                                         ({"uv_available": False}, 127),
                                         ({"valid_shebang": False}, 1)):
            with self.subTest(options=options):
                result, calls, _ = self.run_plugin("upgrade-copilot-plugin",
                                                   installed=True, **options)
                self.assertEqual(result.returncode, expected_status, result.stdout + result.stderr)
                self.assertNotIn("\nuv ", calls)
                self.assertNotIn("llm install", calls)
                self.assertNotIn("llm uninstall", calls)
                self.assertTrue(result.stderr)


class AzureSourceTests(unittest.TestCase):
    def test_fixed_prefix_install_uses_explicit_cfs_source(self):
        for failure in ("", "cfs"):
            with self.subTest(failure=failure):
                with tempfile.TemporaryDirectory(prefix="azure-cfs-test-") as directory:
                    root = Path(directory)
                    bins = root / "bin"
                    bins.mkdir()
                    log = root / "calls"
                    marker = root / "installed"
                    stub = """#!/bin/sh
name=${0##*/}
echo "$name $*" >> "$CALL_LOG"
case "$name:$*" in
  "node:-p "*) echo 25 ;;
  "gh:cfs help") exit 0 ;;
  "gh:cfs -- "*)
    [ "$FAILURE" = cfs ] && { echo 'CFS feed access failed' >&2; exit 13; }
    shift 2
    exec "$@" ;;
  "npm:install "*)
    mkdir -p "$HOME/.local/share/dotfiles/npm/bin"
    touch "$HOME/.local/share/dotfiles/npm/bin/azmcp" "$MARKER"
    chmod +x "$HOME/.local/share/dotfiles/npm/bin/azmcp" ;;
  "node:-e "*) test -f "$MARKER" ;;
esac
"""
                    for command in ("node", "npm", "gh"):
                        path = bins / command
                        path.write_text(stub)
                        path.chmod(0o755)
                    env = dict(os.environ, HOME=str(root), PATH=f"{bins}:/usr/bin:/bin",
                               CALL_LOG=str(log), MARKER=str(marker), FAILURE=failure)
                    result = subprocess.run(["/bin/bash", str(SCRIPT.parent / "ensure-azure-mcp")],
                                            env=env, capture_output=True, text=True, timeout=15)
                    calls = log.read_text()
                    if failure:
                        self.assertEqual(result.returncode, 13, result.stdout + result.stderr)
                        self.assertNotIn("\nnpm install", calls)
                        self.assertFalse(marker.exists())
                    else:
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                        child = next(line for line in calls.splitlines()
                                     if line.startswith("npm install"))
                        self.assertIn("gh cfs -- " + child, calls)
                        self.assertIn(f"--prefix {root}/.local/share/dotfiles/npm", child)
                        self.assertIn(f"--registry={NPM_REGISTRY}", child)
                        self.assertIn("--replace-registry-host=npmjs", child)
                        self.assertIn("@azure/mcp@3.0.0", child)


if __name__ == "__main__":
    unittest.main(verbosity=2)
