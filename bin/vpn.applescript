#!/usr/bin/osascript

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title vpn
# @raycast.mode compact

# Optional parameters:
# @raycast.icon ☎️

# Documentation:
# @raycast.description connect to github vpn
# @raycast.author Jonathan Hoyt
# @raycast.authorURL https://github.com/jonmagic

tell application "Viscosity" to connect "github-iad-prod"
do shell script "open https://fido-challenger.githubapp.com/auth/vpn-prod"
