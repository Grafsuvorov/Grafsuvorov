insert into ods.zsd7536m_pret_ral
select
    tech_etl.util_text_to_null_validation("VBELN") as vbeln,
	tech_etl.util_text_to_null_validation("SAMMG") as sammg
from stg."ZSD7536M_PRET"
where "MANDT" = '400';