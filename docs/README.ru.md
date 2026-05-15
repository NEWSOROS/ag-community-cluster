# Alpenglow Community Cluster — оператор

Скрипты и runbook для запуска валидатора в Alpenglow community cluster. Кластер сейчас ждёт супер-большинство (≥66 % stake онлайн) перед стартом производства блоков. Если ты не успел в genesis-set — всё равно подключайся, stake делегируется позже.

Актуальная инструкция (re-spin 2026-05-15):
[AshwinSekar/71d0847fa3408be79ac41b93316c7929](https://gist.github.com/AshwinSekar/71d0847fa3408be79ac41b93316c7929)
(предыдущая: [tigarcia/bf6ea6585c29c764f3820d9176eeb8f1](https://gist.github.com/tigarcia/bf6ea6585c29c764f3820d9176eeb8f1))

## Константы кластера (re-spin 2026-05-15)

| Поле | Значение |
|------|----------|
| Источник | `https://github.com/AshwinSekar/solana.git` |
| **Git ref** | тег **`ag-v0.2.0`** (был branch `alpenglow`) |
| Ожидаемая `--version` | `agave-validator 0.2.0 (src:fa5b2c96; feat:f4b7e03c, client:Agave)` |
| Entrypoint 1 | `64.130.37.11:8000` |
| Entrypoint 2 | `213.239.141.10:8001` |
| Expected shred version | `61773` |
| Expected genesis hash | `EWmdgUv3HA8184C27qBDQRHMcQdW6kGTr3pMb67tUPXJ` |
| Expected bank hash | `4GWsshLJm3tHGcQko1rBp34LfSdwYCkuYp8GXZAbRRVX` |
| Wait for supermajority | slot `0` |
| Метрики | DB `alpenglow-testnet` на `metrics.solana.com:8086` |

> **Кластер был пересоздан 2026-05-15.** Старый ledger несовместим (genesis hash изменился). Перед первым стартом — выполнить `reset-ledger.sh`.

## Быстрый старт

```bash
# 1. Клонируем репу на хост валидатора
git clone https://github.com/NEWSOROS/ag-community-cluster.git
cd ag-community-cluster

# 2. Перед билдом — отредактировать config/env.sh под хост
#    (AG_USER, AG_LEDGER, AG_ACCOUNTS, AG_LOG, AG_RPC_PORT, AG_DYNAMIC_PORT_RANGE)

# 3. Билдим agave-validator ag-v0.2.0 (~25–40 мин)
./scripts/build-alpenglow.sh
# Проверяем: $AG_BIN --version  →  должно начинаться с "agave-validator 0.2.0"

# 4. Положить уже существующие ключи в $AG_SECRETS_DIR
#    (по умолчанию /home/<user>/.secrets/alpenglow/):
#      identity.json
#      vote-account-keypair.json
# Или сгенерить новые (только если identity ещё не зарегистрирован):
#    ./scripts/keygen.sh

# 5. Остановить старый валидатор + удалить ledger от предыдущего run:
sudo ./scripts/reset-ledger.sh --yes

# 6. Установить systemd unit и стартовать:
sudo ./scripts/install-service.sh
sudo systemctl start agave-alpenglow

# 7. Смотрим, как ждём супер-большинство:
sudo -u solana agave-validator -l "$AG_LEDGER" monitor
```

## Что в репе

```
scripts/
  build-alpenglow.sh     Клонит, checkout ag-v0.2.0, билдит, активирует через симлинк
  keygen.sh              Генерит identity + vote-account (если нет своих)
  reset-ledger.sh        Step 0 — стоп валидатор + удалить старый ledger (после re-spin)
  install-service.sh     Рендерит шаблон systemd unit, ставит, enable
  start-validator.sh     Foreground запуск (без systemd) — для теста
config/
  env.sh                 Все пути и переменные в одном месте
  validator-args.sh      Argv для agave-validator — единый источник правды
systemd/
  agave-alpenglow.service.tmpl   Шаблон unit, install-service.sh подставляет
docs/
  README.ru.md           Этот файл
  troubleshooting.md     Типичные проблемы + куски логов
```

## Genesis-set vs позднее подключение

- **До супер-большинства (сейчас):** твой stake идёт в копилку для достижения 66 %. Кластер стоит на slot 0 пока не наберёт.
- **После супер-большинства:** валидатор синкается из сети, stake делегируется в следующих раундах.

Аргументы запуска одинаковые — `--wait-for-supermajority 0` безвреден после прохождения slot 0.

## Регистрация валидатора

Заполнить форму оператора. Нужно:
- Имя валидатора / организации
- Контакт (TG / Discord)
- Mainnet Identity Pubkey (если есть)
- Community Cluster Identity Pubkey ← из `keygen.sh`
- Community Cluster Vote Account Pubkey ← из `keygen.sh`

## Лицензия

MIT
