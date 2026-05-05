#!/bin/bash
# Generate identity + vote-account keypairs for the Alpenglow community cluster.
# Will REFUSE to overwrite existing files — delete them manually first if you
# really want to rotate.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$REPO_DIR/config/env.sh"

if ! command -v solana-keygen >/dev/null; then
  echo "ERROR: solana-keygen not found in PATH."
  echo "Build the validator first (./scripts/build-alpenglow.sh) or install solana CLI."
  exit 1
fi

mkdir -p "$AG_SECRETS_DIR"
chmod 700 "$AG_SECRETS_DIR"

generate() {
  local label="$1"
  local path="$2"
  if [ -f "$path" ]; then
    echo "  $label already exists at $path — skipping"
    echo "    pubkey: $(solana-keygen pubkey "$path")"
    return
  fi
  echo "  Generating $label → $path"
  solana-keygen new --no-bip39-passphrase --silent -o "$path"
  chmod 600 "$path"
  echo "    pubkey: $(solana-keygen pubkey "$path")"
}

echo "=== Alpenglow keypairs ==="
generate "identity"     "$AG_IDENTITY"
generate "vote-account" "$AG_VOTE_ACCOUNT"

echo
echo "Submit these pubkeys in the operator form:"
echo "  Community Cluster Identity Pubkey   : $(solana-keygen pubkey "$AG_IDENTITY")"
echo "  Community Cluster Vote Account Pubkey: $(solana-keygen pubkey "$AG_VOTE_ACCOUNT")"
echo
echo "BACKUP $AG_SECRETS_DIR NOW. There are no second copies."
