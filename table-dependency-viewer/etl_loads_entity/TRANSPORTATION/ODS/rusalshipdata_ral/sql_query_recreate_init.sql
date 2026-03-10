drop table if exists ods."/rusal/shipdata_ral";

create table ods."/rusal/shipdata_ral" (
	ident varchar(16) not null,
	charg varchar(10) null,
	vbeln varchar(10) null,
	vbeln_lf varchar(10) null,
	order_ varchar(30) null,
	plant varchar(4) null,
	vagon varchar(20) null,
	platf varchar(12) null,
	gradecod varchar(18) null,
	market varchar(1) null,
	expedidsub varchar(10) null,
	shtempel_date date null,
	prih_zavod_date date null,
	impexp_date date null,
	nstamp varchar(150) null,
	rekvizit numeric(13, 3) null,
	werks varchar(4) null,
	customid varchar(10) null,
	contrexp varchar(35) null,
	razmer varchar(20) null,
	firmapid varchar(10) null,
	firmap varchar(120) null,
	idw1 varchar(10) null,
	route varchar(6) null,
	unl_term varchar(10) null,
	stationnc varchar(10) null,
	quar_sert varchar(18) null,
	quar_date timestamp null,
	mest numeric(10, 0) null,
	lgort varchar(4) null,
	nk numeric(13, 3) null,
	plant1 varchar(4) null,
	stationo varchar(40) null,
	raspor varchar(10) null,
	vbeln_lfs varchar(10) null,
	dateadd date null,
	length varchar(10) null,
	width varchar(10) null,
	height varchar(10) null,
	diameter varchar(20) null,
	nsert varchar(20) null,
	posnr_lf varchar(6) null,
	kodat date null,
	stationn varchar(40) null,
	box varchar(3) null,
	marshr varchar(17) null,
	dataprek date null,
	zavod varchar(40) null,
	gtd varchar(40) null,
	dataskl timestamp null,
	exped varchar(120) null,
	dateot date null,
	packing numeric(6, 0) null,
	cust2_id varchar(10) null,
	potrebit varchar(10) null,
	exporter varchar(10) null, 
	locid varchar(10) null,
	vsart varchar(2) null,
	datapgp date null, 
	contr_id varchar(10) null,
	brutto numeric(13, 3) null,
	netto numeric(13, 3) null,
	werks_nosap varchar(1) null,
	svh varchar(1) null,
	posnr_lfs varchar(6) null,
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
distributed by (ident);


comment on table ods."/rusal/shipdata_ral" is 'Партия-поставка';
comment on column ods."/rusal/shipdata_ral".exped is 'Экспедитор | Экспедитор | stg."/RUSAL/SHIPDATA"."EXPED"';
comment on column ods."/rusal/shipdata_ral".charg is 'Партия | Номер партии метала, формируется на заводе производителе, либо при закупке на операторе от внешних поставщиков | stg."/RUSAL/SHIPDATA"."CHARG"';
comment on column ods."/rusal/shipdata_ral".vbeln is 'Исходная поставка | Исходная (первая) поставка, от которой начинается оформление цепочки продаж. 
Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах | stg."/RUSAL/SHIPDATA"."VBELN"';
comment on column ods."/rusal/shipdata_ral".ident is 'Идентификатор записи об отгрузке из файла | Идентификатор записи об отгрузке из файла | stg."/RUSAL/SHIPDATA"."IDENT"';
comment on column ods."/rusal/shipdata_ral".vbeln_lf is 'Поставка завода производителя | Поставка завода производителя, по которой формируется цепочка продаж на заводе произвидителе | stg."/RUSAL/SHIPDATA"."VBELN_LF"';
comment on column ods."/rusal/shipdata_ral".order_ is 'Заказ ЦК в отгрузке | № заказа центральной компании (заявки) под план производства. 
Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах. 
Изначально заказы ЦК вносятся в тразакции ZSD2882M-Регистрация заявок клиентов. 
Если отгрузка не выполняется по внешнему номеру (вносится вручную) - то Заказ ЦК в отгрузке = Заказ ЦК | stg."/RUSAL/SHIPDATA"."ORDER_"';
comment on column ods."/rusal/shipdata_ral".plant is 'Завод производитель (код) | Завод производитель (код) | stg."/RUSAL/SHIPDATA"."PLANT"';
comment on column ods."/rusal/shipdata_ral".vagon is 'Номер вагона | Номер авто, вагона или контейнера, в случае перевозки металла в контенере, в котором металл едет от Завода производителя | stg."/RUSAL/SHIPDATA"."VAGON"';
comment on column ods."/rusal/shipdata_ral".platf is 'Номер платформы | Номер платформы, на которой передвигается контейнер, по жд от Завода производителя | stg."/RUSAL/SHIPDATA"."PLATF"';
comment on column ods."/rusal/shipdata_ral".gradecod is 'Материал (код) | Системный номер материала. Например, APT0006ING0045. Аналог поля  Номер материала | stg."/RUSAL/SHIPDATA"."GRADECOD"';
comment on column ods."/rusal/shipdata_ral".market is 'Рынок в отгрузке (код) | Код рынка сбыта, к которому относится страна потребителя (внутренний, СНГ, Экспорт, Кубал) | stg."/RUSAL/SHIPDATA"."MARKET"';
comment on column ods."/rusal/shipdata_ral".expedidsub is 'Экспедитор Договорной (код) | Системный код экпедитора,  это тот с кем заключен договор экспедирования груза. 
Заполняется заводом производителем при оформлении отгрузки металла с завода до конечной точки | stg."/RUSAL/SHIPDATA"."EXPEDIDSUB"';
comment on column ods."/rusal/shipdata_ral".shtempel_date is 'Дата штемпеля по ЖД-накладной | Дата со штемпеля на ЖД накладной со станции отправления. 
Инфо берем из данных об отгрузке с завода. Эта дата используется по-разному, в зависимости от вида перехода права собственности (далее ППС):
- при ППС 001 (отпуск материала проходит на станции продавца) это дата будет датой отпуска материала;
- при ППС 002 (отпуск материала проходит только, доехав до станции покупателя) это дата отправки вагона со станции отправителя | stg."/RUSAL/SHIPDATA"."SHTEMPEL_DATE"';
comment on column ods."/rusal/shipdata_ral".prih_zavod_date is 'Дата прихода на завод | Дата, прибытия пустого  контейнера на завод. 
Инфо берем из данных об отгрузке с завода | stg."/RUSAL/SHIPDATA"."PRIH_ZAVOD_DATE"';
comment on column ods."/rusal/shipdata_ral".impexp_date is 'Дата перехода из импорта в экспорт | Дата, когда морской контейнер вернули в РФ из-за границы. 
Инфо берем из данных об отгрузке с завода | stg."/RUSAL/SHIPDATA"."IMPEXP_DATE"';
comment on column ods."/rusal/shipdata_ral".nstamp is 'Номер пломбы | Номер пломбы, навешиваемой на кузова транспортных средств (вагоны, фургоны, контейнеры, их секции и отдельные грузовые места), 
	которая не должна допускать возможности доступа к грузу и снятия пломбы без нарушения их целостности.  
Инфо берем из данных об отгрузке с завода | stg."/RUSAL/SHIPDATA"."NSTAMP"';
comment on column ods."/rusal/shipdata_ral".rekvizit is 'Реквизит | Вес крепления товара в транспортном средстве в КГ.
 Инфо берем из данных об отгрузке с завода | stg."/RUSAL/SHIPDATA"."REKVIZIT"';
comment on column ods."/rusal/shipdata_ral".werks is 'Принимающий завод грузополучателя в системе SAP (код) | Системный номер завода оператора, собственника продукции при реализации клиенту | stg."/RUSAL/SHIPDATA"."WERKS"';
comment on column ods."/rusal/shipdata_ral".customid is 'Заказчик (код) | Системный номер дебитора, который является покупателем  у завода производителя, т.е. тот кому отгружает продукцию Завод производитель. | stg."/RUSAL/SHIPDATA"."CUSTOMID"';
comment on column ods."/rusal/shipdata_ral".contrexp is 'Номер экспортного контракта | Договор (номер на бумажном носителе) по которому выполняется экспорт продукции из РФ | stg."/RUSAL/SHIPDATA"."CONTREXP"';
comment on column ods."/rusal/shipdata_ral".razmer is 'Размер единицы готовой продукции | Размер единицы готовой продукции, в зависимости от формы | stg."/RUSAL/SHIPDATA"."RAZMER"';
comment on column ods."/rusal/shipdata_ral".firmapid is 'Грузополучатель материала (код) | Системный код дебитора, который является получателем продукции по отгрузочному документу завода - ЖД накладная/CMR/ТТН.  
Тот, в адрес кого Завод производитель отгружает продукцию  | stg."/RUSAL/SHIPDATA"."FIRMAPID"';
comment on column ods."/rusal/shipdata_ral".firmap is 'Грузополучатель материала | Название получателя материала по отгрузочному документу завода - ЖД накладная/CMR/ТТН.  
Тот, в адрес кого Завод производитель отгружает продукцию.  | stg."/RUSAL/SHIPDATA"."FIRMAP"';
comment on column ods."/rusal/shipdata_ral".idw1 is 'Партия | Внутренний идентификатор вагона при взаимодействии с портовыми экспедиторами по сути равен номеру первой партии вагона | stg."/RUSAL/SHIPDATA"."IDW1"';
comment on column ods."/rusal/shipdata_ral".route is 'Маршрут в отгрузке (код) | Системный номер маршрута из поставки завода производителя. Инфо берем из данных об отгрузке с завода | stg."/RUSAL/SHIPDATA"."ROUTE"';
comment on column ods."/rusal/shipdata_ral".unl_term is 'Терминал разгрузки (код) | Источник данных stg."/RUSAL/SHIPDATA"-UNL_TERM, вегда = пусто | stg."/RUSAL/SHIPDATA"."UNL_TERM"';
comment on column ods."/rusal/shipdata_ral".stationnc is 'Станция назначения (код) | Системный код станции назначения, которая является конечной точкой доставки по ж\д. 
Инфо выводится из Загрузки данных об отгрузке на трейдерах (транзакция ZSD2925M) | stg."/RUSAL/SHIPDATA"."STATIONNC"';
comment on column ods."/rusal/shipdata_ral".quar_sert is 'Карантинный сертификат | Номер документа, который удостоверяет соответствие партии подкарантинной продукции карантинным фитосанитарным требованиям и выдан федеральным органом исполнительной власти, 
	осуществляющим функции по контролю и надзору в области карантина, при перемещении подкарантинной продукции по территории Российской Федерации | stg."/RUSAL/SHIPDATA"."QUAR_SERT"';
comment on column ods."/rusal/shipdata_ral".quar_date is 'Дата карантинного сертификата | Дата документа, который удостоверяет соответствие партии подкарантинной продукции карантинным фитосанитарным требованиям и выдан федеральным органом исполнительной власти, 
	осуществляющим функции по контролю и надзору в области карантина, при перемещении подкарантинной продукции по территории Российской Федерации | stg."/RUSAL/SHIPDATA"."QUAR_DATE"';
comment on column ods."/rusal/shipdata_ral".mest is 'Количество грузовых мест | Количество грузовых мест в вагоне | stg."/RUSAL/SHIPDATA"."MEST"';
comment on column ods."/rusal/shipdata_ral".lgort is 'Принимающий склад (код) | Код склада Завода- оператора (собственника продукции при реализации клиенту), на который будет принята продукция и в дальнейшем с которого будет производиться отгрузка Клиенту | stg."/RUSAL/SHIPDATA"."LGORT"';
comment on column ods."/rusal/shipdata_ral".nk is 'Вес нетто + катанка; Сумма веса нетто и веса катанки | stg."/RUSAL/SHIPDATA"."NK"';
comment on column ods."/rusal/shipdata_ral".plant1 is 'Завод - собственник (код) | Системный номер завода собственника сырья, он передает свое сырье на переработку Заводу производителю  | stg."/RUSAL/SHIPDATA"."PLANT1"';
comment on column ods."/rusal/shipdata_ral".stationo is 'Станция отправления | Название станции, которая является отправной точкой груза по ж\д, инфо выводится из начального узла Маршрута завода | stg."/RUSAL/SHIPDATA"."STATIONO"';
comment on column ods."/rusal/shipdata_ral".raspor is 'Номер распоряжения | Номер распоряжения на отгрузку (номер заказа в системе), создается только для отгрузок на внутренний рынок и СНГ.  
Этот документ является указанием к отгрузке Заводу производителю, в нем указано кому, что и сколько нужно отгрузить. 
Распоряжение на отгрузку создается ДСБ по контракту с клиентом из Заказа ЦК в отгрузке (в тразакции ZSD2882M-Регистрация заявок клиентов) и выдается производителю | stg."/RUSAL/SHIPDATA"."RASPOR"';
comment on column ods."/rusal/shipdata_ral".vbeln_lfs is 'Поставка завода собственника | Поставка завода собственника сырья, по которой формируется цепочка продаж на заводе собственнике | stg."/RUSAL/SHIPDATA"."VBELN_LFS"';
comment on column ods."/rusal/shipdata_ral".dateadd is 'Дата первого появления записи в системе | Дата создания записи об отгрузке, в транзакции ZSD2925M Загрузки данных об отгрузке на трейдерах | stg."/RUSAL/SHIPDATA"."DATEADD"';
comment on column ods."/rusal/shipdata_ral".length is 'Длина единицы готовой продукции | Длина единицы готовой продукции | stg."/RUSAL/SHIPDATA"."LENGTH"';
comment on column ods."/rusal/shipdata_ral".width is 'Ширина единицы готовой продукции | Ширина единицы готовой продукции | stg."/RUSAL/SHIPDATA"."WIDTH"';
comment on column ods."/rusal/shipdata_ral".height is 'Высота единицы готовой продукции | Высота единицы готовой продукции | stg."/RUSAL/SHIPDATA"."HEIGHT"';
comment on column ods."/rusal/shipdata_ral".diameter is 'Диаметр единицы готовой продукции | Диаметр единицы готовой продукции | stg."/RUSAL/SHIPDATA"."DIAMETER"';
comment on column ods."/rusal/shipdata_ral".nsert is 'Номер сертификата | Официальный документ, подтверждающий высокое качество продукции и соответствие установленным требованиям государственных стандартов и технических регламентов | stg."/RUSAL/SHIPDATA"."NSERT"';
comment on column ods."/rusal/shipdata_ral".posnr_lf is 'Позиция поставки завода производителя | Номер позиции поставки завода производителя, по которой формируется цепочка продаж на заводе произвидителе | stg."/RUSAL/SHIPDATA"."POSNR_LF"';
comment on column ods."/rusal/shipdata_ral".kodat is 'Дата комплектования | Дата комплектования (подготовки груза для отгрузки) поставки завода производителя  | stg."/RUSAL/SHIPDATA"."KODAT"';
comment on column ods."/rusal/shipdata_ral".stationn is 'Станция назначения | Название станции, которая является конечной точкой доставки по ж\д, инфо выводится из Загрузки данных об отгрузке на трейдерах (транзакция ZSD2925M) | stg."/RUSAL/SHIPDATA"."STATIONN"';
comment on column ods."/rusal/shipdata_ral".box is 'Ящик  | Номер ящика фольги  | stg."/RUSAL/SHIPDATA"."BOX"';
comment on column ods."/rusal/shipdata_ral".marshr is 'Маршрут (код) | Это номер, который объединяет в себе значение нескольких полей из группы поставок, которая создается на заводе и используется для группировки поставок в составе вагонов. Где, 
1) первый символ (буква), это вид группы, обозначает вид отгрузки;  
2) номер между символами ""-"", это системный номер группы;
3) последние цифры, после символа ""-"", это количество поставок, включенных в группу.  По этому значению мы  понимаем, что это одиночная отправка или целый состав.
Например, Номер маршрута A-8000055482-65, обозначает: вид группы A-ЖД маршрут, номер группы 8000055482, количество поставок, включенных в группу 65." | stg."/RUSAL/SHIPDATA"."MARSHR"';
comment on column ods."/rusal/shipdata_ral".dataprek is 'Дата экспедитора | Дата экспедитора | stg."/RUSAL/SHIPDATA"."DATAPREK"';
comment on column ods."/rusal/shipdata_ral".zavod is 'Наименование завода | Наименование завода | stg."/RUSAL/SHIPDATA"."ZAVOD"';
comment on column ods."/rusal/shipdata_ral".gtd is 'Номер ГТД | Номер ГТД | stg."/RUSAL/SHIPDATA"."GTD"';
comment on column ods."/rusal/shipdata_ral".dataskl is 'Дата склада | Дата прибытия на склад порта, когда экспедитор принял груз на склад | stg."/RUSAL/SHIPDATA"."DATASKL"';
comment on column ods."/rusal/shipdata_ral".exped is 'Экспедитор, наименование | Экспедитор, наименование | stg."/RUSAL/SHIPDATA"."EXPED"';
comment on column ods."/rusal/shipdata_ral".dateot is 'Дата отгрузки | Дата отгрузки | stg."/RUSAL/SHIPDATA"."DATEOT"';
comment on column ods."/rusal/shipdata_ral".packing is 'Вес упаковки | Вес упаковки | stg."/RUSAL/SHIPDATA"."PACKING"';
comment on column ods."/rusal/shipdata_ral".cust2_id is '№ конечного покупателя в SAP | № конечного покупателя в SAP | stg."/RUSAL/SHIPDATA"."CUST2_ID"';
comment on column ods."/rusal/shipdata_ral".potrebit is 'Потребитель | Потребитель | stg."/RUSAL/SHIPDATA"."POTREBIT"';
comment on column ods."/rusal/shipdata_ral".exporter is 'Экспортер | Экспортер | stg."/RUSAL/SHIPDATA"."EXPORTER"';
comment on column ods."/rusal/shipdata_ral".locid is 'Порт (код) | Порт (код) | stg."/RUSAL/SHIPDATA"."LOCID"';
comment on column ods."/rusal/shipdata_ral".vsart is 'Wagon/container | Wagon/container | stg."/RUSAL/SHIPDATA"."VSART"';
comment on column ods."/rusal/shipdata_ral".datapgp is 'Дата пересечения границы вагоном | Дата пересечения границы вагоном | stg."/RUSAL/SHIPDATA"."DATAPGP"';
comment on column ods."/rusal/shipdata_ral".contr_id is 'Системный номер договора завода-производителя | Системный номер договора завода-производителя | stg."/RUSAL/SHIPDATA"."CONTR_ID"';
comment on column ods."/rusal/shipdata_ral".brutto is 'Вес брутто | Вес брутто | stg."/RUSAL/SHIPDATA"."BRUTTO"';
comment on column ods."/rusal/shipdata_ral".netto is 'Вес нетто | Вес нетто | stg."/RUSAL/SHIPDATA"."NETTO"';
comment on column ods."/rusal/shipdata_ral".werks_nosap is 'Завод не в САП | Завод не в САП | stg."/RUSAL/SHIPDATA"."WERKS_NOSAP"';
comment on column ods."/rusal/shipdata_ral".svh is 'Завод не в САП | Завод не в САП | stg."/RUSAL/SHIPDATA"."SVH"';
comment on column ods."/rusal/shipdata_ral".posnr_lf is 'Позиция поставки завода собственника | Позиция поставки завода собственника | stg."/RUSAL/SHIPDATA"."POSNR_LFS"';
