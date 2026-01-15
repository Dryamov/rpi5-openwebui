#!/bin/bash

# ==============================================================================
# Скрипт восстановления (V2.2 - Docker-Safe & Logging)
# ==============================================================================

# --- Инициализация ---
SET_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SET_DIR/.." && pwd)"
LOG_DIR="$SET_DIR/logs"
LOG_FILE="$LOG_DIR/restore.log"

mkdir -p "$LOG_DIR"

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BACKUP_FILE="$1"
TEMP_DIR="/tmp/restore_rpi5_$(date +%s)"

# --- Предварительные проверки ---
# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Docker не установлен или недоступен"
    exit 1
fi

# Проверка docker compose
if ! docker compose version &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Docker Compose недоступен"
    exit 1
fi

# --- Функции ---
log_message() {
    local level=$1
    local msg=$2
    local color=$3
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${color}[${level}]${NC} ${msg}"
    echo "[${timestamp}] [${level}] ${msg}" >> "$LOG_FILE"
}

log_info()    { log_message "INFO" "$1" "$GREEN"; }
log_warn()    { log_message "WARN" "$1" "$YELLOW"; }
log_error()   { log_message "ERROR" "$1" "$RED"; }

# Попытка определить имя проекта для меток томов
PROJECT_NAME=$(grep "^name:" "$PROJECT_ROOT/docker-compose.yml" | awk '{print $2}' | tr -d '"' | tr -d "'")
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME=$(basename "$PROJECT_ROOT")
fi

if [ -z "$BACKUP_FILE" ]; then
    log_error "Укажите путь к файлу бакапа."
    echo "Использование: $0 <путь_к_архиву.tar.gz>"
    exit 1
fi

if [[ "$BACKUP_FILE" != /* ]]; then
    BACKUP_FILE="$(pwd)/$BACKUP_FILE"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    log_error "Файл $BACKUP_FILE не найден."
    exit 1
fi

log_warn "ВНИМАНИЕ: Текущие данные будут перезаписаны!"
read -p "Продолжить восстановление? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Отменено пользователем."
    exit 1
fi

log_info "--- Запуск восстановления ($BACKUP_FILE) ---"

# --- 1. Подготовка ---
log_info "Распаковка основного архива..."
mkdir -p "${TEMP_DIR}"
tar -xzf "$BACKUP_FILE" -C "${TEMP_DIR}" >> "$LOG_FILE" 2>&1 || { log_error "Ошибка распаковки!"; exit 1; }

# --- 2. Остановка сервисов ---
log_info "Остановка текущих контейнеров..."
cd "$PROJECT_ROOT" && docker compose down --remove-orphans >> "$LOG_FILE" 2>&1

# --- 3. Восстановление файлов проекта ---
log_info "Восстановление файлов проекта..."
if [ -f "${TEMP_DIR}/project_files.tar.gz" ]; then
    docker run --rm \
        -v "$PROJECT_ROOT:/dest" \
        -v "${TEMP_DIR}:/source:ro" \
        alpine sh -c "tar -xzf /source/project_files.tar.gz -C /dest" >> "$LOG_FILE" 2>&1
else
    log_warn "Файл project_files.tar.gz не найден в архиве."
fi

# --- 4. Восстановление томов ---
if [ -d "${TEMP_DIR}/volumes" ]; then
    log_info "Восстановление Docker volumes (Project: $PROJECT_NAME)..."
    cd "${TEMP_DIR}/volumes"
    for vol_archive in *.tar.gz; do
        [ -e "$vol_archive" ] || continue
        
        vol_name="${vol_archive%.tar.gz}"
        log_info "-> Восстановление тома: $vol_name"
        
        # Создаем с метками, чтобы Docker Compose признал их своими
        docker volume create "$vol_name" \
            --label "com.docker.compose.project=$PROJECT_NAME" \
            --label "com.docker.compose.volume=$vol_name" >> "$LOG_FILE" 2>&1
        
        # Очистка и распаковка
        docker run --rm \
            -v "${vol_name}:/dest" \
            -v "${TEMP_DIR}/volumes:/source:ro" \
            alpine sh -c "rm -rf /dest/* && tar -xzf /source/$vol_archive -C /dest" >> "$LOG_FILE" 2>&1
    done
fi

# --- 5. Завершение ---
log_info "Очистка временных файлов..."
rm -rf "${TEMP_DIR}"

log_info "Запуск сервисов..."
cd "$PROJECT_ROOT" && docker compose up -d --remove-orphans >> "$LOG_FILE" 2>&1

log_info "--- Восстановление завершено успешно! ---"
