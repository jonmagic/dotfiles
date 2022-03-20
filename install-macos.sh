#!/bin/bash

if [[ $OSTYPE != darwin* ]]; then
  echo "This script will only run on MacOS"
  exit 1
fi

DOTFILES_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ ! -d ~/.dotfiles ]; then
  ln -s $DOTFILES_DIR ~/.dotfiles
fi

if [ ! -f ~/.gitconfig ]; then
  echo "-> Symlinking .gitconfig"
  ln -s ~/.dotfiles/.gitconfig-global ~/.gitconfig
fi

if [ ! -f ~/.gitignore ]; then
  echo "-> Symlinking .gitignore"
  ln -s ~/.dotfiles/.gitignore-global ~/.gitignore
fi

echo "-> Downloading latest antigen.zsh"
curl -sL git.io/antigen > ~/.dotfiles/antigen.zsh

if [ ! -f ~/.zshrc ]; then
  echo "-> Copying .zshrc to home folder"
  cp ~/.dotfiles/zshrc.original ~/.zshrc
fi

if ! command -v brew &> /dev/null; then
  echo "-> Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "-> Installing homebrew packages"
brew update
brew bundle --file=~/.dotfiles/brewfiles/Brewfile

if [[ $CPUTYPE == arm64 ]]; then
  echo "-> Installing homebrew Cask packages"
  brew bundle --file=~/.dotfiles/brewfiles/Caskfile
fi

if ! plutil -extract Window\ Settings.One\ Dark xml1 -o - ~/Library/Preferences/com.apple.Terminal.plist > /dev/null; then
  echo "-> Importing Terminal themes"
  ~/.dotfiles/themes/import.sh
fi

if [ ! -d ~/github ]; then
  echo "-> Creating ~/github directory"
  mkdir -p ~/github
fi

if [ ! -d ~/github/vpn ]; then
  echo "-> Cloning github/vpn"
  cd ~/github
  git clone https://github.com/github/vpn
fi
