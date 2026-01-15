# Конфигурация Caddy

## Обзор

Caddy выступает в роли reverse proxy для всех сервисов в стеке и автоматически управляет SSL/TLS сертификатами через Let's Encrypt.

## Конфигурационные файлы

- **Caddyfile**: `/home/dryamov/Repositories/rpi5-openwebui/caddy/config/Caddyfile`
- **Docker volumes**: `caddy_data` (SSL сертификаты), `caddy_config` (конфигурация)

## Переменные окружения

| Переменная | Обязательна | По умолчанию | Описание |
|------------|-------------|--------------|----------|
| `SEARXNG_BASE_URL` | Нет | `search.localhost` | Домен для SearXNG |
| `OPENWEBUI_HOSTNAME` | Нет | `ai.localhost` | Домен для OpenWebUI |
| `CLIPROXY_HOSTNAME` | Нет | `proxy.localhost` | Домен для CLI-Proxy-API-Plus |
| `LETSENCRYPT_EMAIL` | Да* | `internal` | Email для Let's Encrypt уведомлений |

*Обязательно для production с реальными доменами

## Примеры конфигурации

### Локальная разработка (без SSL)

```env
SEARXNG_BASE_URL=search.localhost
OPENWEBUI_HOSTNAME=ai.localhost
CLIPROXY_HOSTNAME=proxy.localhost
LETSENCRYPT_EMAIL=internal
```

Доступ: `http://ai.localhost:80`, `http://search.localhost:80`

### Production (с Let's Encrypt)

```env
SEARXNG_BASE_URL=search.example.com
OPENWEBUI_HOSTNAME=ai.example.com
CLIPROXY_HOSTNAME=proxy.example.com
LETSENCRYPT_EMAIL=admin@example.com
```

Caddy автоматически получит SSL сертификаты для всех доменов.

## Troubleshooting

### Проблема: Caddy не запускается

**Симптомы**: `docker compose logs caddy` показывает ошибки парсинга Caddyfile

**Решение**:
```bash
# Валидация Caddyfile
docker run --rm -v ./caddy/config:/etc/caddy:ro caddy:2.10 caddy validate --config /etc/caddy/Caddyfile
```

### Проблема: SSL сертификаты не генерируются

**Причины**:
1. DNS не указывает на ваш сервер
2. Порты 80/443 недоступны извне
3. Email не указан корректно

**Решение**:
```bash
# Проверка доступности портов
sudo netstat -tulpn | grep -E ':(80|443)'

# Проверка DNS
nslookup ai.example.com

# Логи Let's Encrypt
docker compose logs caddy | grep -i acme
```

### Проблема: "permission denied" для volumes

**Решение**: Убедитесь, что директория `caddy/config` доступна для чтения:
```bash
chmod -R 755 caddy/config
```

## Мониторинг

Caddy предоставляет метрики на порту 2019:
```bash
curl http://localhost:2019/metrics
```

Эти метрики используются health check'ом Docker Compose.

## Оптимизация для RPi5

- **Логирование**: По умолчанию настроена фильтрация логов для уменьшения нагрузки на диск
- **Лимиты памяти**: 256MB (достаточно для reverse proxy без тяжелой обработки)
- **Health check**: healthcheck проверяет `/metrics` endpoint каждые 10 секунд

## Обновление

```bash
# Остановить Caddy
docker compose stop caddy

# Обновить образ
docker compose pull caddy

# Запустить с новой версией
docker compose up -d caddy
```

> [!WARNING]
> При обновлении основной версии Caddy (например, 2.10 → 2.11) проверьте changelog на breaking changes в Caddyfile синтаксисе.
