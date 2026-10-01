"""HTTP transport for Prototype Review.

Business handlers are injected while the legacy service is moved out of
``main.py`` in smaller, testable steps. Public URLs and payloads stay stable.
"""

from dataclasses import dataclass
from typing import Callable

from fastapi import APIRouter, Request

from ..schemas.prototype_review import (
    BusinessDqCreatePayload,
    BusinessDqPreviewPayload,
    PrototypeReviewCreateIssuePayload,
    PrototypeReviewRunPayload,
    PrototypeReviewTableCheckPayload,
    PrototypeReviewYamlRefreshPayload,
)


@dataclass(frozen=True)
class PrototypeReviewHandlers:
    business_dq_preview: Callable
    business_dq_validate: Callable
    business_dq_create: Callable
    run: Callable
    run_start: Callable
    run_status: Callable
    check_table: Callable
    refresh_yaml: Callable
    create_issue: Callable


def build_prototype_review_router(handlers: PrototypeReviewHandlers) -> APIRouter:
    router = APIRouter(prefix="/api/admin/prototype-review", tags=["prototype-review"])

    @router.post("/business-dq/preview")
    def business_dq_preview(payload: BusinessDqPreviewPayload, request: Request):
        return handlers.business_dq_preview(payload, request)

    @router.post("/business-dq/validate")
    def business_dq_validate(payload: BusinessDqPreviewPayload, request: Request):
        return handlers.business_dq_validate(payload, request)

    @router.post("/business-dq/create")
    def business_dq_create(payload: BusinessDqCreatePayload, request: Request):
        return handlers.business_dq_create(payload, request)

    @router.post("/run")
    def run(payload: PrototypeReviewRunPayload, request: Request):
        return handlers.run(payload, request)

    @router.post("/run-start")
    def run_start(payload: PrototypeReviewRunPayload, request: Request):
        return handlers.run_start(payload, request)

    @router.get("/run-status/{job_id}")
    def run_status(job_id: str, request: Request):
        return handlers.run_status(job_id, request)

    @router.post("/check-table")
    def check_table(payload: PrototypeReviewTableCheckPayload, request: Request):
        return handlers.check_table(payload, request)

    @router.post("/refresh-yaml")
    def refresh_yaml(payload: PrototypeReviewYamlRefreshPayload, request: Request):
        return handlers.refresh_yaml(payload, request)

    @router.post("/create-issue")
    def create_issue(payload: PrototypeReviewCreateIssuePayload, request: Request):
        return handlers.create_issue(payload, request)

    return router
