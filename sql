
# --- PROD пример (раскомментируй нужные строки) ---
#services:
#  frontend:
#    build: .
#    ports:
#      - "80:80"
#  api:
#    build:
#      context: .
#      dockerfile: api/Dockerfile
#    ports:
#      - "8000:8000"
#    # Вариант А: брать переменные из api/.env
#    #env_file:
#    #  - ./api/.env
