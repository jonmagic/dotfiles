# mise shell integration

if command -v mise >/dev/null 2>&1; then
  # Be explicit about where the global config lives (installed via ~/.dotfiles).
  : "${MISE_GLOBAL_CONFIG_FILE:=$HOME/.config/mise/config.toml}"
  export MISE_GLOBAL_CONFIG_FILE

  # Activate only for interactive shells.
  if [[ -o interactive ]]; then
    eval "$(mise activate zsh)"
  fi
fi
