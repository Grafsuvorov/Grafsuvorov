drop table if exists ods."/rusal/perp_ral";

create table ods."/rusal/perp_ral" (
	werks varchar(4) null,
	id varchar(10) null,
	pos varchar(5) null,
	srvpos varchar(18) null,
	nomd varchar(35) null,
	sums numeric(13, 2) null,
	nds numeric(13, 2) null,
	waers varchar(5) null,
	akt_id varchar(10) null,
	fistl varchar(16) null,
	etsng varchar(6) null,
	ebelny varchar(10) null,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
)
with (
 	appendonly=true,
 	orientation=column,
 	compresstype=zstd,
 	compresslevel=3
)
distributed by (werks, id);

comment on table ods."/rusal/perp_ral" is 'Перечни ж/д документов (позиции)';
comment on column ods."/rusal/perp_ral".werks is 'Завод | Завод | STG./RUSAL/PERP.WERKS';
comment on column ods."/rusal/perp_ral".id is 'ID документа | ID документа | STG./RUSAL/PERP.ID';
comment on column ods."/rusal/perp_ral".pos is 'Позиция документа | Позиция документа | STG./RUSAL/PERP.POS';
comment on column ods."/rusal/perp_ral".srvpos is '№ Услуги | № Услуги | STG./RUSAL/PERP.SRVPOS';
comment on column ods."/rusal/perp_ral".nomd is 'Номер документа из строки документа | Номер документа из строки документа | STG./RUSAL/PERP.NOMD';
comment on column ods."/rusal/perp_ral".sums is 'Сумма из строки документа без НДС | Сумма из строки документа без НДС | STG./RUSAL/PERP.SUMS';
comment on column ods."/rusal/perp_ral".nds is 'Сумма НДС из строки документа | Сумма НДС из строки документа | STG./RUSAL/PERP.NDS';
comment on column ods."/rusal/perp_ral".waers is 'Код валюты | Код валюты | STG./RUSAL/PERP.WAERS';
comment on column ods."/rusal/perp_ral".akt_id is 'ID документа корректировки | ID документа корректировки | STG./RUSAL/PERP.AKT_ID';
comment on column ods."/rusal/perp_ral".fistl is 'Подразделение финансового менеджмента | Подразделение финансового менеджмента | STG./RUSAL/PERP.FISTL';
comment on column ods."/rusal/perp_ral".etsng is 'Код ЕТ СНГ | Код ЕТ СНГ | STG./RUSAL/PERP.ETSNG';
comment on column ods."/rusal/perp_ral".ebelny is 'Номер договора перевозчика | Номер договора перевозчика | STG./RUSAL/PERP.EBELNY';
