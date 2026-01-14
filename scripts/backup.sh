#!/bin/bash

# ==============================================================================
# Скрипт резервного копирования (V2.1 - Rootless/Docker-Safe)
# ==============================================================================
# Этот скрипт выполняет архивацию файлов и томов внутри Docker-контейнера,
# что позволяет избежать ошибок "Permission Denied" без использования sudo.

# --- Инициализация ---
SET_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SET_DIR/.." && pwd)"
CONFIG_FILE="$SET_DIR/backup.config"

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Функции ---
log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Защитный механизм: перезапуск контейнеров при любом исходе
cleanup() {
    local status=$?
    log_info "Завершение скрипта. Проверка состояния сервисов..."
    cd "$PROJECT_ROOT" && docker compose up -d --remove-orphans
    rm -rf "$TEMP_DIR"
    if [ $status -ne 0 ]; then
        log_error "Бэкап завершился с ошибкой!"
    fi
}
trap cleanup EXIT INT TERM

# --- Загрузка конфигурации ---
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Файл конфигурации не найден: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="${PROJECT_NAME}_backup_${TIMESTAMP}"
BACKUP_FULL_PATH="${PROJECT_ROOT}/${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
TEMP_DIR="/tmp/${BACKUP_NAME}"

mkdir -p "${PROJECT_ROOT}/${BACKUP_DIR}"
mkdir -p "${TEMP_DIR}/volumes"

log_info "--- Запуск бэкапа: $TIMESTAMP ---"

# --- 1. Остановка сервисов ---
log_info "Остановка контейнеров для обеспечения целостности данных..."
cd "$PROJECT_ROOT" && docker compose down --remove-orphans

# --- 2. Бэкап локальных файлов проекта ---
# Решаем проблему прав: архивируем файлы внутри Alpine с root-доступом
log_info "Архивация файлов проекта (через Docker-контейнер)..."

# Собираем список файлов для передачи в контейнер
FILES_STRING=""
for file in "${BACKUP_FILES[@]}"; do
    if [ -e "$PROJECT_ROOT/$file" ]; then
        FILES_STRING+="$file "
    fi
done

docker run --rm \
    -v "$PROJECT_ROOT:/data:ro" \
    -v "$TEMP_DIR:/dest" \
    alpine sh -c "tar -czf /dest/project_files.tar.gz -C /data $FILES_STRING" \
    || { log_error "Ошибка при архивации файлов!"; exit 1; }

# --- 3. Бэкап Docker Volumes ---
log_info "Бэкап Docker volumes ($([ ${#BACKUP_VOLUMES[@]} ] && echo ${#BACKUP_VOLUMES[@]} || echo 0) шт.)..."

for VOLUME in "${BACKUP_VOLUMES[@]}"; do
    log_info "-> Обработка тома: $VOLUME"
    
    EXTRA_TAR_ARGS=""
    for EXCLUDE in "${VOLUME_EXCLUDES[@]}"; do
        if [[ "$EXCLUDE" == "$VOLUME:"* ]]; then
            EX_PATH="${EXCLUDE#*:}"
            log_warn "   Исключаем из $VOLUME: $EX_PATH"
            EXTRA_TAR_ARGS="--exclude=$EX_PATH"
        fi
    done

    docker run --rm \
        -v "${VOLUME}:/source:ro" \
        -v "${TEMP_DIR}/volumes:/dest" \
        alpine tar -czf "/dest/${VOLUME}.tar.gz" $EXTRA_TAR_ARGS -C /source .
done

# --- 4. Финальная сборка ---
log_info "Создание финального архива..."
tar -czf "${BACKUP_FULL_PATH}" -C "${TEMP_DIR}" .

# --- 5. Облако и ротация ---
if [ -n "$RCLONE_REMOTE" ]; then
    log_info "Отправка в облачное хранилище ($RCLONE_REMOTE)..."
    rclone copy "${BACKUP_FULL_PATH}" "$RCLONE_REMOTE"
fi

log_info "Очистка старых бэкапов (храним $RETENTION_DAYS дн.)..."
find "${PROJECT_ROOT}/${BACKUP_DIR}" -name "${PROJECT_NAME}_backup_*.tar.gz" -mtime +"${RETENTION_DAYS}" -delete

log_info "Бэкап успешно создан: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
# exit (сработает trap и поднимет контейнеры)
