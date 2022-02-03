#!/usr/bin/env bash

plutil -extract Window\ Settings.One\ Dark xml1 -o - ~/Library/Preferences/com.apple.Terminal.plist > one-dark.xml
plutil -extract Window\ Settings.One\ Light xml1 -o - ~/Library/Preferences/com.apple.Terminal.plist > one-light.xml
