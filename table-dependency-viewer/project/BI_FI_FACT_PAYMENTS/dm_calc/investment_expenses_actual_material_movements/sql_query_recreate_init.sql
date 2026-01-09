drop table if exists dm_calc.investment_expenses_actual_material_movements;
create table dm_calc.investment_expenses_actual_material_movements (
	material_movement_document_code varchar(10) not null,
	material_movement_document_year varchar(4) not null,
	material_code	varchar(18),
	wbs_element_code varchar(8),
	payee_alternative_code	varchar(10),
	purchase_document_code varchar(13),	
	purchase_document_position_line_item_code varchar(5),
	"dttm_inserted" timestamp not null default now(),
	"dttm_updated" timestamp not null default now(),
	"job_name" varchar(60) not null default 'airflow'::character varying,
	"deleted_flag" bool not null default false
)
with (
 appendonly = true,
 orientation = column,
 compresstype = zstd,
 compresslevel = 1
)
distributed by (material_movement_document_code,material_movement_document_year, material_code, wbs_element_code);


----------------------------------------------------------------------------------------------------------------COMMENT
comment on table dm_calc.investment_expenses_actual_material_movements IS 'Связь документов ________________ZCO________________ для факта затрат БИЗ';
comment on column dm_calc.investment_expenses_actual_material_movements.material_movement_document_code is 'Документ движения материала (код)| Документ движения материала (код) | MSEG-MBLNR';
comment on column dm_calc.investment_expenses_actual_material_movements.material_movement_document_year is 'Год документа движения материала |Год документа движения материала | MSEG-MJAHR';
comment on column dm_calc.investment_expenses_actual_material_movements.material_code is 'Номер основного договора | Номер основного договора | MSEG-MATNR';
comment on column dm_calc.investment_expenses_actual_material_movements.wbs_element_code is 'Номер поставщика | Номер поставщика | MSEG-PS_PSP_PNR';
comment on column dm_calc.investment_expenses_actual_material_movements.purchase_document_code  is 'Номер основного договора | Номер основного договора | RBKP-ZZVERTN';
comment on column dm_calc.investment_expenses_actual_material_movements.payee_alternative_code is 'Номер поставщика | Номер поставщика | RBKP-LIFNR';
comment on column dm_calc.investment_expenses_actual_material_movements.purchase_document_position_line_item_code  is 'Номер основного договора | Номер основного договора | RBKP-ZZVERTN';
comment on column dm_calc.investment_expenses_actual_material_movements.payee_alternative_code is 'Номер поставщика | Номер поставщика | RBKP-LIFNR';