DROP TABLE IF EXISTS ods."ekpo_ral" cascade;

CREATE TABLE ods."ekpo_ral"
(
	"ebeln" varchar(10) NULL,
	"ebelp" varchar(5) NULL,
	"banfn" varchar(10) NULL,
	"bnfpo" varchar(5) NULL,
	"bprme" varchar(3) NULL,
	"bpumn" int8 NULL,
	"bpumz" int8 NULL,
	"bstae" varchar(4) NULL,
	"ekkol" varchar(4) NULL,
	"elikz" varchar(1) NULL,
	"ematn" varchar(18) NULL,
	"fipos" varchar(14) NULL,
	"fistl" varchar(16) NULL,
	"geber" varchar(10) NULL,
	"knttp" varchar(1) NULL,
	"konnr" varchar(10) NULL,
	"ktmng" numeric(13, 3) NULL,
	"ktpnr" varchar(5) NULL,
	"lgort" varchar(4) NULL,
	"loekz" varchar(1) NULL,
	"matkl" varchar(9) NULL,
	"matnr" varchar(18) NULL,
	"meins" varchar(3) NULL,
	"menge" numeric(13, 3) NULL,
	"mfrnr" varchar(10) NULL,
	"mtart" varchar(4) NULL,
	"mwskz" varchar(2) NULL,
	"netpr" numeric(11, 2) NULL,
	"netwr" numeric(13, 2) NULL,
	"peinh" int8 NULL,
	"prdat" date NULL,
	"pstyp" varchar(1) NULL,
	"txz01" varchar(40) NULL,
	"umren" int8 NULL,
	"umrez" int8 NULL,
	"werks" varchar(4) NULL,
	"zzihrez" varchar(50) NULL,
	"zzimport" varchar(1) NULL,
	"zzinco1" varchar(3) NULL,
	"zzintmarket" varchar(1) NULL,
	"zzknote" varchar(10) NULL,
	"zzkod_okpd" varchar(12) NULL,
	"zzkod_tnved" varchar(17) NULL,
	"zzland" varchar(3) NULL,
	"zzoption" numeric(3, 1) NULL,
	"zzrnpt" varchar(1) NULL,
	"zzroute" varchar(6) NULL,
	"zzsudno" varchar(10) NULL,
	"zztamozhsous" varchar(1) NULL,
	"zztariff" varchar(2) NULL,
	"zzthc" varchar(1) NULL,
	"zztolerance" numeric(13, 3) NULL,
	"zztrnakl" varchar(35) NULL,
	"zzundefined" varchar(1) NULL,
	"zzvehicle" varchar(10) NULL,
	"zzwerks" varchar(4) NULL,
	"gewei" varchar(3) null,
	"lmein" varchar(3) null,
	"bwtar" varchar(10) null,	
	"zzbasis" varchar(1) null,
	"zzbodylength" varchar(1) null,
	"zzbucking" varchar(30) null,
	"zzbunker" varchar(1) null,
	"zzcargoa" numeric(13, 3) null,
	"zzcargow" numeric(13, 3) null,	
	"zzcartare" varchar(2) null,
	"zzdayoff" varchar(1) null,
	"zzet_tarif" varchar(6) null,
	"zzetsng1" varchar(6) null,
	"zzforma" varchar(3) null,
	"zzformula" varchar(3) null,
	"zzfraht_type" varchar(4) null,
	"zzgrade" varchar(15) null,
	"zzkontrag" varchar(10) null,
	"zzkran" varchar(1) null,
	"zzlength" varchar(1) null,
	"zzlif_owner" varchar(10) null,
	"zzline" varchar(10) null,
	"zzmatkl" varchar(9) null,
	"zzmovement" varchar(1) null,
	"zzpr_cont" varchar(2) null,
	"zzpr_pl" varchar(2) null,
	"zzredir_type" varchar(1) null,
	"zzrej_exp" varchar(2) null,
	"zzroute2" varchar(6) null,
	"zzsdabw" varchar(4) null,
	"zzsdabw2" varchar(4) null,
	"zzset" varchar(2) null,
	"zzspart" varchar(2) null,
	"zzsrvpos" varchar(18) null,
	"zzterminal" varchar(10) null,
	"zzport" varchar(10) null,
	"zzstation" varchar(10) null,
	"zzstock" varchar(10) null,
	"zztaresubtype" varchar(2) null,
	"zztraty" varchar(4) null,
	"zztype" varchar(1) null,
	"zztype_prod" varchar(1) null,
	"zzvehicletype" varchar(10) null,
	"zzvsart" varchar(2) null,
	"dttm_inserted" timestamp NOT NULL DEFAULT now(),
	"dttm_updated" timestamp NOT NULL DEFAULT now(),
	"job_name" varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	"deleted_flag" bool NOT NULL DEFAULT false
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by ("ebeln", "ebelp");


comment on table ods."ekpo_ral" is 'Позиция документа закупки';
comment on column ods."ekpo_ral"."ebeln" is 'Номер документа закупки | Номер документа закупки | EKPO.EBELN';
comment on column ods."ekpo_ral"."ebelp" is 'Номер позиции документа закупки | Номер позиции документа закупки | EKPO.EBELP';
comment on column ods."ekpo_ral"."banfn" is 'Номер заявки | Номер заявки | EKPO.BANFN';
comment on column ods."ekpo_ral"."bnfpo" is 'Номер позиции заявки | Номер позиции заявки | EKPO.BNFPO';
comment on column ods."ekpo_ral"."bprme" is 'Единица измерения цены заказа на поставку | Единица измерения цены заказа на поставку | EKPO.BPRME';
comment on column ods."ekpo_ral"."bpumn" is 'Пересчет ЕИЦЗ в ЕИЗ: знаменатель | Пересчет ЕИЦЗ в ЕИЗ: знаменатель | EKPO.BPUMN';
comment on column ods."ekpo_ral"."bpumz" is 'Пересчет ЕИЦЗ в ЕИЗ: числитель | Пересчет ЕИЦЗ в ЕИЗ: числитель | EKPO.BPUMZ';
comment on column ods."ekpo_ral"."bstae" is 'Управляющий код подтверждения | Управляющий код подтверждения | EKPO.BSTAE';
comment on column ods."ekpo_ral"."ekkol" is 'Группа условий у поставщика | Группа условий у поставщика | EKPO.EKKOL';
comment on column ods."ekpo_ral"."elikz" is 'Индикатор конечной поставки | Индикатор конечной поставки | EKPO.ELIKZ';
comment on column ods."ekpo_ral"."ematn" is 'Номер материала | Номер материала | EKPO.EMATN';
comment on column ods."ekpo_ral"."fipos" is 'Финансовая позиция | Финансовая позиция | EKPO.FIPOS';
comment on column ods."ekpo_ral"."fistl" is 'Подразделение финансового менеджмента | Подразделение финансового менеджмента | EKPO.FISTL';
comment on column ods."ekpo_ral"."geber" is 'Фонд | Фонд | EKPO.GEBER';
comment on column ods."ekpo_ral"."knttp" is 'Тип контировки | Тип контировки | EKPO.KNTTP';
comment on column ods."ekpo_ral"."konnr" is 'Номер основного договора | Номер основного договора | EKPO.KONNR';
comment on column ods."ekpo_ral"."ktmng" is 'Договорное количество | Договорное количество | EKPO.KTMNG';
comment on column ods."ekpo_ral"."ktpnr" is 'Номер позиции вышестоящего договора | Номер позиции вышестоящего договора | EKPO.KTPNR';
comment on column ods."ekpo_ral"."lgort" is 'Склад | Склад | EKPO.LGORT';
comment on column ods."ekpo_ral"."loekz" is 'Индикатор удаления в документе закупки | Индикатор удаления в документе закупки | EKPO.LOEKZ';
comment on column ods."ekpo_ral"."matkl" is 'Группа материалов | Группа материалов | EKPO.MATKL';
comment on column ods."ekpo_ral"."matnr" is 'Номер материала | Номер материала | EKPO.MATNR';
comment on column ods."ekpo_ral"."meins" is 'ЕИ заказа на поставку | ЕИ заказа на поставку | EKPO.MEINS';
comment on column ods."ekpo_ral"."menge" is 'Объем заказа на поставку | Объем заказа на поставку | EKPO.MENGE';
comment on column ods."ekpo_ral"."mfrnr" is 'Номер производителя | Номер производителя | EKPO.MFRNR';
comment on column ods."ekpo_ral"."mtart" is 'Вид материала | Вид материала | EKPO.MTART';
comment on column ods."ekpo_ral"."mwskz" is 'Код налога с оборота | Код налога с оборота | EKPO.MWSKZ';
comment on column ods."ekpo_ral"."netpr" is 'Цена нетто в документе закупки в валюте документа | Цена нетто в документе закупки в валюте документа | EKPO.NETPR';
comment on column ods."ekpo_ral"."netwr" is 'Стоимость заказа нетто в валюте заказа | Стоимость заказа нетто в валюте заказа | EKPO.NETWR';
comment on column ods."ekpo_ral"."peinh" is 'Единица цены | Единица цены | EKPO.PEINH';
comment on column ods."ekpo_ral"."prdat" is 'Дата расчета цены | Дата расчета цены | EKPO.PRDAT';
comment on column ods."ekpo_ral"."pstyp" is 'Тип позиции в документе закупки | Тип позиции в документе закупки | EKPO.PSTYP';
comment on column ods."ekpo_ral"."txz01" is 'Краткий текст | Краткий текст | EKPO.TXZ01';
comment on column ods."ekpo_ral"."umren" is 'Знаменатель для пересчета ЕИ заказа в базисную ЕИ | Знаменатель для пересчета ЕИ заказа в базисную ЕИ | EKPO.UMREN';
comment on column ods."ekpo_ral"."umrez" is 'Числитель для пересчета ЕИ заказа в базисную ЕИ | Числитель для пересчета ЕИ заказа в базисную ЕИ | EKPO.UMREZ';
comment on column ods."ekpo_ral"."werks" is 'Завод | Завод | EKPO.WERKS';
comment on column ods."ekpo_ral"."zzihrez" is 'Регистр.№ спецификации | Регистр.№ спецификации | EKPO.ZZIHREZ';
comment on column ods."ekpo_ral"."zzimport" is 'Флаг импорта | Флаг импорта | EKPO.ZZIMPORT';
comment on column ods."ekpo_ral"."zzinco1" is 'Инкотермс часть 1 | Инкотермс часть 1 | EKPO.ZZINCO1';
comment on column ods."ekpo_ral"."zzintmarket" is 'Внутренний рынок | Внутренний рынок | EKPO.ZZINTMARKET';
comment on column ods."ekpo_ral"."zzknote" is 'ИНКОТЕРМС2(Транспортный узел) | ИНКОТЕРМС2(Транспортный узел) | EKPO.ZZKNOTE';
comment on column ods."ekpo_ral"."zzkod_okpd" is 'Код ОКПД2 | Код ОКПД2 | EKPO.ZZKOD_OKPD';
comment on column ods."ekpo_ral"."zzkod_tnved" is 'Товарная номенклатура внешнеэкономической деятельности | Товарная номенклатура внешнеэкономической деятельности | EKPO.ZZKOD_TNVED';
comment on column ods."ekpo_ral"."zzland" is 'Страна происхождения | Страна происхождения | EKPO.ZZLAND';
comment on column ods."ekpo_ral"."zzoption" is 'Опцион поставки % | Опцион поставки % | EKPO.ZZOPTION';
comment on column ods."ekpo_ral"."zzrnpt" is 'Признак РНПТ | Признак РНПТ | EKPO.ZZRNPT';
comment on column ods."ekpo_ral"."zzroute" is 'Маршрут | Маршрут | EKPO.ZZROUTE';
comment on column ods."ekpo_ral"."zzsudno" is 'Номер судна | Номер судна | EKPO.ZZSUDNO';
comment on column ods."ekpo_ral"."zztamozhsous" is 'Таможенный союз | Таможенный союз | EKPO.ZZTAMOZHSOUS';
comment on column ods."ekpo_ral"."zztariff" is 'Тариф | Тариф | EKPO.ZZTARIFF';
comment on column ods."ekpo_ral"."zzthc" is 'THC | THC | EKPO.ZZTHC';
comment on column ods."ekpo_ral"."zztolerance" is 'Толеранс поставки | Толеранс поставки | EKPO.ZZTOLERANCE';
comment on column ods."ekpo_ral"."zztrnakl" is 'Транспортная накладная | Транспортная накладная | EKPO.ZZTRNAKL';
comment on column ods."ekpo_ral"."zzundefined" is 'Не определено | Не определено | EKPO.ZZUNDEFINED';
comment on column ods."ekpo_ral"."zzvehicle" is 'Судно | Судно | EKPO.ZZVEHICLE';
comment on column ods."ekpo_ral"."zzwerks" is 'Завод-получатель | Завод-получатель | EKPO.ZZWERKS';
comment on column ods."ekpo_ral"."gewei" is 'Единица измерения веса | Единица измерения веса | EKPO.GEWEI';
comment on column ods."ekpo_ral"."lmein" is 'Базисная единица измерения | Базисная единица измерения | EKPO.LMEIN';
comment on column ods."ekpo_ral"."bwtar" is ' Вид оценки | Вид оценки | EKPO.BWTAR';
comment on column ods."ekpo_ral"."zzbasis" 	is 'Кол-во заходов в порты | Кол-во заходов в порты | EKPO.ZZBASIS';
comment on column ods."ekpo_ral"."zzbodylength" is 'Длина ПС | Длина ПС | EKPO.ZZBODYLENGTH';
comment on column ods."ekpo_ral"."zzbucking" is 'Номер букинга | Номер букинга | EKPO.ZZBUCKING';
comment on column ods."ekpo_ral"."zzbunker" is 'Базис бункерной поправки | Базис бункерной поправки | EKPO.ZZBUNKER';
comment on column ods."ekpo_ral"."zzcargoa" is 'Вес по, тн | Вес по, тн | EKPO.ZZCARGOA';
comment on column ods."ekpo_ral"."zzcargow" is 'Вес с, тн | Вес с, тн | EKPO.ZZCARGOW';
comment on column ods."ekpo_ral"."zzcartare" is 'Тип тары | Тип тары | EKPO.ZZCARTARE';
comment on column ods."ekpo_ral"."zzdayoff" is 'Выходные и праздничные дни | Выходные и праздничные дни | EKPO.ZZDAYOFF';
comment on column ods."ekpo_ral"."zzet_tarif" is 'Код ЕТ СНГ | Код ЕТ СНГ | EKPO.ZZET_TARIF';
comment on column ods."ekpo_ral"."zzetsng1" is 'Код ЕТ СНГ исходный | Код ЕТ СНГ исходный | EKPO.ZZETSNG1';
comment on column ods."ekpo_ral"."zzforma" is 'Форма | Форма | EKPO.ZZFORMA';
comment on column ods."ekpo_ral"."zzformula" is 'Номер формулы | Номер формулы | EKPO.ZZFORMULA';
comment on column ods."ekpo_ral"."zzfraht_type" is 'Вид фрахта | Вид фрахта | EKPO.ZZFRAHT_TYPE';
comment on column ods."ekpo_ral"."zzgrade" is 'Марка топлива | Марка топлива | EKPO.ZZGRADE';
comment on column ods."ekpo_ral"."zzkontrag" is 'Контрагент | Контрагент | EKPO.ZZKONTRAG';
comment on column ods."ekpo_ral"."zzkran" is 'Кран | Кран | EKPO.ZZKRAN';
comment on column ods."ekpo_ral"."zzlength" is 'Длина контейнера | Длина контейнера | EKPO.ZZLENGTH';
comment on column ods."ekpo_ral"."zzlif_owner" is 'Собственник вагона | Собственник вагона | EKPO.ZZLIF_OWNER';
comment on column ods."ekpo_ral"."zzline" is 'Линия | Линия | EKPO.ZZLINE';
comment on column ods."ekpo_ral"."zzmatkl" is 'Группа материала | Группа материала | EKPO.ZZMATKL';
comment on column ods."ekpo_ral"."zzmovement" is 'Схема перемещения | Схема перемещения | EKPO.ZZMOVEMENT';
comment on column ods."ekpo_ral"."zzpr_cont" is 'Принадлежность контейнера | Принадлежность контейнера | EKPO.ZZPR_CONT';
comment on column ods."ekpo_ral"."zzpr_pl" is 'Принадлежность платформы | Принадлежность платформы | EKPO.ZZPR_PL';
comment on column ods."ekpo_ral"."zzredir_type" is 'Тип переадресации | Тип переадресации | EKPO.ZZREDIR_TYPE';
comment on column ods."ekpo_ral"."zzrej_exp" is 'Режим экспорта | Режим экспорта | EKPO.ZZREJ_EXP';
comment on column ods."ekpo_ral"."zzroute2" is 'Морской маршрут | Морской маршрут | EKPO.ZZROUTE2';
comment on column ods."ekpo_ral"."zzsdabw" is 'Тип вагона | Тип вагона | EKPO.ZZSDABW';
comment on column ods."ekpo_ral"."zzsdabw2" is 'Тип исходного ТС/ПС | Тип исходного ТС/ПС | EKPO.ZZSDABW2';
comment on column ods."ekpo_ral"."zzset" is 'Признак комплектности | Признак комплектности | EKPO.ZZSET';
comment on column ods."ekpo_ral"."zzspart" is 'Сектор | Сектор | EKPO.ZZSPART';
comment on column ods."ekpo_ral"."zzsrvpos" is '№ Услуги LE | № Услуги LE | EKPO.ZZSRVPOS';
comment on column ods."ekpo_ral"."zzterminal" is 'Терминал | Терминал | EKPO.ZZTERMINAL';
comment on column ods."ekpo_ral"."zzport" is 'Порт | Порт | EKPO.ZZPORT';
comment on column ods."ekpo_ral"."zzstation" is 'Станция | Станция | EKPO.ZZSTATION';
comment on column ods."ekpo_ral"."zzstock" is 'Сток | Сток | EKPO.ZZSTOCK';
comment on column ods."ekpo_ral"."zztaresubtype" is 'Подтип тары | Подтип тары | EKPO.ZZTARESUBTYPE';
comment on column ods."ekpo_ral"."zztraty" is 'Вид транспортного средства | Вид транспортного средства | EKPO.ZZTRATY';
comment on column ods."ekpo_ral"."zztype" is 'Тип услуги | Тип услуги | EKPO.ZZTYPE';
comment on column ods."ekpo_ral"."zztype_prod" is 'Схема реализации | Схема реализации | EKPO.ZZTYPE_PROD';
comment on column ods."ekpo_ral"."zzvehicletype" is 'Марка ТС | Марка ТС | EKPO.ZZVEHICLETYPE';
comment on column ods."ekpo_ral"."zzvsart" is 'Вид отгрузки | Вид отгрузки | EKPO.ZZVSART';
