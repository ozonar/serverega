#!/usr/bin/env bash

OUTPUT="logpath.yml"
NGINX_CONF_DIR="/etc/nginx"
WWW_DIR="/var/www"

# Дополнительные пути для поиска, передаются как аргументы
EXTRA_PATHS=("$@")

echo "logs:" > "$OUTPUT"

############################
# PHP-FPM
############################
echo "  php-fpm:" >> "$OUTPUT"

# ищем любые логи вида /var/log/php*-fpm.log
PHP_FPM_LOGS=$(find /var/log -type f -name "php*-fpm.log" 2>/dev/null | sort -u)

# если переданы дополнительные пути, ищем там *.log, игнорируя cache и .cache
for path in "${EXTRA_PATHS[@]}"; do
  if [[ -d "$path" ]]; then
    EXTRA_LOGS=$(find "$path" -type f -name "*.log" \
      ! -path "*/cache/*" ! -path "*/.cache/*" 2>/dev/null | sort -u)
    PHP_FPM_LOGS=$(printf "%s\n%s\n" "$PHP_FPM_LOGS" "$EXTRA_LOGS" | sort -u)
  fi
done

# выводим логи в YAML, если есть
if [[ -n "$PHP_FPM_LOGS" ]]; then
  while read -r log; do
    [[ -n "$log" ]] && echo "    - $log" >> "$OUTPUT"
  done <<< "$PHP_FPM_LOGS"
fi

############################
# NGINX
############################
if command -v nginx >/dev/null 2>&1; then
  echo "  nginx:" >> "$OUTPUT"

  find "$NGINX_CONF_DIR" -type f \( -name "*.conf" -o -name "*.vhost" \) 2>/dev/null \
    | xargs grep -hE "^\s*(access_log|error_log)\s+" 2>/dev/null \
    | awk '{print $2}' \
    | sed 's/;$//' \
    | sort -u \
    | while read -r log; do
        [[ -n "$log" ]] && echo "    - $log" >> "$OUTPUT"
      done
else
  echo "  nginx: []" >> "$OUTPUT"
fi

############################
# /var/www/ логи
############################
echo "  www_logs:" >> "$OUTPUT"
find "$WWW_DIR" -type f -name "*.log" \
  ! -path "*/cache/*" ! -path "*/.cache/*" 2>/dev/null \
  | sort -u \
  | while read -r log; do
      echo "    - $log" >> "$OUTPUT"
    done

############################
# Database logs
############################
echo "  databases:" >> "$OUTPUT"

# MySQL
MYSQL_LOG="/var/log/mysql/error.log"
if [[ -f "$MYSQL_LOG" ]]; then
  echo "    mysql:" >> "$OUTPUT"
  echo "      - $MYSQL_LOG" >> "$OUTPUT"
fi

# PostgreSQL
PG_LOG_DIR="/var/log/postgresql"
if [[ -d "$PG_LOG_DIR" ]]; then
  echo "    postgresql:" >> "$OUTPUT"
  find "$PG_LOG_DIR" -type f -name "*.log" 2>/dev/null \
    | sort -u \
    | while read -r log; do
        echo "      - $log" >> "$OUTPUT"
      done
fi

# MongoDB
MONGO_LOG="/var/log/mongodb/mongod.log"
if [[ -f "$MONGO_LOG" ]]; then
  echo "    mongodb:" >> "$OUTPUT"
  echo "      - $MONGO_LOG" >> "$OUTPUT"
fi
