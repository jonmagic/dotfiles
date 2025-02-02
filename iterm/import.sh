#!/bin/bash

# Import iTerm2 preferences
defaults write com.googlecode.iterm2 "$(cat ~/.dotfiles/iterm/iterm2.plist)"
echo "iTerm2 settings imported from ~/.dotfiles/iterm/iterm2.plist"
