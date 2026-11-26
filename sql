
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose exec api python -c "from api.services.prototype_review import YTRACK_CREATE_DIAGNOSTIC_VERSION; print(YTRACK_CREATE_DIAGNOSTIC_VERSION)"
Traceback (most recent call last):
  File "<string>", line 1, in <module>
ImportError: cannot import name 'YTRACK_CREATE_DIAGNOSTIC_VERSION' from 'api.services.prototype_review' (/app/api/services/prototype_review.py)
