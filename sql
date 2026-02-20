Предметная область: LE

Источник: АСУ ЖДЦ
Стенд: PROD;
1 часть . Загрузка из landing в dict_stg

Необходимо настроить на ПРОД загрузку таблиц из landing в stg по расписанию ежедневно.

Загрузка в landing :

1. 19:00
2. 20:00
3. 22:00
4. 00:00,

загрузка в dict_stg

1. 19:10
2. 20:10
3. 22:10
4. 00:10,

Скрипты настроены, грузим , если есть новые uuid. Нужно перенести с ДЕВ таблицы и поставить на расписание:

1.      Партии учета транспортных средств stg.asuzdc_rwcar_parts  (Код потока КХД: SI_GdcVehicleBatchTracking_AI)

2.      Расширение данных по партиям учета транспортных средств (1 к 1 с партиями) stg.asuzdc_rwcar_date_control (Код потока КХД: SI_GdcVehicleBatchExtension_AI)

3.      Строки документов stg.asuzdc_docs_cars (Код потока КХД: SI_GdcVehicleDocRow_AI)

4.      Оперативная таблица текущего наличия/расположения транспортных средств stg.asuzdc_rwcar_location (Код потока КХД: SI_GdcVehicleLocation_AI)

2 часть. Загрузка из stg в ods

Партии учета транспортных средств ods.asuzdc_rwcar_parts Инкрементальная загрузка.

Ключ: rw_part

Важно!! Таблица не транкейтится. Добавляется/удаляется инкремент.

1.1 Перенести историю с ДЕВ

1.2 Настроить ежедневное обновление. Скрипт:ods/ods.asuzdc_rwcar_parts.sql · main · dwh_analyst / Sql Queries Storage · GitLab

2. Расширение данных по партиям учета транспортных средств (1 к 1 с партиями) ods.asuzdc_rwcar_date_control Инкрементальная загрузка.

Ключ:rw_part,dt_insert

Важно!! Таблица не транкейтится. Добавляется/удаляется инкремент.

2.1 Перенести историю с ДЕВ

2.2 Настроить ежедневное обновление. Скрипт: ods/ods.asuzdc_rwcar_date_control.sql · main · dwh_analyst / Sql Queries Storage · GitLab

Строки документов ods.asuzdc_docs_cars Инкрементальная загрузка.

Ключ: rn_dcr, dt_insert

Важно!! Таблица не транкейтится. Добавляется/удаляется инкремент.

3.1 Перенести историю с ДЕВ

3.2 Настроить ежедневное обновление. Скрипт:ods/ods.asuzdc_docs_cars.sql · main · dwh_analyst / Sql Queries Storage · GitLab

4. Оперативная таблица текущего наличия/расположения транспортных средств ods.asuzdc_rwcar_location Инкрементальная загрузка

Ключ: rw_part,dt_report,dt_insert

Важно!! Справочник не транкейтится. Добавляется/удаляется инкремент.

3.1 Перенести историю с ДЕВ

3.2 Настроить ежедневное обновление. Скрипт:ods/ods.asuzdc_rwcar_location.sql · main · dwh_analyst / Sql Queries Storage · GitLab

Ссылка на статью релиза: Статусы по задачам (2026-02-25) LE+MM+FI | База знаний

CREATE TABLE if not exists ods.asuzdc_rwcar_parts( 
    rw_part varchar NULL,				-- ID партии
   kpr_home varchar NULL,			    -- ID предприятия регистрации партии (HENTER)
   car_num varchar NULL,				-- Номер вагона/контейнера (HRW_CARS)
   car_type varchar NULL,   			-- Тип т/с (1)-локомотив (2)-вагон (3)-контейнер
   tara varchar NULL,				    -- Тара
   tonnage numeric(6,2) NULL,			-- Грузоподъемность
   kpr_owner varchar NULL, 			    -- ID предприятия собственника (HENTER)
   kpr_rent varchar NULL,			    -- ID оператора (HENTER)
   pr_exp varchar NULL,				    -- Признак годности отправки на экспорт
   id_shipdir varchar NULL,			    -- Направление
   rw_kg_load varchar NULL,			    -- Код груза под погрузку (HCARGO)
   dt_start_rzd timestamp NULL, 
   dt_start_ppgt timestamp NULL, 
   pr_pay_use varchar NULL, 
   weight_in numeric(6,0) NULL,			-- Вес груженого вагона по прибыти по перевеске
   weight_out numeric(6,0) NULL,		-- Вес гружегного вагона на отправку по перевеске
   weight_tara numeric(6,0) NULL,		-- Вес тары по перевеске
   etran_rw_st varchar NULL, 
   etran_doc_num varchar NULL, 
   rw_zpu varchar NULL,				   -- ID ЗПУ 1_4 (HRWZPU_TYPE)
   zpu_num varchar NULL,			   -- Номера ЗПУ 1_4(через запятую)
   ref_part varchar NULL,			   -- ID партии с предыдушего предприятия (при отправках внутри компании)
   part_prim varchar NULL, 			   -- Примечание (выводится в операциях и наличии)
   car_viewer varchar NULL,			   -- Осмотрщик вагона. ID_LIST = 43 из HGH_LIST
   cert_num varchar NULL,			   -- Номер свидетельства (номер слива для цистерны)
   zznp varchar NULL,				   -- Номер плана перевозок
   dt_start_svh timestamp NULL,		   -- Дата постановки на СВХ
   dt_end_svh timestamp NULL,		   -- Дата выдачи с СВХ
   gtd varchar NULL,				   -- Декларация по входящему грузу
   dt_gtd timestamp NULL,			   -- Дата декларации
   order_num varchar NULL,			   -- Номер заказа ЦК
   tara_last_clear varchar NULL, 	   -- Тара фактическая после последней очистки вагона
   rw_kg_operload varchar NULL,		   -- Код груза из операции погрузки (HCARGO)
   pr_zd varchar NULL,				   -- Признак направления на пути ЖД ID_LIST = 85 из HGH_LIST
   rw_zpu5_8 varchar NULL,			   -- ID ЗПУ (HRWZPU_TYPE)
   zpu_num5_8 varchar NULL,			   -- Номера ЗПУ 5_8 (через запятую)
   pr_out varchar NULL,				   -- Признак отправки п/м hgh_list 90
   dt_out_beg timestamp NULL,		   -- Период отправки от даты
   k_luk numeric(6,0) NULL,			   -- Количество люков hgh_list 91
   dt_out_end timestamp NULL,		   -- Период отправки до даты
   pr_accepted varchar NULL,		   -- Признак - вагон принят приемосдатчиком
   pr_clean varchar NULL,			   -- Признак зачистки
   id_cargo_form varchar NULL,		   -- Код формы продукции из операции погрузки HCARGO_FROM ID_ROW
   pr_transit varchar NULL,			   -- Признак транзитного вагона, без оформления памяток
   kpr_occup varchar NULL,			   -- ID предприятия арендатора (местный подсыл)
   dt_gdc_in timestamp NULL,		   -- Дата прибытия на станцию/Дата создания партии
   explanation varchar NULL,		   -- Пояснение
   id_expl_wrk varchar NULL,		   -- Причина простоя завода
   id_expl_ctrl varchar NULL,		   -- Причина простоя контролера
   pr_ret_by_load varchar NULL,		   -- Признак возврата по погрузке
   rgb varchar NULL,				   -- Раскраска номера вагона
   silos varchar NULL,				   -- Номер силоса погрузки глинозема
   weight_tara_in numeric(6,0) NULL,   -- Тара фактическая с первого взвешивания
   load_cargo_prim varchar NULL,	   -- Дополнительная информация по грузу погрузки
   raspor varchar NULL,				   -- Номер распоряжения
   foreign_seaport_id varchar NULL,	   -- Код внешнего (заграничного) порта
   kpr_buyer varchar NULL,			   -- Код покупателя (для контейнеров)
   kpr_seaport_trans varchar NULL,	   -- Код экспедитора в порту РФ
   id_mdm_home varchar NULL, 		   -- Код предприятия по справочнику SAP MDM
   id_mdm_owner varchar NULL,		   -- Код собственника по справочнику SAP MDM
   id_mdm_rent varchar NULL,		   -- Код оператора по справочнику SAP MDM
   dsp_id varchar NULL,				   -- Ссылка на пакет документов на отправку
   check_bit varchar NULL,			   -- Битовая маска подтвержденных документов с пакета
   dt_del timestamp NULL,              -- Дата удаления
   uuid varchar NOT NULL,
   record_id int4 NOT NULL,
   dt_insert timestamp NOT NULL,    --Дата загрузки в stg из lending
   create_date_time timestamp NOT NULL,
   dttm_inserted timestamp NOT NULL DEFAULT now(),
   dttm_updated timestamp NOT NULL DEFAULT now(),
   job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
   deleted_flag bool NOT NULL DEFAULT false
) 
with (
	appendonly = true,
	orientation = column,
	compresstype = zstd,
	compresslevel = 3
)
distributed by (rw_part,dt_insert);
COMMENT ON TABLE ods.asuzdc_rwcar_parts IS 'Партии учета транспортных средств';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.rw_part IS 'ID партии';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.kpr_home IS 'ID предприятия регистрации партии (HENTER)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.car_num IS 'Номер вагона/контейнера (HRW_CARS)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.car_type IS 'Тип т/с (1)-локомотив (2)-вагон (3)-контейнер';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.tara IS 'Тара';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.tonnage IS 'Грузоподъемность';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.kpr_owner IS 'ID предприятия собственника (HENTER)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.kpr_rent IS 'ID оператора (HENTER)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.pr_exp IS 'Признак годности отправки на экспорт';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.id_shipdir IS 'Направление';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.rw_kg_load IS 'Код груза под погрузку (HCARGO)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.weight_in IS 'Вес груженого вагона по прибыти по перевеске';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.weight_out IS 'Вес гружегного вагона на отправку по перевеске';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.weight_tara IS 'Вес тары по перевеске';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.rw_zpu IS 'ID ЗПУ 1_4 (HRWZPU_TYPE)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.zpu_num IS 'Номера ЗПУ 1_4(через запятую)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.ref_part IS 'ID партии с предыдушего предприятия (при отправках внутри компании)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.part_prim IS 'Примечание (выводится в операциях и наличии)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.car_viewer IS 'Осмотрщик вагона. ID_LIST = 43 из HGH_LIST';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.cert_num IS 'Номер свидетельства (номер слива для цистерны)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.zznp IS 'Номер плана перевозок';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.dt_start_svh IS 'Дата постановки на СВХ';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.dt_end_svh IS 'Дата выдачи с СВХ';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.gtd IS 'Декларация по входящему грузу';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.dt_gtd IS 'Дата декларации';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.order_num IS 'Номер заказа ЦК';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.tara_last_clear IS 'Тара фактическая после последней очистки вагона';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.rw_kg_operload IS 'Код груза из операции погрузки (HCARGO)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.pr_zd IS 'Признак направления на пути ЖД ID_LIST = 85 из HGH_LIST';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.rw_zpu5_8 IS 'ID ЗПУ (HRWZPU_TYPE)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.zpu_num5_8 IS 'Номера ЗПУ 5_8 (через запятую)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.pr_out IS 'Признак отправки п/м hgh_list 90';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.dt_out_beg IS 'Период отправки от даты';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.k_luk IS 'Количество люков hgh_list 91';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.dt_out_end IS 'Период отправки до даты';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.pr_accepted IS 'Признак - вагон принят приемосдатчиком';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.pr_clean IS 'Признак зачистки';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.id_cargo_form IS 'Код формы продукции из операции погрузки HCARGO_FROM ID_ROW';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.pr_transit IS 'Признак транзитного вагона, без оформления памяток';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.kpr_occup IS 'ID предприятия арендатора (местный подсыл)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.dt_gdc_in IS 'Дата прибытия на станцию/Дата создания партии';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.explanation IS 'Пояснение';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.id_expl_wrk IS 'Причина простоя завода';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.id_expl_ctrl IS 'Причина простоя контролера';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.pr_ret_by_load IS 'Признак возврата по погрузке';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.rgb IS 'Раскраска номера вагона';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.silos IS 'Номер силоса погрузки глинозема';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.weight_tara_in IS 'Тара фактическая с первого взвешивания';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.load_cargo_prim IS 'Дополнительная информация по грузу погрузки';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.raspor IS 'Номер распоряжения';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.foreign_seaport_id IS 'Код внешнего (заграничного) порта';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.kpr_buyer IS 'Код покупателя (для контейнеров)';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.kpr_seaport_trans IS 'Код экспедитора в порту РФ';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.id_mdm_home IS 'Код предприятия по справочнику SAP MDM';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.id_mdm_owner IS 'Код собственника по справочнику SAP MDM';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.id_mdm_rent IS 'Код оператора по справочнику SAP MDM';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.dsp_id IS 'Ссылка на пакет документов на отправку';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.check_bit IS 'Битовая маска подтвержденных документов с пакета';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.dt_del IS 'Дата удаления';
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.uuid IS 'Уникальный номер пакета в системе АСУ ЖДЦ';   
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.record_id IS 'Идентификатор загрузки определяется уникальность по dt_report'; 
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.create_date_time IS 'Дата загрузки данных в landing';   
COMMENT ON COLUMN ods.asuzdc_rwcar_parts.create_date_time IS 'дата и время отправки пакета из АСу ЖДЦ в SAP XI';   
----Ежедневный скрипт
  --ШАГ 1
  --Удаляются из ods все записи, которые есть в новом инкременте. 
  --Данные определяются по rw_part пришедшие в последнем инкременте. 
  --Инкремент определяется по dt_insert в stg большей максимальной dt_insert в ods в разрезе rw_part
  --НА этом шаге мы удаляем измененные записи и удаленные из ods
  delete from ods.asuzdc_rwcar_parts 
   where rw_part in (select rw_part from ods.asuzdc_rwcar_parts car --33 684 новых
   inner join (select cars1.*, --210 045
               row_number() over (partition by "RW_PART" order by dt_insert desc) as rn
  from stg.asuzdc_rwcar_parts as cars1
  where dt_insert>(select max(dt_insert) from ods.asuzdc_rwcar_parts))ttt
  on car.rw_part=ttt."RW_PART" and ttt.rn=1);

 --В ods добавляются данные последнего инкремента из stg, где дата удаления пустая
  --Наданном шаге добавляем новые данные, обновленные, не включаем удаленные, которые были удалены из ods на 1-ом шаге  

insert into ods.asuzdc_rwcar_parts(
   rw_part,				-- ID партии
   kpr_home,			-- ID предприятия регистрации партии (HENTER)
   car_num,				-- Номер вагона/контейнера (HRW_CARS)
   car_type,   			-- Тип т/с (1)-локомотив (2)-вагон (3)-контейнер
   tara,				-- Тара
   tonnage,				-- Грузоподъемность
   kpr_owner, 			-- ID предприятия собственника (HENTER)
   kpr_rent,			-- ID оператора (HENTER)
   pr_exp,				-- Признак годности отправки на экспорт
   id_shipdir,			-- Направление
   rw_kg_load,			-- Код груза под погрузку (HCARGO)
   dt_start_rzd, 
   dt_start_ppgt, 
   pr_pay_use, 
   weight_in,			-- Вес груженого вагона по прибыти по перевеске
   weight_out,			-- Вес гружегного вагона на отправку по перевеске
   weight_tara,			-- Вес тары по перевеске
   etran_rw_st, 
   etran_doc_num, 
   rw_zpu,				-- ID ЗПУ 1_4 (HRWZPU_TYPE)
   zpu_num,				-- Номера ЗПУ 1_4(через запятую)
   ref_part,			-- ID партии с предыдушего предприятия (при отправках внутри компании)
   part_prim, 			-- Примечание (выводится в операциях и наличии)
   car_viewer,			-- Осмотрщик вагона. ID_LIST = 43 из HGH_LIST
   cert_num,			-- Номер свидетельства (номер слива для цистерны)
   zznp,				-- Номер плана перевозок
   dt_start_svh,		-- Дата постановки на СВХ
   dt_end_svh,			-- Дата выдачи с СВХ
   gtd,					-- Декларация по входящему грузу
   dt_gtd,				-- Дата декларации
   order_num,			-- Номер заказа ЦК
   tara_last_clear, 	-- Тара фактическая после последней очистки вагона
   rw_kg_operload,		-- Код груза из операции погрузки (HCARGO)
   pr_zd,				-- Признак направления на пути ЖД ID_LIST = 85 из HGH_LIST
   rw_zpu5_8,			-- ID ЗПУ (HRWZPU_TYPE)
   zpu_num5_8,			-- Номера ЗПУ 5_8 (через запятую)
   pr_out,				-- Признак отправки п/м hgh_list 90
   dt_out_beg,			-- Период отправки от даты
   k_luk,				-- Количество люков hgh_list 91
   dt_out_end,			-- Период отправки до даты
   pr_accepted,			-- Признак - вагон принят приемосдатчиком
   pr_clean,			-- Признак зачистки
   id_cargo_form,		-- Код формы продукции из операции погрузки HCARGO_FROM ID_ROW
   pr_transit,			-- Признак транзитного вагона, без оформления памяток
   kpr_occup,			-- ID предприятия арендатора (местный подсыл)
   dt_gdc_in,			-- Дата прибытия на станцию/Дата создания партии
   explanation,			-- Пояснение
   id_expl_wrk,			-- Причина простоя завода
   id_expl_ctrl,		-- Причина простоя контролера
   pr_ret_by_load,		-- Признак возврата по погрузке
   rgb,					-- Раскраска номера вагона
   silos,				-- Номер силоса погрузки глинозема
   weight_tara_in,		-- Тара фактическая с первого взвешивания
   load_cargo_prim,		-- Дополнительная информация по грузу погрузки
   raspor,				-- Номер распоряжения
   foreign_seaport_id,	-- Код внешнего (заграничного) порта
   kpr_buyer,			-- Код покупателя (для контейнеров)
   kpr_seaport_trans,	-- Код экспедитора в порту РФ
   id_mdm_home, 		-- Код предприятия по справочнику SAP MDM
   id_mdm_owner,		-- Код собственника по справочнику SAP MDM
   id_mdm_rent,			-- Код оператора по справочнику SAP MDM
   dsp_id,				-- Ссылка на пакет документов на отправку
   check_bit,			-- Битовая маска подтвержденных документов с пакета
   dt_del,               --Дата удаления
   uuid,
   record_id,
   dt_insert,            --Дата загрузки в stg из lending
   create_date_time
   )
select 
    tech_etl.util_text_to_null_validation("RW_PART") as rw_part,			    	-- ID партии
   tech_etl.util_text_to_null_validation("KPR_HOME") as kpr_home,			    -- ID предприятия регистрации партии (HENTER)
   tech_etl.util_text_to_null_validation("CAR_NUM") as car_num,			     	-- Номер вагона/контейнера (HRW_CARS)
   tech_etl.util_text_to_null_validation("CAR_TYPE") as car_type,   			-- Тип т/с (1)-локомотив (2)-вагон (3)-контейнер
   tech_etl.util_text_to_null_validation("TARA") as tara,				        -- Тара
   REPLACE("TONNAGE", ',', '.')::numeric as tonnage,		                	-- Грузоподъемность
   tech_etl.util_text_to_null_validation("KPR_OWNER") as kpr_owner, 		    -- ID предприятия собственника (HENTER)
   tech_etl.util_text_to_null_validation("KPR_RENT") as kpr_rent,			    -- ID оператора (HENTER)
   tech_etl.util_text_to_null_validation("PR_EXP") as pr_exp,				    -- Признак годности отправки на экспорт
   tech_etl.util_text_to_null_validation("ID_SHIPDIR") as id_shipdir,			-- Направление
   tech_etl.util_text_to_null_validation("RW_KG_LOAD") as rw_kg_load,			-- Код груза под погрузку (HCARGO)
   "DT_START_RZD"::timestamp as dt_start_rzd,
   "DT_START_PPGT"::timestamp as dt_start_ppgt, 
   tech_etl.util_text_to_null_validation("PR_PAY_USE") as pr_pay_use, 
   REPLACE("WEIGHT_IN", ',', '.')::numeric as weight_in,		            	-- Вес груженого вагона по прибыти по перевеске
   REPLACE("WEIGHT_OUT", ',', '.')::numeric as weight_out,	                	-- Вес гружегного вагона на отправку по перевеске
   REPLACE("WEIGHT_TARA", ',', '.')::numeric as weight_tara,	            	-- Вес тары по перевеске
   tech_etl.util_text_to_null_validation("ETRAN_RW_ST") as etran_rw_st,
   tech_etl.util_text_to_null_validation("ETRAN_DOC_NUM") as etran_doc_num, 
   tech_etl.util_text_to_null_validation("RW_ZPU") as rw_zpu,	   			    -- ID ЗПУ 1_4 (HRWZPU_TYPE)
   tech_etl.util_text_to_null_validation("ZPU_NUM") as zpu_num,			        -- Номера ЗПУ 1_4(через запятую)
   tech_etl.util_text_to_null_validation("REF_PART") as ref_part,			    -- ID партии с предыдушего предприятия (при отправках внутри компании)
   tech_etl.util_text_to_null_validation("PART_PRIM") as part_prim, 			-- Примечание (выводится в операциях и наличии)
   tech_etl.util_text_to_null_validation("CAR_VIEWER") as car_viewer,			-- Осмотрщик вагона. ID_LIST = 43 из HGH_LIST
   tech_etl.util_text_to_null_validation("CERT_NUM") as cert_num,			    -- Номер свидетельства (номер слива для цистерны)
   tech_etl.util_text_to_null_validation("ZZNP") as zznp,				        -- Номер плана перевозок
   "DT_START_SVH"::timestamp as dt_start_svh,		-- Дата постановки на СВХ
   "DT_END_SVH"::timestamp as dt_end_svh,			-- Дата выдачи с СВХ
   tech_etl.util_text_to_null_validation("GTD") as gtd,				            -- Декларация по входящему грузу
   "DT_GTD"::timestamp as dt_gtd,				    -- Дата декларации
   tech_etl.util_text_to_null_validation("ORDER_NUM") as order_num,			    -- Номер заказа ЦК
   tech_etl.util_text_to_null_validation("TARA_LAST_CLEAR") as tra_last_clear, 	-- Тара фактическая после последней очистки вагона
   tech_etl.util_text_to_null_validation("RW_KG_OPERLOAD") as rw_kg_operload,   -- Код груза из операции погрузки (HCARGO)
   tech_etl.util_text_to_null_validation("PR_ZD") as pr_zd,				        -- Признак направления на пути ЖД ID_LIST = 85 из HGH_LIST
   tech_etl.util_text_to_null_validation("RW_ZPU5_8") as rw_zpu5_8,			    -- ID ЗПУ (HRWZPU_TYPE)
   tech_etl.util_text_to_null_validation("ZPU_NUM5_8") as zpu_num5_8,			-- Номера ЗПУ 5_8 (через запятую)
   tech_etl.util_text_to_null_validation("PR_OUT") as pr_out,				    -- Признак отправки п/м hgh_list 90
   "DT_OUT_BEG"::timestamp as dt_out_beg,			-- Период отправки от даты
   REPLACE("K_LUK", ',', '.')::numeric as k_luk,			                    -- Количество люков hgh_list 91
   "DT_OUT_END"::timestamp as dt_out_end,		    -- Период отправки до даты
   tech_etl.util_text_to_null_validation("PR_ACCEPTED") as pr_accepted,		    -- Признак - вагон принят приемосдатчиком
   tech_etl.util_text_to_null_validation("PR_CLEAN") as pr_clean,			    -- Признак зачистки
   tech_etl.util_text_to_null_validation("ID_CARGO_FORM") as id_cargo_form,		-- Код формы продукции из операции погрузки HCARGO_FROM ID_ROW
   tech_etl.util_text_to_null_validation("PR_TRANSIT") as pr_transit,			-- Признак транзитного вагона, без оформления памяток
   tech_etl.util_text_to_null_validation("KPR_OCCUP") as kpr_occup,			    -- ID предприятия арендатора (местный подсыл)
   "DT_GDC_IN"::timestamp as dt_gdc_in,			    -- Дата прибытия на станцию/Дата создания партии
   tech_etl.util_text_to_null_validation("EXPLANATION") as explanation,		    -- Пояснение
   tech_etl.util_text_to_null_validation("ID_EXPL_WRK") as id_expl_wrk,		    -- Причина простоя завода
   tech_etl.util_text_to_null_validation("ID_EXPL_CTRL") as id_expl_ctrl,		-- Причина простоя контролера
   tech_etl.util_text_to_null_validation("PR_RET_BY_LOAD") as pr_ret_by_load,   -- Признак возврата по погрузке
   tech_etl.util_text_to_null_validation("RGB") as rgb,				            -- Раскраска номера вагона
   tech_etl.util_text_to_null_validation("SILOS") as silos,				        -- Номер силоса погрузки глинозема
   REPLACE("WEIGHT_TARA_IN", ',', '.')::numeric as weight_tara_in,              -- Тара фактическая с первого взвешивания
   tech_etl.util_text_to_null_validation("LOAD_CARGO_PRIM") as load_cargo_prim,	-- Дополнительная информация по грузу погрузки
   tech_etl.util_text_to_null_validation("RASPOR") as raspor,				    -- Номер распоряжения
   tech_etl.util_text_to_null_validation("FOREIGN_SEAPORT_ID") as foreign_seaport_id, -- Код внешнего (заграничного) порта
   tech_etl.util_text_to_null_validation("KPR_BUYER") as kpr_buyer,			    -- Код покупателя (для контейнеров)
   tech_etl.util_text_to_null_validation("KPR_SEAPORT_TRANS") as kpr_seaport_trans,	  -- Код экспедитора в порту РФ
   tech_etl.util_text_to_null_validation("ID_MDM_HOME") as id_mdm_home, 		-- Код предприятия по справочнику SAP MDM
   tech_etl.util_text_to_null_validation("ID_MDM_OWNER") as id_mdm_owne,		-- Код собственника по справочнику SAP MDM
   tech_etl.util_text_to_null_validation("ID_MDM_RENT") as id_mdm_rent,		    -- Код оператора по справочнику SAP MDM
   tech_etl.util_text_to_null_validation("DSP_ID") as dsp_id,				    -- Ссылка на пакет документов на отправку
   tech_etl.util_text_to_null_validation("CHECK_BIT") as check_bit,			    -- Битовая маска подтвержденных документов с пакета
   "DT_DEL"::timestamp as dt_del,                                               -- Дата удаления
   uuid,
   record_id,
   dt_insert,                                                                    --Дата загрузки в stg из lending
   create_date_time
from (select *
  from
  (select cars.*,
  row_number() over (partition by "RW_PART" order by dt_insert desc) as rn
  from stg.asuzdc_rwcar_parts as cars
  where dt_insert>coalesce((SELECT MAX(dt_insert) FROM ods.asuzdc_rwcar_parts),'1900-01-01'::timestamp) and "DT_DEL" is null)tt --and "RN_DCR"='87118511'
  where tt.rn=1)ttt;
 
   
