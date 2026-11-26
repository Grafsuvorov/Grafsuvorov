GET https://yt.rusal.ru/api/admin/projects?fields=id%2Cname%2CshortName&%24top=100&%24skip=0
HTTP 200
GET https://yt.rusal.ru/api/admin/projects?fields=id%2Cname%2CshortName&%24top=100&%24skip=32
HTTP 200
Проект: 0-83; SSL verify: False
GET https://yt.rusal.ru/api/issues/SDS-471?fields=id%2CidReadable%2Cproject%28id%2Cname%2CshortName%29%2CcustomFields%28id%2Cname%2C%24type%2Cvalue%28id%2Cname%2Cminutes%2Cpresentation%2Ctext%2Clogin%29%29
HTTP 200

ПОЛЯ СУЩЕСТВУЮЩЕЙ ЗАДАЧИ:
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
        "name": "Завершена",
        "id": "116-1529",
        "$type": "StateBundleElement"
      },
      "name": "State",
      "id": "134-490",
      "$type": "StateMachineIssueCustomField"
    },
    {
      "value": {
        "login": "KitaevSN",
        "name": "Kitaev Stanislav",
        "id": "1-74",
        "$type": "User"
      },
      "name": "Assignee",
      "id": "135-769",
      "$type": "SingleUserIssueCustomField"
    },
    {
      "value": {
        "name": "DE (Data Engineer)",
        "id": "142-104",
        "$type": "OwnedBundleElement"
      },
      "name": "Subsystem",
      "id": "134-1949",
      "$type": "SingleOwnedIssueCustomField"
    },
    {
      "value": 0,
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
      "value": {
        "name": "Транспортировка",
        "id": "142-120",
        "$type": "OwnedBundleElement"
      },
      "name": "Направление",
      "id": "134-1950",
      "$type": "SingleOwnedIssueCustomField"
    },
    {
      "value": [],
      "name": "Дашборд LE",
      "id": "134-1952",
      "$type": "MultiEnumIssueCustomField"
    },
    {
      "value": "LE-TR03 Shipping",
      "name": "Дашборд КХД/Направление",
      "id": "173-646",
      "$type": "SimpleIssueCustomField"
    },
    {
      "value": 1792670400000,
      "name": "Дата релиза",
      "id": "173-517",
      "$type": "DateIssueCustomField"
    },
    {
      "value": {
        "presentation": "1ч",
        "id": "PT1H",
        "minutes": 60,
        "$type": "PeriodValue"
      },
      "name": "Экономия за счет ИИ",
      "id": "141-484",
      "$type": "PeriodIssueCustomField"
    }
  ],
  "idReadable": "SDS-471",
  "project": {
    "shortName": "SDS",
    "name": "ОХД - Общее Хранилище Данных (Данные партнеров)",
    "id": "0-83",
    "$type": "Project"
  },
  "id": "2-122533",
  "$type": "Issue"
}
