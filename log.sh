#!/usr/bin/env bash

# ----------------------------
# Настройка
# ----------------------------
ALIAS_FILE="./alias.yml"
ARG="$1"

if [[ -z "$ARG" ]]; then
  echo "Использование: $0 <server_alias|user@server>"
  exit 1
fi

# ----------------------------
# Определяем сервер
# ----------------------------
if [[ -f "$ALIAS_FILE" ]] && grep -q "^$ARG:" "$ALIAS_FILE"; then
  # Алиас найден
  SERVER=$(grep -E "^$ARG:" "$ALIAS_FILE" | awk -F": " '{print $2}')
  SERVER_ALIAS="$ARG"
else
  # Считаем, что передан полный адрес user@server
  SERVER="$ARG"
  SERVER_ALIAS=$(echo "$SERVER" | sed 's/[@.]/_/g')
fi

# Создаем папку logs если её нет
LOGS_DIR="./logs"
mkdir -p "$LOGS_DIR"

# Обновляем путь к временному файлу YAML
TMP_YAML="$LOGS_DIR/${SERVER_ALIAS}.yml"

# ----------------------------
# 1. Проверка logpath.yml на сервере
# ----------------------------
ssh "$SERVER" "test -f ~/logpath.yml"
if [[ $? -ne 0 ]]; then
  echo "logpath.yml не найден на сервере. Запускаем logfinder.sh на сервере..."
  # Передаем содержимое скрипта через stdin в SSH
  ssh "$SERVER" 'bash -s' < ./server/logfinder.sh
fi

# ----------------------------
# 2. Скачиваем logpath.yml
# ----------------------------
scp "$SERVER:~/logpath.yml" "$TMP_YAML"
if [[ $? -ne 0 ]]; then
  echo "Ошибка: не удалось скачать logpath.yml с сервера $SERVER"
  exit 1
fi
echo "Файл скачан как $TMP_YAML"

# ----------------------------
# 3. Собираем список логов
# ----------------------------
LOGS=($(grep -oP '^\s*-\s*\K.+' "$TMP_YAML"))

if [[ ${#LOGS[@]} -eq 0 ]]; then
  echo "Логи не найдены в $TMP_YAML"
  exit 1
fi

# Выводим список с номерами
echo "Список логов:"
for i in "${!LOGS[@]}"; do
  echo "$((i+1))) ${LOGS[$i]}"
done

# ----------------------------
# 4. Выбор лога пользователем
# ----------------------------
read -rp "Введите номер лога для просмотра: " IDX

if ! [[ "$IDX" =~ ^[0-9]+$ ]] || (( IDX < 1 || IDX > ${#LOGS[@]} )); then
  echo "Неверный номер"
  exit 1
fi

SELECTED_LOG="${LOGS[$((IDX-1))]}"

# ----------------------------
# 5. Открываем выбранный лог через lnav локально с доступом по SSH
# ----------------------------
echo "Открываем $SELECTED_LOG на сервере $SERVER через lnav локально..."
#ssh -t "$SERVER" "lnav '$SELECTED_LOG'"
lnav "$SERVER:$SELECTED_LOG"
