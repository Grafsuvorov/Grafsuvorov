# Production deploy

This deploy flow is isolated for the football app only.

## Files

- `deploy/.env.prod.example` - production env template
- `deploy/deploy.sh` - sync and deploy to server over `ssh`/`rsync`
- `deploy/rsync-exclude.txt` - excludes local-only files from upload

## Server prerequisites

- Docker Engine with Compose plugin installed
- SSH access for the deploy user
- PostgreSQL available from the server
- Open TCP port for `APP_PORT` or put the app behind an external reverse proxy

## First-time setup

1. Copy `deploy/.env.prod.example` to `deploy/.env.prod`
2. Fill real production values
3. Prepare target directory on the server, for example `/opt/football-app`
4. If PostgreSQL runs on the same server but outside Docker, set `DATABASE_URL` to that host and port
5. For private preview, keep `APP_BIND_IP=127.0.0.1` so the app is not public
6. If you use a domain and SSL later, place nginx/caddy/traefik in front of `${APP_PORT}`

## Deploy

```bash
chmod +x deploy/deploy.sh
./deploy/deploy.sh user@server /opt/football-app
```

The script:

- uploads only this football project
- uploads `deploy/.env.prod`
- runs `docker compose --env-file deploy/.env.prod -f docker-compose.prod.yml up -d --build`

## Update

Run the same command again. `rsync` will send only changed files.

## Check

```bash
ssh user@server "cd /opt/football-app && docker compose --env-file deploy/.env.prod -f docker-compose.prod.yml ps"
ssh user@server "cd /opt/football-app && docker compose --env-file deploy/.env.prod -f docker-compose.prod.yml logs --tail=100"
```

## Private preview access

With `APP_BIND_IP=127.0.0.1`, the app is reachable only from the server itself.

Open a tunnel from your laptop:

```bash
ssh -L 8088:127.0.0.1:8088 user@server
```

Then open:

```text
http://127.0.0.1:8088
```
