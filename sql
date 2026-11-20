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

1601212119	69266
1601275818	65953
1601352873	63973
1601211694	55770
1601211681	55024
1601210902	54948
1601244676	54570
1601147691	54520
1601218065	51606
1601210040	50102
1601307395	48591
1601216215	47214
1601208094	45974
1601351214	44156
1601210038	43898
1601349862	43095
1601348943	42988
1601211704	42525
1601209231	40984
1601351985	39990


SELECT
    logistics_document_code,
    delivery_code,
    COUNT(*) AS cnt
FROM dds.logistics_document_and_delivery_relationship
GROUP BY 1, 2
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;

дублей нет


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

0108767490				CN	812
0108767502				CN	812
0108767495				CN	812
0108767505				CN	812
0108767501				CN	812
0108767513				CN	812
0108767497				CN	812
0108767488				CN	812
0108767509				CN	812
0108767504				CN	812
0108767510				CN	812
0108767491				CN	812
0108767496				CN	812
0108767511				CN	812
0108767507				CN	812
0108767499				CN	812
0108767494				CN	812
0108767506				CN	812
0108767508				CN	812
0108767512				CN	812
