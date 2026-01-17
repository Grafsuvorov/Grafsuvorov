drop table if exists ods."/rusal/indel_1_ral";

create table ods."/rusal/indel_1_ral" (
	 dataprek date null
	,dataskl date null
	,gtd varchar(30) null
	,start_storage2 date null
	,vbeln varchar(10) null
	,delind varchar null
	,potrebit varchar(10) null
	,contract_p varchar(10) null
	,sammg_p varchar(10) null
	,sammg_y varchar(10) null
	,load_out_date date null
	,loc_name varchar(30) null
	,sammg_i varchar(10) null
	,v_co2wgt numeric (10,5)
	,co2wgt_scope1 numeric
	,co2wgt_scope2 numeric
	,co2wgt_scope3 numeric
	,container_out varchar(20) null
	,num_mh1 varchar(10) null
	,num_mh3 varchar(10) null
	,dttm_inserted timestamp not null default now()
	,dttm_updated timestamp not null default now()
	,job_name varchar(60) not null default 'airflow'::character varying
	,deleted_flag bool not null default false
)
with (
	appendonly = true,
	orientation = column,
	compresstype = zstd,
	compresslevel = 3
)
distributed by (vbeln);


comment on table ods."/rusal/indel_1_ral" is 'Дополнительные данные входящей поставки';
comment on column ods."/rusal/indel_1_ral".dataprek is 'Дата экcпедитора | Дата экcпедитора | /RUSAL/INDEL_1.DATAPREK';
comment on column ods."/rusal/indel_1_ral".dataskl is 'Дата прибытия на склад порта | Дата прибытия на склад порта | /RUSAL/INDEL_1.DATASKL';
comment on column ods."/rusal/indel_1_ral".gtd is 'Номер ГТД | Номер ГТД | /RUSAL/INDEL_1.GTD';
comment on column ods."/rusal/indel_1_ral".start_storage2 is 'Начало хранения склад 2 | Начало хранения склад 2 | /RUSAL/INDEL_1.START_STORAGE2';
comment on column ods."/rusal/indel_1_ral".vbeln is 'Поставка | Поставка | /RUSAL/INDEL_1.VBELN';
comment on column ods."/rusal/indel_1_ral".delind is 'Флаг удаления записи | Флаг удаления записи | /RUSAL/INDEL_1.DELIND';
comment on column ods."/rusal/indel_1_ral".potrebit is 'Потребитель | Потребитель | /RUSAL/INDEL_1.POTREBIT';
comment on column ods."/rusal/indel_1_ral".contract_p is 'Плановый контракт (код) | Плановый контракт (код) | /RUSAL/INDEL_1.CONTRACT_P';
comment on column ods."/rusal/indel_1_ral".sammg_p is 'Группа поручение | Группа поручение | /RUSAL/INDEL_1.SAMMG_P';
comment on column ods."/rusal/indel_1_ral".sammg_y is 'Группа коносамент | Группа коносамент | /RUSAL/INDEL_1.SAMMG_Y';
comment on column ods."/rusal/indel_1_ral".load_out_date is 'Дата загрузки на ТС | Дата загрузки на ТС | /RUSAL/INDEL_1.LOAD_OUT_DATE';
comment on column ods."/rusal/indel_1_ral".loc_name is 'Терминал/Уд.склад название | Терминал/Уд.склад название | /RUSAL/INDEL_1.LOC_NAME';
comment on column ods."/rusal/indel_1_ral".sammg_i is 'Группа коносамент в иностранном порту | Группа коносамент в иностранном порту | /RUSAL/INDEL_1.SAMMG_I';
comment on column ods."/rusal/indel_1_ral".v_co2wgt is 'Объем выброса СО2, тСО2 экв. | Объем выброса СО2, тСО2 экв. | /RUSAL/INDEL_1.V_CO2WGT';
comment on column ods."/rusal/indel_1_ral".co2wgt_scope1 is 'Уд. объем выброса СО2 Scope1, тСО2 экв. | Уд. объем выброса СО2 Scope1, тСО2 экв | /RUSAL/INDEL_1.co2wgt_scope1';
comment on column ods."/rusal/indel_1_ral".co2wgt_scope2 is 'Уд. объем выброса СО2 Scope2, тСО2 экв. | Уд. объем выброса СО2 Scope3, тСО2 экв | /RUSAL/INDEL_1.co2wgt_scope2';
comment on column ods."/rusal/indel_1_ral".co2wgt_scope3 is 'Уд. объем выброса СО2 Scope3, тСО2 экв. | Уд. объем выброса СО2 Scope3, тСО2 экв | /RUSAL/INDEL_1.co2wgt_scope3';
comment on column ods."/rusal/indel_1_ral".container_out is 'Контейнер (исходящий) | Контейнер (исходящий) | /RUSAL/INDEL_1.CONTAINER_OUT';
comment on column ods."/rusal/indel_1_ral".num_mh1 is 'Номер акта МХ-1 | Номер акта МХ-1 | /RUSAL/INDEL_1.NUM_MH1';
comment on column ods."/rusal/indel_1_ral".num_mh3 is 'Номер акта МХ-3 | Номер акта МХ-3 | /RUSAL/INDEL_1.NUM_MH3';