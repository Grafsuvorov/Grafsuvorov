drop table if exists dm_calc.accounting_counterparty;

create table dm_calc.accounting_counterparty (
	counterparty_code varchar(10) null,
	counterparty_full_name varchar(300) null,
	counterparty_tin_code varchar(16) null,
	address_full_name text null,
	counterparty_mdm_code varchar(10) null,
	counterparty_hfm_code varchar(30) null,
	country_code varchar(3) null,
	counterparty_tin_nonresident_code varchar(20) null,
	counterparty_short_name varchar(35) null,
	counterparty_extended_name varchar(300) null,
	address_code varchar(10) null,
	international_display_format_code varchar(1) null,
	postal_code varchar(10) null,
	street_name varchar(60) null,
	house_number varchar(10) null,
	city_name varchar(40) null,
	region_code varchar(3) null,
	is_related_party_tco bpchar(1) null,
	is_group_company_affiliated bpchar(1) null,
	is_related_party_rsbo bpchar(1) null,
	is_bankrupt bpchar(1) null,
	is_lawsuit_exist bpchar(1) null,
	is_fns_restriction_list_exist bpchar(1) null,
	counterparty_truncated_code varchar(10) null,
    counterparty_search_name varchar(150) null,
	is_deleted bpchar(1) null,
	dttm_inserted 		timestamp not null default now(),
	dttm_updated 		timestamp not null default now(),
	job_name 			varchar(60) not null default 'airflow'::character varying,
	deleted_flag		bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=1
)
distributed replicated;


comment on table dm_calc.accounting_counterparty is 'Бухгалтерия, Справочник контрагентов';
comment on column dm_calc.accounting_counterparty.counterparty_code is 'Номер счета поставщика или кредитора (код) | Номер счета поставщика или кредитора (код) | counterparty.counterparty_code';
comment on column dm_calc.accounting_counterparty.counterparty_short_name is 'Краткое наименование | Краткое наименование | counterparty.counterparty_short_name';
comment on column dm_calc.accounting_counterparty.counterparty_full_name is 'Полное наименование | Полное наименование | counterparty.counterparty_full_name';
comment on column dm_calc.accounting_counterparty.counterparty_extended_name is 'Расширенное наименование | Расширенное наименование | counterparty.counterparty_extended_name';
comment on column dm_calc.accounting_counterparty.is_deleted is 'Центральная метка удаления основной записи | Центральная метка удаления основной записи | counterparty.is_deleted';
comment on column dm_calc.accounting_counterparty.counterparty_tin_code is 'Идентификационный налоговый номер РФ (код) | Идентификационный налоговый номер РФ (код) | counterparty.counterparty_tin_code';
comment on column dm_calc.accounting_counterparty.counterparty_tin_nonresident_code is 'Идентификационный налоговый номер не РФ (код) | Идентификационный налоговый номер не РФ (код) | counterparty.counterparty_tin_nonresident_code';
comment on column dm_calc.accounting_counterparty.counterparty_mdm_code is 'Контрагент в MDM (код) | Контрагент в MDM (код) | counterparty.counterparty_mdm_code';
comment on column dm_calc.accounting_counterparty.counterparty_hfm_code is 'Краткое наименование | Краткое наименование | counterparty.counterparty_hfm_code';
comment on column dm_calc.accounting_counterparty.international_display_format_code is 'Идентификатор версии для международных адресов | Идентификатор версии для международных адресов | address.international_display_format_code';
comment on column dm_calc.accounting_counterparty.postal_code is 'Почтовый индекс города | Почтовый индекс города | address.postal_code';
comment on column dm_calc.accounting_counterparty.street_name is 'Улица | Улица | address.street_name';
comment on column dm_calc.accounting_counterparty.house_number is 'Номер дома | Номер дома | address.house_number';
comment on column dm_calc.accounting_counterparty.country_code is 'Код страны | Код страны | address.country_code';
comment on column dm_calc.accounting_counterparty.city_name is 'Город | Город | address.city_name';
comment on column dm_calc.accounting_counterparty.region_code is 'Регион (штат, федер. земля, провинция, область, графство) | Регион (штат, федер. земля, провинция, область, графство) | address.region_code';
comment on column dm_calc.accounting_counterparty.address_full_name is 'Полный адрес в формате для витрин FI (индекс, город, улица, номер дома) | Полный адрес в формате для витрин FI (индекс, город, улица, номер дома) | address.postal_code||city_name||street_name||house_number';
comment on column dm_calc.accounting_counterparty.is_related_party_tco is 'Связанность по ТЦО | Связанность по ТЦО | counterparty.is_related_party_tco';
comment on column dm_calc.accounting_counterparty.is_group_company_affiliated is 'Входит в ОК | Входит в ОК | counterparty.is_group_company_affiliated';
comment on column dm_calc.accounting_counterparty.is_related_party_rsbo is 'Связанность по РСБО | Связанность по РСБО | counterparty.is_related_party_rsbo';
comment on column dm_calc.accounting_counterparty.is_bankrupt is 'Статус контрагента по банкротству | Статус контрагента по банкротству | counterparty.is_bankrupt';
comment on column dm_calc.accounting_counterparty.is_lawsuit_exist is 'Наличие у контрагента судебных исков | Наличие у контрагента судебных исков | counterparty.is_lawsuit_exist';
comment on column dm_calc.accounting_counterparty.is_fns_restriction_list_exist is 'Контрагент входит в негативные списки ФНС | Контрагент входит в негативные списки ФНС | counterparty.is_fns_restriction_list_exist';
comment on column dm_calc.accounting_counterparty.counterparty_truncated_code is 'Контрагент (код, без лидирующих нулей) | Контрагент (код, без лидирующих нулей) | counterparty.counterparty_code';
comment on column dm_calc.accounting_counterparty.counterparty_search_name is 'Название контрагента (для поиска) | Название контрагента (для поиска) |counterparty.counterparty_code dm_calc.accounting_counterparty.counterparty_full_name';
	