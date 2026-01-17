insert into dm_calc.plant_by_unit_balance (
		unit_balance_code,
		plant_code,
		plant_name,
		plant_full_name,
		plant_count
)
select
	p.unit_balance_code, 
	p.plant_code, 
	p.plant_short_name as plant_name,
	p.plant_full_name,
	sum(1) over (partition by p.unit_balance_code) as plant_count
from dict_dds.plant_and_subsidiary as p
where p.unit_balance_code is not null;
