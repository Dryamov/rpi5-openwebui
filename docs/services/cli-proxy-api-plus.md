# Конфигурация CLI-Proxy-API-Plus

## Обзор

CLI-Proxy-API-Plus — прокси-сервер для работы с различными AI API (OpenAI, Anthropic, и др.), позволяющий централизованно управлять API ключами и маршрутизацией запросов.

## Конфигурационные файлы

- **config.yaml**: `/home/dryamov/Repositories/rpi5-openwebui/cli-proxy-api-plus/config/config.yaml`
- **config.example.yaml**: `/home/dryamov/Repositories/rpi5-openwebui/cli-proxy-api-plus/config.example.yaml`
- **Docker volume**: `cli-proxy_auths` (авторизация)

> [!CAUTION]
> **Безопасность**: `config.yaml` содержит API ключи в plain text! Убедитесь, что файл добавлен в `.gitignore` (уже сделано).

## Начальная настройка

1. Скопируйте example конфиг:
   ```bash
   cp cli-proxy-api-plus/config.example.yaml cli-proxy-api-plus/config/config.yaml
   ```

2. Отредактируйте `config.yaml` и добавьте ваши API ключи:
   ```yaml
   providers:
     - name: openai
       api_key: sk-ваш-ключ-здесь
       enabled: true
     
     - name: anthropic
       api_key: sk-ant-ваш-ключ-здесь
       enabled: false  # Отключен по умолчанию
   ```

3. Перезапустите сервис:
   ```bash
   docker compose restart cli-proxy-api-plus
   ```

## Переменные окружения

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `DEPLOY` | *(пусто)* | Режим развертывания (production/development) |

## Порты

- **8317**: Внутренний HTTP API  
- **54545**: Экспортирован на хост (WebSocket для real-time)
- **51121**: Экспортирован на хост (дополнительный API endpoint)

## Интеграция с Caddy

CLI-Proxy доступен через Caddy по адресу `${CLIPROXY_HOSTNAME}` (по умолчанию `proxy.localhost`).

## Troubleshooting

### Проблема: API ключи не работают

**Проверка**:
```bash
# Посмотреть логи
docker compose logs cli-proxy-api-plus | grep -i error

# Проверить, что config.yaml читается
docker exec cli-proxy-api-plus ls -la /CLIProxyAPI/config.yaml
```

**Решение**: Убедитесь, что:
1. API ключ корректен и не истек
2. `enabled: true` для нужного провайдера
3. Файл `config.yaml` имеет правильные права доступа

### Проблема: Health check падает

**Причина**: Сервис медленно стартует из-за инициализации провайдеров.

**Решение**: Health check уже настроен с `start_period: 10s`. Если проблема сохраняется, увеличьте timeout:
```yaml
healthcheck:
  timeout: 15s  # Вместо 10s
```

### Проблема: "config.yaml already tracked by git"

**Причина**: Файл был добавлен в git до обновления `.gitignore`.

**Решение**:
```bash
# Удалить из git (но оставить локально)
git rm --cached cli-proxy-api-plus/config/config.yaml

# Коммит изменения
git commit -m "Remove config.yaml from git tracking"
```

## Безопасность

### Рекомендации

1. **Никогда не коммитьте `config.yaml`** в git
2. Используйте переменные окружения для API ключей (если поддерживается провайдером)
3. Ограничьте доступ к портам 54545/51121 через firewall в production

### Альтернатива: Environment Variables

Если ваша версия CLI-Proxy-API-Plus поддерживает переменные окружения для ключей:

```env
# В .env или docker-compose.yml
OPENAI_API_KEY=sk-ваш-ключ
ANTHROPIC_API_KEY=sk-ant-ваш-ключ
```

Затем reference их в `config.yaml`:
```yaml
providers:
  - name: openai
    api_key: ${OPENAI_API_KEY}
```

## Логи

Логи хранятся в `cli-proxy-api-plus/logs/`:

```bash
# Просмотр последних логов
tail -f cli-proxy-api-plus/logs/access.log

# Поиск ошибок
grep -i error cli-proxy-api-plus/logs/*.log
```

## Обновление

```bash
# Бэкап конфига (содержит ключи!)
cp cli-proxy-api-plus/config/config.yaml cli-proxy-api-plus/config/config.yaml.backup

# Обновить образ
docker compose pull cli-proxy-api-plus

# Перезапустить
docker compose up -d cli-proxy-api-plus

# Проверить, что конфиг загрузился
docker compose logs cli-proxy-api-plus | head -20
```

> [!IMPORTANT]
> Всегда делайте бэкап `config.yaml` перед обновлением, так как он не версионируется в git.
