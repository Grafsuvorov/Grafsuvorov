docker compose exec api /bin/sh -c 'ls -la /app/etl_loads_entity | head'


  docker compose exec api /bin/sh -c 'echo $META_PARENT_DIR'

  Если в /app/etl_loads_entity пусто или пути нет — значит volume не смонтирован или путь в compose неверный.
  Дальше скажу точное исправление по выводу.
