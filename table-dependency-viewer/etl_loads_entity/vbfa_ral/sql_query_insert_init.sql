insert into ods.vbfa_ral 
select
l."VBELV" as vbelv,													-- Предыдущий документ сбыта
l."POSNV" as posnv,													-- Предыдущая позиция документа сбыта
l."VBELN" as vbeln,													-- Следующий документ сбыта
l."POSNN" as posnn,													-- Следующая позиция документа сбыта
tech_etl.util_text_to_null_validation(l."VBTYP_N") as vbtyp_n,		-- Следующий тип документа сбыта
tech_etl.util_text_to_null_validation(l."VBTYP_V") as vbtyp_v	
from stg."VBFA" as l 
where 1=1
and case when l."AEDAT"='00000000' then l."ERDAT" else l."AEDAT" end  >='20220101'  -- Инкремент обновления, по дате. После инициирующей, обновлять на согласованную глубину
;