from pathlib import Path

from fastapi import APIRouter, HTTPException, Request

from ..auth import get_current_user_from_request
from ..config import ADMIN_CICD_SCRIPT
from ..services.admin import run_ci_cd_script

router = APIRouter(prefix="/api/admin", tags=["admin-operations"])

_ci_cd_status = {
    "last_run_at": None,
    "status": None,
    "return_code": None,
    "stdout": None,
    "stderr": None,
}


def _require_admin(request: Request):
    user = get_current_user_from_request(request)
    if not user or user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    return user


@router.post("/run-ci-cd")
def run_ci_cd(request: Request):
    _require_admin(request)
    script_path = Path(ADMIN_CICD_SCRIPT)
    if not script_path.is_absolute():
        script_path = (Path(__file__).resolve().parents[2] / script_path).resolve()
    return run_ci_cd_script(script_path=script_path, status_state=_ci_cd_status)


@router.get("/ci-cd/status")
def get_ci_cd_status(request: Request):
    _require_admin(request)
    return _ci_cd_status
