select * from tech_etl.detailed_log dl
join tech_etl.tables_meta tm on 
          tm.table_id = dl.object_id
         join tech_etl.layers_meta lm on lm.layer_name = tm.table_schema
         where dl.log_status = 'ok'
           and dl.dttm_inserted is not null
           and tm.table_schema != 'dm_view'
           and tm.entity_id in (42)
           and dl.dttm_inserted::date ='2026-01-13';


SELECT DATE_TRUNC('day', report_date) AS report_date,
       table_schema AS table_schema,
       SUM(time_progress*1000) AS second_progress
FROM
  (select report_date,
          entity_name,
          table_schema,
          started,
          finished,
          time_progress
   from
     (with mas as
        (select dl.report_date,
                tm.entity_name,
                tm.table_schema,
                lm.layer_weight,
                (case
                     when dl.log_message = 'Loading process started' then min(dl.dttm_inserted)
                 end) as started,
                (case
                     when dl.log_message = 'Loading process finished' then max(dl.dttm_inserted)
                 end) as finished
         from
           (select date_trunc('day', dttm_inserted) report_date,
                   object_name,
                   log_message,
                   log_status,
                   object_id,
                   min(dttm_inserted) dttm_inserted
            from tech_etl.detailed_log
            group by date_trunc('day', dttm_inserted),
                     object_name,
                     log_message,
                     log_status,
                     object_id) dl
         join tech_etl.tables_meta tm on tm.table_schema||'.'||tm.table_name = dl.object_name
         and tm.table_id = dl.object_id
         join tech_etl.layers_meta lm on lm.layer_name = tm.table_schema
         where dl.log_status = 'ok'
           and dl.dttm_inserted is not null
           and tm.table_schema != 'dm_view'
           and tm.entity_id in (42,
                                48,
                                49,
                                50)
         group by dl.report_date,
                  tm.entity_name,
                  tm.table_schema,
                  dl.log_message,
                  lm.layer_weight),
           mas_layer as
        (
        select report_date,
                entity_name,
                table_schema,
                layer_weight,
                date_trunc('second', max(started)) started,
                date_trunc('second', max(finished)) finished,
                date_trunc('second', max(finished) - min(started)) time_progress
         from mas
         group by report_date,
                  entity_name,
                  table_schema,
                  layer_weight
         union all select report_date,
                          entity_name,
                          'all' table_schema,
                                1000 layer_weight,
                                date_trunc('second', min(started)) started,
                                date_trunc('second', max(finished)) finished,
                                date_trunc('second', max(finished) - min(started)) time_progress
         from mas
         group by report_date,
                  entity_name) select report_date,
                                      entity_name,
                                      table_schema,
                                      started,
                                      finished,
                                      EXTRACT(EPOCH
                                              FROM time_progress) time_progress,
                                      layer_weight
      from mas_layer) t
   order by report_date desc, entity_name desc, layer_weight desc) AS virtual_table
WHERE entity_name IN ('MANAGEMENT_REPORTING_1')
  AND ((report_date<= now()
        and report_date>=now()-'14 DAY'::interval))
GROUP BY DATE_TRUNC('day', report_date),
         table_schema
ORDER BY second_progress DESC
LIMIT 500;
