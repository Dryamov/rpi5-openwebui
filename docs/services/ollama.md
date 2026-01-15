# Конфигурация Ollama

## Обзор

Ollama — сервер для запуска локальных LLM моделей. В данном стеке используется как бэкенд для OpenWebUI.

## Docker Volume

- **ollama_data**: Хранит загруженные модели и конфигурацию (`/root/.ollama`)

> [!NOTE]
> По умолчанию директория `models` исключена из бэкапов (см. `scripts/backup.config`), так как модели занимают много места и их можно переload.

## Health Check

Для Raspberry Pi 5 health check оптимизирован под загрузку больших моделей:

```yaml
healthcheck:
  test: [ "CMD-SHELL", "ollama list || exit 1" ]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 90s  # Увеличен для RPi5
```

**start_period: 90s** дает достаточно времени для инициализации при первом запуске.

## Ресурсы

```yaml
deploy:
  resources:
    limits:
      memory: 4G
```

Для Raspberry Pi 5 с 16GB RAM лимит 4GB позволяет запускать модели среднего размера (~7B параметров).

## Управление моделями

### Загрузка моделей

```bash
# Зайти в контейнер
docker exec -it ollama bash

# Загрузить модель
ollama pull llama3.2:3b  # Легкая модель для RPi5

# Проверить загруженные модели
ollama list
```

### Рекомендуемые модели для RPi5

| Модель | Размер | Параметры | RAM | Описание |
|--------|--------|-----------|-----|----------|
| `phi3:mini` | ~2GB | 3.8B | 3GB | Быстрая, хороша для кода |
| `llama3.2:3b` | ~2GB | 3B | 3GB | Универсальная |
| `mistral:7b` | ~4.1GB | 7B | 5GB | Лучшее качество, медленнее |

> [!WARNING]
> Модели >7B параметров могут быть слишком медленными на RPi5.

## Troubleshooting

### Проблема: Health check падает при загрузке большой модели

**Симптомы**: `docker compose ps` показывает Ollama как `unhealthy` или `starting`

**Решение**: Это нормально при первой загрузке. Health check автоматически пройдет после инициализации благодаря `start_period: 90s`.

### Проблема: "Out of memory" при запуске модели

**Причина**: Модель слишком большая для доступной RAM.

**Решение**:
1. Удалите большую модель:
   ```bash
   docker exec ollama ollama rm имя-модели:тег
   ```

2. Загрузите меньшую модель (например, `phi3:mini`)

### Проблема: Модели пропали после перезапуска

**Причина**: Volume `ollama_data` не примонтирован или поврежден.

**Решение**:
```bash
# Проверить, что volume существует
docker volume inspect ollama_data

# Если volume не найден, восстановите из бэкапа
./scripts/restore.sh ./backups/последний_бэкап.tar.gz
```

## Backup моделей

Если вы хотите включить модели в бэкап (не рекомендуется из-за размера), отредактируйте `scripts/backup.config`:

```bash
# Закомментируйте исключение
VOLUME_EXCLUDES=(
    # "ollama_data:models"  # Теперь модели будут бэкапиться
)
```

**Альтернатива**: Храните список используемых моделей в файле и восстанавливайте по необходимости:

```bash
# Сохранить список моделей
docker exec ollama ollama list | tail -n +2 | awk '{print $1}' > ollama_models.txt

# Восстановить модели
while read model; do
    docker exec ollama ollama pull "$model"
done < ollama_models.txt
```

## Обновление

```bash
docker compose pull ollama
docker compose up -d ollama

# Проверить, что модели на месте
docker exec ollama ollama list
```

> [!TIP]
> Ollama backwards-compatible с моделями. Обновление не требует переloadа моделей.
