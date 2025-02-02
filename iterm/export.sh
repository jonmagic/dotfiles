#!/bin/bash

# Export iTerm2 preferences
defaults read com.googlecode.iterm2 > ~/.dotfiles/iterm/iterm2.plist
echo "iTerm2 settings exported to ~/.dotfiles/iterm/iterm2.plist"
