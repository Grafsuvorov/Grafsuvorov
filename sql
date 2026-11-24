docker compose logs --since=5m api 2>&1 | grep -A 5 'OHD DB CHECK'
