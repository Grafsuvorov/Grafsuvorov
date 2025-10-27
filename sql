❌ WindowAgg (LEAD) + Sort на 200–240M строк (WindowAgg/Sort, external merge/sort)

❌ Двойное чтение CKMLCR (и base, и temp ckmlcr_2)

❌ Множественные Redistribute Motion перед крупными Hash Join

❌ Поздний учёт MLCD → большие workfile’ы/спиллы

⏱ Execution Time ≈ 8 мин (≈ 479k ms)

Стало (план):

✅ Без оконок и глобальных сортировок (только Hash Join)

✅ Один проход по CKMLCR → Shared Scan (Share ID 1)

✅ Предагрегирование MLCD до джоинов

➡️ Redistribute Motion остался (особенность MPP и ключей), но объём и цена кратно меньше

⏱ Execution Time ≈ 2 мин (≈ 116k ms) в типовом прогоне


Было: есть WindowAgg и большие Sort на сотни млн строк.
Ищи в старом плане:

"Node Type": "WindowAgg"
"Node Type": "Sort",
"Plan Rows": 243810381
"Sort Method": "external sort" | "external merge"


Стало: в новом плане нет WindowAgg/Sort на верхнем уровне — только Hash Join/Aggregate.

2) «Двойное чтение» CKMLCR → один проход с шарингом

Было: и Seq Scan on ods.ckmlcr_ral, и отдельный Seq Scan on ckmlcr_2 (temp).

"Relation Name": "ckmlcr_ral", "Schema": "ods"
"Relation Name": "ckmlcr_2",   "Schema": "pg_temp_..."


Стало: один проход и переиспользование:

"Node Type": "Shared Scan",
"Share ID": 1,
"Relation Name": "ckmlcr_ral"


(В новом плане нет ckmlcr_2 вообще.)

3) LEAD → JOIN по dt_next

Было: джоин на temp с полем dt_posting (это и был «следующий месяц» для LEAD):

"Hash Cond": "(((ckmlpp_ral.kalnr)::text = (ckmlcr_2.kalnr)::text)
               AND ( ... = ckmlcr_2.dt_posting))"


Стало: «предыдущая строка» находится джоином c_prev.dt_next = p.dt_valid_from:

LEFT JOIN cr c_prev
  ON c_prev.kalnr_text = p.kalnr_text
 AND c_prev.dt_next    = p.dt_valid_from


В плане это видно по Hash Cond на share1_ref2.dt_next (или аналогично).

4) Ранняя предагрегация MLCD

Было: join с уже собранной temp mlcd, но тяжёлые спиллы на больших join’ах.
Стало: в новом — явная ранняя агрегация mlcd_ral до join’ов:

"Node Type": "Aggregate",
"Strategy": "Hashed",
"Relation Name": "mlcd_ral"


(В твоём новом плане это в отдельном Slice до основных Hash Join.)

5) Redistribute Motion остался, но «подешевел»

Было: много Redistribute Motion перед тяжёлыми Hash Join, большие workfiles.
Стало: Redistribute Motion всё ещё есть (особенность MPP при составных ключах), но на меньшем объёме:
смотри меньшие Actual Total Time у Redistribute Motion и меньше «Wrote/Read … bytes to workfile» в Extra Text.

Пример маркеров:

"Node Type": "Redistribute Motion",
"Hash Key": "((ckmlpp_ral.kalnr)::text)" | "share1_ref3.kalnr_text"
"Actual Total Time": ...   ← стало заметно меньше

6) «Тяжёлая» функция в сортировке исчезла

Было: в окне сортировали по

"Order By": ["(tech_etl.util_text_to_date_validation(...))"]


Стало: этого больше нет — только простые to_date(...) + '1 mon'.

Быстрые команды для демонстрации (если сохранишь JSON как plan_old.json / plan_new.json)

Проверить наличие оконок/сортировок:

grep -E '"Node Type": "WindowAgg"|"Node Type": "Sort"' plan_old.json
grep -E '"Node Type": "WindowAgg"|"Node Type": "Sort"' plan_new.json


Показать двойное чтение vs. Shared Scan:

grep -n '"Relation Name": "ckmlcr_ral"' plan_old.json
grep -n '"Relation Name": "ckmlcr_2"'   plan_old.json
grep -n '"Node Type": "Shared Scan".*ckmlcr_ral' plan_new.json


Показать замену LEAD → JOIN по dt_next:

grep -n 'dt_posting' plan_old.json      # было
grep -n 'dt_next'    plan_new.json      # стало


Предагрегация MLCD:

grep -n '"Aggregate".*"mlcd_ral' plan_new.json


Redistribute и ключи:

grep -n '"Node Type": "Redistribute Motion"| "Hash Key"' plan_old.json
grep -n '"Node Type": "Redistribute Motion"| "Hash Key"' plan_new.json


Итоговое время:

grep -n '"Execution Time"' plan_old.json
grep -n '"Execution Time"' plan_new.json


Эти фрагменты ровно соответствуют тем планам, что ты прислал: в старом — огромные WindowAgg/Sort (≈243M строк), ckmlcr_2, dt_posting; в новом — Shared Scan по CKMLCR, dt_next в условиях джойна, ранний Aggregate по MLCD и более лёгкие Redistribute.
