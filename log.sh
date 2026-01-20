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
  SERVER=$(awk -F": " "/^$ARG:/ {print \$2}" "$ALIAS_FILE" | awk '{print $1}')
  SERVER_ALIAS="$ARG"
  
  # Получаем дополнительные папки для поиска
  FOLDERS=$(awk "/^$ARG:/ {for(i=1;i<=NF;i++) if(\$i == \"--folders\") {for(j=i+1; j<=NF && \$j !~ /^--/; j++) printf \"%s \", \$j; print \"\"; break}}" "$ALIAS_FILE" | sed 's/"//g' | sed 's/ *$//')
else
  # Считаем, что передан полный адрес user@server
  SERVER="$ARG"
  SERVER_ALIAS=$(echo "$SERVER" | sed 's/[@.]/_/g')
  FOLDERS=""
fi

# Создаем папку logs если её нет
LOGS_DIR="./logs"
mkdir -p "$LOGS_DIR"

# Обновляем путь к временному файлу YAML
TMP_YAML="$LOGS_DIR/${SERVER_ALIAS}.yml"

# ----------------------------
# 1. Проверка logpath.yml на сервере
# ----------------------------
# Запускаем logfinder.sh на сервере и получаем результат сразу в переменную
echo "Запускаем logfinder.sh на сервере..."
LOGFINDER_OUTPUT=$(ssh "$SERVER" "FOLDERS='$FOLDERS' bash -s" < ./server/logfinder.sh)

# Сохраняем результат в временный файл
echo "$LOGFINDER_OUTPUT" > "$TMP_YAML"
echo "Файл сохранен как $TMP_YAML"

# Проверяем, что файл не пустой
if [[ ! -s "$TMP_YAML" ]]; then
  echo "Ошибка: не удалось получить список логов с сервера $SERVER"
  exit 1
fi


# ----------------------------
# 3. Собираем список логов
# ----------------------------
LOGS=($(grep -oP '^\s*-\s*\K.+' "$TMP_YAML" | sort -u))

if [[ ${#LOGS[@]} -eq 0 ]]; then
  echo "Логи не найдены в $TMP_YAML"
  exit 1
fi

# ----------------------------
# 4. Выбор лога пользователем
# ----------------------------
# Показываем нумерованный список логов
echo "Выберите лог:"
for i in "${!LOGS[@]}"; do
  echo "$((i+1)). ${LOGS[i]}"
done

# Получаем выбор пользователя
while true; do
  echo -n "Введите номер лога (1-${#LOGS[@]}): "
  read -r choice
  
  # Проверяем, что введено число в диапазоне
  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#LOGS[@]}" ]; then
    SELECTED_INDEX=$((choice-1))
    SELECTED_LOG="${LOGS[$SELECTED_INDEX]}"
    break
  else
    echo "Неверный ввод. Пожалуйста, введите число от 1 до ${#LOGS[@]}."
  fi
done

# ----------------------------
# 5. Открываем выбранный лог через lnav локально с доступом по SSH
# ----------------------------
echo "Открываем $SELECTED_LOG на сервере $SERVER через lnav локально..."
#ssh -t "$SERVER" "lnav '$SELECTED_LOG'"
lnav "$SERVER:$SELECTED_LOG"


