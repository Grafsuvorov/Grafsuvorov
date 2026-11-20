CREATE TEMP TABLE vbss_vbsk_o_dedup AS
SELECT DISTINCT
    delivery_code,
    invoice_code,
    billing_document_code,
    invoice_type_code,
    "LAND1_exp04"
FROM pg_temp.vbss_vbsk_o_prepare
DISTRIBUTED BY (delivery_code);

ANALYZE vbss_vbsk_o_dedup;


Затем в исходном запросе заменить:
LEFT JOIN pg_temp.vbss_vbsk_o_prepare AS d_ldadr2


на:
LEFT JOIN pg_temp.vbss_vbsk_o_dedup AS d_ldadr2


Это хороший первый эксперимент, поскольку одинаковые строки по всем пяти используемым полям не несут дополнительной информации для расчёта двух итоговых атрибутов.

Однако есть нюанс: у тебя ROW_NUMBER() не содержит полного уникального порядка. Поэтому прежде чем считать результаты полностью эквивалентными, нужно убедиться, что строки с одинаковыми значениями сортировки не дают разных итоговых значений.
3. Насколько сильно можно уменьшить объём
Для начала посчитай:
SELECT COUNT(*) AS cnt_before
FROM pg_temp.vbss_vbsk_o_prepare;

SELECT COUNT(*) AS cnt_after
FROM pg_temp.vbss_vbsk_o_dedup;


Если, например, исходных строк 6,8 млн, а после DISTINCT осталось 200 тысяч, это будет очень существенным сокращением.

Но не обязательно в 34 раза уменьшится весь запрос — итог зависит от распределения совпадений по delivery_code.
4. Ещё один важный момент в твоём запросе
В ROW_NUMBER() у тебя сортировка начинается с:
ORDER BY
    d_ir.invoice_realization_group_code,
    d_ldadr2.invoice_code,
    ...


Но d_ir.invoice_realization_group_code для одной фактуры часто будет одинаковым.

А дальше сортировка по invoice_code может выбрать строку с NULL раньше остальных, поскольку в Greenplum/PostgreSQL для ASC по умолчанию NULLS LAST, то есть сначала идут непустые значения, а затем NULL.

Это важно при оптимизации: нельзя просто оставить произвольную строку на каждую поставку. Нужно сохранить исходный порядок выбора.
5. Что делать дальше
Я бы действовал так:
1. Создал vbss_vbsk_o_dedup через DISTINCT.
2. Выполнил ANALYZE.
3. Повторил EXPLAIN исходного запроса с новой таблицей.
4. Сравнил количество строк на этапах JOIN.
5. Сравнил итоговые результаты старого и нового запросов по всем трём выходным столбцам.
Главное: пока не нужно трогать первую таблицу dds.logistics_document_and_delivery_relationship. Отсутствие дублей по паре logistics_document_code + delivery_code говорит, что там, вероятно, нормальная связь «одна группа — много поставок».

А вот в vbss_vbsk_o_prepare повторы по 812 раз — уже конкретный кандидат на оптимизацию.

Пришли мне два числа — cnt_before и cnt_after после DISTINCT. По ним оценим потенциал оптимизации и решим, достаточно ли этого или стоит переписывать весь запрос с ранжированием.
