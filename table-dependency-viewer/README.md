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

Для корпоративного AI-ассистента добавьте переменные в основной `.env`
и, если запускаете через Docker Compose, они будут проброшены в `api` контейнер:

```env
CORP_AI_API_KEY=
CORP_AI_BASE_URL=
CORP_AI_MODEL=coder-ultra
CORP_AI_SSL_VERIFY=false
CORP_AI_TIMEOUT_SEC=60
```

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

## DEV Meta контур

Для admin-only работы с DEV meta добавлен отдельный каталог:

- `config_files/meta` — PROD source
- `config_files/meta_dev` — DEV контур для ручных правок и тестового запуска DAG

Нужные env:

```env
CLICK_META_DIR=config_files/meta
DEV_CLICK_META_DIR=config_files/meta_dev
DEV_DATABASE_URL=
AIRFLOW_DEV_BASE_URL=
AIRFLOW_DEV_DAG_ID=
AIRFLOW_DEV_USERNAME=
AIRFLOW_DEV_PASSWORD=
DEV_META_LOCK_TTL_MIN=30
```

Замечания:

- `DEV_DATABASE_URL` опционален. Он нужен только для проверки существования объекта в DEV Greenplum.
- `AIRFLOW_DEV_*` нужны только для кнопки запуска DEV DAG.
- Для записи файлов из контейнера `api` каталог `config_files` должен быть примонтирован в `/app/config_files`.

## Автообновление dbt manifest

Для `OHD / dbt` приложение читает текущий manifest из `config_files/dbt/ohd/manifest.json`.

Для ежедневного обновления добавлен скрипт:

```bash
python3 scripts/refresh_dbt_manifest.py
```

Нужные env:

```env
MINIO_HOST=res-s-khs3.resource.local
MINIO_PORT=9000
MINIO_ACCESS_KEY=gpetl
MINIO_SECRET_KEY=
MINIO_SECURE=true
DBT_MINIO_BUCKET=dbt-zp-prod
DBT_MINIO_PREFIX=dbt_run_manual
DBT_MANIFEST_ROOT=config_files/dbt
DBT_MANIFEST_SOURCE=ohd
DBT_MANIFEST_KEEP=2
```

Что делает скрипт:

- по умолчанию ищет последний доступный запуск внутри `dbt_run_manual/`, даже если он не за сегодня
- скачивает `manifest.json` и, если есть, `run_results.json`
- обновляет текущие файлы в `config_files/dbt/ohd/`
- сохраняет архив в `config_files/dbt/.archive/ohd/`
- хранит по одной версии на день: повторный запуск за тот же день перезаписывает архив этого дня
- оставляет только 2 последних дня в архиве, остальные удаляет

Если нужно принудительно взять конкретную дату:

```bash
DBT_REFRESH_DAY=2026-04-10 python3 scripts/refresh_dbt_manifest.py
```

Пример `cron` на Linux для запуска каждый день в `09:00`:

```cron
0 9 * * * cd /opt/table-dependency-viewer && /usr/bin/python3 scripts/refresh_dbt_manifest.py >> /var/log/tdv_refresh_dbt_manifest.log 2>&1
```

Скрипт использует lock-файл `/tmp/tdv_refresh_dbt_manifest.lock`, поэтому параллельные запуски не пересекутся.

## DBT logs

Для отдельной БД с `dbt`-логами нужен отдельный DSN, как и для основной БД.

Пример env:

```env
DBT_LOGS_DATABASE_URL=postgresql+psycopg2://user:password@host:5432/db_name
TABLE_DBT_MODEL_CATALOG=dc_dbt.model
TABLE_DBT_MODEL_LOG=tech_monitoring.log_dbt_model
TABLE_DBT_RUN_LOG=tech_monitoring.log_dbt_run
```

## Технический долг / куда дальше

- Разбить крупные файлы (`HomePage`, `api/main.py`) на модули по доменам.
- Добавить тесты API (минимум smoke + контрактные для ночной аналитики).
- Вынести DSN БД из `api/config.py` в env-переменные.
