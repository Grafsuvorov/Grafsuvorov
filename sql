
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose exec api /bin/sh -c 'python - <<PY
>   import urllib.request
>   url="http://localhost:8000/api/graph/diagnostics?include_any=true"
>   try:
>       r=urllib.request.urlopen(url)
>       print("status", r.status)
>       print(r.read(200))
>   except Exception as e:
>       print("error", e)
>   PY'
  File "<stdin>", line 1
    import urllib.request
IndentationError: unexpected indent
