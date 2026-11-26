[root@rgm-s-dwhapp01 table-dependency-viewer]# grep -n 'YTRACK_CREATE_DIAGNOSTIC_VERSION' api/services/prototype_        review.py
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose exec api grep -n 'YTRACK_CREATE_DIAGNOSTIC_VERSION' /app/api/services/prototype_review.py

from __future__ import annotations

import json
import logging
import re
import ssl
import time
import uuid
from datetime import datetime, timezone
from dataclasses import dataclass
from typing import Any, Optional
from urllib import parse as urlparse
from urllib import request as urlrequest
from urllib import error as urlerror

from sqlalchemy import create_engine, text

from .entity_dev_meta import (
    _extract_schema_table_refs,
    _gitlab_json_request,
    _parse_gitlab_project,
    _urlopen_without_proxy,
)


SQL_FILE_RE = re.compile(r"\.sql$", re.IGNORECASE)
IGNORED_DEPENDENCY_SCHEMAS = {"information_schema", "pg_catalog", "pg_temp"}
YTRACK_CREATE_DIAGNOSTIC_VERSION = "ytrack-create-v2"
TARGET_PATTERNS = [
    re.compile(r"\binsert\s+into\s+([^\s;(]+)", re.IGNORECASE),
    re.compile(r"\binsert\s+overwrite(?:\s+table)?\s+([^\s;(]+)", re.IGNORECASE),
    re.compile(r"\bcreate\s+(?:or\s+replace\s+)?table\s+(?:if\s+not\s+exists\s+)?([^\s;(]+)", re.IGNORECASE),
]
DEPENDENCY_PATTERNS = [
    re.compile(r"\bfrom\s+([^\s;(]+)", re.IGNORECASE),
    re.compile(r"\bjoin\s+([^\s;(]+)", re.IGNORECASE),
    re.compile(r"\bupdate\s+([^\s;(]+)", re.IGNORECASE),
]
DROP_TARGET_PATTERNS = [
    re.compile(r"\bdrop\s+(?:table|view)\s+(?:if\s+exists\s+)?([^\s;(]+)", re.IGNORECASE),
]
CREATE_OBJECT_PATTERNS = [
    re.compile(r"\bcreate\s+(?:or\s+replace\s+)?table\s+(?:if\s+not\s+exists\s+)?([^\s;(]+)", re.IGNORECASE),
    re.compile(r"\bcreate\s+(?:or\s+replace\s+)?(?:materialized\s+)?view\s+(?:if\s+not\s+exists\s+)?([^\s;(]+)", re.IGNORECASE),
]
