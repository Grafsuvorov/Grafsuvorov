insert into dm_calc.accounting_counterparty
(
	counterparty_code,
	counterparty_full_name,
	counterparty_tin_code,
	address_full_name,
	counterparty_mdm_code,
	counterparty_hfm_code,
	country_code,
	counterparty_tin_nonresident_code,
	counterparty_short_name,
	counterparty_extended_name,
	address_code,
	international_display_format_code,
	postal_code,
	street_name,
	house_number,
	city_name,
	region_code,
	is_related_party_tco,
	is_group_company_affiliated,
	is_related_party_rsbo,
	is_bankrupt,
	is_lawsuit_exist,
	is_fns_restriction_list_exist,
	counterparty_truncated_code,
    counterparty_search_name,
	is_deleted
)
select 
c.counterparty_code,
c.counterparty_full_name,
c.counterparty_tin_code,
case when a.postal_code is null then '' else postal_code || ', ' end ||  
case when a.city_name is null then '' else city_name || ', ' end ||  
case when a.street_name is null then '' else street_name || ', ' end ||  
case when a.house_number is null then '' else house_number end as address_full_name, -- в витрине FI counterparty_address_name,
c.counterparty_mdm_code,
c.counterparty_hfm_code,
a.country_code,
c.counterparty_tin_nonresident_code,
c.counterparty_short_name,
c.counterparty_extended_name,
c.address_code,
a.international_display_format_code,
a.postal_code,
a.street_name,
a.house_number,
a.city_name,
a.region_code,
c.is_related_party_tco,
c.is_group_company_affiliated,
c.is_related_party_rsbo,
c.is_bankrupt ,
c.is_lawsuit_exist,
c.is_fns_restriction_list_exist,
c.counterparty_truncated_code,
c.counterparty_search_name,
c.is_deleted
from dict_dds.counterparty c
left join dict_dds.address a on 
	a.address_code = c.address_code 
	and a.international_display_format_code is null 
	and a.deleted_flag = false
where 1=1;
