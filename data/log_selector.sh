#!/usr/bin/env bash

# Функция для отображения интерактивного меню
select_log() {
  local logs=("$@")
  local selected=0
  local count=${#logs[@]}

  # Настройка терминала
  stty -echo -icanon time 0 min 1

  # Функция отрисовки меню
  draw() {
    tput rc        # вернуть курсор
    for i in "${!logs[@]}"; do
      tput el      # очистить строку
      if [[ $i -eq $selected ]]; then
        echo -e "\e[7m> ${logs[i]}\e[0m"
      else
        echo "  ${logs[i]}"
      fi
    done
  }

  # точка якоря
  tput sc
  draw

  while true; do
    read -rsn1 key
    case "$key" in
      $'\x1b')
        read -rsn2 key
        case "$key" in
          '[A') ((selected--)) ;;
          '[B') ((selected++)) ;;
        esac
        ;;
      '') break ;;
    esac

    ((selected<0)) && selected=$((count-1))
    ((selected>=count)) && selected=0

    draw
  done

  stty sane
  echo
  echo "Вы выбрали: ${logs[selected]}"
  return $selected
}

# Экспортируем функцию для использования в других скриптах
export -f select_log