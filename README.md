# These are my dotfiles

Getting started:

```bash
sudo softwareupdate -i -a
bash -c "`curl -fsSL https://raw.githubusercontent.com/jonmagic/dotfiles/main/remote-install.sh`"
```

## Terminal help

The first local interactive terminal opened each day prints a workflow-focused command guide sourced from:

- `sources/aliases`
- `sources/functions.zsh`
- executable scripts in `bin/`

Run `help` at any time to show the guide again, `help all` for the full implementation inventory, `help <name>` for one command, or `help ollama` for on-demand Ollama service instructions.

## Software update package sources

`update-software` keeps its safe/default and `--all` lanes: Copilot CLI stays on `@github/copilot@prerelease`, and blanket global npm updates remain `--all` only. Both npm lanes use `gh cfs -- npm` with the explicit CFS npm registry and `replace-registry-host=npmjs`. Each lane captures `npm prefix -g` before CFS replaces npm's user/global configuration, retaining the active Node installation's global destination even when run from another project. Global operations do not consume that project's npm configuration or lockfile; no project lockfiles are migrated. Azure MCP retains its separate fixed prefix and pin with the same explicit feed routing.

The `llm` plugin installer uses the existing `uv` executable through `gh cfs -- uv`, targeting the Python executable in Homebrew `llm`'s shebang. It disables ambient uv project configuration, cache reuse, and Python downloads, and selects only the CFS PyPI default index. The plugin itself remains pinned to GitHub commit `e4a37e2c8d105a7a26dea06569ea369c5862b42d`, an intentional direct Git source for Responses API support; its registry dependencies and build dependencies resolve through CFS. Upgrades reinstall only the plugin without first uninstalling the working copy.

These lanes require an installed `gh-cfs`, an existing CFS login, and feed access; the Python lane also requires the already-managed `uv`. Missing prerequisites, authentication, or feed access fail visibly with no direct npm/PyPI fallback. Source configuration is not network-egress enforcement: direct Git sources and package build/lifecycle scripts remain separate trust boundaries. Changes affect future invocations, not updater functions already loaded by a running shell.

## Scheduled note synchronization

`com.jonmagic.brain-commit` supervises `bin/brain-commit --watch`, which waits five minutes between completed sync attempts rather than relying on deferrable launchd interval events. Failed attempts are logged and retried. It preserves Copilot session directories and indexed conversation history, and writes diagnostics to `~/Library/Logs/brain-commit.log`. After changing its LaunchAgent configuration, reload the job with `launchctl bootout gui/$(id -u)/com.jonmagic.brain-commit` followed by `launchctl bootstrap gui/$(id -u) ~/.dotfiles/bin/com.jonmagic.brain-commit.plist` and `launchctl kickstart gui/$(id -u)/com.jonmagic.brain-commit`. To pause synchronization, boot out the job; killing its process alone causes launchd to restart it.

## T3 availability monitoring

`com.jonmagic.t3-healthcheck` supervises `bin/t3-healthcheck --watch`. Every five minutes it requires the T3 background service to be running and T3 Connect to report that other devices can reach Wasp before checking in with Dead Man's Snitch. The machine-local snitch URL belongs at `~/.config/t3/deadmanssnitch-url` with mode `0600`; it must never be committed. Logs are written to `~/Library/Logs/t3-healthcheck.log`.

## Copilot CLI credentials

`copilot` and `c` run through `bin/copilot`. On macOS, the wrapper first looks for a machine-local manifest at `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/copilot-keychain-credentials`, then falls back to the repository manifest at `sources/copilot-keychain-credentials`. It passes declared credentials to the launched Copilot process through environment variables. The manifest is non-secret and uses this format:

```text
# label|environment_variable|keychain_service|keychain_account|requiredness
Example|COPILOT_MCP_EXAMPLE_TOKEN|copilot-mcp-example||optional
```

A blank account uses the current macOS user. Required credentials fail closed when their Keychain item is missing or empty; optional credentials are skipped. Set `COPILOT_KEYCHAIN_CREDENTIALS_FILE` to use a different non-secret manifest. Keep work-only declarations in the machine-local manifest so personal machines use the empty repository fallback.

To add another credential:

1. Add a manifest row using a `COPILOT_MCP_` environment variable.
2. Reference `${COPILOT_MCP_NAME_TOKEN}` from the MCP configuration.
3. Store the credential with an interactive Keychain prompt:

```sh
security add-generic-password \
  -U \
  -a "$USER" \
  -s copilot-mcp-name \
  -w
```

Keep `-w` last so the credential is prompted for rather than placed in shell history or process arguments. Work-only integrations and credentials do not belong in this personal repository. Non-macOS installations skip the Keychain integration.

## Azure MCP

`install-macos.sh` and `update-software` use `bin/ensure-azure-mcp` to install the first-party `@azure/mcp@3.0.0` npm package through `gh cfs`, not the Brewfile or a floating `npx` package. This requires Node.js 22 or later, npm, and Azure CLI authentication with CFS feed access. macOS setup installs the `github/gh-cfs` GitHub CLI extension pinned to v0.3.0 if it is missing. The installer fails visibly when a prerequisite or feed access is missing; it does not install from the public npm registry. It verifies the native platform package is present so the launcher does not need to fetch it at startup.

The direct launcher is `$HOME/.local/share/dotfiles/npm/bin/azmcp` (on this Mac, `/Users/jonmagic/.local/share/dotfiles/npm/bin/azmcp`). Point the machine-local Copilot MCP server command there, retaining its `server start` arguments. The fixed prefix is independent of mise's Node versions and of `npm update -g` in `update-software --all`. Do not commit machine-local Copilot MCP settings or feed credentials.
