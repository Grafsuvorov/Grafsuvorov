import sqlglot
import re

query = """
CREATE TEMP TABLE temp1 AS
SELECT * FROM dict_stg.contracts;

DO $$
BEGIN
  INSERT INTO ods.temp_contracts
  SELECT * FROM temp1;
END $$;
"""

# 1. Вытащим содержимое DO $$ ... $$ и отдельно распарсим
do_blocks = re.findall(r'DO\s+\$\$(.*?)\$\$', query, flags=re.DOTALL | re.IGNORECASE)

# 2. Распарсим остальное (без DO)
query_wo_do = re.sub(r'DO\s+\$\$(.*?)\$\$', '', query, flags=re.DOTALL | re.IGNORECASE)
parsed = sqlglot.parse(query_wo_do, read='postgres')

print("== Извлечено из основного SQL ==")
for stmt in parsed:
    print(stmt.sql())
    for t in stmt.find_all(sqlglot.expressions.Table):
        print(" →", t.sql())

print("\n== Извлечено из DO $$ ==")
for block in do_blocks:
    # вытаскиваем SQL внутри DO BEGIN ... END
    inner_sql = re.findall(r'(INSERT\s+INTO.*?;|UPDATE\s+.*?;|DELETE\s+FROM.*?;)', block, flags=re.IGNORECASE | re.DOTALL)
    for stmt in parsed:
        if stmt is None:
            continue
        print(stmt.sql())
        for t in stmt.find_all(sqlglot.expressions.Table):
            print(" →", t.sql())
        except Exception as e:
            print("  [!] Ошибка парсинга DO блока:", e)
