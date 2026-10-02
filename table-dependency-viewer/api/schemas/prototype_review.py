from typing import Any, Dict, List, Optional, Union

from pydantic import BaseModel


class PrototypeReviewRunPayload(BaseModel):
    mr_input: str
    key_attributes: Optional[List[str]] = None
    create_issue: bool = False
    task_text: Optional[str] = None
    target_table_fqn: Optional[str] = None
    entity_name: Optional[str] = None
    issue_summary: Optional[str] = None
    load_mode: Optional[str] = None
    stand_dev: bool = True
    stand_prod: bool = True
    copy_to_clickhouse: Optional[bool] = None
    dependent_views: Optional[List[str]] = None
    linked_issues: Optional[List[str]] = None
    release_date: Optional[str] = None
    direction: Optional[str] = None
    business_key_changed: Optional[bool] = None
    parent_issue: Optional[str] = None
    diff_comment: Optional[str] = None


class PrototypeReviewTableCheckPayload(BaseModel):
    mr_input: str
    item_id: Optional[str] = None
    target_fqn: str
    entity_name: Optional[str] = None
    key_attributes: Optional[List[str]] = None


class PrototypeReviewYamlRefreshPayload(BaseModel):
    target_fqn: str
    entity_name: str
    key_attributes: Optional[List[str]] = None
    object_type: Optional[str] = None
    yaml_content: Optional[str] = None


class PrototypeReviewItemPayload(BaseModel):
    item_id: Optional[str] = None
    path: Optional[str] = None
    paths: Optional[List[str]] = None
    target_fqn: str
    entity_name: Optional[str] = None
    key_attributes: Optional[List[str]] = None
    scd_type: Optional[str] = "scd1"
    version_key: Optional[List[str]] = None
    filter: Optional[str] = None
    null_conditions: Optional[List[str]] = None
    clickhouse_keys: Optional[List[str]] = None
    dependent_views: Optional[List[str]] = None
    is_new: Optional[bool] = None
    object_type: Optional[str] = None
    duration_sec: Optional[float] = None
    row_count: Optional[int] = None
    duplicate_groups: Optional[int] = None
    dependencies: Optional[List[str]] = None
    impact_tables: Optional[List[Dict[str, Any]]] = None
    yaml_content: Optional[str] = None
    stand_dev: Optional[bool] = True
    stand_prod: Optional[bool] = True
    copy_to_clickhouse: Optional[bool] = None
    comment: Optional[str] = None
    manual_script_name: Optional[str] = None
    manual_scripts: Optional[List[Dict[str, Any]]] = None


class PrototypeReviewCreateIssuePayload(BaseModel):
    mr_input: str
    task_text: Optional[str] = None
    issue_summary: Optional[str] = None
    load_mode: Optional[str] = None
    stand_dev: bool = True
    stand_prod: bool = True
    copy_to_clickhouse: Optional[bool] = None
    linked_issues: Optional[List[str]] = None
    release_date: Optional[str] = None
    direction: Optional[str] = None
    business_key_changed: Optional[bool] = None
    parent_issue: Optional[str] = None
    diff_comment: Optional[str] = None
    review_items: List[PrototypeReviewItemPayload]


class BusinessDqPreviewPayload(BaseModel):
    mr_input: str
    business_area: str
    business_area_code: Optional[str] = None


class BusinessDqCreatePayload(BusinessDqPreviewPayload):
    checks: List[Dict[str, Any]]
    detail_store_limit: Optional[Union[int, str]] = 100000
    stand_dev: bool = True
    stand_prod: bool = True
    issue_summary: Optional[str] = None
    direction: Optional[str] = None
    release_date: Optional[str] = None
    parent_issue: Optional[str] = None
