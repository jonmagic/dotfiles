# mise shell integration

if command -v mise >/dev/null 2>&1; then
  # Be explicit about where the global config lives (installed via ~/.dotfiles).
  : "${MISE_GLOBAL_CONFIG_FILE:=$HOME/.config/mise/config.toml}"
  export MISE_GLOBAL_CONFIG_FILE

  # Activate only for interactive shells.
  if [[ -o interactive ]]; then
    mise_bin="$(command -v mise)"
    mise_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
    mise_cache="$mise_cache_dir/mise-activate.zsh"

    if [[ ! -s "$mise_cache" || "$mise_bin" -nt "$mise_cache" ]]; then
      mkdir -p "$mise_cache_dir"
      mise_cache_tmp="$mise_cache.$$"
      if "$mise_bin" activate zsh >| "$mise_cache_tmp"; then
        mv "$mise_cache_tmp" "$mise_cache"
      else
        rm -f "$mise_cache_tmp"
        return 1
      fi
    fi

    source "$mise_cache"
    unset mise_bin mise_cache_dir mise_cache mise_cache_tmp
  fi
fi
