 Команда curl у тебя оборвалась без вывода. Повтори и пришли результат:

  curl -i "http://localhost:5312/api/graph/diagnostics?include_any=true" | head -n 20

  Если там 500 — сразу покажи логи:

  docker compose logs --tail=50 api
