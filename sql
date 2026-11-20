SELECT
    d_ir.invoice_realization_code,
    COUNT(*) AS cnt
FROM pg_temp.vbrk d_ir
LEFT JOIN dds.logistics_document_and_delivery_relationship d_ldadr
    ON d_ldadr.logistics_document_code =
       d_ir.invoice_realization_group_code
LEFT JOIN pg_temp.vbss_vbsk_o_prepare d_ldadr2
    ON d_ldadr2.delivery_code =
       d_ldadr.delivery_code
WHERE d_ir.posting_status_code IN ('C', 'E')
GROUP BY 1
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;


Этот запрос покажет, сколько строк возникает для одной фактуры после первых двух JOIN. Он тоже может быть тяжёлым, поэтому лучше запускать его на тестовом окружении, если ресурсы ограничены.
3. Проверим, нет ли полностью одинаковых строк
Для первой таблицы:
SELECT
    logistics_document_code,
    delivery_code,
    COUNT(*) AS cnt
FROM dds.logistics_document_and_delivery_relationship
GROUP BY 1, 2
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;


Для второй:
SELECT
    delivery_code,
    invoice_code,
    billing_document_code,
    invoice_type_code,
    "LAND1_exp04",
    COUNT(*) AS cnt
FROM pg_temp.vbss_vbsk_o_prepare
GROUP BY 1, 2, 3, 4, 5
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;


Здесь мы проверяем повторения по полям, используемым в твоём запросе. Это не обязательно полные дубли исходных записей.

Если найдём полностью эквивалентные строки, можно рассмотреть их удаление до JOIN через DISTINCT, но сначала нужно проверить, что дополнительные поля не влияют на результат.
4. Почему нельзя просто поставить DISTINCT
У тебя есть бизнес-логика:
ROW_NUMBER() OVER (
    PARTITION BY d_ir.invoice_realization_code
    ORDER BY
        d_ir.invoice_realization_group_code,
        d_ldadr2.invoice_code,
        d_ir.counterparty_country_code,
        d_ldadr2."LAND1_exp04",
        d_i2.billing_document_code,
        d_sch.sales_partner_role_code
)


То есть из нескольких строк выбирается первая по определённому приоритету.

Если мы заранее удалим разные строки, которые считаем дублями только из-за одинакового ключа, можем случайно изменить конечные значения:
- country_of_destination_code
- sales_bank_account_code
Поэтому оптимизация должна сохранить порядок выбора.
Что предлагаю дальше
Мне важно понять, какого типа дубли у тебя в двух таблицах.

Например, в dds.logistics_document_and_delivery_relationship:
logistics_document_code	delivery_code
100	200
100	201
100	202

Это нормальная связь «одна группа — несколько поставок».

А вот такой вариант:
logistics_document_code	delivery_code
100	200
100	200
100	200

Уже похож на повторяющиеся связи.

У тебя первый вариант (разные delivery_code для одной группы) или второй (одинаковые delivery_code)?

От этого зависит, можно ли безопасно сократить данные до JOIN или нужно оптимизировать сам способ выбора первой строки.










  
































Уровень усилий рассужденияInstant
