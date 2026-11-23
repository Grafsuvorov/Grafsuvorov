error	0.004 сек	syntax error at or near "document_text" LINE 58: document_text must be JSON (::jsonb). ^

-- =====================================================================
-- stg.sapxi_casting_schedule   (раздел JSON "GRAPH_PLAN" потока flow_id = 'SI_GraphPlan_AI')
-- Источник: landing."INPUT_DATA_AS_TEXT_FROM_SAPXI_IN".document_text (JSON, разбор jsonb)
-- Self-contained: DROP(закомментирован) + CREATE + инкрементальный INSERT.
-- =====================================================================

-- ---- DROP (раскомментировать для пересоздания таблицы с нуля) ----------
-- DROP TABLE IF EXISTS stg.sapxi_casting_schedule;

-- ---- CREATE (идемпотентно) ---------------------------------------------
CREATE TABLE IF NOT EXISTS stg.sapxi_casting_schedule (
    PLAN_ID NUMERIC,
    GRAPH_ID NUMERIC,
    PERIOD TEXT,
    CAST_HOUSES TEXT,
    PLAN_TYPE NUMERIC,
    PLAN_NUMB NUMERIC,
    PLAN_DATE TEXT,
    PARENT_PLAN_ID TEXT,
    VERSION NUMERIC,
    CALC_VERSION NUMERIC,
    AUTHOR_NAME TEXT,
    AUTHOR_EMAIL TEXT,
    STATUS NUMERIC,
    CALC_ID NUMERIC,
    READY NUMERIC,
    SIGN_LEVEL NUMERIC,
    PERIOD_END TEXT,
    PLAN_LAST_UPDATE TEXT,
    PERIOD_START TEXT,
    REVISION NUMERIC,
    DISABLE_BYPRODUCTS TEXT,
    TO_ZNP NUMERIC,
    COB_TONNAGE NUMERIC,
    DISABLE_OVERLOAD TEXT,
    source_system varchar(100) NULL,
    flow_id varchar(100) NULL,
    uuid varchar(60) NULL,
    dt_insert timestamp NULL,
    record_id int4 NULL,
    dttm_inserted timestamp NOT NULL DEFAULT now(),
    dttm_updated timestamp NOT NULL DEFAULT now(),
    job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
    deleted_flag bool NOT NULL DEFAULT false
)
WITH (
    appendonly=true,
    compresstype=zstd,
    compresslevel=3
)
DISTRIBUTED BY (PLAN_ID);

COMMENT ON TABLE stg.sapxi_casting_schedule IS 'STG: график литья, шапка плана. Источник: раздел GRAPH_PLAN потока SI_GraphPlan_AI (SAP XI).';


-- ---- INSERT (JSON parse: jsonb_array_elements) ----
-- NOTE: all SI_GraphPlan_AI rows are parsed; document_text must be JSON (::jsonb).
INSERT INTO stg.sapxi_casting_schedule (PLAN_ID, GRAPH_ID, PERIOD, CAST_HOUSES, PLAN_TYPE, PLAN_NUMB, PLAN_DATE, PARENT_PLAN_ID, VERSION, CALC_VERSION, AUTHOR_NAME, AUTHOR_EMAIL, STATUS, CALC_ID, READY, SIGN_LEVEL, PERIOD_END, PLAN_LAST_UPDATE, PERIOD_START, REVISION, DISABLE_BYPRODUCTS, TO_ZNP, COB_TONNAGE, DISABLE_OVERLOAD, source_system, flow_id, uuid, dt_insert, record_id)
SELECT
    (j.value ->> 'PLAN_ID')::NUMERIC AS PLAN_ID,
    (j.value ->> 'GRAPH_ID')::NUMERIC AS GRAPH_ID,
    (j.value ->> 'PERIOD') AS PERIOD,
    (j.value ->> 'CAST_HOUSES') AS CAST_HOUSES,
    (j.value ->> 'PLAN_TYPE')::NUMERIC AS PLAN_TYPE,
    (j.value ->> 'PLAN_NUMB')::NUMERIC AS PLAN_NUMB,
    (j.value ->> 'PLAN_DATE') AS PLAN_DATE,
    (j.value ->> 'PARENT_PLAN_ID') AS PARENT_PLAN_ID,
    (j.value ->> 'VERSION')::NUMERIC AS VERSION,
    (j.value ->> 'CALC_VERSION')::NUMERIC AS CALC_VERSION,
    (j.value ->> 'AUTHOR_NAME') AS AUTHOR_NAME,
    (j.value ->> 'AUTHOR_EMAIL') AS AUTHOR_EMAIL,
    (j.value ->> 'STATUS')::NUMERIC AS STATUS,
    (j.value ->> 'CALC_ID')::NUMERIC AS CALC_ID,
    (j.value ->> 'READY')::NUMERIC AS READY,
    (j.value ->> 'SIGN_LEVEL')::NUMERIC AS SIGN_LEVEL,
    (j.value ->> 'PERIOD_END') AS PERIOD_END,
    (j.value ->> 'PLAN_LAST_UPDATE') AS PLAN_LAST_UPDATE,
    (j.value ->> 'PERIOD_START') AS PERIOD_START,
    (j.value ->> 'REVISION')::NUMERIC AS REVISION,
    (j.value ->> 'DISABLE_BYPRODUCTS') AS DISABLE_BYPRODUCTS,
    (j.value ->> 'TO_ZNP')::NUMERIC AS TO_ZNP,
    (j.value ->> 'COB_TONNAGE')::NUMERIC AS COB_TONNAGE,
    (j.value ->> 'DISABLE_OVERLOAD') AS DISABLE_OVERLOAD,
    l.source_system,
    l.flow_id,
    l.uuid,
    l.dt_insert,
    l.record_id
FROM landing."INPUT_DATA_AS_TEXT_FROM_SAPXI_IN" l,
     jsonb_array_elements(l.document_text::jsonb -> 'GRAPH_PLAN') AS j(value)
WHERE (l.flow_id = 'SI_GraphPlan_AI')
  AND (NOT EXISTS (SELECT 1 FROM stg.sapxi_casting_schedule a WHERE a.record_id = l.record_id));
