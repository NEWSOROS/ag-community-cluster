#!/bin/bash
# Single source of truth for paths, users, and the agave-validator argv.
# Edit this file (especially AG_LEDGER and AG_ACCOUNTS) to match your host.

# ===== User =====
export AG_USER="${AG_USER:-solana}"
export AG_HOME="${AG_HOME:-/home/$AG_USER}"

# ===== Source build location =====
# Where build-alpenglow.sh clones AshwinSekar/solana
export AG_SRC_DIR="${AG_SRC_DIR:-$AG_HOME/agave-alpenglow}"
# Where the built binary is symlinked
export AG_INSTALL_DIR="${AG_INSTALL_DIR:-$AG_HOME/.local/share/solana/alpenglow/active}"
export AG_BIN="${AG_BIN:-$AG_INSTALL_DIR/bin/agave-validator}"

# ===== Keypairs =====
export AG_SECRETS_DIR="${AG_SECRETS_DIR:-$AG_HOME/.secrets/alpenglow}"
export AG_IDENTITY="${AG_IDENTITY:-$AG_SECRETS_DIR/identity.json}"
export AG_VOTE_ACCOUNT="${AG_VOTE_ACCOUNT:-$AG_SECRETS_DIR/vote-account-keypair.json}"

# ===== Storage =====
# Use a SEPARATE ledger and accounts dir from any other validator on this host.
# Default puts them under /mnt/solana/alpenglow but you may need to point
# AG_LEDGER at a fast NVMe partition you've already mounted.
export AG_DATA_BASE="${AG_DATA_BASE:-/mnt/solana/alpenglow}"
export AG_LEDGER="${AG_LEDGER:-$AG_DATA_BASE/ledger}"
export AG_ACCOUNTS="${AG_ACCOUNTS:-$AG_DATA_BASE/accounts}"
export AG_LOG="${AG_LOG:-$AG_DATA_BASE/log/solana-validator.log}"

# ===== Network =====
# Dynamic port range — make sure this doesn't overlap with any other
# validator on this host. Default 9000-12500 (Alpenglow gist value).
export AG_DYNAMIC_PORT_RANGE="${AG_DYNAMIC_PORT_RANGE:-9000-12500}"
export AG_RPC_PORT="${AG_RPC_PORT:-8899}"

# ===== Cluster constants (do not change unless instructed by Anza/Jito) =====
export AG_ENTRYPOINT="64.130.37.11:8000"
export AG_EXPECTED_SHRED_VERSION="25519"
export AG_EXPECTED_GENESIS_HASH="DoJeJQZwEvKhDxn3uE1ZXNR5Bq1y4BAFkG2tDseV3Ga2"
export AG_EXPECTED_BANK_HASH="2pM9pWtQcWQY4MuRhvCtNpFjBDZMxeNyDsusY2xT8K49"
export AG_WAIT_FOR_SUPERMAJORITY="0"

# ===== Metrics =====
export SOLANA_METRICS_CONFIG="host=https://metrics.solana.com:8086,db=alpenglow-testnet,u=ag,p=!d.tWEViQRhhP.*be9!a"

# ===== Logging =====
export RUST_LOG="${RUST_LOG:-INFO}"
