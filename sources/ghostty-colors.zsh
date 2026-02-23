# ghostty-colors.zsh -- Persistent per-directory color tinting for Ghostty tabs
#
# Every directory gets a deterministic color + emoji the first time you
# visit it. The assignment is stored in ~/.config/ghostty/path-colors.json
# so it stays consistent across sessions.
#
# SSH sessions get a separate warm-toned palette.
# Supports both dark (Niji) and light (Dayfox) Ghostty themes and
# reacts to macOS light/dark mode changes on every prompt.
#
# Only activates inside Ghostty.

# Bail out if not running in Ghostty
case "$TERM" in
  xterm-ghostty) ;;
  *) [[ -z "$GHOSTTY_RESOURCES_DIR" ]] && return ;;
esac

# Disable oh-my-zsh's auto-title -- this script manages tab titles with emoji
DISABLE_AUTO_TITLE=true

# ---------------------------------------------------------------------------
# Palette -- subtle tints that pair well with Niji (dark) and Dayfox (light)
# ---------------------------------------------------------------------------

# Cool tones for local directories (dark mode)
typeset -ga _GTC_PROJECT_COLORS_DARK=(
  "#1a1e2a"   # slate blue
  "#1a2626"   # deep teal
  "#221a2e"   # plum
  "#1a2e1f"   # forest
  "#261a26"   # mauve
  "#1a2630"   # steel
  "#26261a"   # olive
  "#1a2e26"   # sea green
  "#261a2e"   # violet
  "#1a2e2e"   # cyan
  "#201a2e"   # indigo
  "#1a2e28"   # jade
)

# Cool tones for local directories (light mode)
typeset -ga _GTC_PROJECT_COLORS_LIGHT=(
  "#e8ecf6"   # slate blue
  "#e4f0f0"   # teal mist
  "#ede4f4"   # plum
  "#e4f0e8"   # forest
  "#f0e4f0"   # mauve
  "#e4ecf2"   # steel
  "#eeeed8"   # olive
  "#e4f0ec"   # sea green
  "#ede4f4"   # violet
  "#e4f0f0"   # cyan
  "#e8e4f4"   # indigo
  "#e4f0ea"   # jade
)

# Warm tones for SSH hosts (dark mode)
typeset -ga _GTC_SSH_COLORS_DARK=(
  "#2e1c1c"   # brick
  "#2e261a"   # amber
  "#2e201a"   # burnt orange
  "#261c1c"   # rosewood
  "#2e241a"   # golden brown
  "#261a1a"   # dark cherry
  "#2e2620"   # copper
  "#2e1a1a"   # deep red
)

# Warm tones for SSH hosts (light mode)
typeset -ga _GTC_SSH_COLORS_LIGHT=(
  "#f6e8e8"   # brick
  "#f4eee0"   # amber
  "#f6e8e0"   # burnt orange
  "#f0e6e6"   # rosewood
  "#f4ece0"   # golden brown
  "#f0e4e4"   # dark cherry
  "#f4eee6"   # copper
  "#f6e4e4"   # deep red
)

# Default backgrounds from the Ghostty themes
_GTC_DEFAULT_BG_DARK="#141515"    # Niji
_GTC_DEFAULT_BG_LIGHT="#f6f2ee"   # Dayfox

# Emojis -- indexed by hash to visually distinguish tabs
typeset -ga _GTC_PROJECT_DOTS=( 🔷 🍀 🔮 🌰 ⭐ 💎 🌿 🌕 🪻 🧊 🎯 🍃 )
typeset -ga _GTC_SSH_DOTS=( 🔥 🍊 🌅 🌹 🌻 🍒 🥧 ♦️ )

# State
_GTC_CURRENT_TITLE=""
_GTC_SSH_ACTIVE=""
_GTC_LAST_APPEARANCE=""   # "dark" or "light" -- used to detect mode changes
_GTC_CURRENT_IDX=""       # palette index of current directory (1-based)
_GTC_CURRENT_DOT=""       # emoji for current directory

# Persistent storage
_GTC_DB="$HOME/.config/ghostty/path-colors.json"

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

_gtc_hash() {
  local s="$1" h=0 i
  for (( i=0; i<${#s}; i++ )); do
    h=$(( (h * 31 + $(printf '%d' "'${s:$i:1}")) % 65536 ))
  done
  echo $h
}

# Detect dark vs light mode via macOS appearance
_gtc_is_dark() {
  [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == "Dark" ]]
}

_gtc_appearance() {
  if _gtc_is_dark; then echo "dark"; else echo "light"; fi
}

_gtc_default_bg() {
  if [[ "$1" == "dark" ]]; then
    echo "$_GTC_DEFAULT_BG_DARK"
  else
    echo "$_GTC_DEFAULT_BG_LIGHT"
  fi
}

# Shorten paths for tab titles:
#   /Users/jon/code/foo/bar  -> ~/code/foo/bar
#   /Users/jon               -> ~
_gtc_short_cwd() {
  if [[ "$PWD" == "$HOME" ]]; then
    echo "~"
  elif [[ "$PWD" == "$HOME/"* ]]; then
    echo "~${PWD#$HOME}"
  else
    echo "$PWD"
  fi
}

_gtc_set_bg() {
  printf '\033]11;%s\007' "$1"
}

_gtc_set_title() {
  printf '\033]2;%s\007' "$1"
  _GTC_CURRENT_TITLE="$1"
}

# Prefix for tab titles -- includes hostname when in an SSH session
if [[ -n "$SSH_CONNECTION" ]]; then
  _GTC_HOST_PREFIX="${HOST%%.*}: "
else
  _GTC_HOST_PREFIX=""
fi

# ---------------------------------------------------------------------------
# Persistent color DB -- simple JSON using only zsh builtins + sed
#
# Format: {"<path>": <index>, ...}
# The index is 0-based into the palette arrays. The emoji is derived
# from the same index so we only need to store one number.
# ---------------------------------------------------------------------------

_gtc_db_ensure() {
  if [[ ! -f "$_GTC_DB" ]]; then
    mkdir -p "${_GTC_DB:h}"
    echo '{}' > "$_GTC_DB"
  fi
}

# Look up a path in the DB. Prints the index or nothing if not found.
_gtc_db_get() {
  _gtc_db_ensure
  local key="$1"
  # Extract value for this exact key from the JSON
  sed -n 's/.*"'"${key//\//\\/}"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$_GTC_DB" | head -1
}

# Store a path -> index mapping in the DB.
_gtc_db_set() {
  _gtc_db_ensure
  local key="$1" val="$2"
  local tmp="${_GTC_DB}.tmp.$$"

  if grep -q "\"${key}\"" "$_GTC_DB" 2>/dev/null; then
    # Key exists -- update in place
    sed 's/"'"${key//\//\\/}"'"[[:space:]]*:[[:space:]]*[0-9][0-9]*/"'"${key//\//\\/}"'": '"$val"'/' "$_GTC_DB" > "$tmp"
  else
    # Key doesn't exist -- append before closing brace
    local content
    content="$(cat "$_GTC_DB")"
    if [[ "$content" == "{}" ]]; then
      echo "{\"${key}\": ${val}}" > "$tmp"
    else
      # Remove trailing } and add new entry
      sed '$s/}$/, "'"${key//\//\\/}"'": '"$val"'}/' "$_GTC_DB" > "$tmp"
    fi
  fi

  mv "$tmp" "$_GTC_DB"
}

# ---------------------------------------------------------------------------
# Project coloring -- fires on every cd
# ---------------------------------------------------------------------------

_gtc_chpwd() {
  [[ -n "$_GTC_SSH_ACTIVE" ]] && return

  local appearance="$(_gtc_appearance)"
  _GTC_LAST_APPEARANCE="$appearance"

  # Home directory gets default (no tint)
  if [[ "$PWD" == "$HOME" ]]; then
    _GTC_CURRENT_IDX=""
    _GTC_CURRENT_DOT=""
    _gtc_set_bg "$(_gtc_default_bg "$appearance")"
    _gtc_set_title "${_GTC_HOST_PREFIX}~"
    return
  fi

  # Look up or assign a persistent color for this path
  local idx="$(_gtc_db_get "$PWD")"
  local palette_size=${#_GTC_PROJECT_COLORS_DARK[@]}

  if [[ -z "$idx" ]]; then
    # First visit -- hash the path and persist
    idx=$(( $(_gtc_hash "$PWD") % palette_size ))
    _gtc_db_set "$PWD" "$idx"
  fi

  # Convert 0-based DB index to 1-based zsh array index
  local zsh_idx=$(( idx + 1 ))

  _GTC_CURRENT_IDX="$zsh_idx"
  _GTC_CURRENT_DOT="${_GTC_PROJECT_DOTS[$zsh_idx]}"

  # Apply color for current appearance
  if [[ "$appearance" == "dark" ]]; then
    _gtc_set_bg "${_GTC_PROJECT_COLORS_DARK[$zsh_idx]}"
  else
    _gtc_set_bg "${_GTC_PROJECT_COLORS_LIGHT[$zsh_idx]}"
  fi

  _gtc_set_title "$_GTC_CURRENT_DOT ${_GTC_HOST_PREFIX}$(_gtc_short_cwd)"
}

# ---------------------------------------------------------------------------
# precmd -- re-assert title and react to appearance changes
# ---------------------------------------------------------------------------

_gtc_precmd() {
  # Re-assert title so other programs can't permanently overwrite it
  [[ -n "$_GTC_CURRENT_TITLE" ]] && printf '\033]2;%s\007' "$_GTC_CURRENT_TITLE"

  # Detect dark/light mode changes and re-apply background color
  local appearance="$(_gtc_appearance)"
  if [[ "$appearance" != "$_GTC_LAST_APPEARANCE" ]]; then
    _GTC_LAST_APPEARANCE="$appearance"

    if [[ -n "$_GTC_SSH_ACTIVE" ]]; then
      # Re-apply SSH color with new palette
      # (SSH idx is stored in _GTC_CURRENT_IDX during ssh wrapper)
      if [[ -n "$_GTC_CURRENT_IDX" ]]; then
        if [[ "$appearance" == "dark" ]]; then
          _gtc_set_bg "${_GTC_SSH_COLORS_DARK[$_GTC_CURRENT_IDX]}"
        else
          _gtc_set_bg "${_GTC_SSH_COLORS_LIGHT[$_GTC_CURRENT_IDX]}"
        fi
      fi
    elif [[ -n "$_GTC_CURRENT_IDX" ]]; then
      # Re-apply project color with new palette
      if [[ "$appearance" == "dark" ]]; then
        _gtc_set_bg "${_GTC_PROJECT_COLORS_DARK[$_GTC_CURRENT_IDX]}"
      else
        _gtc_set_bg "${_GTC_PROJECT_COLORS_LIGHT[$_GTC_CURRENT_IDX]}"
      fi
    else
      # Default bg (home dir or uncolored)
      _gtc_set_bg "$(_gtc_default_bg "$appearance")"
    fi
  fi
}

# ---------------------------------------------------------------------------
# SSH coloring -- wraps ssh to tint before connect, restore after
# ---------------------------------------------------------------------------

ssh() {
  local host="" skip=false arg
  for arg in "$@"; do
    if $skip; then skip=false; continue; fi
    case "$arg" in
      -[bcDEeFIiJLlmOopQRSWw]) skip=true ;;
      -*) ;;
      *@*) host="${arg#*@}"; break ;;
      *)   [[ -z "$host" ]] && host="$arg"; break ;;
    esac
  done

  if [[ -n "$host" ]]; then
    local short="${host%%.*}"
    local appearance="$(_gtc_appearance)"
    _GTC_LAST_APPEARANCE="$appearance"

    local palette_size=${#_GTC_SSH_COLORS_DARK[@]}
    local idx=$(( $(_gtc_hash "$short") % palette_size + 1 ))

    _GTC_SSH_ACTIVE="$short"
    _GTC_CURRENT_IDX="$idx"
    _GTC_CURRENT_DOT="${_GTC_SSH_DOTS[$idx]}"

    if [[ "$appearance" == "dark" ]]; then
      _gtc_set_bg "${_GTC_SSH_COLORS_DARK[$idx]}"
    else
      _gtc_set_bg "${_GTC_SSH_COLORS_LIGHT[$idx]}"
    fi
    _gtc_set_title "$_GTC_CURRENT_DOT $short"
  fi

  command ssh "$@"
  local ret=$?

  _GTC_SSH_ACTIVE=""
  _gtc_chpwd
  return $ret
}

# ---------------------------------------------------------------------------
# Hook registration + initial apply
# ---------------------------------------------------------------------------

autoload -Uz add-zsh-hook
add-zsh-hook chpwd  _gtc_chpwd
add-zsh-hook precmd _gtc_precmd
_gtc_chpwd
