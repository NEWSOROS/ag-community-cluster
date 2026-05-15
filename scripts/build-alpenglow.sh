#!/bin/bash
# Build agave-validator from AshwinSekar/solana at AG_GIT_REF (e.g. ag-v0.2.0).
# Output: $AG_INSTALL_DIR/bin/agave-validator (symlinked to versioned dir)
#
# Run as the validator user (e.g. `solana`) — needs cargo + write access
# to $AG_SRC_DIR.
#
# Tracks Ashwin's instruction (2026-05-15):
#   https://gist.github.com/AshwinSekar/71d0847fa3408be79ac41b93316c7929

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
echo "  git ref    : $AG_GIT_REF"
echo

# 1. Clone or update
if [ ! -d "$AG_SRC_DIR/.git" ]; then
  echo "Cloning AshwinSekar/solana → $AG_SRC_DIR"
  git clone https://github.com/AshwinSekar/solana.git "$AG_SRC_DIR"
fi

cd "$AG_SRC_DIR"
git fetch --tags
git checkout -f "$AG_GIT_REF"

# Export CI_COMMIT so the build records its own commit hash (gist instructions).
export CI_COMMIT=$(git rev-parse HEAD)
SHORT_COMMIT=$(git rev-parse --short HEAD)
echo "Building $AG_GIT_REF @ $SHORT_COMMIT"

# 2. Build
# nice -n 19 — don't starve other validators on the same box (if any).
echo "Building (nice -n 19, --validator-only)..."
INSTALL_TARGET="$HOME/.local/share/solana/alpenglow/releases/${AG_GIT_REF}-${SHORT_COMMIT}"
mkdir -p "$INSTALL_TARGET"
nice -n 19 ./scripts/cargo-install-all.sh --validator-only "$INSTALL_TARGET"

# 3. Activate via symlink
mkdir -p "$(dirname "$AG_INSTALL_DIR")"
ln -sfn "$INSTALL_TARGET" "$AG_INSTALL_DIR"

echo
echo "=== Build complete ==="
echo "Binary : $AG_BIN"
ACTUAL_VERSION=$("$AG_BIN" --version 2>/dev/null || echo "unknown")
echo "Version: $ACTUAL_VERSION"

# Sanity-check: must start with the expected version string per gist
if [ -n "${AG_EXPECTED_VERSION_PREFIX:-}" ]; then
  if [[ "$ACTUAL_VERSION" != "$AG_EXPECTED_VERSION_PREFIX"* ]]; then
    echo
    echo "WARNING: version mismatch."
    echo "  expected prefix: $AG_EXPECTED_VERSION_PREFIX"
    echo "  got            : $ACTUAL_VERSION"
    echo "  Continuing anyway — verify the gist hasn't moved if this surprises you."
  fi
fi

echo
echo "Next:"
echo "  ./scripts/keygen.sh           — only if you don't have keypairs yet"
echo "  sudo ./scripts/install-service.sh"
echo "  sudo systemctl start agave-alpenglow"
