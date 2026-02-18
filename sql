[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose up -d --force-recreate
[+] Running 2/2
 ⠿ Container table-dependency-viewer-frontend-1  Started                                                                             0.9s
 ⠿ Container table-dependency-viewer-api-1       Started                                                                             0.9s
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose exec api ls /app/scripts
dagre_layout.cjs
[root@rgm-s-dwhapp01 table-dependency-viewer]# curl -s "http://localhost:5312/api/graph/diagnostics?include_any=true" | head
