#!/bin/bash

set -euo pipefail

if [[ ! -d "$HOME/.config" ]]; then
  mkdir -p "$HOME/.config"
fi

mkdir -p "$HOME/.config/mise"

# Don't overwrite an existing config (user may already have one).
# Note: mise uses a trust model for config files; symlinking to ~/.dotfiles can
# show up as an untrusted config path. Copying avoids that.
if [[ ! -e "$HOME/.config/mise/config.toml" ]]; then
  echo "-> Installing mise config.toml"
  cp "$HOME/.dotfiles/mise-config/config.toml" "$HOME/.config/mise/config.toml"
elif [[ -L "$HOME/.config/mise/config.toml" ]]; then
  # If an older version of these dotfiles symlinked this file, replace it with a copy.
  link_target="$(readlink "$HOME/.config/mise/config.toml" || true)"
  if [[ "$link_target" == "$HOME/.dotfiles/mise/config.toml" ]] || [[ "$link_target" == "$HOME/.dotfiles/mise-config/config.toml" ]]; then
    echo "-> Replacing mise config.toml symlink with a regular file"
    rm "$HOME/.config/mise/config.toml"
    cp "$HOME/.dotfiles/mise-config/config.toml" "$HOME/.config/mise/config.toml"
  fi
fi
