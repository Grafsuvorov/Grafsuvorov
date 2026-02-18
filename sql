docker run --rm \
    -e HTTP_PROXY="http://rgm-s-rtproxnlb01.hq.root.ad:1010" \
    -e HTTPS_PROXY="http://rgm-s-rtproxnlb01.hq.root.ad:1010" \
    -v "$PWD":/app -w /app \
    node:20-alpine sh -lc \
    "npm config set proxy http://rgm-s-rtproxnlb01.hq.root.ad:1010 && \
     npm config set https-proxy http://rgm-s-rtproxnlb01.hq.root.ad:1010 && \
     npm install react-router-dom"

  Это обновит и package.json, и package-lock.json.

  Дальше:

  DOCKER_BUILDKIT=0 docker compose build --no-cache frontend
  docker compose up -d --force-recreate

  Если с прокси снова упадёт — скажи, я добавлю NO_PROXY или укажем корпоративный registry.
