def normalize_fqn(table_fqn: str) -> tuple[str, str]:
    s = table_fqn.strip().lower()

    if "/" in s and "." in s:
        schema, rest = s.split(".", 1)
        rest = rest.replace("/", "").replace("-", "").replace(" ", "")
        s = f"{schema}.{rest}"

    if "." not in s:
        raise ValueError("Expected schema.table")

    return tuple(s.split(".", 1))
2️⃣ ИСПРАВЛЯЕМ /api/incident
❌ Было (НЕПРАВИЛЬНО):

python
Копировать код
table_fqn = normalize_fqn(table_fqn)

schema, table = table_fqn.split(".", 1)
✅ Должно быть:

python
Копировать код
try:
    schema, table = normalize_fqn(table_fqn)
except ValueError:
    return JSONResponse(
        status_code=400,
        content={"error": "table_fqn must be schema.table"}
    )
