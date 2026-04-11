ts_log() {
  printf '==> %s\n' "$*"
}

ts_warn() {
  printf '!! %s\n' "$*" >&2
}

ts_die() {
  ts_warn "$*"
  exit 1
}

TAILSCALE_BIN="${TAILSCALE_BIN:-$HOME/.dotfiles/bin/tailscale}"
TAILSCALE_APP_NAME="${TAILSCALE_APP_NAME:-Tailscale}"
TS_CLI_READY_TIMEOUT="${TS_CLI_READY_TIMEOUT:-30}"
TS_PROFILE_READY_TIMEOUT="${TS_PROFILE_READY_TIMEOUT:-45}"

ts_require_tailscale() {
  if [[ ! -x "$TAILSCALE_BIN" ]]; then
    ts_die "Expected Tailscale wrapper at $TAILSCALE_BIN"
  fi
}

ts_cli_ready() {
  "$TAILSCALE_BIN" switch --list >/dev/null 2>&1
}

ts_wait_for_cli() {
  local attempts="${1:-$TS_CLI_READY_TIMEOUT}"
  local i=0

  while (( i < attempts )); do
    if ts_cli_ready; then
      return 0
    fi

    sleep 1
    ((i += 1))
  done

  return 1
}

ts_open_app() {
  open -ga "$TAILSCALE_APP_NAME" >/dev/null 2>&1 || open -a "$TAILSCALE_APP_NAME" >/dev/null 2>&1
}

ts_app_running() {
  [[ "$(osascript -e 'application "Tailscale" is running' 2>/dev/null || printf 'false')" == "true" ]]
}

ts_stop_app() {
  ts_log "Quitting Tailscale..."
  osascript -e 'quit app "Tailscale"' >/dev/null 2>&1 || true

  local attempts=0
  while (( attempts < 15 )); do
    if ! ts_app_running; then
      ts_log "Tailscale is fully closed."
      return 0
    fi

    sleep 1
    ((attempts += 1))
  done

  ts_warn "Tailscale still appears to be running."
  return 1
}

ts_profile_line() {
  local profile="$1"

  "$TAILSCALE_BIN" switch --list 2>/dev/null | awk -v profile="$profile" '
    NR == 1 { next }
    {
      account = $3
      sub(/\*$/, "", account)

      if (profile == "work" && ($2 == "github.com" || account == "work" || account == "jonmagic@github.com")) {
        print $0
        exit
      }

      if (profile == "personal" && ($2 == "github" || account == "personal" || account == "jonmagic@github")) {
        print $0
        exit
      }
    }
  '
}

ts_profile_id() {
  local profile="$1"
  local line

  line="$(ts_profile_line "$profile" || true)"
  [[ -n "$line" ]] || return 1

  awk '{ print $1 }' <<<"$line"
}

ts_active_profile() {
  "$TAILSCALE_BIN" switch --list 2>/dev/null | awk '
    NR == 1 { next }
    {
      account = $3
      active = account ~ /\*$/
      sub(/\*$/, "", account)

      if (!active) {
        next
      }

      if ($2 == "github.com" || account == "work" || account == "jonmagic@github.com") {
        print "work"
        exit
      }

      if ($2 == "github" || account == "personal" || account == "jonmagic@github") {
        print "personal"
        exit
      }

      print account
      exit
    }
  '
}

ts_wait_for_active_profile() {
  local profile="$1"
  local attempts="${2:-$TS_PROFILE_READY_TIMEOUT}"
  local i=0

  while (( i < attempts )); do
    if [[ "$(ts_active_profile || true)" == "$profile" ]]; then
      return 0
    fi

    sleep 1
    ((i += 1))
  done

  return 1
}

ts_switch_profile() {
  local profile="$1"
  local profile_id="$2"
  local output=""
  local status=0

  ts_log "Switching to the $profile profile..."

  set +e
  output="$("$TAILSCALE_BIN" switch "$profile_id" 2>&1)"
  status=$?
  set -e

  if (( status == 0 )); then
    ts_log "Switch request returned successfully."
  else
    ts_warn "Switch returned $status: $output"
    ts_warn "Checking whether Tailscale still completed the switch..."
  fi

  if ts_wait_for_active_profile "$profile"; then
    ts_log "$profile profile is active."
    return 0
  fi

  ts_die "Tailscale did not settle on the $profile profile."
}

ts_login_profile() {
  local profile="$1"
  shift

  ts_log "No saved $profile profile found. Starting browser login..."
  "$TAILSCALE_BIN" login --nickname="$profile" "$@"
  ts_wait_for_active_profile "$profile" "$TS_PROFILE_READY_TIMEOUT" || true
}

ts_apply_nickname() {
  local profile="$1"
  "$TAILSCALE_BIN" set --nickname="$profile" >/dev/null 2>&1 || true
}

ts_profile_flags() {
  local profile="$1"

  case "$profile" in
    work)
      printf '%s\n' --accept-routes=true --accept-dns=true --report-posture=true
      ;;
    personal)
      printf '%s\n' --accept-routes=false --accept-dns=true --report-posture=false
      ;;
    *)
      return 1
      ;;
  esac
}

ts_up_profile() {
  local profile="$1"
  shift
  local output=""
  local status=0

  ts_log "Bringing Tailscale up for $profile..."

  set +e
  output="$("$TAILSCALE_BIN" up "$@" 2>&1)"
  status=$?
  set -e

  if (( status == 0 )); then
    ts_log "Tailscale is connected for $profile."
    return 0
  fi

  ts_warn "tailscale up returned $status: $output"
  return "$status"
}

ts_show_summary() {
  ts_log "Profiles:"
  "$TAILSCALE_BIN" switch --list 2>/dev/null | sed 's/^/    /' || ts_warn "Unable to list saved profiles."

  ts_log "Status:"
  "$TAILSCALE_BIN" status --peers=false 2>/dev/null | sed -n '1,5p' | sed 's/^/    /' || ts_warn "Unable to read Tailscale status."
}

ts_start_profile() {
  local profile="$1"
  local profile_id=""
  local -a flags=()

  ts_require_tailscale

  while IFS= read -r flag; do
    flags+=("$flag")
  done < <(ts_profile_flags "$profile")

  ts_log "Preparing a clean Tailscale start for $profile..."
  ts_stop_app || true

  ts_log "Launching Tailscale..."
  ts_open_app

  if ! ts_wait_for_cli "$TS_CLI_READY_TIMEOUT"; then
    ts_die "The Tailscale CLI did not become ready after launch."
  fi

  if [[ "$(ts_active_profile || true)" == "$profile" ]]; then
    ts_log "$profile profile is already active."
  else
    profile_id="$(ts_profile_id "$profile" || true)"

    if [[ -n "$profile_id" ]]; then
      ts_switch_profile "$profile" "$profile_id"
    else
      ts_login_profile "$profile" "${flags[@]}"
    fi
  fi

  if ! ts_up_profile "$profile" "${flags[@]}"; then
    ts_warn "Retrying with a full reset and reauthentication..."
    "$TAILSCALE_BIN" up "${flags[@]}" --force-reauth --reset
  fi

  ts_apply_nickname "$profile"
  ts_show_summary
}
