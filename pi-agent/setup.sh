#!/usr/bin/env bash
set -euo pipefail

source_dir="$HOME/.dotfiles/pi-agent"
target_dir="$HOME/.pi/agent"

mkdir -p "$target_dir"

install_config() {
  local name="$1"
  local source="$source_dir/$name"
  local target="$target_dir/$name"

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    return 0
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    echo "Pi config already exists and was not replaced: $target" >&2
    exit 1
  fi

  echo "-> Symlinking Pi $name"
  ln -s "$source" "$target"
}

install_config models.json
install_config settings.json
