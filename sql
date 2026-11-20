-- 1. Выборка: 6000 кодов с группой + 2000 без группы
drop table if exists t_sample;
create temp table t_sample as
select invoice_realization_code from (
    select invoice_realization_code from t_vbrk
    where invoice_realization_group_code is not null
    order by invoice_realization_code limit 6000
) a
union all
select invoice_realization_code from (
    select invoice_realization_code from t_vbrk
    where invoice_realization_group_code is null
    order by invoice_realization_code limit 2000
) b
distributed by (invoice_realization_code);

-- 2. Оригинальный запрос, ограниченный выборкой.
--    Скопируйте ваш исходный запрос (без explain) и поменяйте ТОЛЬКО одну строку:
--    было:   from pg_temp.vbrk as d_ir
--    стало:  from (select * from pg_temp.vbrk
--                  where invoice_realization_code in (select invoice_realization_code from t_sample)) as d_ir
--    Результат сохраните:
drop table if exists t_orig;
create temp table t_orig as
-- <ваш запрос целиком с изменённым from>
;

-- 3. Сравнение
select 'only_orig' as src, * from (
    select * from t_orig
    except
    select * from t_result where invoice_realization_code in (select invoice_realization_code from t_sample)
) a
union all
select 'only_new', * from (
    select * from t_result where invoice_realization_code in (select invoice_realization_code from t_sample)
    except
    select * from t_orig
) b;

Что может показать сравнение:

Пусто — результат совпал на выборке, можно считать замену корректной.
Расхождения только по sales_bank_account_code — вероятно, у оригинала при равных ключах сортировки порядок не был однозначным (я для этого добавил bank_as_counterparty_code и customer_code в ORDER BY). Выберите один расходящийся код и посмотрите все его строки в промежуточных таблицах, чтобы убедиться, что это именно ничья.
Расхождения по country_of_destination_code — это уже потеря логики, пришлите несколько примеров, разберём.
Ещё одна проверка по логике оригинала

Раньше я отметил, что для строк без группы ветка vgtyp = 'U' → vgbel в оригинале не срабатывает, потому что условие invoice_type_code = 'О' в ON для них всегда ложно. Я сохранил это поведение. Узнайте, касается ли это реальных данных:

sql
select count(*) as rows_with_vgtyp_u
from pg_temp.vbrk
where posting_status_code in ('C','E')
  and invoice_realization_group_code is null
  and vgtyp = 'U';

Если там ноль или мало, вопрос снят. Если много, то для этих строк sales_bank_account_code сейчас всегда NULL. Решите, так ли задумано, или в оригинале баг, который стоит исправить.

Как перенести в боевой запуск

Временные таблицы живут до конца сессии, поэтому в ETL эти шаги должны идти подряд в одной сессии, а финальная вставка выглядит так: insert into <целевая> select * from t_result. Если запрос раньше был вьюхой или CTE внутри другого запроса, пришлите, как он используется, подскажу, как встроить.
