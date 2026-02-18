Сделай и пришли лог по этому запросу:

  docker compose logs -f api | tail -n 50

  или конкретно:

  curl -s "http://localhost:5312/api/graph/diagnostics?include_any=true"
