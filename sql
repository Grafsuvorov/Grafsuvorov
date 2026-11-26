GET https://yt.rusal.ru/api/admin/projects?fields=id%2Cname%2CshortName&%24top=100&%24skip=0
HTTP 200
GET https://yt.rusal.ru/api/admin/projects?fields=id%2Cname%2CshortName&%24top=100&%24skip=32
HTTP 200
Проект: 0-83; SSL verify: False
GET https://yt.rusal.ru/api/admin/projects/0-83/customFields?fields=id%2C%24type%2CcanBeEmpty%2Cfield%28id%2Cname%2CfieldType%28id%2CvalueType%29%29&%24top=100&%24skip=0
HTTP 200

Список настроек полей пуст. Читаю типы из SDS-471; значения задачи не копируются.
GET https://yt.rusal.ru/api/issues/SDS-471?fields=id%2CidReadable%2Cproject%28id%2Cname%2CshortName%29%2CcustomFields%28id%2Cname%2C%24type%2Cvalue%28id%2Cname%2Cminutes%2Cpresentation%2Ctext%2Clogin%29%29
HTTP 200

ПОЛЯ ПРОЕКТА (canBeEmpty не отражает все обязательные поля workflow):
[
  {
    "id": "134-1948",
    "$type": "SingleEnumIssueCustomField",
    "field": {
      "name": "Тип карточки",
      "fieldType": {
        "valueType": ""
      }
    }
  },
  {
    "id": "134-493",
    "$type": "SingleEnumIssueCustomField",
    "field": {
      "name": "Priority",
      "fieldType": {
        "valueType": ""
      }
    }
  },
  {
    "id": "134-490",
    "$type": "StateMachineIssueCustomField",
    "field": {
      "name": "State",
      "fieldType": {
        "valueType": ""
      }
    }
  },
  {
    "id": "135-769",
    "$type": "SingleUserIssueCustomField",
    "field": {
      "name": "Assignee",
      "fieldType": {
        "valueType": ""
      }
    }
  },
  {
    "id": "134-1949",
    "$type": "SingleOwnedIssueCustomField",
    "field": {
      "name": "Subsystem",
      "fieldType": {
        "valueType": ""
      }
    }
  },
  {
    "id": "173-515",
    "$type": "SimpleIssueCustomField",
    "field": {
      "name": "Оценка (чел./час.)",
      "fieldType": {
        "valueType": "integer"
      }
    }
  },
  {
    "id": "173-692",
    "$type": "DateIssueCustomField",
    "field": {
      "name": "Due Date",
      "fieldType": {
        "valueType": ""
      }
    }
  },
  {
    "id": "141-360",
    "$type": "PeriodIssueCustomField",
    "field": {
      "name": "Затраченное время",
      "fieldType": {
        "valueType": ""
      }
    }
  },
  {
    "id": "134-1950",
    "$type": "SingleOwnedIssueCustomField",
    "field": {
      "name": "Направление",
      "fieldType": {
        "valueType": ""
      }
    }
  },
  {
    "id": "134-1952",
    "$type": "MultiEnumIssueCustomField",
    "field": {
      "name": "Дашборд LE",
      "fieldType": {
        "valueType": ""
      }
    }
  },
  {
    "id": "173-646",
    "$type": "SimpleIssueCustomField",
    "field": {
      "name": "Дашборд КХД/Направление",
      "fieldType": {
        "valueType": "string"
      }
    }
  },
  {
    "id": "173-517",
    "$type": "DateIssueCustomField",
    "field": {
      "name": "Дата релиза",
      "fieldType": {
        "valueType": "integer"
      }
    }
  },
  {
    "id": "141-484",
    "$type": "PeriodIssueCustomField",
    "field": {
      "name": "Экономия за счет ИИ",
      "fieldType": {
        "valueType": ""
      }
    }
  }
]

PAYLOAD СОЗДАНИЯ:
{
  "project": {
    "id": "0-83"
  },
  "queue": "SDS",
  "summary": "[TEST ОХД] Создание задачи и обязательная оценка 2026-11-26 12:20:47",
  "description": "Тестовая задача для отладки API Prototype Review. Можно удалить после проверки.",
  "customFields": [
    {
      "$type": "SimpleIssueCustomField",
      "value": 1,
      "id": "173-515",
      "name": "Оценка (чел./час.)"
    },
    {
      "$type": "SingleEnumIssueCustomField",
      "value": {
        "name": "Task"
      },
      "id": "134-1948",
      "name": "Тип карточки"
    }
  ]
}
POST https://yt.rusal.ru/api/issues?fields=id%2CidReadable%2Csummary

ОШИБКА: HTTP 400: {"error":"Field required","error_description":"Поле Дашборд КХД/Направление обязательно","error_field":"Дашборд КХД/Направление","error_rule_name":"@jetbrains/required-custom-fields-feature","error_issue_id":"2-266745","error_issue_is_draft":false,"error_transitions":[],"error_original_command":"Тип карточки Task","error_project_custom_field_id":"173-646","error_type":"workflow","error_workflow_type":"require"}
Повторная отправка автоматически не выполнялась. Если ответ содержит error_issue_id, проверьте наличие задачи перед новым запуском.
