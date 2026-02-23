#!/bin/bash
set -euo pipefail

# fix-yara-dbprepare.sh — Install yara-x stub and run hamzo db:prepare
#
# Quick fix script for a VM that's already provisioned but failed on db:prepare
# due to missing libyara_x_capi.so.

log() { echo "==> $*"; }

# ---------------------------------------------------------------------------
# 1. Install yara-x stub library
# ---------------------------------------------------------------------------
YARA_STUB_SRC="/opt/vibe-binaries/yara_x_capi_stub.c"
YARA_LIB_DIR="/usr/local/lib/aarch64-linux-gnu"
YARA_LIB="$YARA_LIB_DIR/libyara_x_capi.so"

if [ ! -f "$YARA_LIB" ]; then
    if [ -f "$YARA_STUB_SRC" ]; then
        log "Building yara-x stub library"
        mkdir -p "$YARA_LIB_DIR"
        gcc -shared -fPIC -o "$YARA_LIB" "$YARA_STUB_SRC"
        ldconfig
        log "Installed: $YARA_LIB"
    else
        log "ERROR: stub source not found at $YARA_STUB_SRC"
        echo "FIX-FAILED"
        exit 1
    fi
else
    log "yara-x library already at $YARA_LIB"
fi

# Verify the library is loadable
ldconfig -p | grep yara_x_capi && log "Library visible to dynamic linker"

# ---------------------------------------------------------------------------
# 2. Run hamzo db:prepare
# ---------------------------------------------------------------------------
HAMZO_DIR="/root/github/hamzo"
if [ -d "$HAMZO_DIR" ]; then
    cd "$HAMZO_DIR"

    export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
    eval "$(mise activate bash)" 2>/dev/null || true

    if [ ! -f db/development.sqlite3 ]; then
        log "Running bin/rails db:prepare"
        DB_LOG="$HAMZO_DIR/tmp/db_prepare.log"
        mkdir -p tmp
        if bin/rails db:prepare > "$DB_LOG" 2>&1; then
            log "hamzo db:prepare SUCCEEDED"
            ls -la db/development.sqlite3
        else
            log "hamzo db:prepare FAILED (exit $?)"
            log "--- First 30 lines ---"
            head -30 "$DB_LOG"
            log "--- Last 20 lines ---"
            tail -20 "$DB_LOG"
            log "Full log: $DB_LOG"
        fi
    else
        log "hamzo database already exists"
    fi
    cd /root
fi

echo ""
echo "FIX-DONE"
