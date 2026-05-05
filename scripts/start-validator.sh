#!/bin/bash
# Foreground start of agave-validator — useful for first-run testing
# without enabling the systemd unit. Ctrl-C to stop. Logs still go to
# $AG_LOG (via --log).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$REPO_DIR/config/env.sh"
# shellcheck disable=SC1091
source "$REPO_DIR/config/validator-args.sh"

mkdir -p "$AG_LEDGER" "$AG_ACCOUNTS" "$(dirname "$AG_LOG")"

echo "=== Starting agave-validator (foreground) ==="
echo "Binary: $AG_BIN"
echo "Args:   ${AG_VALIDATOR_ARGS[*]}"
echo

exec "$AG_BIN" "${AG_VALIDATOR_ARGS[@]}"
