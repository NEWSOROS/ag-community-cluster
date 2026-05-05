#!/bin/bash
# Render systemd/agave-alpenglow.service.tmpl with values from config/env.sh
# and install it to /etc/systemd/system/. Must run as root (or via sudo).

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: must run as root (sudo $0)"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPL="$REPO_DIR/systemd/agave-alpenglow.service.tmpl"
DEST="/etc/systemd/system/agave-alpenglow.service"

# shellcheck disable=SC1091
source "$REPO_DIR/config/env.sh"

echo "=== Render systemd unit ==="
echo "Template: $TMPL"
echo "Dest    : $DEST"

# Pre-flight checks: required files / dirs
for var in AG_BIN AG_IDENTITY AG_VOTE_ACCOUNT; do
  path="${!var}"
  if [ ! -e "$path" ]; then
    echo "ERROR: $var=$path does not exist."
    case "$var" in
      AG_BIN)          echo "  → run ./scripts/build-alpenglow.sh as $AG_USER first" ;;
      AG_IDENTITY|AG_VOTE_ACCOUNT) echo "  → run ./scripts/keygen.sh as $AG_USER first, or copy keypairs in" ;;
    esac
    exit 1
  fi
done

# Make sure data dirs exist + are owned by AG_USER (validator process needs r/w)
for dir in "$AG_LEDGER" "$AG_ACCOUNTS" "$(dirname "$AG_LOG")"; do
  install -d -o "$AG_USER" -g "$AG_USER" -m 0755 "$dir"
done

# Render template
sed \
  -e "s|__AG_USER__|$AG_USER|g" \
  -e "s|__AG_HOME__|$AG_HOME|g" \
  -e "s|__AG_INSTALL_DIR__|$AG_INSTALL_DIR|g" \
  -e "s|__AG_BIN__|$AG_BIN|g" \
  -e "s|__AG_RPC_PORT__|$AG_RPC_PORT|g" \
  -e "s|__AG_IDENTITY__|$AG_IDENTITY|g" \
  -e "s|__AG_VOTE_ACCOUNT__|$AG_VOTE_ACCOUNT|g" \
  -e "s|__AG_LOG__|$AG_LOG|g" \
  -e "s|__AG_LEDGER__|$AG_LEDGER|g" \
  -e "s|__AG_ACCOUNTS__|$AG_ACCOUNTS|g" \
  -e "s|__AG_DYNAMIC_PORT_RANGE__|$AG_DYNAMIC_PORT_RANGE|g" \
  -e "s|__AG_ENTRYPOINT__|$AG_ENTRYPOINT|g" \
  -e "s|__AG_EXPECTED_SHRED_VERSION__|$AG_EXPECTED_SHRED_VERSION|g" \
  -e "s|__AG_EXPECTED_BANK_HASH__|$AG_EXPECTED_BANK_HASH|g" \
  -e "s|__AG_EXPECTED_GENESIS_HASH__|$AG_EXPECTED_GENESIS_HASH|g" \
  -e "s|__AG_WAIT_FOR_SUPERMAJORITY__|$AG_WAIT_FOR_SUPERMAJORITY|g" \
  -e "s|__RUST_LOG__|$RUST_LOG|g" \
  -e "s|__SOLANA_METRICS_CONFIG__|$SOLANA_METRICS_CONFIG|g" \
  "$TMPL" > "$DEST"

chmod 644 "$DEST"

echo "Installed: $DEST"
echo
systemctl daemon-reload
systemctl enable agave-alpenglow.service

echo
echo "=== Service installed and enabled ==="
echo "Start  : sudo systemctl start agave-alpenglow"
echo "Status : systemctl status agave-alpenglow"
echo "Logs   : journalctl -u agave-alpenglow -f"
echo "Monitor: sudo -u $AG_USER $AG_BIN -l $AG_LEDGER monitor"
