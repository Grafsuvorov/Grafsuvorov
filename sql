Добавь в api/Dockerfile после копирования node и перед pip:

  RUN npm install -g dagre

  Или локально в /app/scripts:

  RUN npm init -y && npm install dagre

  Я рекомендую глобально:

  RUN npm install -g dagre
  ENV NODE_PATH=/usr/local/lib/node_modules

  Чтобы require("dagre") находился.

  ———

  После правки Dockerfile:

  docker compose build --no-cache api
  docker compose up -d --force-recreate

  Проверка:

  curl -x "" -i "http://localhost:5312/api/graph/diagnostics?include_any=true" | head -n 20

  Должно быть 200.

