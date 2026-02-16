# Table Dependency Viewer

Веб-приложение для оперативного мониторинга DWH: зависимости таблиц, инциденты (YouTrack), SLA, ночные загрузки, DQ-проверки и анализ влияния.

## Что умеет

- Дашборд состояния пайплайна (инциденты, order breaches, DQ, ночная сводка).
- Карточка таблицы: метрики, история запусков, SQL-скрипты, граф зависимостей.
- Night Ops: длинные/аномальные/упавшие загрузки + анализ «тяжелых таблиц» в выбранном временном окне.
- Граф влияния (Impact Graph) с экспортом списка затронутых таблиц.
- Поиск таблиц, просмотр сущностей (entities), покрытие до DM, SLA-страница.

## Стек

- Frontend: React + Vite + React Router + React Flow + Recharts
- Backend: FastAPI + SQLAlchemy
- БД: PostgreSQL

## Структура проекта

- `src/` — фронтенд
- `api/` — FastAPI backend
- `etl_loads_entity/` — YAML/SQL метаданные ETL
- `scripts/` — утилиты (в т.ч. layout графа)
- `docker-compose.yml`, `Dockerfile`, `nginx.conf` — сборка и отдача фронта

## Быстрый старт (локально)

### 1) Frontend

```bash
npm ci
npm run dev
```

По умолчанию фронт поднимается на `http://localhost:5173`.

### 2) Backend

Создайте окружение Python и установите зависимости:

```bash
python -m venv .venv
source .venv/bin/activate
pip install fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary pyyaml openpyxl
```

Запуск API:

```bash
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
```

### 3) Конфиг

Frontend берет API из `.env`:

```env
VITE_API_BASE_URL=http://localhost:8000
```

Backend-конфиг БД и таблиц: `api/config.py`.

## Ключевые API ручки

- `GET /api/night-summary` — сводка ночного окна (по умолчанию 21:00–08:00)
- `GET /api/night/heavy-tables` — тяжелые таблицы в произвольном окне (например, `04:30–05:20`)
- `GET /api/graph/table/{schema}/{table}` — граф зависимостей таблицы
- `GET /api/graph/impact/{schema}/{table}` — граф влияния
- `GET /api/impact/summary/{schema}/{table}` — сводка влияния
- `GET /api/ytrek/incidents` — инциденты YouTrack

## Сценарий анализа пика 04:30–05:20

1. Откройте `Night Ops`.
2. В блоке `Peak window focus` задайте окно `04:30`–`05:20`.
3. Нажмите `Apply`.
4. В панели `Heavy tables in selected window` смотрите:
   - `Σ minutes` — суммарная длительность в окне,
   - `max minutes` — максимальная длительность одного запуска,
   - `runs` — число запусков,
   - `MB` — размер таблицы (если есть в метаданных).
5. Клик по строке открывает карточку таблицы для root-cause анализа.

## Особенности графа слоев

Для визуализации зависимостей слой `dict_ods` теперь идет сразу после `dict_stg`, чтобы порядок выглядел логично в pipeline-потоке.

## Production-сборка фронтенда

```bash
npm run build
npm run preview
```

Docker-сборка (frontend + backend):

```bash
docker compose up --build
```

## Технический долг / куда дальше

- Разбить крупные файлы (`HomePage`, `api/main.py`) на модули по доменам.
- Добавить тесты API (минимум smoke + контрактные для ночной аналитики).
- Вынести DSN БД из `api/config.py` в env-переменные.
