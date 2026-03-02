FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN pip install --no-cache-dir fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary pyyaml openpyxl

COPY api/ /app/api/
COPY etl_loads_entity/ /app/etl_loads_entity/
COPY config_files/ /app/config_files/

EXPOSE 8000

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
