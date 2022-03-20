#!/bin/bash

if [[ ! -n "$CODESPACES" ]]; then
  echo "This script will not run outside of a Codespace"
  exit 1
fi

set -x

rm -f $HOME/.gitconfig
rm -rf $HOME/.oh-my-zsh
rm -f $HOME/.zshrc

DOTFILES_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ ! -d ~/.dotfiles ]; then
  ln -s $DOTFILES_DIR ~/.dotfiles
fi

~/.dotfiles/gitconfig/setup.sh

echo "-> Downloading latest antigen.zsh"
curl -sL git.io/antigen > ~/.dotfiles/antigen.zsh

if [ ! -f ~/.zshrc ]; then
  echo "-> Copying .zshrc to home folder"
  cp ~/.dotfiles/sources/zshrc ~/.zshrc
fi

sudo chsh -s "$(which zsh)" "$(whoami)"
