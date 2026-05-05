# Troubleshooting

## Validator stuck on "waiting for supermajority"

This is the expected state until ≥66 % stake comes online. Run:

```bash
agave-validator -l "$AG_LEDGER" monitor
```

You'll see output like:

```
⠴ 00:00:23 | Processed Slot:        0 | Confirmed Slot:        0 | Finalized Slot:        0
```

Slots stay at 0 until supermajority is reached. Nothing to fix on the operator side — just wait.

## "Failed to start: bind: Address already in use" on RPC port 8899

Another validator on the same host owns 8899. Edit `config/env.sh`:

```bash
export AG_RPC_PORT=8898
```

Then re-render the unit:

```bash
sudo ./scripts/install-service.sh
sudo systemctl restart agave-alpenglow
```

## "Failed to start: bind: Address already in use" on a gossip/turbine port

`AG_DYNAMIC_PORT_RANGE` overlaps with another validator. Pick a non-overlapping range:

```bash
# If your existing validator uses 8000–8800:
export AG_DYNAMIC_PORT_RANGE="13000-15000"
```

## "Hash mismatch: bank hash"

Your local ledger drifted from the cluster genesis. Wipe the ledger and accounts:

```bash
sudo systemctl stop agave-alpenglow
sudo rm -rf "$AG_LEDGER"/* "$AG_ACCOUNTS"/*
sudo systemctl start agave-alpenglow
```

(`AG_LEDGER` and `AG_ACCOUNTS` from `config/env.sh`.)

## Build OOM-killed during link

`agave-validator` link step uses ~16 GB RAM. If you have less:

```bash
# Drop link-time parallelism
export CARGO_BUILD_JOBS=1
./scripts/build-alpenglow.sh
```

Or build on another box and `scp` the binary into `$AG_INSTALL_DIR/bin/`.

## Validator restarts every minute

Look at the journal:

```bash
journalctl -u agave-alpenglow -n 200 --no-pager
```

Common causes:
- **Plugin ABI mismatch**: do NOT pass `--geyser-plugin-config` here. Alpenglow validator interface differs from mainnet 3.1.x; standard Yellowstone plugin will panic.
- **Identity pubkey not in cluster manifest**: the cluster operators haven't whitelisted your validator yet. Check the shared spreadsheet / form status.
- **Wrong `--expected-bank-hash`**: copy-paste mistake. Compare with `config/env.sh` (which mirrors the official gist).

## Logs grow forever

`limit-ledger-size` is on, but `--log` writes to a single file. Add logrotate:

```
# /etc/logrotate.d/agave-alpenglow
$AG_LOG {
  daily
  rotate 1
  size 1G
  compress
  missingok
  postrotate
    systemctl kill -s USR1 agave-alpenglow.service
  endscript
}
```

(Substitute the literal `$AG_LOG` value from `config/env.sh`.)
