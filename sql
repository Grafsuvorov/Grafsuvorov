select
    r,
    count(*) total,
    count(nullif(ppdat, '00000000')) as ppdat_not_null,
    count(nullif(ppnam, '')) as ppnam_not_null
from (
    select
        row_number() over (
            partition by bukrs, belnr, gjahr, buzei
            order by file_num desc, row_num desc
        ) r,
        ppdat,
        ppnam
    from stg.ral_zbw1595m_odata_srv
    where sap_pointer = '20260128233010_000222000'
) t
group by r
order by r;
