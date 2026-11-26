[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose exec api python -c                                          "from api.services.prototype_review import YTRACK_CREATE_DIAGNOSTIC_VERSION; pr                                         int(YTRACK_CREATE_DIAGNOSTIC_VERSION)"
Traceback (most recent call last):
  File "<string>", line 1, in <module>
ImportError: cannot import name 'YTRACK_CREATE_DIAGNOSTIC_VERSION' from 'api.ser                                         vices.prototype_review' (/app/api/services/prototype_review.py)
[root@rgm-s-dwhapp01 table-dependency-viewer]# grep -n 'YTRACK_CREATE_DIAGNOSTIC_VERSION' api/services/prototype_        review.py
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose exec api grep -n 'YTRACK_CREATE_DIAGNOSTIC_VERSION' /app/api/services/prototype_review.py
[root@rgm-s-dwhapp01 table-dependency-viewer]# pwd
/root/table-dependency-viewer
[root@rgm-s-dwhapp01 table-dependency-viewer]# readlink -f api/services/prototype_review.py
/root/table-dependency-viewer/api/services/prototype_review.py
[root@rgm-s-dwhapp01 table-dependency-viewer]# sed -n '20,35p' api/services/prototype_review.py
    _parse_gitlab_project,
    _urlopen_without_proxy,
)


SQL_FILE_RE = re.compile(r"\.sql$", re.IGNORECASE)
IGNORED_DEPENDENCY_SCHEMAS = {"information_schema", "pg_catalog", "pg_temp"}
TARGET_PATTERNS = [
    re.compile(r"\binsert\s+into\s+([^\s;(]+)", re.IGNORECASE),
    re.compile(r"\binsert\s+overwrite(?:\s+table)?\s+([^\s;(]+)", re.IGNORECASE),
    re.compile(r"\bcreate\s+(?:or\s+replace\s+)?table\s+(?:if\s+not\s+exists\s+)?([^\s;(]+)", re.IGNORECASE),
]
DEPENDENCY_PATTERNS = [
    re.compile(r"\bfrom\s+([^\s;(]+)", re.IGNORECASE),
    re.compile(r"\bjoin\s+([^\s;(]+)", re.IGNORECASE),
    re.compile(r"\bupdate\s+([^\s;(]+)", re.IGNORECASE),
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose exec api sed -n '20,35p' /app/api/services/prototype_review.py
    _parse_gitlab_project,
    _urlopen_without_proxy,
)


SQL_FILE_RE = re.compile(r"\.sql$", re.IGNORECASE)
IGNORED_DEPENDENCY_SCHEMAS = {"information_schema", "pg_catalog", "pg_temp"}
TARGET_PATTERNS = [
    re.compile(r"\binsert\s+into\s+([^\s;(]+)", re.IGNORECASE),
    re.compile(r"\binsert\s+overwrite(?:\s+table)?\s+([^\s;(]+)", re.IGNORECASE),
    re.compile(r"\bcreate\s+(?:or\s+replace\s+)?table\s+(?:if\s+not\s+exists\s+)?([^\s;(]+)", re.IGNORECASE),
]
DEPENDENCY_PATTERNS = [
    re.compile(r"\bfrom\s+([^\s;(]+)", re.IGNORECASE),
    re.compile(r"\bjoin\s+([^\s;(]+)", re.IGNORECASE),
    re.compile(r"\bupdate\s+([^\s;(]+)", re.IGNORECASE),
[root@rgm-s-dwhapp01 table-dependency-viewer]#
