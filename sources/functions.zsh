function homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed; skipping."
    return 0
  fi

  brew update && brew outdated && brew upgrade && brew bundle cleanup --force --file="$HOME/.dotfiles/brew/Brewfile"
}

function update_software() {
  echo "==> Upgrading antigen plugins"
  if command -v antigen >/dev/null 2>&1; then
    antigen update
  else
    echo "antigen not installed; skipping."
  fi
  echo ""

  echo "==> Upgrading gh extensions"
  if command -v gh >/dev/null 2>&1; then
    gh extension upgrade --all
  else
    echo "GitHub CLI not installed; skipping."
  fi
  echo ""

  echo "==> Upgrading asdf plugins"
  if command -v asdf >/dev/null 2>&1; then
    asdf plugin update --all
  else
    echo "asdf not installed; skipping."
  fi
  echo ""

  echo "==> Upgrading homebrew"
  homebrew
  echo ""

  echo "==> Upgrading Mac App Store apps"
  if command -v mas >/dev/null 2>&1; then
    mas upgrade
  else
    echo "mas CLI not installed; skipping."
  fi
}
