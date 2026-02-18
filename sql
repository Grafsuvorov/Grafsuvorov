Проверь так:

  ### 1) Убедимся, что запрос внутри контейнера

  docker compose exec api /bin/sh -c 'python - <<PY
  import urllib.request
  url="http://localhost:8000/api/graph/diagnostics?include_any=true"
  try:
      r=urllib.request.urlopen(url)
      print("status", r.status)
      print(r.read(200))
  except Exception as e:
      print("error", e)
  PY'

  ### 2) Посмотреть, что пишет API в логах на этот запрос

  Сразу после запроса:

  docker compose logs --tail=50 api

  ### 3) Проверить, не переопределён порт

  docker compose port api 8000

  Если внутри контейнера тоже 403 — значит логика API блокирует /api/graph/diagnostics. Тогда нужно смотреть код (или ограничения в конфиге).
  Если внутри конт
