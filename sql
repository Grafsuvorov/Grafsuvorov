cd C:\Users\SuvorovND\GIT\table-dependency-viewer
  python scripts\audit_depends_on.py --root "C:\Users\SuvorovND\GIT\meta_info\database\greenplum\schema_name\tech_etl\etl_loads_entity" --out reports\depends_audit.txt

  Проверка:

  type reports\depends_audit.txt

  Если хочешь сразу увидеть в консоли:

  python scripts\audit_depends_on.py --root "C:\Users\SuvorovND\GIT\meta_info\database\greenplum\schema_name\tech_etl\etl_loads_entity"

  Чтобы убедиться, что скрипт вообще читает данные, можешь ограничить 1 файл:

  python scripts\audit_depends_on.py --root "C:\Users\SuvorovND\GIT\meta_info\database\greenplum\schema_name\tech_etl\etl_loads_entity" --limit 1

  Если всё равно пусто — пришли 5–10 строк вывода этой команды, проверю.
