# Конфигурация OpenWebUI

## Обзор

OpenWebUI — веб-интерфейс для работы с локальными и удаленными LLM моделями через Ollama и другие API.

## Конфигурационные файлы

- **Данные**: `/home/dryamov/Repositories/rpi5-openwebui/openwebui/data`
- **Пример конфига**: `/home/dryamov/Repositories/rpi5-openwebui/openwebui/config.example.env`

## Основные переменные окружения

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `OLLAMA_BASE_URL` | `http://ollama:11434` | URL для подключения к Ollama |
| `WEBUI_SECRET_KEY` | *(обязательно)* | Ключ для шифрования сессий |
| `ENABLE_CORS` | `false` | Включить CORS (для production используйте `true`) |
| `CORS_ALLOW_ORIGIN` | `*` | Разрешенные домены для CORS |
| `ENABLE_PERSISTENT_CONFIG` | `true` | Использовать настройки из БД вместо переменных окружения |

Для полного списка см. [`openwebui/config.example.env`](file:///home/dryamov/Repositories/rpi5-openwebui/openwebui/config.example.env).

## Production CORS Setup

> [!WARNING]
> По умолчанию `CORS_ALLOW_ORIGIN` установлен в `*`, что небезопасно для production!

### Рекомендуемая конфигурация для production:

```env
ENABLE_CORS=true
CORS_ALLOW_ORIGIN=https://ai.example.com
```

Это ограничит доступ только с вашего домена.

## Интеграция с Ollama

OpenWebUI автоматически подключается к Ollama через `OLLAMA_BASE_URL`. Health check OpenWebUI зависит от health check Ollama:

```yaml
depends_on:
  ollama:
    condition: service_healthy
```

## Мониторинг и Телеметрия

OpenWebUI поддерживает OpenTelemetry для детального мониторинга. См. [`TELEMETRY.MD`](file:///home/dryamov/Repositories/rpi5-openwebui/TELEMETRY.MD) для подробной настройки.

**Быстрый старт**:
```env
# В .env файле
ENABLE_OTEL=true
ENABLE_OTEL_TRACES=true
ENABLE_OTEL_METRICS=true
OTEL_EXPORTER_OTLP_ENDPOINT=http://grafana:4317
OTEL_SERVICE_NAME=open-webui
```

## Ресурсы CPU/Memory

Для Raspberry Pi 5 установлены следующие лимиты:

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 2G
    reservations:
      cpus: '1.0'
      memory: 1G
```

Это предотвращает перегрузку системы при одновременной работе нескольких пользователей.

## Troubleshooting

### Проблема: "CORS policy: No 'Access-Control-Allow-Origin' header"

**Решение**:
```env
ENABLE_CORS=true
CORS_ALLOW_ORIGIN=https://ваш-домен.com
```

Затем перезапустите OpenWebUI:
```bash
docker compose restart openwebui
```

### Проблема: Настройки не применяются после изменения .env

**Причина**: `ENABLE_PERSISTENT_CONFIG=true` приоритизирует настройки из БД.

**Решение**:
```env
# Временно отключить persistent config
ENABLE_PERSISTENT_CONFIG=false
```

Или измените настройки через веб-интерфейс OpenWebUI в разделе Settings.

### Проблема: Ollama models не отображаются

**Проверка**:
```bash
# Проверить, что Ollama доступен
docker exec openwebui curl -f http://ollama:11434/api/tags

# Проверить логи
docker compose logs openwebui | grep -i ollama
```

**Решение**: Убедитесь, что `OLLAMA_BASE_URL` корректен и контейнер Ollama запущен.

## Backup данных

OpenWebUI хранит все данные (пользователи, чаты, настройки) в `openwebui/data`. Эта директория автоматически бэкапится скриптом `scripts/backup.sh`.

**Ручной бэкап**:
```bash
# Остановить OpenWebUI
docker compose stop openwebui

# Создать архив
tar -czf openwebui_data_backup.tar.gz openwebui/data

# Запустить обратно
docker compose start openwebui
```

## Обновление

```bash
# Создать бэкап перед обновлением!
./scripts/backup.sh

# Обновить образ
docker compose pull openwebui

# Перезапустить с новой версией
docker compose up -d openwebui

# Проверить логи
docker compose logs -f openwebui
```

> [!CAUTION]
> Всегда создавайте бэкап перед обновлением! OpenWebUI активно разрабатывается, и схема БД может измениться между версиями.
