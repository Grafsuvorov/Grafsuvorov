echo "ФАЙЛ НА СЕРВЕРЕ" 
  grep -nF 'ytrack-create-v2' /root/table-dependency-viewer/api/services/prototype_review.py 
 
  echo "ФАЙЛ В КОНТЕЙНЕРЕ" 
  docker compose exec api grep -nF 'ytrack-create-v2' /app/api/services/prototype_review.py 
 
  echo "ОТКУДА ИМПОРТИРУЕТ PYTHON" 
  docker compose exec api python -c "import api.services.prototype_review as m; print(m.__file__); print(getattr(m, 'YTRACK_CREATE_DIAGNOSTIC_VERSION', 'КОНСТАНТА
  ОТСУТСТВУЕТ'))"
