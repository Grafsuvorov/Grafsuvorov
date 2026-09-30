# Pin the Debian release: the floating slim tag recently switched to trixie,
# while the corporate package proxy intermittently serves incomplete indexes.
FROM python:3.11-slim-bookworm

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update \
    && apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 install -y --no-install-recommends bash git openssh-client sshpass fonts-dejavu-core \
    && groupadd -r airflow \
    && useradd -r -g airflow airflow \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary pyyaml openpyxl python-dotenv pillow reportlab openai

COPY api/ /app/api/
COPY scripts/ /app/scripts/
COPY etl_loads_entity/ /app/etl_loads_entity/
COPY config_files/ /app/config_files/

EXPOSE 8000

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
