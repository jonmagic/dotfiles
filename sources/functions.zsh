# Toggle demo mode — hides cloud/work context from the prompt
function demo-on() {
  cat > "$HOME/.spaceshiprc.zsh" <<'EOF'
# Demo mode — minimal prompt, no work context
SPACESHIP_PROMPT_ORDER=(
  dir
  git
  node
  exec_time
  line_sep
  char
)
SPACESHIP_RPROMPT_ORDER=()
EOF
  echo "Demo mode ON. Restart your shell or run: source ~/.zshrc"
}

function demo-off() {
  rm -f "$HOME/.spaceshiprc.zsh"
  echo "Demo mode OFF. Restart your shell or run: source ~/.zshrc"
}

function homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed; skipping."
    return 0
  fi

  brew update && brew outdated && brew upgrade && brew bundle cleanup --force --no-vscode --file="$HOME/.dotfiles/brew/Brewfile"
}
