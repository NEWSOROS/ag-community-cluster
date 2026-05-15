#!/bin/bash
# One-shot bootstrap for an Alpenglow community-cluster validator host.
# Mirrors what sv-manager Ansible would do (base_system + disk_setup
# + chrony + firewall + helper user) but plain bash over ssh, because
# Ansible isn't available on the operator workstation today.
#
# Idempotent: re-running is safe — every step checks current state.
# Run as root.

set -euo pipefail

LOG=/var/log/ag-bootstrap.log
exec > >(tee -a "$LOG") 2>&1
echo "================================================================"
echo "  Alpenglow host bootstrap — $(date -u)"
echo "================================================================"

# ---------- knobs (override at top of script if host is different) -----
AG_USER="solana"
AG_HOME="/home/$AG_USER"
MNT="/mnt/solana"
LEDGER_DIR="$MNT/ledger"
ACCOUNTS_DIR="$MNT/accounts"
RAMDISK_DIR="$MNT/ramdisk"
LOG_DIR="$MNT/log"
RAMDISK_SIZE="32G"
NEW_HOSTNAME="testnet-cho-p1"

# Firewall — mirror of sv-manager roles/firewall/tasks/main.yaml + group_vars/all.yml
# Keep this list in sync with inventory/group_vars/all.yml:allowed_subnets.
ALLOWED_SUBNETS=(
    "127.0.0.1/32"        # local
    "92.185.46.212/32"    # operator canary (was .120 before reboot)
    "206.81.31.16/32"     # vpn DO
    "144.76.112.244/32"   # OpenClaw build-server
    "37.27.104.158/32"    # monitoring-hel-1
)
DENY_SUBNETS=(
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    # 100.64.0.0/10 excluded because Tailscale is enabled
    "198.18.0.0/15"
)
TAILSCALE_SUBNET="100.64.0.0/10"
# Alpenglow's --dynamic-port-range is 9000-12500 (per gist) — not the
# 8000-8800 default the rest of sv-manager uses for mainnet validators.
OPEN_SOLANA_PORTS_START=9000
OPEN_SOLANA_PORTS_END=12500

# ---------- 0. preliminaries -------------------------------------------
echo "--- set hostname ---"
hostnamectl set-hostname "$NEW_HOSTNAME"
echo "127.0.1.1 $NEW_HOSTNAME" >> /etc/hosts
grep -q "$NEW_HOSTNAME" /etc/hosts || echo "127.0.1.1 $NEW_HOSTNAME" >> /etc/hosts

echo "--- apt update + base packages ---"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
    chrony fail2ban ufw \
    build-essential pkg-config libssl-dev libudev-dev clang protobuf-compiler \
    git curl wget jq python3 python3-yaml \
    xfsprogs e2fsprogs parted \
    lsof htop iotop sysstat \
    >/dev/null

# ---------- 1. SSH hardening -------------------------------------------
echo "--- harden sshd ---"
SSHD=/etc/ssh/sshd_config
cp -a "$SSHD" "${SSHD}.pre-ag-$(date -u +%Y%m%d)" 2>/dev/null || true
for kv in \
    "PermitRootLogin prohibit-password" \
    "PasswordAuthentication no" \
    "PubkeyAuthentication yes" \
    "X11Forwarding no" \
    "MaxAuthTries 3" \
; do
    k="${kv%% *}"
    grep -qE "^[# ]*${k}\b" "$SSHD" \
        && sed -i -E "s|^[# ]*${k}\b.*|${kv}|" "$SSHD" \
        || echo "$kv" >> "$SSHD"
done
systemctl restart ssh || systemctl restart sshd

# ---------- 2. disable algif_aead (CVE-2026-31431 — Copy Fail) ---------
echo "--- blacklist algif_aead ---"
cat > /etc/modprobe.d/blacklist-algif_aead.conf <<EOF
# Workaround for CVE-2026-31431 (Copy Fail) — block algif_aead AF_ALG path.
# Managed by Alpenglow host bootstrap.
blacklist algif_aead
install algif_aead /bin/true
EOF

# ---------- 3. sysctl drop-in (validator tuning) -----------------------
echo "--- sysctl drop-in ---"
cat > /etc/sysctl.d/99-solana.conf <<'EOF'
# Solana / Alpenglow validator sysctl — managed by Alpenglow bootstrap
kernel.panic = 10
kernel.watchdog_thresh = 20
fs.file-max = 6521604
fs.nr_open = 1000000
vm.vfs_cache_pressure = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.max_map_count = 2100000
net.core.netdev_budget = 1000
net.core.netdev_max_backlog = 65536
net.core.optmem_max = 25165824
net.core.somaxconn = 65535
net.core.rmem_default = 134217728
net.core.rmem_max = 134217728
net.core.wmem_default = 134217728
net.core.wmem_max = 134217728
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.udp_mem = 8388608 12582912 16777216
net.ipv4.udp_rmem_min = 16384
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.udp_wmem_min = 16384
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_redirects = 0
EOF
sysctl --system >/dev/null

cat > /etc/security/limits.d/90-solana-nofiles.conf <<EOF
${AG_USER}  soft  nofile  1000000
${AG_USER}  hard  nofile  1000000
EOF

# ---------- 4. solana user --------------------------------------------
echo "--- create $AG_USER user ---"
if ! id "$AG_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$AG_USER"
fi
install -d -o "$AG_USER" -g "$AG_USER" -m 0700 "$AG_HOME/.ssh"
install -d -o "$AG_USER" -g "$AG_USER" -m 0700 "$AG_HOME/.secrets"
install -d -o "$AG_USER" -g "$AG_USER" -m 0700 "$AG_HOME/.secrets/alpenglow"
# allow root to ssh-jump into solana@ — same key as for root
test -f /root/.ssh/authorized_keys && cp /root/.ssh/authorized_keys "$AG_HOME/.ssh/authorized_keys"
chown "$AG_USER:$AG_USER" "$AG_HOME/.ssh/authorized_keys" 2>/dev/null || true
chmod 600 "$AG_HOME/.ssh/authorized_keys" 2>/dev/null || true

# ---------- 5. disks --------------------------------------------------
echo "--- disk layout ---"
mkdir -p "$LEDGER_DIR" "$ACCOUNTS_DIR" "$RAMDISK_DIR" "$LOG_DIR"

# accounts → entire /dev/nvme0n1 (894 GB), ext4
if ! grep -q "$ACCOUNTS_DIR " /etc/fstab; then
    echo "[disk] formatting /dev/nvme0n1 as ext4 → $ACCOUNTS_DIR"
    umount /dev/nvme0n1 2>/dev/null || true
    wipefs -af /dev/nvme0n1
    mkfs.ext4 -F -E nodiscard,lazy_itable_init=1,lazy_journal_init=1 /dev/nvme0n1
    ACCOUNTS_UUID=$(blkid -s UUID -o value /dev/nvme0n1)
    echo "UUID=$ACCOUNTS_UUID  $ACCOUNTS_DIR  ext4  defaults,noatime,lazytime  0  2" >> /etc/fstab
fi

# ledger → new partition on /dev/nvme1n1 in the unused space after p2 (rootfs)
if ! grep -q "$LEDGER_DIR " /etc/fstab; then
    if ! lsblk /dev/nvme1n1p3 >/dev/null 2>&1; then
        echo "[disk] creating /dev/nvme1n1p3 from free space"
        # find sector right after p2's end
        END_P2_SEC=$(parted /dev/nvme1n1 --script unit s print | awk '/^ 2/{print $3}' | tr -d s)
        START_P3=$((END_P2_SEC + 1))
        parted /dev/nvme1n1 --script mkpart primary "${START_P3}s" 100%
        sleep 2
        partprobe /dev/nvme1n1
        sleep 2
    fi
    if [ ! -b /dev/nvme1n1p3 ]; then
        echo "[disk] ERROR: /dev/nvme1n1p3 didn't materialise"
        exit 1
    fi
    echo "[disk] formatting /dev/nvme1n1p3 as XFS → $LEDGER_DIR"
    wipefs -af /dev/nvme1n1p3 2>/dev/null || true
    mkfs.xfs -f -K /dev/nvme1n1p3
    LEDGER_UUID=$(blkid -s UUID -o value /dev/nvme1n1p3)
    echo "UUID=$LEDGER_UUID  $LEDGER_DIR  xfs  async,auto,rw,lazytime,nofail,noatime  0  2" >> /etc/fstab
fi

# ramdisk
if ! grep -q "$RAMDISK_DIR " /etc/fstab; then
    echo "tmpfs $RAMDISK_DIR tmpfs nodev,nosuid,noexec,noatime,size=$RAMDISK_SIZE 0 2" >> /etc/fstab
fi

mount -a
chown -R "$AG_USER:$AG_USER" "$MNT"

echo "[disk] result:"
df -hT | grep -E "$MNT|^Filesystem" || true

# ---------- 6. chrony --------------------------------------------------
echo "--- chrony with Jito NTP ---"
systemctl disable --now systemd-timesyncd 2>/dev/null || true
cat > /etc/chrony/chrony.conf <<'EOF'
# Alpenglow validator NTP — managed by bootstrap
# Jito NTP first (closest geographically), generic fallbacks below.
server ntp.amsterdam.jito.wtf iburst prefer
server ntp.frankfurt.jito.wtf iburst
server ntp.dublin.jito.wtf iburst
server ntp.dallas.jito.wtf iburst
server time.google.com iburst
server time.cloudflare.com iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
maxupdateskew 100.0
logdir /var/log/chrony
EOF
# Ubuntu 24.04 / Debian 12: canonical unit is chrony.service; chronyd is an alias.
# Older distros may have it the other way around. Pick the unit whose state != "alias".
CHRONY_UNIT=$(systemctl list-unit-files --type=service --no-legend 2>/dev/null \
    | awk '/^(chrony|chronyd)\.service[[:space:]]+(static|enabled|disabled)[[:space:]]/{print $1; exit}')
CHRONY_UNIT="${CHRONY_UNIT:-chrony.service}"
echo "  chrony unit: $CHRONY_UNIT"
systemctl enable --now "$CHRONY_UNIT"
systemctl restart "$CHRONY_UNIT"

# ---------- 7. UFW (mirror of sv-manager roles/firewall) --------------
echo "--- UFW ---"
ufw --force reset >/dev/null
# IPv6 off (same as Ansible role)
sed -i -E 's|^IPV6=.*|IPV6=no|' /etc/default/ufw
ufw default deny incoming
ufw default allow outgoing

# SSH from trusted subnets (allowed_subnets)
for s in "${ALLOWED_SUBNETS[@]}"; do
    ufw allow from "$s" to any port 22 proto tcp comment "SSH trusted"
done
# SSH from Tailscale CGNAT
ufw allow from "$TAILSCALE_SUBNET" to any port 22 proto tcp comment "SSH Tailscale"

# Solana / Alpenglow dynamic port range (TCP+UDP)
ufw allow "${OPEN_SOLANA_PORTS_START}:${OPEN_SOLANA_PORTS_END}/tcp" comment "Alpenglow dynamic"
ufw allow "${OPEN_SOLANA_PORTS_START}:${OPEN_SOLANA_PORTS_END}/udp" comment "Alpenglow dynamic"

# Full access from trusted subnets (matches Ansible step "Allow access from trusted subnets")
for s in "${ALLOWED_SUBNETS[@]}"; do
    ufw allow from "$s" comment "trusted full"
done

# node_exporter :9100 from Tailscale (Prometheus scrape)
ufw allow from "$TAILSCALE_SUBNET" to any port 9100 proto tcp comment "node-exporter (Tailscale)"

# Deny outbound to private networks (Tailscale CGNAT excluded — Tailscale on)
for s in "${DENY_SUBNETS[@]}"; do
    ufw deny out to "$s"
done

ufw --force enable

# ---------- 8. disable auto-reboot ------------------------------------
echo "--- disable auto-reboot ---"
mkdir -p /etc/needrestart/conf.d
cat > /etc/needrestart/conf.d/99-no-auto-restart.conf <<'EOF'
$nrconf{restart} = 'l';
$nrconf{kernelhints} = 0;
EOF
cat > /etc/apt/apt.conf.d/99-no-auto-reboot <<'EOF'
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
EOF

# ---------- 8a. Tailscale --------------------------------------------
echo "--- Tailscale install ---"
if ! command -v tailscale >/dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi
systemctl enable --now tailscaled

# Bring tailscale up only if not already authenticated.
# `tailscale up` with no token prints an auth URL — we show it and continue
# without blocking. Authorise it in the Tailscale admin console from a
# browser; metrics scrape will start working once the node is admitted.
TS_STATUS=$(tailscale status --json 2>/dev/null | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('BackendState','Unknown'))" 2>/dev/null || echo "Unknown")
echo "  current Tailscale state: $TS_STATUS"
if [ "$TS_STATUS" != "Running" ]; then
    echo "  starting tailscale (will print auth URL)..."
    tailscale up --hostname "$NEW_HOSTNAME" --accept-routes=true --timeout=15s 2>&1 \
        | tee /var/log/ag-tailscale-up.log || true
    echo "  >>> Authorise the URL above in https://login.tailscale.com/admin/machines"
fi
sleep 3
echo "  tailscale IP: $(tailscale ip -4 2>/dev/null || echo '(pending auth)')"

# ---------- 8b. node_exporter ----------------------------------------
echo "--- node_exporter ---"
NODE_EXPORTER_VERSION="1.8.2"
if [ ! -x /usr/local/bin/node_exporter ] || ! /usr/local/bin/node_exporter --version 2>&1 | grep -q "$NODE_EXPORTER_VERSION"; then
    cd /tmp
    curl -fsSL -o ne.tar.gz \
        "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
    tar xzf ne.tar.gz
    install -m 0755 "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/node_exporter
    rm -rf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64" ne.tar.gz
fi

# dedicated unprivileged user
id node_exporter >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter

cat > /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
User=node_exporter
Group=node_exporter
# Bind to all interfaces; UFW restricts access to Tailscale subnet 100.64.0.0/10
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now node_exporter
echo "  node_exporter: $(systemctl is-active node_exporter)"

# ---------- 9. rustup for solana --------------------------------------
echo "--- rustup for $AG_USER ---"
if [ ! -x "$AG_HOME/.cargo/bin/cargo" ]; then
    sudo -u "$AG_USER" -i bash -c \
        "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable >/dev/null"
fi
echo "  cargo: $(sudo -u "$AG_USER" -i bash -c 'cargo --version')"

# ---------- 10. clone ag-community-cluster ---------------------------
echo "--- clone ag-community-cluster ---"
REPO="$AG_HOME/ag-community-cluster"
if [ ! -d "$REPO/.git" ]; then
    sudo -u "$AG_USER" git clone https://github.com/NEWSOROS/ag-community-cluster.git "$REPO"
else
    sudo -u "$AG_USER" -i bash -c "cd $REPO && git pull --ff-only"
fi

# ---------- 11. localised env.sh override ----------------------------
# default env.sh puts data under /mnt/solana/alpenglow — we want /mnt/solana
# directly (consistent with the rest of the fleet).
echo "--- env.sh override (paths under $MNT, user $AG_USER) ---"
cat > "$REPO/config/env.local.sh" <<EOF
# Local overrides applied AFTER config/env.sh — sourced by all scripts
# (because each script does \`source config/env.sh\` then \`source config/env.local.sh\`
# if present). Keep this file local to the host; do not commit.

# Paths
export AG_USER="$AG_USER"
export AG_HOME="$AG_HOME"
export AG_DATA_BASE="$MNT"
export AG_LEDGER="$LEDGER_DIR"
export AG_ACCOUNTS="$ACCOUNTS_DIR"
export AG_LOG="$LOG_DIR/agave-alpenglow.log"

# Default RPC port and dynamic range are fine.
EOF
chown "$AG_USER:$AG_USER" "$REPO/config/env.local.sh"

# Patch every script to source env.local.sh after env.sh, if present.
for s in "$REPO"/scripts/*.sh; do
    grep -q "env.local.sh" "$s" && continue
    sed -i 's|source "\$REPO_DIR/config/env.sh"|source "\$REPO_DIR/config/env.sh"\n[ -f "\$REPO_DIR/config/env.local.sh" ] \&\& source "\$REPO_DIR/config/env.local.sh"|' "$s"
done

echo "--- effective env (sanity) ---"
sudo -u "$AG_USER" bash -c "cd $REPO && source config/env.sh && source config/env.local.sh 2>/dev/null && env | grep ^AG_" | head -20

# ---------- DONE bootstrap ------------------------------------------
echo
echo "================================================================"
echo "  Bootstrap done.  Next:"
echo "    0. (manual) authorise the Tailscale node in the admin console"
echo "       https://login.tailscale.com/admin/machines"
echo "       → then add it to inventory + Prometheus targets on monitoring host"
echo "    1. scp $AG_HOME/.secrets/alpenglow/{identity,vote-account-keypair}.json"
echo "    2. sudo -u $AG_USER -i bash -c 'cd ag-community-cluster && ./scripts/build-alpenglow.sh'"
echo "    3. sudo $REPO/scripts/reset-ledger.sh --yes"
echo "    4. sudo $REPO/scripts/install-service.sh"
echo "    5. sudo systemctl start agave-alpenglow"
echo "================================================================"
