# CI/CD и Автоматическое Тестирование

Проект `rpi5-openwebui` использует GitHub Actions для непрерывной интеграции, обеспечивая стабильность и качество кода при каждом изменении.

## Обзор

Автоматические проверки запускаются при:
- Push в `main`/`master` ветку
- Создании Pull Request
- Изменениях в критичных файлах (`docker-compose.yml`, `scripts/`)

### Доступные Workflows

#### 🔍 Docker Compose Validation
**Файл**: [`.github/workflows/docker-compose-validation.yml`](file:///home/dryamov/Repositories/rpi5-openwebui/.github/workflows/docker-compose-validation.yml)

**Проверки**:
- Синтаксис `docker compose config`
- Валидация переменных окружения (все `${VAR}` определены в `.env.example`)
- YAML линтинг через yamllint
- Наличие health checks для критичных сервисов

**Триггеры**:
- Изменения в `docker-compose.yml`
- Изменения в `*.env.example`
- Изменения в `scripts/**`

---

#### 🐚 ShellCheck
**Файл**: [`.github/workflows/shellcheck.yml`](file:///home/dryamov/Repositories/rpi5-openwebui/.github/workflows/shellcheck.yml)

**Проверки**:
- Синтаксис bash скриптов
- Потенциальные баги (неинициализированные переменные, word splitting)
- Best practices (quoting, error handling)
- Security issues

**Severity**: Warning и выше

**Триггеры**:
- Изменения в `scripts/**/*.sh`

---

#### 💾 Backup & Restore Test
**Файл**: [`.github/workflows/backup-test.yml`](file:///home/dryamov/Repositories/rpi5-openwebui/.github/workflows/backup-test.yml)

**Проверки**:
- Синтаксическая валидация `backup.sh` и `restore.sh`
- Проверка `backup.config` конфигурации
- Базовая функциональная проверка скриптов

**Примечание**: Полное функциональное тестирование требует запущенного Docker Compose окружения. Weekly run выполняется каждое воскресенье в 03:00 UTC.

**Триггеры**:
- Weekly schedule (воскресенье, 03:00 UTC)
- Manual dispatch
- Изменения в `scripts/backup.sh`, `scripts/restore.sh`, `scripts/backup.config`

---

## Локальное Тестирование

Перед созданием Pull Request рекомендуется запустить проверки локально.

### Установка зависимостей

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install shellcheck

# Python packages
pip install yamllint
```

### 1. Docker Compose Validation

```bash
# Синтаксис и конфигурация
docker compose config

# YAML линтинг
yamllint -c .yamllint.yml docker-compose.yml
```

**Ожидаемый результат**: Нет ошибок. Warnings допустимы, но желательно их исправить.

---

### 2. ShellCheck

```bash
# Проверить все скрипты
find scripts -name "*.sh" -exec shellcheck {} \;

# Или для конкретного скрипта
shellcheck scripts/backup.sh
```

**Ожидаемый результат**: 
- ✅ Нет errors
- ⚠️ Warnings допустимы, но рекомендуется исправить

**Игнорирование специфичных правил**:
Если warning ложно-положительный, добавьте комментарий в скрипт:
```bash
# shellcheck disable=SC2086
variable_without_quotes
```

---

### 3. Валидация переменных окружения

```bash
./scripts/ci/validate-env-vars.sh
```

**Проверяет**:
- Все `${VAR}` из `docker-compose.yml` определены в `.env.example`
- Нет отсутствующих переменных

**Ожидаемый вывод**:
```
🔍 Validating environment variables...
📋 Extracting variables from docker-compose.yml...
📋 Extracting variables from .env.example...
✅ All required environment variables are defined in .env.example

📊 Statistics:
   Variables in docker-compose.yml: 15
   Variables in .env.example: 20
```

---

### 4. Проверка Health Checks

```bash
./scripts/ci/validate-healthchecks.sh
```

**Проверяет**:
- Критичные сервисы имеют `healthcheck` секцию
- Сервисы: `openwebui`, `ollama`, `postgres`, `redis`, `searxng`

**Ожидаемый вывод**:
```
🔍 Validating health checks in docker-compose.yml...
   Checking openwebui... ✅
   Checking ollama... ✅
   Checking postgres... ✅
   Checking redis... ✅
   Checking searxng... ✅

✅ All critical services have health checks configured
```

---

## Конфигурация

### `.yamllint.yml`

Настройки линтинга для YAML файлов:

- **Отступы**: 2 пробела
- **Длина строки**: 120 символов (уровень warning)
- **Truthy values**: разрешены `true/false`, `yes/no`, `on/off`
- **Document start**: не требуется

### `dependabot.yml`

Автоматическое обновление зависимостей:

- **GitHub Actions**: ежемесячная проверка обновлений
- **Docker images**: еженедельная проверка
- Автоматические PR для minor/patch обновлений

---

## Troubleshooting

### ❌ Docker Compose validation failed

**Проблема**: `docker compose config` выдает ошибку

**Решение**:
1. Проверьте синтаксис YAML (отступы, кавычки)
2. Убедитесь, что все переменные окружения определены
3. Запустите локально: `docker compose config`

---

### ❌ ShellCheck errors

**Проблема**: Скрипт не проходит ShellCheck

**Решение**:
1. Посмотрите конкретную ошибку и строку
2. Исправьте согласно [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
3. Если warning ложно-положительный, добавьте `# shellcheck disable=SCXXXX`

**Частые ошибки**:
- `SC2086` — Unquoted variable (добавьте кавычки: `"$VAR"`)
- `SC2155` — Declare and assign separately
- `SC1091` — Source file not found (можно игнорировать для динамических source)

---

### ❌ Missing environment variables

**Проблема**: `validate-env-vars.sh` находит отсутствующие переменные

**Решение**:
1. Добавьте переменные в `.env.example`
2. Укажите пример значения или комментарий
3. Запустите скрипт повторно

**Пример**:
```env
# New service configuration
NEW_SERVICE_URL=https://example.com
NEW_SERVICE_API_KEY=your-api-key-here
```

---

### ❌ Missing health checks

**Проблема**: `validate-healthchecks.sh` находит сервисы без healthcheck

**Решение**:
1. Добавьте `healthcheck` секцию в `docker-compose.yml`:

```yaml
services:
  your-service:
    # ... other config ...
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:port/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
```

2. Или добавьте сервис в список исключений (если healthcheck не нужен)

---

## Self-Hosted Runner (опционально)

Для private репозиториев или экономии GitHub Actions минут можно настроить self-hosted runner на RPi5.

### Установка

```bash
# Создать директорию
mkdir -p ~/actions-runner && cd ~/actions-runner

# Скачать runner (ARM64)
curl -o actions-runner-linux-arm64-2.311.0.tar.gz \
  -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-arm64-2.311.0.tar.gz

# Извлечь
tar xzf ./actions-runner-linux-arm64-2.311.0.tar.gz

# Настроить (замените URL и токен)
./config.sh --url https://github.com/username/rpi5-openwebui --token YOUR_TOKEN

# Запустить как сервис
sudo ./svc.sh install
sudo ./svc.sh start
```

### Обновление workflows для self-hosted

В `.github/workflows/*.yml` замените:
```yaml
runs-on: ubuntu-latest
```

на:
```yaml
runs-on: self-hosted
```

### Преимущества self-hosted runner

- ✅ Неограниченные минуты выполнения
- ✅ Тестирование на реальной RPi5 архитектуре
- ✅ Доступ к локальным ресурсам
- ✅ Быстрее для больших Docker images

### Недостатки

- ❌ Нужно поддерживать runner (обновления, мониторинг)
- ❌ RPi5 должна быть онлайн для запуска тестов
- ❌ Security considerations (runner имеет доступ к системе)

---

## GitHub Actions Secrets

Для тестирования с реальными credentials (Telegram, SMTP) настройте GitHub Secrets:

1. Перейдите в **Settings** → **Secrets and variables** → **Actions**
2. Добавьте secrets:
   - `TELEGRAM_BOT_TOKEN`
   - `TELEGRAM_CHAT_ID`
   - `SMTP_PASSWORD`
   - и т.д.

3. Используйте в workflows:
```yaml
env:
  TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN }}
```

> [!CAUTION]
> Никогда не коммитьте sensitive данные в репозиторий! Используйте только GitHub Secrets.

---

## Лимиты GitHub Actions

### Free Plan
- **Public repos**: Неограниченные минуты
- **Private repos**: 2000 минут/месяц

### Что считается как минуты
- Linux runners: 1x множитель
- macOS runners: 10x множитель
- Self-hosted: не считаются

### Оптимизация использования

1. **Используйте path filters** — запускайте workflows только при изменении релевантных файлов
2. **Cache dependencies** — кэшируйте Docker layers, pip packages
3. **Fail fast** — добавьте quick checks в начало workflow
4. **Self-hosted runner** — для интенсивного использования

---

## Мониторинг CI/CD

### GitHub Actions UI

1. Откройте вкладку **Actions** в репозитории
2. Просмотрите историю запусков
3. Проверьте логи failed runs

### Status Badges

Бейджи в README показывают текущий статус:

![Docker Compose Validation](https://github.com/dryamov/rpi5-openwebui/workflows/Docker%20Compose%20Validation/badge.svg)

- **Зеленый**: Все проверки прошли
- **Красный**: Есть ошибки
- **Серый**: Workflow не запускался или был отменен

---

## Дальнейшее Развитие

Планируемые улучшения CI/CD:

- [ ] **Integration tests** — запуск полного Docker Compose стека в CI
- [ ] **Performance benchmarks** — мониторинг производительности
- [ ] **Security scanning** — Trivy для сканирования Docker images
- [ ] **Automated releases** — semantic versioning и GitHub Releases
- [ ] **Notification integration** — уведомления в Telegram о failed builds

---

## Справка

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [yamllint Documentation](https://yamllint.readthedocs.io/)
- [Docker Compose CI/CD Best Practices](https://docs.docker.com/compose/ci-cd/)
