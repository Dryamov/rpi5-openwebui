# Monitoring Stack

Краткое руководство по использованию встроенного мониторинга.

## Запуск

```bash
# С мониторингом
docker compose --profile monitoring up -d

# Без мониторинга (по умолчанию)
docker compose up -d
```

## Доступ

- **Grafana**: http://localhost:3000
  - Логин: `admin`
  - Пароль: `admin`

## Активация OpenTelemetry

В `.env`:

```bash
ENABLE_OTEL=true
ENABLE_OTEL_TRACES=true
ENABLE_OTEL_METRICS=true
```

Перезапустить OpenWebUI:
```bash
docker compose restart openwebui
```

## Компоненты

| Сервис | Порт | Назначение |
|--------|------|------------|
| Grafana | 3000 | Визуализация, дашборды |
| Grafana (OTLP) | 4317/4318 | Приём телеметрии |
| Tempo | 3200 | Distributed tracing |
| Mimir | 9009 | Метрики (Prometheus) |
| Loki | 3100 | Логи |

## Что собирается

### Трейсы
- HTTP запросы (FastAPI)
- Database queries (SQLAlchemy)
- Redis операции
- External calls (requests, httpx)

### Метрики
- `http.server.requests` — счётчик запросов
- `http.server.duration` — histogram latency

### Логи
- Application logs
- Container logs

## Resource Limits

Общее потребление мониторинга:
- RAM: ~1.9 GB
- CPU: Минимальное

**Рекомендации для RPi5**:
- Включать мониторинг только при необходимости
- Использовать для debugging и оптимизации
- В production можно отключить для экономии ресурсов

## Остановка мониторинга

```bash
docker compose --profile monitoring down
```

## Troubleshooting

### Трейсы не появляются

1. Проверить переменные в `.env`:
   ```bash
   grep ENABLE_OTEL .env
   ```

2. Проверить логи OpenWebUI:
   ```bash
   docker logs openwebui | grep -i otel
   ```

3. Проверить доступность Grafana:
   ```bash
   curl http://localhost:4317  # OTLP endpoint
   ```

### Grafana не запускается

Проверить логи:
```bash
docker logs grafana
```

Очистить данные и перезапустить:
```bash
docker compose --profile monitoring down -v
docker compose --profile monitoring up -d
```
