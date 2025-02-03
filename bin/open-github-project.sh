#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title open github project
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "project" }

# Documentation:
# @raycast.author Jonathan Hoyt
# @raycast.authorURL https://github.com/jonmagic

open "hammerspoon://openGitHubProject?path=$1"
