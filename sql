cd /root/table-dependency-viewer
  docker compose exec api /bin/sh -c 'python -c "import urllib.request; url=\"http://localhost:8000/api/graph/diagnostics?include_any=true\";
  try:
      r=urllib.request.urlopen(url); print(\"status\", r.status); print(r.read(200))
  except Exception as e:
      print(\"error\", e)"'

  Если shell ругается, ещё проще:

  docker compose exec api /bin/sh -c 'python -c "import urllib.request; url=\"http://localhost:8000/api/graph/diagnostics?include_any=true\";
  r=urllib.request.urlopen(url); print(r.status); print(r.read(200))"'
