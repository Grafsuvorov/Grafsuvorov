with params as (
    select
        (xpath('Data/MdmId/text()', document_xml))[1]::varchar as mdmid,
            (xpath('Data/RopId/text()', document_xml))[1]::varchar as ropid,
            (xpath('Data/Inn/text()', document_xml))[1]::varchar as inn,
            (xpath('Data/Okpo/text()', document_xml))[1]::varchar as okpo,
            (xpath('Data/Ogrn/text()', document_xml))[1]::varchar as ogrn,
            (xpath('Data/CreatedAt/text()', document_xml))[1]::varchar::timestamp as createdat,
            (xpath('Data/Id/text()', document_xml))[1]::varchar as id,
            uuid,
        dt_insert,
        unnest(xpath('Data/Params', document_xml)) as xml_params
    from landing."INPUT_DATA_FROM_SAPXI_IN"
    where source_system = 'BSP_SOK'
      and uuid not in (select uuid from dict_stg.sok_counterparty_parameters)
)
select
    mdmid,
    ropid,
    inn,
    okpo,
    ogrn,
    (xpath('Code/text()', xml_params))[1]::varchar as code,
    (xpath('SubCode/text()', xml_params))[1]::varchar as subcode,
    (xpath('SubSubCode/text()', xml_params))[1]::varchar as subsubcode,
    createdat,
    (xpath('Value/text()', xml_params))[1]::varchar as value,
    id,
    uuid,
    dt_insert
from params;

исправленная
select
    (xpath('Data/MdmId/text()', xiin.document_xml))[1]::varchar as mdmid,
    (xpath('Data/RopId/text()', xiin.document_xml))[1]::varchar as ropid,
    (xpath('Data/Inn/text()', xiin.document_xml))[1]::varchar as inn,
    (xpath('Data/Okpo/text()', xiin.document_xml))[1]::varchar as okpo,
    (xpath('Data/Ogrn/text()', xiin.document_xml))[1]::varchar as ogrn,
    (xpath('Code/text()', xml_params))[1]::varchar as code,
    (xpath('SubCode/text()', xml_params))[1]::varchar as subcode,
    (xpath('SubSubCode/text()', xml_params))[1]::varchar as subsubcode,
    (xpath('Data/CreatedAt/text()', xiin.document_xml))[1]::varchar::timestamp as createdat,
    (xpath('Value/text()', xml_params))[1]::varchar as value,
    (xpath('Data/Id/text()', xiin.document_xml))[1]::varchar as id,
    xiin.uuid,
    xiin.dt_insert 
from landing."INPUT_DATA_FROM_SAPXI_IN" xiin
cross join lateral unnest(xpath('Data/Params', document_xml)) as xml_params
left join dict_stg.sok_counterparty_parameters prm
	on xiin.uuid = prm.uuid
where  source_system = 'BSP_SOK' and prm.job_name is null
