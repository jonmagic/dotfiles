#!/usr/bin/env bash

theme=$(<~/.dotfiles/themes/one-dark.xml)
plutil -replace Window\ Settings.One\ Dark -xml "$theme" ~/Library/Preferences/com.apple.Terminal.plist
defaults write com.apple.Terminal "Default Window Settings" -string "One Dark"
defaults write com.apple.Terminal "Startup Window Settings" -string "One Dark"

theme=$(<~/.dotfiles/themes/one-light.xml)
plutil -replace Window\ Settings.One\ Light -xml "$theme" ~/Library/Preferences/com.apple.Terminal.plist

echo "Quit the Terminal app, re-open, and the theme should now be applied."
