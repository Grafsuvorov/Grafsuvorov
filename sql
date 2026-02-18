Проверим ответ графа (без прокси):

  curl -x "" -i "http://localhost:5312/api/graph/diagnostics?include_any=true" | head -n 20

  2. Проверим, что node доступен внутри контейнера:

  docker compose exec api node -v

  3. Логи после запроса:

  docker compose logs --tail=50 api

  По этим трём пунктам будет видно, это снова 500 или что-то ещё (например proxy/403).

