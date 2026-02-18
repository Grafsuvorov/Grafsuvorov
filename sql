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

  Это покажет, отвечает ли API внутри контейнера.

  Про “почему только одна страница”:
  скорее всего только эта страница дергает эндпоинты /api/graph/* (диагностика, сироты, граф), и именно они сейчас отдают 403/500. Остальные страницы используют другие
  эндпоинты и работают.

  Я
