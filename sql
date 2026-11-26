GET https://yt.rusal.ru/api/admin/projects?fields=id%2Cname%2CshortName&%24top=100&%24skip=0
HTTP 200
GET https://yt.rusal.ru/api/admin/projects?fields=id%2Cname%2CshortName&%24top=100&%24skip=32
HTTP 200
Проект: 0-83; SSL verify: False
GET https://yt.rusal.ru/api/admin/projects/0-83/customFields?fields=id%2C%24type%2CcanBeEmpty%2Cfield%28id%2Cname%2CfieldType%28id%2CvalueType%29%29&%24top=100&%24skip=0
HTTP 200

ПОЛЯ ПРОЕКТА (canBeEmpty не отражает все обязательные поля workflow):
[]

ОШИБКА: Поле не найдено однозначно: name='Оценка (чел./час.)', project_field_id='173-515'. Проверьте --fields.
Повторная отправка автоматически не выполнялась. Если ответ содержит error_issue_id, проверьте наличие задачи перед новым запуском.
