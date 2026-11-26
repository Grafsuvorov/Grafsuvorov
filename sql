
  docker compose exec api grep -n 'YTRACK_CREATE_DIAGNOSTIC_VERSION' /app/api/services/prototype_review.py 
 
  Если на сервере строка есть, а внутри контейнера нет — API работает на старом образе, его нужно успешно пересобрать и пересоздать

grep -n 'YTRACK_CREATE_DIAGNOSTIC_VERSION' api/services/prototype_review.py
