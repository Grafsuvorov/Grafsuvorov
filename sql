with base as (
  select
    xiin.document_xml,
    (xpath('Data/MdmId/text()', xiin.document_xml))[1]::varchar as mdmid,
    (xpath('Data/RopId/text()', xiin.document_xml))[1]::varchar as ropid,
    (xpath('Data/Inn/text()', xiin.document_xml))[1]::varchar as inn,
    (xpath('Data/Okpo/text()', xiin.document_xml))[1]::varchar as okpo,
    (xpath('Data/Ogrn/text()', xiin.document_xml))[1]::varchar as ogrn,
    (xpath('Data/CreatedAt/text()', xiin.document_xml))[1]::varchar::timestamp as createdat,
    (xpath('Data/Id/text()', xiin.document_xml))[1]::varchar as id,
    xiin.uuid,
    xiin.dt_insert
  from landing."INPUT_DATA_FROM_SAPXI_IN" xiin
  left join dict_stg.sok_counterparty_parameters prm
    on xiin.uuid = prm.uuid
  where xiin.source_system = 'BSP_SOK'
    and prm.job_name is null
)
select
  b.mdmid,
  b.ropid,
  b.inn,
  b.okpo,
  b.ogrn,
  (xpath('Code/text()', p))[1]::varchar as code,
  (xpath('SubCode/text()', p))[1]::varchar as subcode,
  (xpath('SubSubCode/text()', p))[1]::varchar as subsubcode,
  b.createdat,
  (xpath('Value/text()', p))[1]::varchar as value,
  b.id,
  b.uuid,
  b.dt_insert
from base b
cross join lateral unnest(xpath('Data/Params', b.document_xml)) as p;
