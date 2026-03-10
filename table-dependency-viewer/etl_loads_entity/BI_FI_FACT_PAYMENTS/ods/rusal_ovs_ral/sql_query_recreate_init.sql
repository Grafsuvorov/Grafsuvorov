create table ods.rusal_ovs_ral (
    bukrs varchar(4),
    bdatj varchar(4),
    poper varchar(3),
    dtype varchar(1),
    werks varchar(4),
    id varchar(20),
    hkont varchar(10),
    kalnr varchar(12),
    bwagr varchar(4),
    saknr varchar(10),
    account varchar(15),
    lifnrka varchar(10),
    bklas varchar(4),
    meins varchar(3),
    menge numeric(15,3),
    dmbtr numeric(17,2),
    dmbe2 numeric(17,2),
    dttm_inserted timestamp not null default now(),
    dttm_updated timestamp not null default now(),
    job_name varchar(60) not null default 'airflow'::character varying,    
    deleted_flag bool not null default false
)
with (
    appendonly = true,
    orientation = column,
    compresstype = zstd,
    compresslevel = 3
)
distributed by (id);
---ключ bukrs,bdatj,poper,dtype,werks,id
----------------------------------------------------------------------------------------------------------------COMMENT
comment on table ods.rusal_ovs_ral is 'Таблица материальных оборотов';
comment on column ods.rusal_ovs_ral.bukrs is 'Балансовая единица | Балансовая единица | BUKRS';
comment on column ods.rusal_ovs_ral.bdatj is 'Дата проводки ГГГГ | Дата проводки ГГГГ | BDATJ';
comment on column ods.rusal_ovs_ral.poper is 'Период проводки | Период проводки | POPER';
comment on column ods.rusal_ovs_ral.dtype is 'Тип данных в строке | Тип данных в строке | DTYPE';
comment on column ods.rusal_ovs_ral.werks is 'Завод | Завод | WERKS';
comment on column ods.rusal_ovs_ral.id is 'Ид строки | Ид строки | ID';
comment on column ods.rusal_ovs_ral.hkont is 'Основной счет главной бухгалтерии | Основной счет главной бухгалтерии | HKONT';
comment on column ods.rusal_ovs_ral.kalnr is 'Номер калькуляции для кальк. без количественной структуры | Номер калькуляции для кальк. без количественной структуры | KALNR';
comment on column ods.rusal_ovs_ral.bwagr is 'Группа видов движения для МСБ | Группа видов движения для МСБ | BWAGR';
comment on column ods.rusal_ovs_ral.saknr is 'Корреспондирующий счет | Корреспондирующий счет | SAKNR';
comment on column ods.rusal_ovs_ral.account is 'Номер основного счета (без преобразования) | Номер основного счета (без преобразования) | ACCOUNT';
comment on column ods.rusal_ovs_ral.lifnrka is 'Номер счета поставщика или кредитора | Номер счета поставщика или кредитора | LIFNRKA';
comment on column ods.rusal_ovs_ral.bklas is 'Класс оценки | Класс оценки | BKLAS';
comment on column ods.rusal_ovs_ral.meins is 'Базовая единица измерения | Базовая единица измерения | MEINS';
comment on column ods.rusal_ovs_ral.menge is 'Общее количество | Общее количество | MENGE';
comment on column ods.rusal_ovs_ral.dmbtr is 'Общая сумма в валюте объекта | Общая сумма в валюте объекта | DMBTR';
comment on column ods.rusal_ovs_ral.dmbe2 is 'Общая сумма в валюте КЕ | Общая сумма в валюте КЕ | DMBE2';