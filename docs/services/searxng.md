# Конфигурация SearXNG

## Обзор

SearXNG — метапоисковый движок, который агрегирует результаты из множества поисковых систем, обеспечивая приватность пользователей.

## Конфигурационные файлы

- **settings.yml**: `/home/dryamov/Repositories/rpi5-openwebui/searxng/config/settings.yml`
- **Docker volume**: `searxng_data` (кэш результатов)

## Переменные окружения

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `SEARXNG_PUBLIC_INSTANCE` | `false` | Публичный доступ (не рекомендуется для RPi5) |
| `SEARXNG_LIMITER` | `true` | Rate limiting для защиты от DDoS |
| `SEARXNG_BASE_URL` | `https://search.search.localhost/` | Базовый URL для SearXNG |
| `SEARXNG_SECRET` | *(обязательно)* | Секретный ключ для безопасности |
| `SEARXNG_VALKEY_URL` | `valkey://valkey:6379/0` | URL для подключения к Valkey (кэш) |
| `SEARXNG_PORT` | `8080` | Внутренний порт контейнера |

## Интеграция с Valkey

SearXNG использует Valkey (форк Redis) для кэширования результатов поиска, что значительно ускоряет повторные запросы.

**Конфигурация**: Valkey автоматически подключается через `SEARXNG_VALKEY_URL`.

**Проверка**:
```bash
# Проверить, что Valkey доступен
docker exec valkey valkey-cli ping
# Ожидаемый результат: PONG

# Посмотреть статистику кэша
docker exec valkey valkey-cli INFO stats
```

## Rate Limiting

С версии 2.0 плана **SEARXNG_LIMITER** включен по умолчанию для защиты от:
- Случайных циклических запросов от AI агентов
- DDoS атак (даже для приватных инстансов)

Если вы уверены, что limiter не нужен:
```env
SEARXNG_LIMITER=false
```

## Примеры конфигурации

### Приватный инстанс (рекомендуется)

```env
SEARXNG_PUBLIC_INSTANCE=false
SEARXNG_LIMITER=true
SEARXNG_SECRET=$(openssl rand -hex 32)
```

### Публичный инстанс (не рекомендуется на RPi5)

```env
SEARXNG_PUBLIC_INSTANCE=true
SEARXNG_LIMITER=true  # ВСЕГДА включайте для публичных инстансов!
SEARXNG_SECRET=$(openssl rand -hex 32)
```

## Troubleshooting

### Проблема: Health check падает с ошибкой "X-Forwarded-For required"

**Причина**: SearXNG требует заголовок `X-Forwarded-For` для безопасности.

**Решение**: Health check уже настроен правильно в docker-compose.yml. Если проблема сохраняется:
```bash
# Проверить логи
docker compose logs searxng | tail -30

# Убедиться, что Valkey запущен (SearXNG зависит от него)
docker compose ps valkey
```

### Проблема: Медленные результаты поиска

**Решение 1**: Проверьте, что Valkey кэширует результаты:
```bash
docker exec valkey valkey-cli DBSIZE
# Должно быть > 0 после нескольких поисковых запросов
```

**Решение 2**: Уменьшите количество поисковых движков в `settings.yml`.

### Проблема: Ошибка "limiter: too many requests"

**Причина**: Превышен лимит запросов.

**Решение**: Увеличить лимиты в `searxng/config/settings.yml`:
```yaml
server:
  limiter: true
  limiter_rules:
    - ip_limit: 100  # Увеличьте с 50 до 100
      time_range: 300  # 5 минут
```

## Оптимизация для RPi5

- **Лимиты памяти**: 512MB
- **Кэширование**: Valkey значительно снижает нагрузку на CPU
- **Health check**: Увеличен интервал до 30 секунд для экономии ресурсов

## Обновление

```bash
docker compose pull searxng
docker compose up -d searxng
```

> [!NOTE]
> После обновления проверьте `settings.yml` на наличие новых опций в официальной документации SearXNG.
