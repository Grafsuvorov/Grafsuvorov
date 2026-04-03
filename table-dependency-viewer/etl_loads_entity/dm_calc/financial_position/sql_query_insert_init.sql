insert into dm_calc.financial_position
select
	fp.financial_management_area_code,
	mfp.financial_position_external_code,
	fp.financial_position_full_name,
	mfp.financial_position_internal_code,
	fp.financial_position_short_name,
	fp.fiscal_year::numeric,
	fp.language_code
from
	dict_dds.map_financial_position mfp
left join dict_dds.financial_position_master_data_texts fp on
	fp.financial_position_external_code = mfp.financial_position_external_code