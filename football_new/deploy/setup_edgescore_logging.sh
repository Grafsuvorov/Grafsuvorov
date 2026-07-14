#!/usr/bin/env bash
set -euo pipefail

cat > /etc/nginx/conf.d/edgescore_logging.conf <<'EOF'
log_format edgescore_json escape=json '{'
  '"time":"$time_iso8601",'
  '"ip":"$remote_addr",'
  '"host":"$host",'
  '"method":"$request_method",'
  '"uri":"$request_uri",'
  '"status":$status,'
  '"bytes":$body_bytes_sent,'
  '"referer":"$http_referer",'
  '"user_agent":"$http_user_agent",'
  '"request_time":$request_time,'
  '"upstream_time":"$upstream_response_time"'
'}';
EOF

python3 - <<'PY'
from pathlib import Path

p = Path("/etc/nginx/sites-available/edgescore.pro")
s = p.read_text()
needle = "    server_name edgescore.pro www.edgescore.pro;\n"
line = "    access_log /var/log/nginx/edgescore_access.json edgescore_json;\n"
if line not in s:
    s = s.replace(needle, needle + line, 1)
p.write_text(s)
PY

cat > /etc/logrotate.d/edgescore-nginx <<'EOF'
/var/log/nginx/edgescore_access.json {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        [ -s /run/nginx.pid ] && kill -USR1 `cat /run/nginx.pid`
    endscript
}
EOF

cat > /usr/local/bin/edgescore-visitors <<'PY'
#!/usr/bin/env python3
import json
import sys
from collections import Counter
from pathlib import Path

path = Path("/var/log/nginx/edgescore_access.json")
limit = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 30
rows = []

if path.exists():
    with path.open(errors="replace") as f:
        for line in f:
            try:
                r = json.loads(line)
            except Exception:
                continue
            uri = r.get("uri") or ""
            if uri.startswith("/assets/") or uri in ("/favicon.ico", "/robots.txt"):
                continue
            rows.append(r)

print(f"Events: {len(rows)}")
print("\nLast visits:")
for r in rows[-limit:]:
    ua = (r.get("user_agent") or "")[:90]
    print(f"{r.get('time')} {r.get('ip')} {r.get('status')} {r.get('method')} {r.get('uri')} {r.get('request_time')}s {ua}")

print("\nTop IPs:")
for ip, n in Counter(r.get("ip") for r in rows).most_common(15):
    print(f"{n:5} {ip}")

print("\nTop pages:")
for uri, n in Counter((r.get("uri") or "").split("?")[0] for r in rows).most_common(15):
    print(f"{n:5} {uri}")

print("\nStatuses:")
for st, n in Counter(str(r.get("status")) for r in rows).most_common():
    print(f"{n:5} {st}")
PY
chmod +x /usr/local/bin/edgescore-visitors

nginx -t
systemctl reload nginx
