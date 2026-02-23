#!/bin/bash

mkdir -p ~/.config/ghostty

if [ -f ~/.config/ghostty/config ] && [ ! -L ~/.config/ghostty/config ]; then
  echo "-> Backing up existing Ghostty config to ~/.config/ghostty/config.bak"
  mv ~/.config/ghostty/config ~/.config/ghostty/config.bak
fi

if [ ! -L ~/.config/ghostty/config ]; then
  echo "-> Symlinking Ghostty config"
  ln -s ~/.dotfiles/ghostty/config ~/.config/ghostty/config
fi
