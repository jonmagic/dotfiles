#!/bin/bash

if [ ! -f ~/.gitconfig ]; then
  echo "-> Symlinking .gitconfig"
  ln -s ~/.dotfiles/gitconfig/gitconfig ~/.gitconfig
fi

if [ ! -f ~/.gitignore ]; then
  echo "-> Symlinking .gitignore"
  ln -s ~/.dotfiles/gitconfig/gitignore ~/.gitignore
fi
