#!/bin/bash
# agave-validator argv builder for the Alpenglow community cluster.
# Sourced by both start-validator.sh (foreground) and the systemd unit.
#
# IMPORTANT: source config/env.sh BEFORE this file. The args below
# rely on AG_* variables defined there.
#
# Adapted from the official gist:
#   https://gist.github.com/tigarcia/bf6ea6585c29c764f3820d9176eeb8f1

AG_VALIDATOR_ARGS=(
  --rpc-port "$AG_RPC_PORT"
  --full-rpc-api
  --identity         "$AG_IDENTITY"
  --vote-account     "$AG_VOTE_ACCOUNT"
  --log              "$AG_LOG"
  --ledger           "$AG_LEDGER"
  --accounts         "$AG_ACCOUNTS"
  --dynamic-port-range          "$AG_DYNAMIC_PORT_RANGE"
  --entrypoint                  "$AG_ENTRYPOINT"
  --limit-ledger-size
  --expected-shred-version      "$AG_EXPECTED_SHRED_VERSION"
  --expected-bank-hash          "$AG_EXPECTED_BANK_HASH"
  --expected-genesis-hash       "$AG_EXPECTED_GENESIS_HASH"
  --wait-for-supermajority      "$AG_WAIT_FOR_SUPERMAJORITY"
  --no-port-check
  --no-poh-speed-test
)

export AG_VALIDATOR_ARGS
