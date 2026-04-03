from __future__ import annotations

import os
import subprocess
from datetime import datetime
from pathlib import Path

from fastapi import HTTPException


def refresh_application_caches(reset_fn, warmup_fn):
    reset_fn()
    try:
      warmup_fn()
    except Exception as exc:
      raise HTTPException(status_code=500, detail="Не удалось обновить кеш") from exc
    return {"status": "ok"}


def run_ci_cd_script(*, script_path: str | Path, status_state: dict):
    script_path = Path(script_path)
    if not script_path.exists():
        raise HTTPException(status_code=404, detail=f"Скрипт не найден: {script_path}")
    if not script_path.is_file():
        raise HTTPException(status_code=400, detail="Путь скрипта должен указывать на файл")

    status_state.update(
        {
            "last_run_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "status": "running",
            "return_code": None,
            "stdout": None,
            "stderr": None,
        }
    )

    try:
        result = subprocess.run(
            ["bash", str(script_path)],
            capture_output=True,
            text=True,
            timeout=900,
            cwd=str(script_path.parent),
            env=os.environ.copy(),
        )
    except subprocess.TimeoutExpired as exc:
        raise HTTPException(status_code=500, detail="Скрипт выполняется слишком долго (timeout)") from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Не удалось запустить скрипт: {exc}") from exc

    response = {
        "status": "ok" if result.returncode == 0 else "failed",
        "return_code": result.returncode,
        "stdout": (result.stdout or "").strip()[:2000],
        "stderr": (result.stderr or "").strip()[:2000],
        "last_run_at": status_state.get("last_run_at"),
    }
    status_state.update(response)
    if result.returncode != 0:
        raise HTTPException(status_code=500, detail=response)
    return response

