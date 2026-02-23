# mise shell integration
#
# Goal: allow mise to coexist with asdf without changing current asdf behavior.
# Default policy here is conservative:
# - do NOT read .tool-versions (asdf) by default
# - do not set global runtime versions (node/python/ruby) by default
#
# If/when you want mise to honor .tool-versions, remove the override below.

if command -v mise >/dev/null 2>&1; then
  # Early-init setting: tells mise which "tool-versions" filenames to read.
  # Setting to "none" prevents mise from treating asdf projects as mise projects.
  : "${MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES:=none}"
  export MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES

  # Be explicit about where the global config lives (installed via ~/.dotfiles).
  : "${MISE_GLOBAL_CONFIG_FILE:=$HOME/.config/mise/config.toml}"
  export MISE_GLOBAL_CONFIG_FILE

  # Activate only for interactive shells.
  if [[ -o interactive ]]; then
    eval "$(mise activate zsh)"
  fi
fi
