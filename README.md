# Raspberry Pi 5 OpenWebUI Stack

![Docker Compose Validation](https://github.com/dryamov/rpi5-openwebui/workflows/Docker%20Compose%20Validation/badge.svg)
![ShellCheck](https://github.com/dryamov/rpi5-openwebui/workflows/ShellCheck/badge.svg)
![Backup Test](https://github.com/dryamov/rpi5-openwebui/workflows/Backup%20&%20Restore%20Test/badge.svg)

A high-performance, self-hosted AI suite optimized for the Raspberry Pi 5. This stack includes OpenWebUI for the interface, Ollama for local model inference, SearXNG for privacy-respecting web search, and Caddy as a secure reverse proxy.

## Architecture

```mermaid
graph TD
    User([User]) -->|HTTPS| Caddy[Caddy Proxy]
    Caddy -->|Internal| WebUI[OpenWebUI]
    Caddy -->|Internal| Search[SearXNG]
    WebUI -->|Internal| Ollama[Ollama]
    Search -->|Internal| Valkey[Valkey Cache]
```

## Setup Instructions

### 1. Prerequisites
- **Hardware**: Raspberry Pi 5 (16GB RAM recommended).
- **OS**: Ubuntu Server or Raspberry Pi OS (64-bit).
- **Software**: Docker and Docker Compose installed.

### 2. Configuration
Create a `.env` file in the root directory based on this template:

```env
# Domain names
SEARXNG_BASE_URL=search.example.com
OPENWEBUI_HOSTNAME=ai.example.com
CLIPROXY_HOSTNAME=proxy.example.com

# Email for Let's Encrypt
LETSENCRYPT_EMAIL=your-email@example.com

# Secrets (Generate with: openssl rand -hex 32)
WEBUI_SECRET_KEY=paste_random_key_here
SEARXNG_SECRET=paste_another_random_key_here
```

### 3. Deployment
```bash
docker compose up -d
```

## Maintenance

### Updating Services
```bash
docker compose pull
docker compose up -d --remove-orphans
```

### Checking Logs
```bash
docker compose logs -f
```

### Open WebUI Configuration
Open WebUI is primarily configured via environment variables. For a full list of available options:
1. See [openwebui/config.example.env](file:///home/dryamov/Repositories/rpi5-openwebui/openwebui/config.example.env).
2. To use these variables, you can add them to your root `.env` file or directly in `docker-compose.yml`.

> [!NOTE]
> Open WebUI stores many settings in its internal database (PersistentConfig). To force it to reload from environment variables, set `ENABLE_PERSISTENT_CONFIG=false`.

## Резервное копирование и восстановление (Backup & Restore)

Доступны два типа бэкапов:

### 1. Полный tar.gz бэкап (традиционный)

Запустите скрипт:
```bash
./scripts/backup.sh
```
- Создаёт архив в `./backups`
- Исключает тяжелые данные (модели Ollama)
- Автоочистка старых копий (7 дней)

**Восстановление**:
```bash
./scripts/restore.sh ./backups/rpi5-openwebui_backup_XXXX.tar.gz
```

### 2. Инкрементальный restic бэкап (рекомендуется)

**Преимущества**: дедупликация (экономия 70-80% места), шифрование, быстрое восстановление

**Установка**:
```bash
sudo apt-get install restic
```

**Быстрый старт**:
```bash
# Инициализация (первый раз)
./scripts/backup-restic.sh init

# Создание снапшота
./scripts/backup-restic.sh

# Просмотр бэкапов
./scripts/restic-maintenance.sh list

# Восстановление
./scripts/restore-restic.sh restore latest
```

**Подробнее**: [docs/backup-restic.md](file:///home/dryamov/Repositories/rpi5-openwebui/docs/backup-restic.md)

**Настройки**: В `scripts/backup.config` можно включить/выключить restic и настроить retention policy.

## Расширение системы (Добавление новых сервисов)
Если вы добавили новый контейнер в `docker-compose.yml`, выполните следующие шаги:

### 1. Добавление Docker тома
Если у сервиса есть именованный том (volume):
1. Укажите имя тома в массиве `BACKUP_VOLUMES` внутри файла `scripts/backup.config`.
2. В `docker-compose.yml` рекомендуется не использовать `external: true` при первом создании, чтобы Docker сам создал том. Скрипт восстановления сам добавит нужные метки проекта при восстановлении.

### 2. Добавление локальных папок (Bind Mounts)
Если сервис использует локальную папку:
1. Убедитесь, что путь к папке указан в массиве `BACKUP_FILES` в `scripts/backup.config`.
2. Рекомендуется использовать пути относительно корня проекта.

### 3. Исключение данных
Если в новом томе/папке есть тяжелые данные (кэш, временные файлы), которые не нужно бэкапить:
1. Добавьте запись в `VOLUME_EXCLUDES` в формате `"volume_name:relative_path"`.

### 4. Логирование
Все новые операции будут автоматически записываться в `scripts/logs/backup.log`. В случае ошибок проверьте этот файл.

## Optimization for RPi5
- **Resource Limits**: Configured in `docker-compose.yml` to prevent system crashes.
- **Valkey**: Used by SearXNG for ultra-fast result caching.
- **RAG Server Architecture**: RPi5 functions as a dedicated RAG server, offloading LLM inference to remote APIs to ensure high performance and stability.

## Мониторинг и Телеметрия

Встроенный мониторинг с использованием Grafana LGTM stack (Grafana + Tempo + Mimir + Loki) и OpenTelemetry.

### Быстрый старт

```bash
# Запуск с мониторингом
docker compose --profile monitoring up -d

# Без мониторинга (по умолчанию)
docker compose up -d
```

**Доступ к Grafana**: http://localhost:3000 (admin/admin)

### Что включает

- **Grafana** — визуализация и дашборды
- **Tempo** — distributed tracing
- **Mimir** — Prometheus-совместимые метрики
- **Loki** — агрегация логов

### Активация OpenTelemetry

В `.env` установите:
```bash
ENABLE_OTEL=true
ENABLE_OTEL_TRACES=true
ENABLE_OTEL_METRICS=true
```

Трейсы, метрики и логи автоматически отправятся в Grafana.

**Подробнее**: [TELEMETRY.MD](file:///home/dryamov/Repositories/rpi5-openwebui/TELEMETRY.MD)

## Automated Testing

Проект использует GitHub Actions для непрерывной интеграции (CI/CD):

- **Docker Compose Validation** — автоматическая проверка конфигурации при каждом изменении
- **ShellCheck** — валидация всех bash скриптов на ошибки и best practices
- **Backup Testing** — еженедельное тестирование скриптов резервного копирования

Все pull requests проходят автоматические проверки перед слиянием. Статус проверок отображается в бейджах выше.

Подробнее о локальном тестировании и CI/CD процессе см. [docs/ci-cd.md](file:///home/dryamov/Repositories/rpi5-openwebui/docs/ci-cd.md).

## Документация

Подробная документация по каждому сервису доступна в директории `docs/`:

- [Caddy](file:///home/dryamov/Repositories/rpi5-openwebui/docs/services/caddy.md) — Reverse proxy и SSL
- [SearXNG](file:///home/dryamov/Repositories/rpi5-openwebui/docs/services/searxng.md) — Метапоиск и интеграция с Valkey
- [OpenWebUI](file:///home/dryamov/Repositories/rpi5-openwebui/docs/services/openwebui.md) — CORS, мониторинг, переменные окружения
- [Ollama](file:///home/dryamov/Repositories/rpi5-openwebui/docs/services/ollama.md) — Управление моделями, рекомендации для RPi5
- [CLI-Proxy-API-Plus](file:///home/dryamov/Repositories/rpi5-openwebui/docs/services/cli-proxy-api-plus.md) — API ключи и конфигурация

## Участие в разработке

Хотите добавить новый сервис или улучшить существующий? См. [CONTRIBUTING.md](file:///home/dryamov/Repositories/rpi5-openwebui/CONTRIBUTING.md) для инструкций.

## Security Hardening
### Production CORS
To avoid the `CORS_ALLOW_ORIGIN is set to '*'` warning in production:
1. Set `ENABLE_CORS=true` in your `.env`.
2. Set `CORS_ALLOW_ORIGIN=https://your-domain.com` to restrict access to your specific domain.