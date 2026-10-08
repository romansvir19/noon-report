#!/bin/zsh
# Резервная копия Noon Report на GitHub.
# Запуск: двойной клик по этому файлу.
cd "$(dirname "$0")" || exit 1
echo "=== Резервная копия Noon Report ==="
echo
if [ -z "$(git status --porcelain)" ]; then
  echo "Изменений нет — на GitHub уже самая свежая версия."
else
  git add -A
  git commit -q -m "Обновление $(date '+%d.%m.%Y %H:%M')"
  echo "Отправляю на GitHub…"
  if git push -q origin main; then
    echo "✓ Готово. https://github.com/romansvir19/noon-report"
  else
    echo "✗ Не вышло отправить — проверь интернет."
  fi
fi
echo
echo "Окно можно закрыть."
