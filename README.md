# Alpenglow Community Cluster — Operator Toolkit

**[README на русском](docs/README.ru.md)**

Tooling and runbook for joining the Alpenglow community cluster. The cluster is currently waiting for super majority to start. Operators not in the genesis set can still join — stake will be delegated afterwards.

Original instructions: [tigarcia/bf6ea6585c29c764f3820d9176eeb8f1](https://gist.github.com/tigarcia/bf6ea6585c29c764f3820d9176eeb8f1)

## Cluster Constants

| Field | Value |
|-------|-------|
| Source repo | `https://github.com/AshwinSekar/solana.git` |
| Branch | `alpenglow` |
| Entrypoint | `64.130.37.11:8000` |
| Expected shred version | `25519` |
| Expected genesis hash | `DoJeJQZwEvKhDxn3uE1ZXNR5Bq1y4BAFkG2tDseV3Ga2` |
| Expected bank hash | `2pM9pWtQcWQY4MuRhvCtNpFjBDZMxeNyDsusY2xT8K49` |
| Wait for supermajority | slot `0` |
| Metrics DB | `alpenglow-testnet` on `metrics.solana.com:8086` |

## Quick start

```bash
# 1. Clone this repo onto the validator host
git clone https://github.com/NEWSOROS/ag-community-cluster.git
cd ag-community-cluster

# 2. Build the alpenglow agave fork (~25-40 min on a fast box)
./scripts/build-alpenglow.sh

# 3. Generate identity + vote-account keypairs (skip if you already have them)
./scripts/keygen.sh

# 4. Pick storage layout: edit config/env.sh
#    AG_LEDGER, AG_ACCOUNTS, AG_LOG, AG_HOME, AG_BIN

# 5. Install the systemd unit and start
sudo ./scripts/install-service.sh
sudo systemctl start agave-alpenglow

# 6. Watch it wait for supermajority
sudo -u solana agave-validator -l "$AG_LEDGER" monitor
```

## What's in this repo

```
scripts/
  build-alpenglow.sh      Clone + checkout + cargo build (validator-only)
  keygen.sh               Generate identity + vote-account keypairs
  install-service.sh      Render env.sh into systemd unit + enable
  start-validator.sh      Direct foreground start (no systemd) — for testing
config/
  env.sh                  All paths and env vars in one file (source me)
  validator-args.sh       The agave-validator arg list — single source of truth
systemd/
  agave-alpenglow.service.tmpl   Systemd template; install-service.sh fills it
docs/
  README.ru.md            Russian version of this document
  troubleshooting.md      Common issues + log snippets
```

## Joining the genesis set vs joining late

The community cluster has two regimes:
- **Pre-supermajority (now):** validators that join contribute to reaching super-majority. The cluster waits at slot 0 until ≥66% stake is online.
- **Post-supermajority:** the cluster has started producing blocks. New validators sync from the network and stake will be delegated to them in subsequent rounds.

The startup args are identical in both cases — `--wait-for-supermajority 0` is harmless once the cluster is past slot 0.

## Hardware requirements

Same as standard Solana validator. For the genesis set (low load early on), a 32-core / 256 GB RAM / 2× NVMe box is plenty. After full block production resumes, expect mainnet-class load.

We deploy these on top of [sv-manager](https://github.com/NEWSOROS/sv-manager) — see [docs/sv-manager-integration.md](docs/sv-manager-integration.md) for how to layer the alpenglow validator alongside an existing mainnet/testnet validator on the same host (separate ports, ledger, identity).

## Submitting your validator

Fill the operator form: [Validator registration](https://docs.google.com/forms) — provide:
- Validator / Organization Name
- Contact (TG / Discord)
- Mainnet Identity Pubkey (if applicable)
- Community Cluster Identity Pubkey ← from `keygen.sh`
- Community Cluster Vote Account Pubkey ← from `keygen.sh`

## License

MIT
