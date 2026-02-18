from fastapi.middleware.cors import CORSMiddleware

  app.add_middleware(
      CORSMiddleware,
      allow_origins=[
          "http://rgm-s-dwhapp01.hq.root.ad:15312",
          "http://rgm-s-dwhapp01.hq.root.ad",
      ],
      allow_credentials=True,
      allow_methods=["*"],
      allow_headers=["*"],
  )

  (Можно временно allow_origins=["*"], но лучше указать домен.)

  2. Пересобери API и перезапусти:

  docker compose build --no-cache api
  docker compose up -d --force-recreate

  После этого главная страница загрузится.
