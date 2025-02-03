#!/bin/bash

if [[ $OSTYPE != darwin* ]]; then
  echo "This script will only run on MacOS"
  exit 1
fi

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

if ! command -v brew &> /dev/null; then
  echo "-> Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "-> Installing homebrew packages"
brew update
brew bundle --file=~/.dotfiles/brew/Brewfile

if ! plutil -extract Window\ Settings.One\ Dark xml1 -o - ~/Library/Preferences/com.apple.Terminal.plist > /dev/null; then
  echo "-> Importing Terminal themes"
  ~/.dotfiles/themes/import.sh
fi

echo "-> Importing iTerm2 settings"
~/.dotfiles/iterm/import.sh

if [ ! -d ~/github ]; then
  echo "-> Creating ~/github directory"
  mkdir -p ~/github
fi

if [ ! -d ~/github/vpn ]; then
  echo "-> Cloning github/vpn"
  cd ~/github
  git clone https://github.com/github/vpn
fi

if [ ! -d ~/.hammerspoon ]; then
  echo "-> Creating ~/.hammerspoon directory"
  ln -s ~/.dotfiles/hammerspoon ~/.hammerspoon
fi
