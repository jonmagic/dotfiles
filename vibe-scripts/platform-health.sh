#!/bin/bash
set -euo pipefail

# platform-health.sh — Provision a vibe VM for the platform health stack
#
# Runs INSIDE the Debian VM. Expects:
#   /opt/vibe-binaries/kafka-lite         Pre-built linux/arm64 Go binary
#   /opt/vibe-binaries/aqueduct-lite      Pre-built linux/arm64 Go binary
#   /opt/vibe-binaries/aqueduct-bridge-lite  Pre-built linux/arm64 Go binary (optional)
#   /root/github/spamurai-next/           Cloned repo (virtiofs mount)
#   /root/github/hamzo/                   Cloned repo (virtiofs mount)
#   /root/.local/share/mise/              Shared mise cache (virtiofs mount)
#
# This script is idempotent — safe to re-run.

export DEBIAN_FRONTEND=noninteractive

log() { echo "==> $*"; }
err() { echo "ERROR: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 0. Fix DNS — Apple's VZNATNetworkDeviceAttachment only NATs TCP, not UDP.
#    Standard DNS uses UDP:53, so it fails. DNS-over-TLS uses TCP:853.
# ---------------------------------------------------------------------------
log "Configuring DNS (vibe NAT doesn't forward UDP)"

# Hardcode public nameservers in resolv.conf so DNS works immediately,
# even when Tailscale is running on the host and intercepting the default resolver.
echo 'nameserver 1.1.1.1' > /etc/resolv.conf
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf

# Also configure DNS-over-TLS (TCP:853) via systemd-resolved for long-term reliability.
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/dns-over-tls.conf <<'DNSCONF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google
DNSOverTLS=yes
DNSCONF
systemctl restart systemd-resolved
sleep 1
log "DNS configured"

# ---------------------------------------------------------------------------
# 1. Grow disk partition FIRST — the 3GB base image has very little free space.
#    MariaDB's postinst auto-starts the server, which needs room for data files.
#    cloud-guest-utils (provides growpart) and e2fsprogs (provides resize2fs)
#    are both present in the Debian 13 base image.
# ---------------------------------------------------------------------------
log "Checking disk space"

# Install cloud-guest-utils if growpart is missing (shouldn't be, but be safe)
if ! command -v growpart &>/dev/null; then
    apt-get update -qq
    apt-get install -y -qq cloud-guest-utils > /dev/null
fi

root_size_gb=$(df -BG / | awk 'NR==2{print int($2)}')
if [ "$root_size_gb" -lt 10 ]; then
    log "Growing root partition (currently ${root_size_gb}G)"
    growpart /dev/vda 1 || true
    resize2fs /dev/vda1 || true
    log "Root partition now: $(df -h / | awk 'NR==2{print $2}')"
else
    log "Root partition is ${root_size_gb}G — no resize needed"
fi

# ---------------------------------------------------------------------------
# 2. Install system packages (disk is now large enough for MariaDB data files)
# ---------------------------------------------------------------------------
log "Installing system packages"

# Only update apt cache if it's older than 1 hour (idempotent speedup)
apt_cache="/var/cache/apt/pkgcache.bin"
if [ ! -f "$apt_cache" ] || [ "$(( $(date +%s) - $(stat -c %Y "$apt_cache" 2>/dev/null || echo 0) ))" -gt 3600 ]; then
    apt-get update -qq
fi

apt-get install -y -qq \
    build-essential \
    cmake \
    curl \
    git \
    git-lfs \
    tmux \
    mariadb-server \
    redis-server \
    libmariadb-dev \
    libmariadb-dev-compat \
    libzstd-dev \
    libicu-dev \
    libsodium-dev \
    libffi-dev \
    libyaml-dev \
    libreadline-dev \
    libssl-dev \
    zlib1g-dev \
    libcurl4-openssl-dev \
    tzdata \
    ca-certificates \
    procps \
    > /dev/null

# Install overmind (process manager for Procfile)
if ! command -v overmind &>/dev/null; then
    log "Installing overmind"
    OVERMIND_VERSION="2.5.1"
    curl -fsSL "https://github.com/DarthSim/overmind/releases/download/v${OVERMIND_VERSION}/overmind-v${OVERMIND_VERSION}-linux-arm64.gz" \
        | gunzip > /usr/local/bin/overmind
    chmod +x /usr/local/bin/overmind
fi

log "System packages installed"

# ---------------------------------------------------------------------------
# 3. Configure MariaDB (Debian 13 ships MariaDB instead of MySQL)
# ---------------------------------------------------------------------------
log "Configuring MariaDB"

# Ensure MariaDB is running
systemctl enable mariadb
systemctl start mariadb

# Create databases (idempotent)
mariadb -u root <<'SQL' 2>/dev/null || true
CREATE DATABASE IF NOT EXISTS spamurai_development;
CREATE DATABASE IF NOT EXISTS spamurai_test;

-- Ensure root can connect locally via unix socket (dev only)
ALTER USER IF EXISTS 'root'@'localhost' IDENTIFIED VIA unix_socket;
FLUSH PRIVILEGES;
SQL

# Set sql_mode for compatibility with spamurai-next expectations
if ! grep -q 'NO_ENGINE_SUBSTITUTION' /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null; then
    cat >> /etc/mysql/mariadb.conf.d/50-server.cnf <<'CONF'

# spamurai-next compatibility
sql_mode = NO_ENGINE_SUBSTITUTION
CONF
    systemctl restart mariadb
fi

log "MariaDB configured"

# ---------------------------------------------------------------------------
# 4. Configure Redis
# ---------------------------------------------------------------------------
log "Configuring Redis"
systemctl enable redis-server
systemctl start redis-server
log "Redis running on port 6379"

# ---------------------------------------------------------------------------
# 5. Install pre-built Go binaries
# ---------------------------------------------------------------------------
log "Installing Go binaries from /opt/vibe-binaries/"

for bin in kafka-lite aqueduct-lite aqueduct-bridge-lite; do
    src="/opt/vibe-binaries/$bin"
    dest="/usr/local/bin/$bin"
    if [ -f "$src" ]; then
        if [ ! -f "$dest" ] || ! cmp -s "$src" "$dest"; then
            cp "$src" "$dest"
            chmod +x "$dest"
            log "  Installed $bin"
        else
            log "  $bin already up to date"
        fi
    else
        log "  WARNING: $src not found (skipping)"
    fi
done

# ---------------------------------------------------------------------------
# 6. Install language runtimes via mise
# ---------------------------------------------------------------------------
log "Installing language runtimes via mise"

# Install mise if not present
if ! command -v mise &>/dev/null; then
    curl -fsSL https://mise.run | sh
    echo 'eval "$(~/.local/bin/mise activate bash)"' >> /root/.bashrc
fi

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

# Install runtimes (versions match .tool-versions in each project)
mise use --global node@20.19.0
mise use --global ruby@3.3.9
mise use --global go@1.20.1

# Ensure shims are available
eval "$(mise activate bash)" 2>/dev/null || true

log "Runtimes installed: node $(node --version), ruby $(ruby --version | awk '{print $2}'), go $(go version | awk '{print $3}')"

# ---------------------------------------------------------------------------
# 7. Create systemd services for Go daemons
# ---------------------------------------------------------------------------
log "Creating systemd services"

# kafka-lite service
cat > /etc/systemd/system/kafka-lite.service <<'UNIT'
[Unit]
Description=kafka-lite (in-memory Kafka broker)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/kafka-lite -f production -s memory --listen-address 127.0.0.1:9092
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

# aqueduct-lite service
cat > /etc/systemd/system/aqueduct-lite.service <<'UNIT'
[Unit]
Description=aqueduct-lite (Twirp RPC server)
After=network.target redis-server.service
Requires=redis-server.service

[Service]
Type=simple
ExecStart=/usr/local/bin/aqueduct-lite --redis-address 127.0.0.1:6379 --listen-address 0.0.0.0:8085
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

# aqueduct-bridge-lite service (optional — bridges Kafka to aqueduct)
cat > /etc/systemd/system/aqueduct-bridge-lite.service <<'UNIT'
[Unit]
Description=aqueduct-bridge-lite (Kafka to Aqueduct bridge)
After=kafka-lite.service aqueduct-lite.service
Requires=kafka-lite.service aqueduct-lite.service

[Service]
Type=simple
ExecStart=/usr/local/bin/aqueduct-bridge-lite --hydro-url 127.0.0.1:9092 --aqueduct-url http://127.0.0.1:8085
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload

# ---------------------------------------------------------------------------
# 8. Start all services
# ---------------------------------------------------------------------------
log "Starting services"

# Start Go daemons (only if binaries exist)
if [ -f /usr/local/bin/kafka-lite ]; then
    systemctl enable --now kafka-lite
    log "  kafka-lite listening on :9092"
fi

if [ -f /usr/local/bin/aqueduct-lite ]; then
    systemctl enable --now aqueduct-lite
    log "  aqueduct-lite listening on :8085"
fi

# aqueduct-bridge-lite is optional — only start if binary exists
if [ -f /usr/local/bin/aqueduct-bridge-lite ]; then
    systemctl enable --now aqueduct-bridge-lite
    log "  aqueduct-bridge-lite started"
fi

# Verify core services
for svc in mariadb redis-server; do
    if systemctl is-active --quiet "$svc"; then
        log "  $svc is running"
    else
        err "$svc failed to start"
    fi
done

# ---------------------------------------------------------------------------
# 9. Per-project environment setup
# ---------------------------------------------------------------------------

# --- spamurai-next ---
SPAMURAI_DIR="/root/github/spamurai-next"
if [ -d "$SPAMURAI_DIR" ]; then
    log "Configuring spamurai-next"

    # Write .env if it doesn't exist (or overwrite with correct dev values)
    cat > "$SPAMURAI_DIR/.env" <<'ENV'
# Auto-generated by platform-health.sh for vibe VM development
NODE_ENV=development
DATABASE_URL=mysql2://root@localhost:3306/spamurai_development
AZURE_MYSQL_RW_URL=mysql2://root@localhost:3306/spamurai_development
AZURE_MYSQL_RO_URL=mysql2://root@localhost:3306/spamurai_development
AWS_REDIS_URL=redis://localhost:6379
AZURE_REDIS_URL=redis://localhost:6379
KAFKA_BROKERS_SSL=localhost:9092
KAFKA_STAGING_BROKERS_SSL=localhost:9092
HAMZO_API_URL=http://localhost:3002
PORT=3001
CLIENT_PORT=3000
INSPECT_MODE=0
BASE_URL=http://localhost:3001
GITHUB_CLIENT_ID=dummy-client-id
GITHUB_CLIENT_SECRET=dummy-client-secret
SESSION_SECRET=vibe-dev-session-secret
GITHUB_PLATFORM_URI=http://localhost:9999/graphql
GITHUB_PLATFORM_TOKEN=dummy-platform-token
SQL_GATEWAY_HOST=http://localhost:9998
ENV

    # Create a Procfile.dev that removes kafka (already running via systemd)
    if [ -f "$SPAMURAI_DIR/Procfile" ]; then
        grep -v '^kafka:' "$SPAMURAI_DIR/Procfile" > "$SPAMURAI_DIR/Procfile.dev"
        log "  Created Procfile.dev (removed kafka — already running via systemd)"
    fi

    # Install node dependencies if node_modules is missing
    if [ ! -d "$SPAMURAI_DIR/node_modules" ]; then
        log "  Installing npm dependencies (this may take a while)..."
        cd "$SPAMURAI_DIR"
        eval "$(mise activate bash)" 2>/dev/null || true
        NPM_LOG="$SPAMURAI_DIR/tmp/npm_install.log"
        mkdir -p "$SPAMURAI_DIR/tmp"
        if npm install > "$NPM_LOG" 2>&1; then
            log "  npm install completed"
        else
            log "  WARNING: npm install failed (exit $?)"
            tail -20 "$NPM_LOG" 2>/dev/null || true
            log "  Full log: $NPM_LOG"
        fi
        cd /root
    fi

    # Install client dependencies (separate npm project, not a workspace)
    if [ ! -d "$SPAMURAI_DIR/client/node_modules" ]; then
        log "  Installing client npm dependencies..."
        cd "$SPAMURAI_DIR/client"
        eval "$(mise activate bash)" 2>/dev/null || true
        CLIENT_NPM_LOG="$SPAMURAI_DIR/tmp/client_npm_install.log"
        mkdir -p "$SPAMURAI_DIR/tmp"
        if npm install > "$CLIENT_NPM_LOG" 2>&1; then
            log "  client npm install completed"
        else
            log "  WARNING: client npm install failed (exit $?)"
            tail -20 "$CLIENT_NPM_LOG" 2>/dev/null || true
            log "  Full log: $CLIENT_NPM_LOG"
        fi
        cd /root
    fi

    log "  spamurai-next configured"
    log "  Start with: cd $SPAMURAI_DIR && overmind start -f Procfile.dev"
fi

# --- yara-x stub library (needed for hamzo's yara-ffi gem) ---
YARA_STUB_SRC="/opt/vibe-binaries/yara_x_capi_stub.c"
# Install directly into the standard system library path (already in linker search path)
# so we don't need ldconfig (which segfaults in the VZ/nocloud environment).
YARA_LIB="/usr/lib/aarch64-linux-gnu/libyara_x_capi.so"

if [ ! -f "$YARA_LIB" ]; then
    if [ -f "$YARA_STUB_SRC" ]; then
        log "Building yara-x stub library from $YARA_STUB_SRC"
        gcc -shared -fPIC -o "$YARA_LIB" "$YARA_STUB_SRC"
        log "  yara-x stub installed at $YARA_LIB"
    else
        log "  WARNING: yara-x stub source not found at $YARA_STUB_SRC (hamzo may fail to boot)"
    fi
else
    log "yara-x library already installed at $YARA_LIB"
fi

# --- hamzo ---
HAMZO_DIR="/root/github/hamzo"
if [ -d "$HAMZO_DIR" ]; then
    log "Configuring hamzo"

    # Write .env (hamzo uses dotenv for local dev)
    cat > "$HAMZO_DIR/.env" <<'ENV'
# Auto-generated by platform-health.sh for vibe VM development
RAILS_ENV=development
REDIS_URL_BASE=redis://localhost:6379
AZURE_REDIS_URL_BASE=redis://localhost:6379
AQUEDUCT_URL=http://localhost:8085/twirp
SPAMURAI_PLATFORM_URI=http://localhost:3001
SECRET_KEY_BASE=development_secret_key_base_for_vibe_vm_only
ENV

    # Install Ruby dependencies (credentials via mounted ~/.bundle/config)
    cd "$HAMZO_DIR"
    eval "$(mise activate bash)" 2>/dev/null || true
    bundle config set --local path vendor/bundle
    # Force compiling from source — Gemfile.lock only has x86_64-linux prebuilt
    # gems (grpc, etc.) which install x86 native libs that corrupt aarch64 system libs
    bundle config set --local force_ruby_platform true
    if ! bundle check &>/dev/null; then
        log "  Installing Ruby gems (this may take a while)..."
        BUNDLE_LOG="$HAMZO_DIR/tmp/bundle_install.log"
        mkdir -p "$HAMZO_DIR/tmp"
        if bundle install > "$BUNDLE_LOG" 2>&1; then
            log "  bundle install completed"
        else
            log "  WARNING: bundle install failed (exit $?)"
            tail -20 "$BUNDLE_LOG" 2>/dev/null || true
            log "  Full log: $BUNDLE_LOG"
        fi
    else
        log "  Ruby gems already installed"
    fi

    # Run database setup (SQLite — fast)
    if [ ! -f "$HAMZO_DIR/db/development.sqlite3" ]; then
        log "  Setting up hamzo database (SQLite)"
        DB_LOG="$HAMZO_DIR/tmp/db_prepare.log"
        mkdir -p "$HAMZO_DIR/tmp"
        if bin/rails db:prepare > "$DB_LOG" 2>&1; then
            log "  hamzo database created successfully"
        else
            log "  WARNING: hamzo db:prepare failed (exit $?)"
            log "  --- First 30 lines of output ---"
            head -30 "$DB_LOG" 2>/dev/null || true
            log "  --- Last 15 lines of output ---"
            tail -15 "$DB_LOG" 2>/dev/null || true
            log "  Full log: $DB_LOG"
            log "  Continuing provisioning..."
        fi
    fi
    cd /root

    log "  hamzo configured"
    log "  Start with: cd $HAMZO_DIR && bin/rails server -p 3002"
fi

# ---------------------------------------------------------------------------
# 10. Set up reverse SSH tunnel to host
#     The VM can't receive inbound connections (VZ NAT is outbound-only),
#     so we SSH *out* to the host with -R to create a reverse tunnel.
#     This lets the host connect to the VM via localhost:<port>.
# ---------------------------------------------------------------------------
SSH_CONF="/root/.vibe-config/ssh-tunnel.conf"
VIBE_KEY="/root/.vibe-ssh/vibe_key"

if [ -f "$SSH_CONF" ] && [ -f "$VIBE_KEY" ]; then
    log "Setting up reverse SSH tunnel"

    # Install openssh-server if not present
    if ! command -v sshd &>/dev/null; then
        apt-get install -y -qq openssh-server > /dev/null
    fi

    # Configure sshd: allow root login with key only, listen on port 22
    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/vibe.conf <<'SSHD'
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
SSHD

    # Install the host's public key as an authorized key for root
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    if [ -f "/root/.vibe-ssh/vibe_key.pub" ]; then
        cp /root/.vibe-ssh/vibe_key.pub /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
    fi

    # Generate host keys if they don't exist (first boot)
    ssh-keygen -A 2>/dev/null

    # Start sshd
    systemctl enable ssh
    systemctl restart ssh

    # Read tunnel config
    # shellcheck disable=SC1090
    . "$SSH_CONF"

    # Discover the host gateway IP (the VZ NAT host)
    HOST_IP=$(ip route show default | awk '{print $3}' | head -1)
    [ -n "$HOST_IP" ] || HOST_IP="192.168.64.1"

    # Copy the private key to a writable location (virtiofs mount is read-only)
    mkdir -p /root/.ssh
    cp "$VIBE_KEY" /root/.ssh/vibe_key
    chmod 600 /root/.ssh/vibe_key

    # Set up the reverse tunnel as a systemd service so it persists and auto-reconnects
    cat > /etc/systemd/system/vibe-ssh-tunnel.service <<TUNNEL
[Unit]
Description=Reverse SSH tunnel to host (port ${SSH_PORT})
After=network-online.target ssh.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/ssh -N -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    -i /root/.ssh/vibe_key \
    -R ${SSH_PORT}:localhost:22 \
    -R $((SSH_PORT + 1000)):localhost:3000 \
    -R $((SSH_PORT + 1001)):localhost:3001 \
    -R $((SSH_PORT + 1002)):localhost:3002 \
    ${HOST_USER}@${HOST_IP}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
TUNNEL

    systemctl daemon-reload
    systemctl enable --now vibe-ssh-tunnel

    # Wait briefly for tunnel to establish
    sleep 2

    if systemctl is-active --quiet vibe-ssh-tunnel; then
        log "  Reverse SSH tunnel established"
        log "  SSH:  ssh -p ${SSH_PORT} root@localhost  (from host)"
        log "  Ports forwarded to host:"
        log "    VM :3000 -> host localhost:$((SSH_PORT + 1000))"
        log "    VM :3001 -> host localhost:$((SSH_PORT + 1001))"
        log "    VM :3002 -> host localhost:$((SSH_PORT + 1002))"
    else
        log "  WARNING: SSH tunnel failed to start (check: systemctl status vibe-ssh-tunnel)"
    fi
else
    log "Skipping SSH tunnel setup (no config or key found)"
    [ ! -f "$SSH_CONF" ] && log "  Missing: $SSH_CONF"
    [ ! -f "$VIBE_KEY" ] && log "  Missing: $VIBE_KEY"
fi

# ---------------------------------------------------------------------------
# 11. Done
# ---------------------------------------------------------------------------
echo ""
log "Platform health stack provisioned successfully!"
echo ""
echo "  Services running:"
echo "    MariaDB      :3306"
echo "    Redis        :6379"
systemctl is-active --quiet kafka-lite 2>/dev/null && echo "    kafka-lite   :9092"
systemctl is-active --quiet aqueduct-lite 2>/dev/null && echo "    aqueduct-lite :8085"
echo ""
if [ -f "$SSH_CONF" ] && systemctl is-active --quiet vibe-ssh-tunnel 2>/dev/null; then
    echo "  SSH access (from host):"
    echo "    ssh -p ${SSH_PORT} root@localhost"
    echo ""
    echo "  Port forwards (from host):"
    echo "    http://localhost:$((SSH_PORT + 1000))  -> VM :3000 (spamurai client)"
    echo "    http://localhost:$((SSH_PORT + 1001))  -> VM :3001 (spamurai server)"
    echo "    http://localhost:$((SSH_PORT + 1002))  -> VM :3002 (hamzo)"
    echo ""
fi
echo "  To start spamurai-next:"
echo "    cd /root/github/spamurai-next && overmind start -f Procfile.dev"
echo ""
echo "  To start hamzo:"
echo "    cd /root/github/hamzo && bin/rails server -p 3002"
echo ""
echo "PROVISIONED"
