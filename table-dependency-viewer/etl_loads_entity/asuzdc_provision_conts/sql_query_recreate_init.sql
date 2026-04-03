drop table if exists ods.asuzdc_provision_conts;
create table ods.asuzdc_provision_conts
(werks varchar(4) null,
home_name varchar(20) null,
pr_tk varchar(1) null, 
kpr_owner varchar(8) null,
own text null,
foot varchar(2) null,
id_group varchar(10) null, 
fact_cnt_send numeric (5) null,
plant_fact_cnt_send numeric (5) null,
fact_cnt_loc numeric (5) null,
cnt_cont_full numeric (5) null,
cnt_cont_empt numeric (5) null,
cnt_cont_break numeric (5) null,
ove_cnt_cont_full numeric (5) null,
ove_cnt_cont_empt numeric (5) null,
ove_cnt_car_empt numeric (5) null,
ove_cnt_car_full numeric (5) null,
cnt_cont_disl numeric (5) null,
cnt_car_disl numeric (5) null,
skpp numeric (5) null,
skpp_ready numeric (5) null,
plan_cnt_all numeric (5) null,
plan_cnt_ready numeric (5) null,
cnt_car_full numeric (5) null,
cnt_car_empt numeric (5) null,
cnt_car_break numeric (5) null,
dttm_inserted timestamp default now(),
dttm_updated timestamp default now(),
job_name varchar(50) default 'airflow',
deleted_flag bool default false
)
with (
appendonly = true,
orientation = column,
compresstype = zstd,
compresslevel = 3
)
distributed by(werks, pr_tk,kpr_owner,foot,id_group);

comment on table ods.asuzdc_provision_conts is 'Отображение доступного оборудования';
comment on column ods.asuzdc_provision_conts."werks" is 'Завод (код) | Завод (код) |  stg.asuzdc_provision_conts.WERKS';
comment on column ods.asuzdc_provision_conts."home_name" is 'Наименование завода | Наименование завода |  stg.asuzdc_provision_conts.HOME_NAME';
comment on column ods.asuzdc_provision_conts."pr_tk" is 'Признак принадлежности ТрансКонтейнеру/Русскому контейнеру | Признак принадлежности ТрансКонтейнеру/Русскому контейнеру |  stg.asuzdc_provision_conts.PR_TK';
comment on column ods.asuzdc_provision_conts."kpr_owner" is 'Код SAP/R3 собственника | Код SAP/R3 собственника |  stg.asuzdc_provision_conts.KPR_OWNER';
comment on column ods.asuzdc_provision_conts."own" is 'Наименование собственника/Линии | Наименование собственника/Линии |  stg.asuzdc_provision_conts.OWN';
comment on column ods.asuzdc_provision_conts."foot" is 'Футовость контейнера (код) | Футовость контейнера (код) |  stg.asuzdc_provision_conts.FOOT';
comment on column ods.asuzdc_provision_conts."id_group" is 'Идентификатор группы грузов (Алюминий/Аноды) (код) | Идентификатор группы грузов (Алюминий/Аноды) (код) |  stg.asuzdc_provision_conts.ID_GROUP';
comment on column ods.asuzdc_provision_conts."fact_cnt_send" is 'Факт отгрузки контейнеров на дату, то что принято к перевозке (штуки) | Факт отгрузки контейнеров на дату, то что принято к перевозке (штуки) |  stg.asuzdc_provision_conts.FACT_CNT_SEND';
comment on column ods.asuzdc_provision_conts."plant_fact_cnt_send" is 'Факт отправки контейнеров с завода (штуки) | Факт отправки контейнеров с завода (штуки) |  stg.asuzdc_provision_conts.PLANT_FACT_CNT_SEND';
comment on column ods.asuzdc_provision_conts."fact_cnt_loc" is 'Наличие груженых на отправку контейнеров на заводе на 00 часов по МСК (штуки) | Наличие груженых на отправку контейнеров на заводе на 00 часов по МСК (штуки) | stg.asuzdc_provision_conts.FACT_CNT_LOC';
comment on column ods.asuzdc_provision_conts."cnt_cont_full" is 'Наличие груженых с входящим грузом контейнеров на заводе на 00 часов по МСК (штуки) | Наличие груженых с входящим грузом контейнеров на заводе на 00 часов по МСК (штуки) |  stg.asuzdc_provision_conts.CNT_CONT_FULL';
comment on column ods.asuzdc_provision_conts."cnt_cont_empt" is 'Наличие порожних контейнеров на заводе на 00 часов по МСК (штуки) | Наличие порожних контейнеров на заводе на 00 часов по МСК (штуки) |  stg.asuzdc_provision_conts.CNT_CONT_EMPT';
comment on column ods.asuzdc_provision_conts."cnt_cont_break" is 'Наличие бракованных контейнеров на заводе на 00 часов по МСК (штуки) | Наличие бракованных контейнеров на заводе на 00 часов по МСК (штуки) |  stg.asuzdc_provision_conts.CNT_CONT_BREAK';
comment on column ods.asuzdc_provision_conts."ove_cnt_cont_full" is 'Наличие груженых с входящим грузом контейнеров на ОВЭ на 00 часов по МСК (штуки) | Наличие груженых с входящим грузом контейнеров на ОВЭ на 00 часов по МСК (штуки) |  stg.asuzdc_provision_conts.FACT_CNT_SEND';
comment on column ods.asuzdc_provision_conts."ove_cnt_cont_empt" is 'Наличие порожних контейнеров на ОВЭ на 00 часов по МСК (штуки) | Наличие порожних контейнеров на ОВЭ на 00 часов по МСК (штуки) |  stg.asuzdc_provision_conts.OVE_CNT_CONT_EMPT';
comment on column ods.asuzdc_provision_conts."ove_cnt_car_empt" is 'Наличие порожних платформ на ОВЭ на 00 часов по МСК (штуки) | Наличие порожних платформ на ОВЭ на 00 часов по МСК (штуки) |  stg.asuzdc_provision_conts.OVE_CNT_CAR_EMPT';
comment on column ods.asuzdc_provision_conts."ove_cnt_car_full" is 'Наличие груженых входящих платформ на ОВЭ на 00 часов по МСК (штуки) | Наличие груженых входящих платформ на ОВЭ на 00 часов по МСК (штуки) |  stg.asuzdc_provision_conts.OVE_CNT_CAR_FULL';
comment on column ods.asuzdc_provision_conts."cnt_cont_disl" is 'Количество контейнеров в подходе | Количество контейнеров в подходе |  stg.asuzdc_provision_conts.CNT_CONT_DISL';
comment on column ods.asuzdc_provision_conts."cnt_car_disl" is 'Количество платформ в подходе | Количество платформ в подходе |  stg.asuzdc_provision_conts.CNT_CAR_DISL';
comment on column ods.asuzdc_provision_conts."skpp" is 'Заявлено количество в СКПП | Заявлено количество в СКПП |  stg.asuzdc_provision_conts.SKPP';
comment on column ods.asuzdc_provision_conts."skpp_ready" is 'Согласовано количество в СКПП | Согласовано количество в СКПП |  stg.asuzdc_provision_conts.SKPP_READY';
comment on column ods.asuzdc_provision_conts."plan_cnt_all" is 'Плановое количество по графику отгрузки на месяц | Плановое количество по графику отгрузки на месяц | stg.asuzdc_provision_conts.PLAN_CNT_ALL';
comment on column ods.asuzdc_provision_conts."plan_cnt_ready" is 'Плановое количество по графику отгрузки на дату | Плановое количество по графику отгрузки на дату |  stg.asuzdc_provision_conts.PLAN_CNT_READY';
comment on column ods.asuzdc_provision_conts."cnt_car_full" is 'Наличие груженых платформ на заводе на 00 часов по МСК (штуки) | Наличие груженых платформ на заводе на 00 часов по МСК (штуки) |  stg.asuzdc_provision_conts.CNT_CAR_FULL';
comment on column ods.asuzdc_provision_conts."cnt_car_empt" is 'Наличие порожних платформ на заводе на 00 часов по МСК (штуки) | Наличие порожних платформ на заводе на 00 часов по МСК (штуки) |  stg.asuzdc_provision_conts.CNT_CAR_EMPT';
comment on column ods.asuzdc_provision_conts."cnt_car_break" is 'Наличие бракованных платформ на заводе на 00 часов по МСК (штуки) | Наличие бракованных платформ на заводе на 00 часов по МСК (штуки) |  stg.asuzdc_provision_conts.CNT_CAR_BREAK';
