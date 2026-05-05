#!/bin/bash
# Build agave-validator from AshwinSekar/solana#alpenglow.
# Output: $AG_INSTALL_DIR/bin/agave-validator (symlinked to versioned dir)
#
# Run as the validator user (e.g. `solana`) — needs cargo + write access
# to $AG_SRC_DIR.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$REPO_DIR/config/env.sh"

# Load cargo if running outside a login shell
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

if ! command -v cargo >/dev/null; then
  echo "ERROR: cargo not found. Install rustup first:"
  echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
  exit 1
fi

echo "=== Build alpenglow ==="
echo "  source dir : $AG_SRC_DIR"
echo "  install dir: $AG_INSTALL_DIR"
echo

# 1. Clone or update
if [ ! -d "$AG_SRC_DIR/.git" ]; then
  echo "Cloning AshwinSekar/solana → $AG_SRC_DIR"
  git clone https://github.com/AshwinSekar/solana.git "$AG_SRC_DIR"
fi

cd "$AG_SRC_DIR"
git fetch
git checkout alpenglow
git pull --ff-only

CI_COMMIT=$(git rev-parse --short HEAD)
echo "Building commit: $CI_COMMIT"

# 2. Build
# Use nice -n 19 so the build doesn't starve other validators on the same box.
echo "Building (nice -n 19, --validator-only)..."
INSTALL_TARGET="$HOME/.local/share/solana/alpenglow/releases/$CI_COMMIT"
mkdir -p "$INSTALL_TARGET"
nice -n 19 ./scripts/cargo-install-all.sh --validator-only "$INSTALL_TARGET"

# 3. Activate via symlink
mkdir -p "$(dirname "$AG_INSTALL_DIR")"
ln -sfn "$INSTALL_TARGET" "$AG_INSTALL_DIR"

echo
echo "=== Build complete ==="
echo "Binary : $AG_BIN"
echo "Version: $("$AG_BIN" --version 2>/dev/null || echo unknown)"
echo
echo "Next:"
echo "  ./scripts/keygen.sh           — only if you don't have keypairs yet"
echo "  sudo ./scripts/install-service.sh"
echo "  sudo systemctl start agave-alpenglow"
