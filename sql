Добавь установку nodejs:

  RUN apt-get update && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*

  Рекомендуемый порядок:

  FROM python:3.11-slim
  WORKDIR /app/api
  ENV PYTHONDONTWRITEBYTECODE=1
  ENV PYTHONUNBUFFERED=1

  RUN apt-get update && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*

  COPY api/ /app/api/
  COPY scripts/ /app/scripts/
  ...
  CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

  (если scripts монтируешь как volume, COPY scripts можно не делать)

  Дальше:

  docker compose build --no-cache api
  docker compose up -d --force-recreate

  После этого /api/graph/diagnostics заработает и главная загрузится.

  ———

  Про curl и 407 Proxy Authentication: это потому что на сервере запрос curl уходит через системный прокси. Для проверки API на сервере лучше так:

  curl -x "" -s "http://localhost:5312/api/graph/diagnostics?include_any=true" | head

  (это отключает прокси).
