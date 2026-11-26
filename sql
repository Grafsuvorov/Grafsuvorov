pwd 
  readlink -f api/services/prototype_review.py 
  sed -n '20,35p' api/services/prototype_review.py 
 
  И отдельно внутри контейнера: 
 
  docker compose exec api sed -n '20,35p' /app/api/services/prototype_review.py
