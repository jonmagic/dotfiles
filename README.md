# These are my dotfiles

Getting started:

```bash
sudo softwareupdate -i -a
bash -c "`curl -fsSL https://raw.githubusercontent.com/jonmagic/dotfiles/main/remote-install.sh`"
```

## Terminal help

Opening a new local interactive terminal prints a workflow-focused command guide sourced from:

- `sources/aliases`
- `sources/functions.zsh`
- executable scripts in `bin/`

Run `help` at any time to show the guide again, `help all` for the full implementation inventory, `help <name>` for one command, or `help ollama` for on-demand Ollama service instructions.

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
