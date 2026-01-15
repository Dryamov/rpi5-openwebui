# Restic Incremental Backups

Инкрементальная система бэкапов с автоматической дедупликацией и шифрованием.

## Быстрый старт

### 1. Установка restic

```bash
sudo apt-get update
sudo apt-get install restic
```

### 2. Настройка

Создать `.env` файл с паролем:

```bash
# Сгенерировать пароль
openssl rand -hex 32

# Добавить в .env
echo "RESTIC_PASSWORD=your-generated-password" >> .env
echo "RESTIC_REPOSITORY=/backups/restic-repo" >> .env
```

### 3. Инициализация

```bash
./scripts/backup-restic.sh init
```

### 4. Создание бэкапа

```bash
./scripts/backup-restic.sh
```

## Основные команды

### Просмотр снапшотов

```bash
./scripts/restic-maintenance.sh list
```

### Статистика

```bash
./scripts/restic-maintenance.sh stats
```

### Восстановление

```bash
# Список снапшотов
./scripts/restore-restic.sh list

# Восстановить последний
./scripts/restore-restic.sh restore latest

# Восстановить конкретный
./scripts/restore-restic.sh restore abc123
```

### Обслуживание

```bash
# Проверка целостности
./scripts/restic-maintenance.sh check

# Очистка старых данных
./scripts/restic-maintenance.sh prune
```

## Retention Policy

По умолчанию хранятся:
- 7 ежедневных снапшотов
- 4 еженедельных
- 6 ежемесячных
- 2 годовых

Настройка в `scripts/backup.config`

## Преимущества

- **Дедупликация**: экономия 70-80% места
- **Инкрементальность**: только изменения
- **Шифрование**: AES-256
- **Быстрое восстановление**: по выбору

## Troubleshooting

### Repository locked

```bash
./scripts/restic-maintenance.sh unlock
```

### Проверка целостности

```bash
./scripts/restic-maintenance.sh check
```
