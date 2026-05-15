#!/bin/bash
# Step 0 from the gist (2026-05-15 re-spin):
#   "Stop any existing validator process and delete the ledger directory
#    from the previous cluster run"
#
# Must run as root. Aborts unless --yes is passed because the ledger
# wipe is destructive — once gone, the validator must re-fetch a
# snapshot before it can vote.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$REPO_DIR/config/env.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: must run as root (sudo $0 --yes)"
  exit 1
fi

if [ "${1:-}" != "--yes" ]; then
  cat <<EOF
This will:
  1. systemctl stop solana-validator  (if running)
  2. rm -rf $AG_LEDGER/*
  3. rm -rf $AG_ACCOUNTS/*

The Alpenglow cluster was re-spun on 2026-05-15 (new genesis hash).
Any ledger from the previous run is incompatible.

Re-run with --yes to proceed:
  sudo $0 --yes
EOF
  exit 1
fi

echo "=== Step 0: stop validator + reset ledger ==="

if systemctl list-unit-files | grep -q "^solana-validator.service"; then
  echo "Stopping solana-validator..."
  systemctl stop solana-validator || true
else
  echo "solana-validator service not installed yet — skipping stop"
fi

# Wipe ledger + accounts content but keep the mount points / directories
for dir in "$AG_LEDGER" "$AG_ACCOUNTS"; do
  if [ -d "$dir" ]; then
    echo "Wiping $dir"
    find "$dir" -mindepth 1 -delete
  fi
done

# Make sure the directories themselves exist + are owned by AG_USER
for dir in "$AG_LEDGER" "$AG_ACCOUNTS" "$(dirname "$AG_LOG")"; do
  install -d -o "$AG_USER" -g "$AG_USER" -m 0755 "$dir"
done

echo "=== Ledger reset complete ==="
echo
echo "Next:"
echo "  sudo systemctl start solana-validator"
echo "  sudo -u $AG_USER $AG_BIN -l $AG_LEDGER monitor"
