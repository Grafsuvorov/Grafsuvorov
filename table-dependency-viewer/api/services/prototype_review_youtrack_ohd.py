"""YouTrack schema verified against SDS-543, SDS-546 and SDS-547 (project 0-83)."""

VERIFIED_PROJECT_ID = "0-83"

# These are identities and types, never values copied from an existing issue.
VERIFIED_FIELDS = [
    {"id": "173-515", "$type": "SimpleIssueCustomField", "field": {
        "name": "Оценка (чел./час.)", "fieldType": {"valueType": "integer"}}},
    {"id": "173-646", "$type": "SimpleIssueCustomField", "field": {
        "name": "Дашборд КХД/Направление", "fieldType": {"valueType": "string"}}},
    {"id": "134-1948", "$type": "SingleEnumIssueCustomField", "field": {
        "name": "Тип карточки", "fieldType": {"valueType": "enum"}}},
    {"id": "135-769", "$type": "SingleUserIssueCustomField", "field": {
        "name": "Assignee", "fieldType": {"valueType": "user"}}},
    {"id": "173-517", "$type": "DateIssueCustomField", "field": {
        "name": "Дата релиза", "fieldType": {"valueType": "date"}}},
]
