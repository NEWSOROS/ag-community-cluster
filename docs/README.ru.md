# Alpenglow Community Cluster — оператор

Скрипты и runbook для запуска валидатора в Alpenglow community cluster. Кластер сейчас ждёт супер-большинство (≥66 % stake онлайн) перед стартом производства блоков. Если ты не успел в genesis-set — всё равно подключайся, stake делегируется позже.

Оригинальная инструкция: [tigarcia/bf6ea6585c29c764f3820d9176eeb8f1](https://gist.github.com/tigarcia/bf6ea6585c29c764f3820d9176eeb8f1)

## Константы кластера

| Поле | Значение |
|------|----------|
| Источник | `https://github.com/AshwinSekar/solana.git` |
| Ветка | `alpenglow` |
| Entrypoint | `64.130.37.11:8000` |
| Expected shred version | `25519` |
| Expected genesis hash | `DoJeJQZwEvKhDxn3uE1ZXNR5Bq1y4BAFkG2tDseV3Ga2` |
| Expected bank hash | `2pM9pWtQcWQY4MuRhvCtNpFjBDZMxeNyDsusY2xT8K49` |
| Wait for supermajority | slot `0` |
| Метрики | DB `alpenglow-testnet` на `metrics.solana.com:8086` |

## Быстрый старт

```bash
# 1. Клонируем репу на хост валидатора
git clone https://github.com/NEWSOROS/ag-community-cluster.git
cd ag-community-cluster

# 2. Билдим форк Ashwin (~25–40 мин на быстром железе)
./scripts/build-alpenglow.sh

# 3. Генерим identity + vote-account ключи (если нет своих)
./scripts/keygen.sh

# 4. Под свой хост — отредактировать config/env.sh
#    (AG_LEDGER, AG_ACCOUNTS, AG_LOG, пути)

# 5. Установить systemd unit и стартовать
sudo ./scripts/install-service.sh
sudo systemctl start agave-alpenglow

# 6. Смотрим как ждём супер-большинство
sudo -u solana agave-validator -l "$AG_LEDGER" monitor
```

## Что в репе

```
scripts/
  build-alpenglow.sh     Клонит, билдит, активирует через симлинк
  keygen.sh              Генерит identity + vote-account
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
