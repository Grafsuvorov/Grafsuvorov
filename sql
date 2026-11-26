GET https://yt.rusal.ru/api/admin/projects?fields=id%2Cname%2CshortName&%24top=100&%24skip=0
HTTP 200
GET https://yt.rusal.ru/api/admin/projects?fields=id%2Cname%2CshortName&%24top=100&%24skip=32
HTTP 200
Проект: 0-83; SSL verify: False
Источник схемы: три поля, проверенные созданием SDS-543.

ПОЛЯ ПРОЕКТА (canBeEmpty не отражает все обязательные поля workflow):
[
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
    "id": "134-1948",
    "$type": "SingleEnumIssueCustomField",
    "field": {
      "name": "Тип карточки",
      "fieldType": {
        "valueType": "enum"
      }
    }
  }
]
Режим запроса: как при успешном SDS-543

PAYLOAD СОЗДАНИЯ:
{
  "project": {
    "id": "0-83"
  },
  "queue": "SDS",
  "summary": "[TEST ОХД] Создание задачи и обязательная оценка 2026-11-26 14:30:37",
  "description": "Тестовая задача для отладки API Prototype Review. Можно удалить после проверки.",
  "customFields": [
    {
      "$type": "SimpleIssueCustomField",
      "value": 1,
      "id": "173-515",
      "name": "Оценка (чел./час.)"
    },
    {
      "$type": "SimpleIssueCustomField",
      "value": "LE-TR03 Shipping",
      "id": "173-646",
      "name": "Дашборд КХД/Направление"
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
HTTP 200

ЗАДАЧА СОЗДАНА:
{
  "summary": "[TEST ОХД] Создание задачи и обязательная оценка 2026-11-26 14:30:37",
  "idReadable": "SDS-546",
  "id": "2-266777",
  "$type": "Issue"
}
Ссылка: https://yt.rusal.ru/issue/SDS-546
GET https://yt.rusal.ru/api/issues/SDS-546?fields=id%2CidReadable%2CcustomFields%28id%2Cname%2C%24type%2Cvalue%28id%2Cname%2Cminutes%2Cpresentation%2Ctext%2Clogin%29%29
HTTP 200

СОХРАНЁННЫЕ ПОЛЯ:
{
  "customFields": [
    {
      "value": {
        "name": "Task",
        "id": "114-921",
        "$type": "EnumBundleElement"
      },
      "name": "Тип карточки",
      "id": "134-1948",
      "$type": "SingleEnumIssueCustomField"
    },
    {
      "value": {
        "name": "Normal",
        "id": "114-141",
        "$type": "EnumBundleElement"
      },
      "name": "Priority",
      "id": "134-493",
      "$type": "SingleEnumIssueCustomField"
    },
    {
      "value": {
        "name": "Зарегистрирована",
        "id": "116-1528",
        "$type": "StateBundleElement"
      },
      "name": "State",
      "id": "134-490",
      "$type": "StateMachineIssueCustomField"
    },
    {
      "value": {
        "login": "SuvorovND",
        "name": "Suvorov Nikita",
        "id": "1-155",
        "$type": "User"
      },
      "name": "Assignee",
      "id": "135-769",
      "$type": "SingleUserIssueCustomField"
    },
    {
      "value": null,
      "name": "Subsystem",
      "id": "134-1949",
      "$type": "SingleOwnedIssueCustomField"
    },
    {
      "value": 1,
      "name": "Оценка (чел./час.)",
      "id": "173-515",
      "$type": "SimpleIssueCustomField"
    },
    {
      "value": null,
      "name": "Due Date",
      "id": "173-692",
      "$type": "DateIssueCustomField"
    },
    {
      "value": null,
      "name": "Затраченное время",
      "id": "141-360",
      "$type": "PeriodIssueCustomField"
    },
    {
      "value": null,
      "name": "Направление",
      "id": "134-1950",
      "$type": "SingleOwnedIssueCustomField"
    },
    {
      "value": "LE-TR03 Shipping",
      "name": "Дашборд КХД/Направление",
      "id": "173-646",
      "$type": "SimpleIssueCustomField"
    },
    {
      "value": null,
      "name": "Дата релиза",
      "id": "173-517",
      "$type": "DateIssueCustomField"
    },
    {
      "value": null,
      "name": "Экономия за счет ИИ",
      "id": "141-484",
      "$type": "PeriodIssueCustomField"
    }
  ],
  "idReadable": "SDS-546",
  "id": "2-266777",
  "$type": "Issue"
}
