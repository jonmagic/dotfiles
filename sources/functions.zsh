function homebrew() {
  brew update && brew outdated && brew upgrade
}

function update_software() {
  echo "==> Upgrading antigen plugins"
  antigen update
  echo ""

  echo "==> Upgrading gh extensions"
  gh extension upgrade --all
  echo ""

  echo "==> Upgrading asdf plugins"
  asdf plugin update --all
  echo ""

  echo "==> Upgrading homebrew"
  homebrew
  echo ""

  echo "==> Upgrading Mac App Store apps"
  mas upgrade
}
