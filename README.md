# Alpenglow Community Cluster — Operator Toolkit

**[README на русском](docs/README.ru.md)**

Tooling and runbook for joining the Alpenglow community cluster. The cluster is currently waiting for super majority to start. Operators not in the genesis set can still join — stake will be delegated afterwards.

Current upstream instructions (2026-05-15 cluster re-spin):
[AshwinSekar/71d0847fa3408be79ac41b93316c7929](https://gist.github.com/AshwinSekar/71d0847fa3408be79ac41b93316c7929)
(prior version: [tigarcia/bf6ea6585c29c764f3820d9176eeb8f1](https://gist.github.com/tigarcia/bf6ea6585c29c764f3820d9176eeb8f1))

## Cluster Constants (2026-05-15 re-spin)

| Field | Value |
|-------|-------|
| Source repo | `https://github.com/AshwinSekar/solana.git` |
| **Git ref** | tag **`ag-v0.2.0`** (was branch `alpenglow`) |
| Expected `--version` | `agave-validator 0.2.0 (src:fa5b2c96; feat:f4b7e03c, client:Agave)` |
| Entrypoint 1 | `64.130.37.11:8000` |
| Entrypoint 2 | `213.239.141.10:8001` |
| Expected shred version | `61773` |
| Expected genesis hash | `EWmdgUv3HA8184C27qBDQRHMcQdW6kGTr3pMb67tUPXJ` |
| Expected bank hash | `4GWsshLJm3tHGcQko1rBp34LfSdwYCkuYp8GXZAbRRVX` |
| Wait for supermajority | slot `0` |
| Metrics DB | `alpenglow-testnet` on `metrics.solana.com:8086` |

> **The cluster was re-spun on 2026-05-15.** Any existing ledger from the
> previous run is incompatible (genesis hash changed). Use `reset-ledger.sh`
> before the first start with this revision.

## Quick start

```bash
# 1. Clone this repo onto the validator host
git clone https://github.com/NEWSOROS/ag-community-cluster.git
cd ag-community-cluster

# 2. Pick storage layout BEFORE the build: edit config/env.sh
#    AG_USER, AG_LEDGER, AG_ACCOUNTS, AG_LOG, AG_HOME, AG_RPC_PORT, AG_DYNAMIC_PORT_RANGE

# 3. Build agave-validator ag-v0.2.0 (~25-40 min on a fast box)
./scripts/build-alpenglow.sh
# Verify: $AG_BIN --version  → should start with "agave-validator 0.2.0"

# 4. Drop the existing keypairs into $AG_SECRETS_DIR (default /home/<user>/.secrets/alpenglow/):
#    - identity.json
#    - vote-account-keypair.json
# Or generate fresh ones — only if not joining with an already-registered identity:
#    ./scripts/keygen.sh

# 5. Stop any previous validator AND wipe the old ledger (REQUIRED — cluster was re-spun):
sudo ./scripts/reset-ledger.sh --yes

# 6. Install the systemd unit and start
sudo ./scripts/install-service.sh
sudo systemctl start solana-validator

# 7. Watch it wait for supermajority
sudo -u solana agave-validator -l "$AG_LEDGER" monitor
```

## What's in this repo

```
scripts/
  build-alpenglow.sh      Clone + checkout ag-v0.2.0 + cargo build (validator-only)
  keygen.sh               Generate identity + vote-account keypairs (skip if you have them)
  reset-ledger.sh         Step 0 — stop validator + wipe ledger (required after re-spin)
  install-service.sh      Render env.sh into systemd unit + enable
  start-validator.sh      Direct foreground start (no systemd) — for testing
config/
  env.sh                  All paths and env vars in one file (source me)
  validator-args.sh       The agave-validator arg list — single source of truth
systemd/
  solana-validator.service.tmpl   Systemd template; install-service.sh fills it
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
