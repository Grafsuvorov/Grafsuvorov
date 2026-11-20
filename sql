Функция создаёт или пересоздаёт объект в DEV и формирует SQL для последующей загрузки.
Схема target

stg
Таблица target
BIP_/BIC/ATR_T013000
Совпадений нет — будет создана новая таблица.
Выберите существующую — её поля подставятся автоматически.
Схема источника
SAPSR3
Таблица источника
/BIC/ATR_TO13000
Сущность / расписание
TRANSPORTATION
Несколько сущностей: через запятую. Для каждой будет создан отдельный YAML в одном MR.
Первичный ключ
REQUEST, DATAPAKID, RECORD
Несколько полей: через || или запятую.
Поля
ALL
Можно добавлять и удалять поля перед повторным запуском.
Ключ распределения
RN
Сервер источника

oracle_sap_bi_prod · ID 2
Сгенерировать в DEV
Некорректное значение поля «Таблица источника»


вот вручную нормально вызвлось 
SELECT tech_etl.etl_source_to_greenplum_new(
    v_source_schema_name := 'SAPSR3',
    v_source_table_name  := '/BIC/ATR_TO13000',
    v_fields_list        := 'ALL',
    v_target_schema_name := 'STG',
    v_target_table_name  := 'BIP_/BIC/ATR_T013000',
    v_server_id          := '2',
    v_distribution_field := 'RN',
    v_pk                 := '"REQUEST" || "DATAPAKID" || "RECORD"');


Status: Starting loading
v_source_schema_name: SAPSR3
v_source_table_name: /BIC/ATR_TO13000
v_fields_list: ALL
v_target_schema_name: STG
v_target_table_name: BIP_/BIC/ATR_T013000
v_source_server_name: oracle_sap_bi_prod
l_script_name: BIP__BIC_ATR_T013000
Query to get columns: select tech_etl.get_source_table_fields_oracle
 (v_source_schema_name := 'SAPSR3', 
 v_source_table_name := '/BIC/ATR_TO13000', 
 v_source_server_name := 'oracle_sap_bi_prod', 
 v_cols_table := 'tech_etl.v_all_tab_cols_ora_sap_bi_prod' 
)
QUERY FOR ALL COLUMNS: select string_agg(column_name,',')    from tech_etl.v_all_tab_cols_ora_sap_bi_prod WHERE true  AND table_name =  '/BIC/ATR_TO13000'  AND owner = 'SAPSR3'
ALL COLUMNS: REQUEST,/BIC/ZTRSRVTYP,DATAPAKID,RECORD,RECORDMODE,/BIC/ZDATE_S,/BIC/ZREAL_D,/BIC/ZMARKET,/BIC/TRSHIPTYP,PLANT,/BIC/ZKNOTEGRI,/BIC/ZKNOTEGRT,/BIC/ZKNOTEINT,/BIC/ZKNOTEFNL,/BIC/ZSDABW,/BIC/ZTREXPETY,/BIC/TRSDABWPR,/BIC/ZCOUNTRY2,/BIC/ZREGION2,/BIC/ZCOUNTRYF,/BIC/ZREGION,/BIC/TRDESTOUT,/BIC/TRDESTIN,/BIC/TRINCO1FB,DIVISION,/BIC/ZTRATY,/BIC/TRDAY_2,/BIC/TRDAY_4,MATL_GRP_4,/BIC/TRBORDCRP,/BIC/TRINCO2FB,/BIC/ZKF,/BIC/ZTRMONTH,/BIC/ZQUANTITY,/BIC/ZWEIGHT,AMOUNT,CURRENCY
ALL COLUMNS: REQUEST,/BIC/ZTRSRVTYP,DATAPAKID,RECORD,RECORDMODE,/BIC/ZDATE_S,/BIC/ZREAL_D,/BIC/ZMARKET,/BIC/TRSHIPTYP,PLANT,/BIC/ZKNOTEGRI,/BIC/ZKNOTEGRT,/BIC/ZKNOTEINT,/BIC/ZKNOTEFNL,/BIC/ZSDABW,/BIC/ZTREXPETY,/BIC/TRSDABWPR,/BIC/ZCOUNTRY2,/BIC/ZREGION2,/BIC/ZCOUNTRYF,/BIC/ZREGION,/BIC/TRDESTOUT,/BIC/TRDESTIN,/BIC/TRINCO1FB,DIVISION,/BIC/ZTRATY,/BIC/TRDAY_2,/BIC/TRDAY_4,MATL_GRP_4,/BIC/TRBORDCRP,/BIC/TRINCO2FB,/BIC/ZKF,/BIC/ZTRMONTH,/BIC/ZQUANTITY,/BIC/ZWEIGHT,AMOUNT,CURRENCY
ALL FIELDS REQUEST,/BIC/ZTRSRVTYP,DATAPAKID,RECORD,RECORDMODE,/BIC/ZDATE_S,/BIC/ZREAL_D,/BIC/ZMARKET,/BIC/TRSHIPTYP,PLANT,/BIC/ZKNOTEGRI,/BIC/ZKNOTEGRT,/BIC/ZKNOTEINT,/BIC/ZKNOTEFNL,/BIC/ZSDABW,/BIC/ZTREXPETY,/BIC/TRSDABWPR,/BIC/ZCOUNTRY2,/BIC/ZREGION2,/BIC/ZCOUNTRYF,/BIC/ZREGION,/BIC/TRDESTOUT,/BIC/TRDESTIN,/BIC/TRINCO1FB,DIVISION,/BIC/ZTRATY,/BIC/TRDAY_2,/BIC/TRDAY_4,MATL_GRP_4,/BIC/TRBORDCRP,/BIC/TRINCO2FB,/BIC/ZKF,/BIC/ZTRMONTH,/BIC/ZQUANTITY,/BIC/ZWEIGHT,AMOUNT,CURRENCY
Garbage: t
Query to get ddl: select tech_etl.generate_greenplum_target_statement_ddl_oracle
 (v_source_schema_name := 'SAPSR3', 
 v_source_table_name := '/BIC/ATR_TO13000', 
 v_fields_list := 'REQUEST,/BIC/ZTRSRVTYP,DATAPAKID,RECORD,RECORDMODE,/BIC/ZDATE_S,/BIC/ZREAL_D,/BIC/ZMARKET,/BIC/TRSHIPTYP,PLANT,/BIC/ZKNOTEGRI,/BIC/ZKNOTEGRT,/BIC/ZKNOTEINT,/BIC/ZKNOTEFNL,/BIC/ZSDABW,/BIC/ZTREXPETY,/BIC/TRSDABWPR,/BIC/ZCOUNTRY2,/BIC/ZREGION2,/BIC/ZCOUNTRYF,/BIC/ZREGION,/BIC/TRDESTOUT,/BIC/TRDESTIN,/BIC/TRINCO1FB,DIVISION,/BIC/ZTRATY,/BIC/TRDAY_2,/BIC/TRDAY_4,MATL_GRP_4,/BIC/TRBORDCRP,/BIC/TRINCO2FB,/BIC/ZKF,/BIC/ZTRMONTH,/BIC/ZQUANTITY,/BIC/ZWEIGHT,AMOUNT,CURRENCY', 
 v_target_schema_name := 'STG', 
 v_target_table_name := 'BIP_/BIC/ATR_T013000', 
 v_source_server_name := 'oracle_sap_bi_prod', 
 v_cols_table := 'tech_etl.v_all_tab_cols_ora_sap_bi_prod', 
 v_distribution_field := 'RN' 
)
Query in tech_etl.generate_greenplum_target_statement_with_fields:  SELECT CONCAT( 'DROP TABLE IF EXISTS ' ,'STG."BIP_/BIC/ATR_T013000"'  ,' CASCADE ;'
 , REPLACE( CONCAT(chr(10), CONCAT( 'create table ','STG."BIP_/BIC/ATR_T013000"', ' (' || chr( 10 ) , string_agg(CONCAT( quote_ident(UPPER( REPLACE( column_name, '"', '' ) ) ), ' ',  CASE  WHEN (
data_type = 'NUMBER'  AND data_precision >=19  AND (
data_scale =0  OR data_scale IS NULL
) )  THEN 'numeric'  WHEN (
data_type = 'NUMBER'  AND data_precision <19  AND (
data_scale =0  OR data_scale IS NULL
) )  THEN 'bigint'  WHEN (
data_type = 'NUMBER'  AND data_precision <10  AND (
data_scale =0  OR data_scale IS NULL
) )  THEN 'integer'  WHEN (
data_type = 'NUMBER'  AND data_precision <5  AND (
data_scale =0  OR data_scale IS NULL
) )  THEN 'smallint'  WHEN data_type = 'INTEGER'  THEN 'decimal(38)'  WHEN data_type = 'SMALLINT'  THEN 'decimal(38)'  WHEN data_type = 'DOUBLE PRECISION'  THEN 'double precision'  WHEN data_type = 'FLOAT'  THEN 'double precision'  WHEN data_type = 'REAL'  THEN 'double precision'  WHEN data_type = 'NUMBER'  AND data_scale >0  THEN 'decimal(' || data_precision || chr( 44 ) || data_scale || ')'  WHEN data_type = 'NUMBER'  AND data_scale >0  THEN 'double precision'  WHEN data_type = 'NUMBER'  OR data_type = 'NUMERIC'  THEN 'numeric'  WHEN data_type = 'CHAR'  THEN 'char(' || data_length || ')'  WHEN data_type = 'CHARACTER'  THEN 'char(' || data_length || ')'  WHEN data_type = 'VARCHAR'  THEN 'varchar(' || data_length || ')'  WHEN data_type = 'VARCHAR2'  THEN 'varchar(' || data_length || ')'  WHEN data_type = 'LONG'  THEN 'text'  WHEN data_type = 'NCLOB'  THEN 'text'  WHEN data_type = 'DATE'  THEN 'date'  WHEN data_type = 'TIMESTAMP'  THEN 'timestamp'  WHEN data_type = 'RAW'  THEN 'text'  ELSE 'text'  END ,  CASE WHEN nullable = 'Y'  THEN ' NULL'  ELSE ' NULL'  END ) , ', '  ORDER BY column_id
), ',' || ' "RN" integer NOT NULL) ' || chr( 10 ) , 'WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
) DISTRIBUTED BY("RN");'
)
), 'NULL,', 'NULL,' || chr( 10 )
)
) AS table_ddl  FROM tech_etl.v_all_tab_cols_ora_sap_bi_prod 
 WHERE true  AND table_name =  '/BIC/ATR_TO13000'  AND owner = 'SAPSR3' AND column_name = any( string_to_array( 'REQUEST,/BIC/ZTRSRVTYP,DATAPAKID,RECORD,RECORDMODE,/BIC/ZDATE_S,/BIC/ZREAL_D,/BIC/ZMARKET,/BIC/TRSHIPTYP,PLANT,/BIC/ZKNOTEGRI,/BIC/ZKNOTEGRT,/BIC/ZKNOTEINT,/BIC/ZKNOTEFNL,/BIC/ZSDABW,/BIC/ZTREXPETY,/BIC/TRSDABWPR,/BIC/ZCOUNTRY2,/BIC/ZREGION2,/BIC/ZCOUNTRYF,/BIC/ZREGION,/BIC/TRDESTOUT,/BIC/TRDESTIN,/BIC/TRINCO1FB,DIVISION,/BIC/ZTRATY,/BIC/TRDAY_2,/BIC/TRDAY_4,MATL_GRP_4,/BIC/TRBORDCRP,/BIC/TRINCO2FB,/BIC/ZKF,/BIC/ZTRMONTH,/BIC/ZQUANTITY,/BIC/ZWEIGHT,AMOUNT,CURRENCY' , ',')) 
;
Query ddl: DROP TABLE IF EXISTS STG."BIP_/BIC/ATR_T013000" CASCADE ;
create table STG."BIP_/BIC/ATR_T013000" (
"REQUEST" varchar(90) NULL,
 "DATAPAKID" varchar(18) NULL,
 "RECORD" bigint NULL,
 "RECORDMODE" varchar(3) NULL,
 "/BIC/ZDATE_S" varchar(24) NULL,
 "/BIC/ZREAL_D" varchar(24) NULL,
 "/BIC/ZMARKET" varchar(27) NULL,
 "/BIC/TRSHIPTYP" varchar(6) NULL,
 "PLANT" varchar(12) NULL,
 "/BIC/ZKNOTEGRI" varchar(30) NULL,
 "/BIC/ZKNOTEGRT" varchar(30) NULL,
 "/BIC/ZKNOTEINT" varchar(30) NULL,
 "/BIC/ZKNOTEFNL" varchar(30) NULL,
 "/BIC/ZSDABW" varchar(12) NULL,
 "/BIC/ZTREXPETY" varchar(3) NULL,
 "/BIC/TRSDABWPR" varchar(12) NULL,
 "/BIC/ZCOUNTRY2" varchar(9) NULL,
 "/BIC/ZREGION2" varchar(90) NULL,
 "/BIC/ZCOUNTRYF" varchar(9) NULL,
 "/BIC/ZREGION" varchar(90) NULL,
 "/BIC/TRDESTOUT" varchar(30) NULL,
 "/BIC/TRDESTIN" varchar(30) NULL,
 "/BIC/TRINCO1FB" varchar(9) NULL,
 "DIVISION" varchar(6) NULL,
 "/BIC/ZTRATY" varchar(12) NULL,
 "/BIC/TRDAY_2" varchar(24) NULL,
 "/BIC/TRDAY_4" varchar(24) NULL,
 "MATL_GRP_4" varchar(9) NULL,
 "/BIC/TRBORDCRP" varchar(30) NULL,
 "/BIC/TRINCO2FB" varchar(84) NULL,
 "/BIC/ZKF" varchar(27) NULL,
 "/BIC/ZTRMONTH" varchar(18) NULL,
 "/BIC/ZQUANTITY" decimal(17,3) NULL,
 "/BIC/ZWEIGHT" decimal(17,3) NULL,
 "AMOUNT" decimal(17,2) NULL,
 "CURRENCY" varchar(15) NULL,
 "/BIC/ZTRSRVTYP" varchar(3) NULL,
 "RN" integer NOT NULL) 
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
) DISTRIBUTED BY("RN");
DDL CREATE TABLE: DROP TABLE IF EXISTS STG."BIP_/BIC/ATR_T013000" CASCADE ;
create table STG."BIP_/BIC/ATR_T013000" (
"REQUEST" varchar(90) NULL,
 "DATAPAKID" varchar(18) NULL,
 "RECORD" bigint NULL,
 "RECORDMODE" varchar(3) NULL,
 "/BIC/ZDATE_S" varchar(24) NULL,
 "/BIC/ZREAL_D" varchar(24) NULL,
 "/BIC/ZMARKET" varchar(27) NULL,
 "/BIC/TRSHIPTYP" varchar(6) NULL,
 "PLANT" varchar(12) NULL,
 "/BIC/ZKNOTEGRI" varchar(30) NULL,
 "/BIC/ZKNOTEGRT" varchar(30) NULL,
 "/BIC/ZKNOTEINT" varchar(30) NULL,
 "/BIC/ZKNOTEFNL" varchar(30) NULL,
 "/BIC/ZSDABW" varchar(12) NULL,
 "/BIC/ZTREXPETY" varchar(3) NULL,
 "/BIC/TRSDABWPR" varchar(12) NULL,
 "/BIC/ZCOUNTRY2" varchar(9) NULL,
 "/BIC/ZREGION2" varchar(90) NULL,
 "/BIC/ZCOUNTRYF" varchar(9) NULL,
 "/BIC/ZREGION" varchar(90) NULL,
 "/BIC/TRDESTOUT" varchar(30) NULL,
 "/BIC/TRDESTIN" varchar(30) NULL,
 "/BIC/TRINCO1FB" varchar(9) NULL,
 "DIVISION" varchar(6) NULL,
 "/BIC/ZTRATY" varchar(12) NULL,
 "/BIC/TRDAY_2" varchar(24) NULL,
 "/BIC/TRDAY_4" varchar(24) NULL,
 "MATL_GRP_4" varchar(9) NULL,
 "/BIC/TRBORDCRP" varchar(30) NULL,
 "/BIC/TRINCO2FB" varchar(84) NULL,
 "/BIC/ZKF" varchar(27) NULL,
 "/BIC/ZTRMONTH" varchar(18) NULL,
 "/BIC/ZQUANTITY" decimal(17,3) NULL,
 "/BIC/ZWEIGHT" decimal(17,3) NULL,
 "AMOUNT" decimal(17,2) NULL,
 "CURRENCY" varchar(15) NULL,
 "/BIC/ZTRSRVTYP" varchar(3) NULL,
 "RN" integer NOT NULL) 
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
) DISTRIBUTED BY("RN");
table "BIP_/BIC/ATR_T013000" does not exist, skipping
DDL CREATE TABLE: DROP TABLE IF EXISTS STG."BIP_/BIC/ATR_T013000" CASCADE ;
create table STG."BIP_/BIC/ATR_T013000" (
"REQUEST" varchar(90) NULL,
 "DATAPAKID" varchar(18) NULL,
 "RECORD" bigint NULL,
 "RECORDMODE" varchar(3) NULL,
 "/BIC/ZDATE_S" varchar(24) NULL,
 "/BIC/ZREAL_D" varchar(24) NULL,
 "/BIC/ZMARKET" varchar(27) NULL,
 "/BIC/TRSHIPTYP" varchar(6) NULL,
 "PLANT" varchar(12) NULL,
 "/BIC/ZKNOTEGRI" varchar(30) NULL,
 "/BIC/ZKNOTEGRT" varchar(30) NULL,
 "/BIC/ZKNOTEINT" varchar(30) NULL,
 "/BIC/ZKNOTEFNL" varchar(30) NULL,
 "/BIC/ZSDABW" varchar(12) NULL,
 "/BIC/ZTREXPETY" varchar(3) NULL,
 "/BIC/TRSDABWPR" varchar(12) NULL,
 "/BIC/ZCOUNTRY2" varchar(9) NULL,
 "/BIC/ZREGION2" varchar(90) NULL,
 "/BIC/ZCOUNTRYF" varchar(9) NULL,
 "/BIC/ZREGION" varchar(90) NULL,
 "/BIC/TRDESTOUT" varchar(30) NULL,
 "/BIC/TRDESTIN" varchar(30) NULL,
 "/BIC/TRINCO1FB" varchar(9) NULL,
 "DIVISION" varchar(6) NULL,
 "/BIC/ZTRATY" varchar(12) NULL,
 "/BIC/TRDAY_2" varchar(24) NULL,
 "/BIC/TRDAY_4" varchar(24) NULL,
 "MATL_GRP_4" varchar(9) NULL,
 "/BIC/TRBORDCRP" varchar(30) NULL,
 "/BIC/TRINCO2FB" varchar(84) NULL,
 "/BIC/ZKF" varchar(27) NULL,
 "/BIC/ZTRMONTH" varchar(18) NULL,
 "/BIC/ZQUANTITY" decimal(17,3) NULL,
 "/BIC/ZWEIGHT" decimal(17,3) NULL,
 "AMOUNT" decimal(17,2) NULL,
 "CURRENCY" varchar(15) NULL,
 "/BIC/ZTRSRVTYP" varchar(3) NULL,
 "RN" integer NOT NULL) 
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
) DISTRIBUTED BY("RN");
Status: target table created
Query to get columns: select tech_etl.generate_greenplum_readable_statement_ddl_oracle
 (v_target_schema_name := 'STG', 
 v_target_table_name := 'BIP_/BIC/ATR_T013000', 
 v_source_server_name := 'oracle_sap_bi_prod', 
 v_script_name := 'BIP__BIC_ATR_T013000' 
)
ALL COLUMNS: DROP EXTERNAL TABLE IF EXISTS RAW_EXT."BIP_/BIC/ATR_T013000_READ" CASCADE ;
CREATE READABLE EXTERNAL TABLE RAW_EXT."BIP_/BIC/ATR_T013000_READ"(
LIKE STG."BIP_/BIC/ATR_T013000"
)
LOCATION (
'pxf://query:query_BIP__BIC_ATR_T013000?PROFILE=JDBC&SERVER=oracle_sap_bi_prod&FETCH_SIZE=5000&PARTITION_BY=RN:int&RANGE=1:5&INTERVAL=1'
) ON ALL
FORMAT 'CUSTOM' (FORMATTER='pxfwritable_import')
ENCODING 'UTF8';
DDL CREATE READABLE: DROP EXTERNAL TABLE IF EXISTS RAW_EXT."BIP_/BIC/ATR_T013000_READ" CASCADE ;
CREATE READABLE EXTERNAL TABLE RAW_EXT."BIP_/BIC/ATR_T013000_READ"(
LIKE STG."BIP_/BIC/ATR_T013000"
)
LOCATION (
'pxf://query:query_BIP__BIC_ATR_T013000?PROFILE=JDBC&SERVER=oracle_sap_bi_prod&FETCH_SIZE=5000&PARTITION_BY=RN:int&RANGE=1:5&INTERVAL=1'
) ON ALL
FORMAT 'CUSTOM' (FORMATTER='pxfwritable_import')
ENCODING 'UTF8';
table "BIP_/BIC/ATR_T013000_READ" does not exist, skipping
Status: readable external table created
LOG BASH: SAPSR3
/BIC/ATR_TO13000
REQUEST,/BIC/ZTRSRVTYP,DATAPAKID,RECORD,RECORDMODE,/BIC/ZDATE_S,/BIC/ZREAL_D,/BIC/ZMARKET,/BIC/TRSHIPTYP,PLANT,/BIC/ZKNOTEGRI,/BIC/ZKNOTEGRT,/BIC/ZKNOTEINT,/BIC/ZKNOTEFNL,/BIC/ZSDABW,/BIC/ZTREXPETY,/BIC/TRSDABWPR,/BIC/ZCOUNTRY2,/BIC/ZREGION2,/BIC/ZCOUNTRYF,/BIC/ZREGION,/BIC/TRDESTOUT,/BIC/TRDESTIN,/BIC/TRINCO1FB,DIVISION,/BIC/ZTRATY,/BIC/TRDAY_2,/BIC/TRDAY_4,MATL_GRP_4,/BIC/TRBORDCRP,/BIC/TRINCO2FB,/BIC/ZKF,/BIC/ZTRMONTH,/BIC/ZQUANTITY,/BIC/ZWEIGHT,AMOUNT,CURRENCY
query_BIP__BIC_ATR_T013000
oracle_sap_bi_prod
"REQUEST" || "DATAPAKID" || "RECORD"
TRUE
oracle
COPY 1
Syncing PXF configuration files from master host to standby master host and 6 segment hosts...
PXF configs synced successfully on 7 out of 7 hosts
Status: query fox PXF loaded
DDL ALTERS: ALTER TABLE STG."BIP_/BIC/ATR_T013000" 
 ADD COLUMN  "DTTM_INSERTED" TIMESTAMP NOT NULL DEFAULT now(), 
 ADD COLUMN  "DTTM_UPDATED" TIMESTAMP NOT NULL DEFAULT now(), 
 ADD COLUMN  "JOB_NAME" varchar(60) NOT NULL DEFAULT 'airflow', 
 ADD COLUMN  "DELETED_FLAG" bool NOT NULL DEFAULT false, 
 ADD COLUMN  "IS_ACTUAL" bool NOT NULL DEFAULT true;
No result comment
Status:  Technical fields were added to target
Readable schema: RAW_EXT
Insert fields: "REQUEST",
"DATAPAKID",
"RECORD",
"RECORDMODE",
"/BIC/ZDATE_S",
"/BIC/ZREAL_D",
"/BIC/ZMARKET",
"/BIC/TRSHIPTYP",
"PLANT",
"/BIC/ZKNOTEGRI",
"/BIC/ZKNOTEGRT",
"/BIC/ZKNOTEINT",
"/BIC/ZKNOTEFNL",
"/BIC/ZSDABW",
"/BIC/ZTREXPETY",
"/BIC/TRSDABWPR",
"/BIC/ZCOUNTRY2",
"/BIC/ZREGION2",
"/BIC/ZCOUNTRYF",
"/BIC/ZREGION",
"/BIC/TRDESTOUT",
"/BIC/TRDESTIN",
"/BIC/TRINCO1FB",
"DIVISION",
"/BIC/ZTRATY",
"/BIC/TRDAY_2",
"/BIC/TRDAY_4",
"MATL_GRP_4",
"/BIC/TRBORDCRP",
"/BIC/TRINCO2FB",
"/BIC/ZKF",
"/BIC/ZTRMONTH",
"/BIC/ZQUANTITY",
"/BIC/ZWEIGHT",
"AMOUNT",
"CURRENCY",
"/BIC/ZTRSRVTYP",
"RN",
"DTTM_INSERTED",
"DTTM_UPDATED",
"JOB_NAME",
"DELETED_FLAG",
"IS_ACTUAL"
Select fields: "REQUEST",
"DATAPAKID",
"RECORD",
"RECORDMODE",
"/BIC/ZDATE_S",
"/BIC/ZREAL_D",
"/BIC/ZMARKET",
"/BIC/TRSHIPTYP",
"PLANT",
"/BIC/ZKNOTEGRI",
"/BIC/ZKNOTEGRT",
"/BIC/ZKNOTEINT",
"/BIC/ZKNOTEFNL",
"/BIC/ZSDABW",
"/BIC/ZTREXPETY",
"/BIC/TRSDABWPR",
"/BIC/ZCOUNTRY2",
"/BIC/ZREGION2",
"/BIC/ZCOUNTRYF",
"/BIC/ZREGION",
"/BIC/TRDESTOUT",
"/BIC/TRDESTIN",
"/BIC/TRINCO1FB",
"DIVISION",
"/BIC/ZTRATY",
"/BIC/TRDAY_2",
"/BIC/TRDAY_4",
"MATL_GRP_4",
"/BIC/TRBORDCRP",
"/BIC/TRINCO2FB",
"/BIC/ZKF",
"/BIC/ZTRMONTH",
"/BIC/ZQUANTITY",
"/BIC/ZWEIGHT",
"AMOUNT",
"CURRENCY",
"/BIC/ZTRSRVTYP",
"RN",
now(),
now(),
'airflow',
false,
true
Insert query:  INSERT INTO STG."BIP_/BIC/ATR_T013000"(
"REQUEST",
"DATAPAKID",
"RECORD",
"RECORDMODE",
"/BIC/ZDATE_S",
"/BIC/ZREAL_D",
"/BIC/ZMARKET",
"/BIC/TRSHIPTYP",
"PLANT",
"/BIC/ZKNOTEGRI",
"/BIC/ZKNOTEGRT",
"/BIC/ZKNOTEINT",
"/BIC/ZKNOTEFNL",
"/BIC/ZSDABW",
"/BIC/ZTREXPETY",
"/BIC/TRSDABWPR",
"/BIC/ZCOUNTRY2",
"/BIC/ZREGION2",
"/BIC/ZCOUNTRYF",
"/BIC/ZREGION",
"/BIC/TRDESTOUT",
"/BIC/TRDESTIN",
"/BIC/TRINCO1FB",
"DIVISION",
"/BIC/ZTRATY",
"/BIC/TRDAY_2",
"/BIC/TRDAY_4",
"MATL_GRP_4",
"/BIC/TRBORDCRP",
"/BIC/TRINCO2FB",
"/BIC/ZKF",
"/BIC/ZTRMONTH",
"/BIC/ZQUANTITY",
"/BIC/ZWEIGHT",
"AMOUNT",
"CURRENCY",
"/BIC/ZTRSRVTYP",
"RN",
"DTTM_INSERTED",
"DTTM_UPDATED",
"JOB_NAME",
"DELETED_FLAG",
"IS_ACTUAL")
 SELECT 
"REQUEST",
"DATAPAKID",
"RECORD",
"RECORDMODE",
"/BIC/ZDATE_S",
"/BIC/ZREAL_D",
"/BIC/ZMARKET",
"/BIC/TRSHIPTYP",
"PLANT",
"/BIC/ZKNOTEGRI",
"/BIC/ZKNOTEGRT",
"/BIC/ZKNOTEINT",
"/BIC/ZKNOTEFNL",
"/BIC/ZSDABW",
"/BIC/ZTREXPETY",
"/BIC/TRSDABWPR",
"/BIC/ZCOUNTRY2",
"/BIC/ZREGION2",
"/BIC/ZCOUNTRYF",
"/BIC/ZREGION",
"/BIC/TRDESTOUT",
"/BIC/TRDESTIN",
"/BIC/TRINCO1FB",
"DIVISION",
"/BIC/ZTRATY",
"/BIC/TRDAY_2",
"/BIC/TRDAY_4",
"MATL_GRP_4",
"/BIC/TRBORDCRP",
"/BIC/TRINCO2FB",
"/BIC/ZKF",
"/BIC/ZTRMONTH",
"/BIC/ZQUANTITY",
"/BIC/ZWEIGHT",
"AMOUNT",
"CURRENCY",
"/BIC/ZTRSRVTYP",
"RN",
now(),
now(),
'airflow',
false,
true
 FROM  RAW_EXT."BIP_/BIC/ATR_T013000_READ";
DML INSERT QUERY:  INSERT INTO STG."BIP_/BIC/ATR_T013000"(
"REQUEST",
"DATAPAKID",
"RECORD",
"RECORDMODE",
"/BIC/ZDATE_S",
"/BIC/ZREAL_D",
"/BIC/ZMARKET",
"/BIC/TRSHIPTYP",
"PLANT",
"/BIC/ZKNOTEGRI",
"/BIC/ZKNOTEGRT",
"/BIC/ZKNOTEINT",
"/BIC/ZKNOTEFNL",
"/BIC/ZSDABW",
"/BIC/ZTREXPETY",
"/BIC/TRSDABWPR",
"/BIC/ZCOUNTRY2",
"/BIC/ZREGION2",
"/BIC/ZCOUNTRYF",
"/BIC/ZREGION",
"/BIC/TRDESTOUT",
"/BIC/TRDESTIN",
"/BIC/TRINCO1FB",
"DIVISION",
"/BIC/ZTRATY",
"/BIC/TRDAY_2",
"/BIC/TRDAY_4",
"MATL_GRP_4",
"/BIC/TRBORDCRP",
"/BIC/TRINCO2FB",
"/BIC/ZKF",
"/BIC/ZTRMONTH",
"/BIC/ZQUANTITY",
"/BIC/ZWEIGHT",
"AMOUNT",
"CURRENCY",
"/BIC/ZTRSRVTYP",
"RN",
"DTTM_INSERTED",
"DTTM_UPDATED",
"JOB_NAME",
"DELETED_FLAG",
"IS_ACTUAL")
 SELECT 
"REQUEST",
"DATAPAKID",
"RECORD",
"RECORDMODE",
"/BIC/ZDATE_S",
"/BIC/ZREAL_D",
"/BIC/ZMARKET",
"/BIC/TRSHIPTYP",
"PLANT",
"/BIC/ZKNOTEGRI",
"/BIC/ZKNOTEGRT",
"/BIC/ZKNOTEINT",
"/BIC/ZKNOTEFNL",
"/BIC/ZSDABW",
"/BIC/ZTREXPETY",
"/BIC/TRSDABWPR",
"/BIC/ZCOUNTRY2",
"/BIC/ZREGION2",
"/BIC/ZCOUNTRYF",
"/BIC/ZREGION",
"/BIC/TRDESTOUT",
"/BIC/TRDESTIN",
"/BIC/TRINCO1FB",
"DIVISION",
"/BIC/ZTRATY",
"/BIC/TRDAY_2",
"/BIC/TRDAY_4",
"MATL_GRP_4",
"/BIC/TRBORDCRP",
"/BIC/TRINCO2FB",
"/BIC/ZKF",
"/BIC/ZTRMONTH",
"/BIC/ZQUANTITY",
"/BIC/ZWEIGHT",
"AMOUNT",
"CURRENCY",
"/BIC/ZTRSRVTYP",
"RN",
now(),
now(),
'airflow',
false,
true
 FROM  RAW_EXT."BIP_/BIC/ATR_T013000_READ";
Value: 1688724
Status: data was inserted to the target table
QUERY CREATE WITH FIELDS:
select tech_etl.etl_source_to_greenplum_new(
    v_source_schema_name := 'SAPSR3',
    v_source_table_name := '/BIC/ATR_TO13000',
    v_fields_list := 'REQUEST,/BIC/ZTRSRVTYP,DATAPAKID,RECORD,RECORDMODE,/BIC/ZDATE_S,/BIC/ZREAL_D,/BIC/ZMARKET,/BIC/TRSHIPTYP,PLANT,/BIC/ZKNOTEGRI,/BIC/ZKNOTEGRT,/BIC/ZKNOTEINT,/BIC/ZKNOTEFNL,/BIC/ZSDABW,/BIC/ZTREXPETY,/BIC/TRSDABWPR,/BIC/ZCOUNTRY2,/BIC/ZREGION2,/BIC/ZCOUNTRYF,/BIC/ZREGION,/BIC/TRDESTOUT,/BIC/TRDESTIN,/BIC/TRINCO1FB,DIVISION,/BIC/ZTRATY,/BIC/TRDAY_2,/BIC/TRDAY_4,MATL_GRP_4,/BIC/TRBORDCRP,/BIC/TRINCO2FB,/BIC/ZKF,/BIC/ZTRMONTH,/BIC/ZQUANTITY,/BIC/ZWEIGHT,AMOUNT,CURRENCY',
    v_target_schema_name := 'STG',
    v_target_table_name := 'BIP_/BIC/ATR_T013000',
    v_server_id := '2',
    v_distribution_field := 'RN',
    v_pk := '"REQUEST" || "DATAPAKID" || "RECORD"'
);
