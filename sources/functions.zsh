function homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed; skipping."
    return 0
  fi

  brew update && brew outdated && brew upgrade && brew bundle cleanup --force --no-vscode --file="$HOME/.dotfiles/brew/Brewfile"
}
