drop table if exists ods."/rusal/perp_ral";

create table if not exists ods."/rusal/perp_ral" (
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
	doc_type varchar(1) null,
	check_tarif varchar(1) null,
	statuss varchar(4) null,
	aufnr varchar(12) null,
	belnr varchar(10) null,
	charg varchar(10) null,
	check_off varchar(1) null,
	check_off_dub varchar(1) null,
	hkont varchar(10) null,
	hranenie_from date null,
	hranenie_to date null,
	fi_112 varchar(1) null,
	fi_137 varchar(1) null,
	kostl varchar(10) null,
	kunnr varchar(10) null,
	matnr varchar(18) null,
	request varchar(10) null,
	vatcl varchar(1) null,
	kontyp varchar(2) null,
	manual_aufnr varchar(1) null,
	manual_hkont varchar(1) null,
	manual_kontyp varchar(1) null,
	manual_kostl varchar(1) null,
	manual_kunnr varchar(1) null,
	manual_mwskz varchar(1) null,
	manual_pspnr varchar(1) null,
	manual_vatcl varchar(1) null,
	pspnr varchar(8) null,
	fipos_manual varchar(1) null,
	fistl_manual varchar(1) null,
	bwtar varchar(10) null,
	route varchar(6) null,
	mwskz varchar(2) null,
	kor varchar(1) null,
	nds_nvv varchar(1) null,
	type_prod varchar(1) null,
	check_off_limit varchar(1) null,
	ebelnz varchar(10) null,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
) with (appendonly=true, orientation=column, compresstype=zstd, compresslevel=3)
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
comment on column ods."/rusal/perp_ral".doc_type is 'Тип документа | Тип документа | STG./RUSAL/PERP.DOC_TYPE';
comment on column ods."/rusal/perp_ral".check_tarif is 'Контроль сумм в акте и в позиции доп.соглашения на перевозк | Контроль сумм в акте и в позиции доп.соглашения на перевозк | STG./RUSAL/PERP.CHECK_TARIF';
comment on column ods."/rusal/perp_ral".statuss is 'Статус сверки | Статус сверки | STG./RUSAL/PERP.STATUSS';
comment on column ods."/rusal/perp_ral".aufnr is 'Номер заказа | Номер заказа | STG./RUSAL/PERP.AUFNR';
comment on column ods."/rusal/perp_ral".belnr is 'Номер бухгалтерского документа | Номер бухгалтерского документа | STG./RUSAL/PERP.BELNR';
comment on column ods."/rusal/perp_ral".charg is 'Номер партии | Номер партии | STG./RUSAL/PERP.CHARG';
comment on column ods."/rusal/perp_ral".check_off is 'Сверка отлючена | Сверка отлючена | STG./RUSAL/PERP.CHECK_OFF';
comment on column ods."/rusal/perp_ral".check_off_dub is 'Проверка на дубли отлючена | Проверка на дубли отлючена | STG./RUSAL/PERP.CHECK_OFF_DUB';
comment on column ods."/rusal/perp_ral".hkont is 'Основной счет главной бухгалтерии | Основной счет главной бухгалтерии | STG./RUSAL/PERP.HKONT';
comment on column ods."/rusal/perp_ral".hranenie_from is 'Период с | Период с | STG./RUSAL/PERP.HRANENIE_FROM';
comment on column ods."/rusal/perp_ral".hranenie_to is 'Период по | Период по | STG./RUSAL/PERP.HRANENIE_TO';
comment on column ods."/rusal/perp_ral".fi_112 is 'Существует ДокПозДокумента | Существует ДокПозДокумента | STG./RUSAL/PERP.FI_112';
comment on column ods."/rusal/perp_ral".fi_137 is 'Существует ДокЗакрытия | Существует ДокЗакрытия | STG./RUSAL/PERP.FI_137';
comment on column ods."/rusal/perp_ral".kostl is 'Место возникновения затрат | Место возникновения затрат | STG./RUSAL/PERP.KOSTL';
comment on column ods."/rusal/perp_ral".kunnr is 'Клиент | Клиент | STG./RUSAL/PERP.KUNNR';
comment on column ods."/rusal/perp_ral".matnr is 'Номер материала | Номер материала | STG./RUSAL/PERP.MATNR';
comment on column ods."/rusal/perp_ral".request is '№Заявки сервис-деск | №Заявки сервис-деск | STG./RUSAL/PERP.REQUEST';
comment on column ods."/rusal/perp_ral".vatcl is 'Налоговая классификация | Налоговая классификация | STG./RUSAL/PERP.VATCL';
comment on column ods."/rusal/perp_ral".kontyp is 'Тип контировки | Тип контировки | STG./RUSAL/PERP.KONTYP';
comment on column ods."/rusal/perp_ral".manual_aufnr is 'Ручной ввод: Контировка заказ | Ручной ввод: Контировка заказ | STG./RUSAL/PERP.MANUAL_AUFNR';
comment on column ods."/rusal/perp_ral".manual_hkont is 'Ручной ввод: Счет ГК | Ручной ввод: Счет ГК | STG./RUSAL/PERP.MANUAL_HKONT';
comment on column ods."/rusal/perp_ral".manual_kontyp is 'Ручной ввод: Тип контировки | Ручной ввод: Тип контировки | STG./RUSAL/PERP.MANUAL_KONTYP';
comment on column ods."/rusal/perp_ral".manual_kostl is 'Ручной ввод: Контировка МВЗ | Ручной ввод: Контировка МВЗ | STG./RUSAL/PERP.MANUAL_KOSTL';
comment on column ods."/rusal/perp_ral".manual_kunnr is 'Ручной ввод: Клиент | Ручной ввод: Клиент | STG./RUSAL/PERP.MANUAL_KUNNR';
comment on column ods."/rusal/perp_ral".manual_mwskz is 'Ручной ввод: Код налога | Ручной ввод: Код налога | STG./RUSAL/PERP.MANUAL_MWSKZ';
comment on column ods."/rusal/perp_ral".manual_pspnr is 'Ручной ввод: Контировка СПП | Ручной ввод: Контировка СПП | STG./RUSAL/PERP.MANUAL_PSPNR';
comment on column ods."/rusal/perp_ral".manual_vatcl is 'Ручной ввод: Налоговая классификация | Ручной ввод: Налоговая классификация | STG./RUSAL/PERP.MANUAL_VATCL';
comment on column ods."/rusal/perp_ral".pspnr is 'СПП-элемент оцененного запаса для заказа клиента | СПП-элемент оцененного запаса для заказа клиента | STG./RUSAL/PERP.PSPNR';
comment on column ods."/rusal/perp_ral".fipos_manual is 'Ручной ввод Фин. позиции | Ручной ввод Фин. позиции | STG./RUSAL/PERP.FIPOS_MANUAL';
comment on column ods."/rusal/perp_ral".fistl_manual is 'Ручной ввод ПФМ | Ручной ввод ПФМ | STG./RUSAL/PERP.FISTL_MANUAL';
comment on column ods."/rusal/perp_ral".bwtar is 'Вид оценки | Вид оценки | STG./RUSAL/PERP.BWTAR';
comment on column ods."/rusal/perp_ral".route is 'Маршрут | Маршрут | STG./RUSAL/PERP.ROUTE';
comment on column ods."/rusal/perp_ral".mwskz is 'Код налога с оборота | Код налога с оборота | STG./RUSAL/PERP.MWSKZ';
comment on column ods."/rusal/perp_ral".kor is 'Вид корректировки | Вид корректировки | STG./RUSAL/PERP.KOR';
comment on column ods."/rusal/perp_ral".nds_nvv is 'Невозмещаемый НДС | Невозмещаемый НДС | STG./RUSAL/PERP.NDS_NVV';
comment on column ods."/rusal/perp_ral".type_prod is 'Схема реализации | Схема реализации | STG./RUSAL/PERP.TYPE_PROD';
comment on column ods."/rusal/perp_ral".check_off_limit is 'Проверка на лимиты отключена | Проверка на лимиты отключена | STG./RUSAL/PERP.CHECK_OFF_LIMIT';
comment on column ods."/rusal/perp_ral".ebelnz is 'Номер Договора Поставщика Агента | Номер Договора Поставщика Агента | STG./RUSAL/PERP.EBELNZ';
