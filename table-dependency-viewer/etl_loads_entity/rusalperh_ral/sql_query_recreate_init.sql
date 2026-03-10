drop table if exists ods."/rusal/perh_ral";

create table if not exists ods."/rusal/perh_ral" (
	werks varchar(4) null,
	id varchar(10) null,
	noms varchar(15) null,
	nomp varchar(40) null,
	bedat date null,
	status_doc varchar(2) null,
	lifnr varchar(10) null,
	zlifnr varchar(10) null,
	lifnr_pr varchar(10) null,
	lifnr_pr1 varchar(10) null,
	comments varchar(200) null,
	duedat date null,
	ernam varchar(12) null,
	erdat date null,
	erzet time null,
	aenam varchar(12) null,
	aedat date null,
	aezet time null,
	type2 varchar(2) null,
	waers varchar(5) null,
	tap_sum numeric(13, 2) null,
	odo_user varchar(12) null,
	odo_dfk_user varchar(12) null,
	odo_date date null,
	accept varchar(1) null,
	accept_name varchar(12) null,
	accept_date date null,
	budat date null,
	duedatm varchar(1) null,
	kor_akt varchar(1) null,
	state varchar(4) null,
	status_sver varchar(4) null,
	status_sogl varchar(4) null,
	status_uved varchar(1) null,
	status_back_off varchar(1) null,
	sverka_pass_date date null,
	aldor varchar(1) null,
	blok_user varchar(12) null,
	blok_date date null,
	rereg varchar(1) null,
	respon varchar(12) null,
	nofact2 varchar(1) null,
	recdt date null,
	invtp varchar(1) null,
	edit_ztap varchar(1) null,
	sogl_usnam varchar(12) null,
	sogl_date date null,
	uved_ernam varchar(12) null,
	uved_erdat date null,
	rcu_uname varchar(12) null,
	rcu_date date null,
	rcu_time time null,
	vehicle varchar(10) null,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
) with (appendonly=true, orientation=column, compresstype=zstd, compresslevel=3)
distributed by (werks, id);

comment on table ods."/rusal/perh_ral" is 'Перечни ж/д документов (заголовок)';
comment on column ods."/rusal/perh_ral".werks is 'Завод | Завод | STG./RUSAL/PERH.WERKS';
comment on column ods."/rusal/perh_ral".id is 'ID документа | ID документа | STG./RUSAL/PERH.ID';
comment on column ods."/rusal/perh_ral".noms is '№ ЛС | № ЛС | STG./RUSAL/PERH.NOMS';
comment on column ods."/rusal/perh_ral".nomp is 'Номер документа | Номер документа | STG./RUSAL/PERH.NOMP';
comment on column ods."/rusal/perh_ral".bedat is 'Дата документа | Дата документа | STG./RUSAL/PERH.BEDAT';
comment on column ods."/rusal/perh_ral".status_doc is 'Препятствие оплаты | Препятствие оплаты | STG./RUSAL/PERH.STATUS_DOC';
comment on column ods."/rusal/perh_ral".lifnr is 'Номер счета поставщика или кредитора | Номер счета поставщика или кредитора | STG./RUSAL/PERH.LIFNR';
comment on column ods."/rusal/perh_ral".zlifnr is 'Кредитор Агента | Кредитор Агента | STG./RUSAL/PERH.ZLIFNR';
comment on column ods."/rusal/perh_ral".lifnr_pr is 'Перевозчик | Перевозчик | STG./RUSAL/PERH.LIFNR_PR';
comment on column ods."/rusal/perh_ral".lifnr_pr1 is 'Продавец | Продавец | STG./RUSAL/PERH.LIFNR_PR1';
comment on column ods."/rusal/perh_ral".comments is 'Комментарий | Комментарий | STG./RUSAL/PERH.COMMENTS';
comment on column ods."/rusal/perh_ral".duedat is 'Дата оплаты | Дата оплаты | STG./RUSAL/PERH.DUEDAT';
comment on column ods."/rusal/perh_ral".ernam is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | STG./RUSAL/PERH.ERNAM';
comment on column ods."/rusal/perh_ral".erdat is 'Дата создания записи | Дата создания записи | STG./RUSAL/PERH.ERDAT';
comment on column ods."/rusal/perh_ral".erzet is 'Время ввода | Время ввода | STG./RUSAL/PERH.ERZET';
comment on column ods."/rusal/perh_ral".aenam is 'Имя исполнителя, изменившего объект | Имя исполнителя, изменившего объект | STG./RUSAL/PERH.AENAM';
comment on column ods."/rusal/perh_ral".aedat is 'Дата последнего изменения | Время последнего изменения | STG./RUSAL/PERH.AEDAT';
comment on column ods."/rusal/perh_ral".aezet is 'Время последнего изменения | Время последнего изменения | STG./RUSAL/PERH.AEZET';
comment on column ods."/rusal/perh_ral".type2 is 'Вид документа | Вид документа | STG./RUSAL/PERH.TYPE2';
comment on column ods."/rusal/perh_ral".waers is 'Код валюты | Код валюты | STG./RUSAL/PERH.WAERS';
comment on column ods."/rusal/perh_ral".tap_sum is 'Сумма авансового ТАП | Сумма авансового ТАП | STG./RUSAL/PERH.TAP_SUM';
comment on column ods."/rusal/perh_ral".odo_user is 'Отправил уведомление | Отправил уведомление | STG./RUSAL/PERH.ODO_USER';
comment on column ods."/rusal/perh_ral".odo_dfk_user is 'Сотрудник ОДО ДФК | Сотрудник ОДО ДФК | STG./RUSAL/PERH.ODO_DFK_USER';
comment on column ods."/rusal/perh_ral".odo_date is 'Дата ОДО (отправления уведомлению сотрудником ОДО) | Дата ОДО (отправления уведомлению сотрудником ОДО) | STG./RUSAL/PERH.ODO_DATE';
comment on column ods."/rusal/perh_ral".accept is 'Акцепт | Акцепт | STG./RUSAL/PERH.ACCEPT';
comment on column ods."/rusal/perh_ral".accept_name is 'Автор акцепта | Автор акцепта | STG./RUSAL/PERH.ACCEPT_NAME';
comment on column ods."/rusal/perh_ral".accept_date is 'Дата последнего изменения акцепта | Дата последнего изменения акцепта | STG./RUSAL/PERH.ACCEPT_DATE';
comment on column ods."/rusal/perh_ral".budat is 'Дата проводки в документе | Дата проводки в документе | STG./RUSAL/PERH.BUDAT';
comment on column ods."/rusal/perh_ral".duedatm is 'Дата оплаты внесена вручную | Дата оплаты внесена вручную | STG./RUSAL/PERH.DUEDATM';
comment on column ods."/rusal/perh_ral".kor_akt is 'Корректировочный документ | Корректировочный документ | STG./RUSAL/PERH.KOR_AKT';
comment on column ods."/rusal/perh_ral".state is 'Статус регистрации | Статус регистрации | STG./RUSAL/PERH.STATE';
comment on column ods."/rusal/perh_ral".status_sver is 'Статус сверки | Статус сверки | STG./RUSAL/PERH.STATUS_SVER';
comment on column ods."/rusal/perh_ral".status_sogl is 'Статус согласования | Статус согласования | STG./RUSAL/PERH.STATUS_SOGL';
comment on column ods."/rusal/perh_ral".status_uved is 'Статус уведомления куратора | Статус уведомления куратора | STG./RUSAL/PERH.STATUS_UVED';
comment on column ods."/rusal/perh_ral".status_back_off is 'Статус уведомления бек-офиса | Статус уведомления бек-офиса | STG./RUSAL/PERH.STATUS_BACK_OFF';
comment on column ods."/rusal/perh_ral".sverka_pass_date is 'Дата прохождения сверки | Дата прохождения сверки | STG./RUSAL/PERH.SVERKA_PASS_DATE';
comment on column ods."/rusal/perh_ral".aldor is 'Статус передачи в Алдор | Статус передачи в Алдор | STG./RUSAL/PERH.ALDOR';
comment on column ods."/rusal/perh_ral".blok_user is 'Деблокировал | Деблокировал | STG./RUSAL/PERH.BLOK_USER';
comment on column ods."/rusal/perh_ral".blok_date is 'Дата деблокирования | Дата деблокирования | STG./RUSAL/PERH.BLOK_DATE';
comment on column ods."/rusal/perh_ral".rereg is 'Перерегистрировано | Перерегистрировано | STG./RUSAL/PERH.REREG';
comment on column ods."/rusal/perh_ral".respon is 'Ответственный 2 | Ответственный 2 | STG./RUSAL/PERH.RESPON';
comment on column ods."/rusal/perh_ral".nofact2 is 'Неотфактуровка | Неотфактуровка | STG./RUSAL/PERH.NOFACT2';
comment on column ods."/rusal/perh_ral".recdt is 'Дата получения документа | Дата получения документа | STG./RUSAL/PERH.RECDT';
comment on column ods."/rusal/perh_ral".invtp is 'Вид счета-фактуры | Вид счета-фактуры | STG./RUSAL/PERH.INVTP';
comment on column ods."/rusal/perh_ral".edit_ztap is 'Текст "Назначения платежа" изменен в ручную | Текст "Назначения платежа" изменен в ручную | STG./RUSAL/PERH.EDIT_ZTAP';
comment on column ods."/rusal/perh_ral".sogl_usnam is 'Согласующий | Согласующий | STG./RUSAL/PERH.SOGL_USNAM';
comment on column ods."/rusal/perh_ral".sogl_date is 'Дата согласования | Дата согласования | STG./RUSAL/PERH.SOGL_DATE';
comment on column ods."/rusal/perh_ral".uved_ernam is 'Куратор договора | Куратор договора | STG./RUSAL/PERH.UVED_ERNAM';
comment on column ods."/rusal/perh_ral".uved_erdat is 'Дата отправления акта на согласование куратору | Дата отправления акта на согласование куратору | STG./RUSAL/PERH.UVED_ERDAT';
comment on column ods."/rusal/perh_ral".rcu_uname is 'Сотрудник РЦУ | Сотрудник РЦУ | STG./RUSAL/PERH.RCU_UNAME';
comment on column ods."/rusal/perh_ral".rcu_date is 'Дата РЦУ | Дата РЦУ | STG./RUSAL/PERH.RCU_DATE';
comment on column ods."/rusal/perh_ral".rcu_time is 'Время РЦУ | Время РЦУ | STG./RUSAL/PERH.RCU_TIME';
comment on column ods."/rusal/perh_ral".vehicle is 'TD: номер транспортного средства | TD: номер транспортного средства | STG./RUSAL/PERH.VEHICLE';