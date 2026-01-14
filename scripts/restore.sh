#!/bin/bash

# ==============================================================================
# Скрипт восстановления (V2.1 - Docker-Safe)
# ==============================================================================

# --- Инициализация ---
SET_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SET_DIR/.." && pwd)"

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BACKUP_FILE="$1"
TEMP_DIR="/tmp/restore_rpi5_$(date +%s)"

# --- Функции ---
log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

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

# --- 1. Подготовка ---
log_info "Распаковка архива во временную директорию..."
mkdir -p "${TEMP_DIR}"
tar -xzf "$BACKUP_FILE" -C "${TEMP_DIR}" || { log_error "Ошибка распаковки!"; exit 1; }

# --- 2. Остановка сервисов ---
log_info "Остановка текущих контейнеров..."
cd "$PROJECT_ROOT" && docker compose down --remove-orphans

# --- 3. Восстановление файлов проекта ---
log_info "Восстановление файлов проекта..."
if [ -f "${TEMP_DIR}/project_files.tar.gz" ]; then
    # Используем Docker для восстановления файлов (проблема прав)
    docker run --rm \
        -v "$PROJECT_ROOT:/dest" \
        -v "${TEMP_DIR}:/source:ro" \
        alpine sh -c "tar -xzf /source/project_files.tar.gz -C /dest"
else
    log_warn "Файл project_files.tar.gz не найден в архиве. Пропускаем восстановление файлов."
fi

# --- 4. Восстановление томов ---
if [ -d "${TEMP_DIR}/volumes" ]; then
    log_info "Восстановление Docker volumes..."
    cd "${TEMP_DIR}/volumes"
    for vol_archive in *.tar.gz; do
        [ -e "$vol_archive" ] || continue
        
        vol_name="${vol_archive%.tar.gz}"
        log_info "-> Восстановление тома: $vol_name"
        
        # Создаем если нет
        docker volume create "$vol_name" > /dev/null
        
        # Очистка и распаковка
        docker run --rm \
            -v "${vol_name}:/dest" \
            -v "${TEMP_DIR}/volumes:/source:ro" \
            alpine sh -c "rm -rf /dest/* && tar -xzf /source/$vol_archive -C /dest"
    done
fi

# --- 5. Завершение ---
log_info "Очистка временных файлов..."
rm -rf "${TEMP_DIR}"

log_info "Запуск сервисов..."
cd "$PROJECT_ROOT" && docker compose up -d --remove-orphans

log_info "--- Восстановление завершено успешно! ---"
