do
$$
DECLARE
    v_row_cnt int8;
    v_row_cnt_agg int8 = 0;
    v_calc_time interval;
    v_start_dttm timestamp(0);
    v_last_step_finish_dttm timestamp(0);

BEGIN
    v_start_dttm := clock_timestamp();
    raise notice '% START ', to_char(clock_timestamp(), 'hh24:mi:ss');
    v_last_step_finish_dttm := clock_timestamp();

    drop table if exists pg_temp.lepervlka;
    create temporary table pg_temp.lepervlka with (appendonly = true, orientation = column, compresstype = zstd, compresslevel = 3) as (
        select
            numnakl,
            numvag
        from
            ods."ral_/rusal/lepervlka_fs"
        where
            weightnet <> 0
        group by
            numnakl,
            numvag
    )
    distributed by (numnakl, numvag);

    get diagnostics v_row_cnt = row_count;
    raise notice '% [%] create pg_temp.lepervlka (%)', to_char(clock_timestamp(),'hh24:mi:ss'), (clock_timestamp() - v_last_step_finish_dttm)::interval, v_row_cnt;
    v_last_step_finish_dttm :=  clock_timestamp();


    drop table if exists pg_temp.lepervlks;
    create temporary table pg_temp.lepervlks with (appendonly = true, orientation = column, compresstype = zstd, compresslevel = 3) as (
        select
            numnakl,
            numvag
        from
            ods."ral_/rusal/lepervlka_fs"
        where
            weightnet <> 0
        group by
            numnakl,
            numvag
        union
        select
            numnakl,
            numvag
        from
            ods."ral_/rusal/lepervlk1_fs"
        where
            weightnet <> 0
        group by
            numnakl,
            numvag
    )
    distributed by (numnakl, numvag);

    get diagnostics v_row_cnt = row_count;
    raise notice '% [%] create pg_temp.lepervlks (%)', to_char(clock_timestamp(),'hh24:mi:ss'), (clock_timestamp() - v_last_step_finish_dttm)::interval, v_row_cnt;
    v_last_step_finish_dttm :=  clock_timestamp();

    drop table if exists pg_temp.all_table_union;
    create temporary table pg_temp.all_table_union with (appendonly = true, orientation = column, compresstype = zstd, compresslevel = 3) as (
        select 1 as transport_bill_code
    )
    distributed by (transport_bill_code);

    get diagnostics v_row_cnt = row_count;
    raise notice '% [%] create pg_temp.all_table_union (%)', to_char(clock_timestamp(),'hh24:mi:ss'), (clock_timestamp() - v_last_step_finish_dttm)::interval, v_row_cnt;
    v_last_step_finish_dttm :=  clock_timestamp();

    drop table if exists pg_temp.all_table_union;

    truncate table dds.transport_bill_fs;

    get diagnostics v_row_cnt = row_count;
    raise notice '% [%] truncate target (%)', to_char(clock_timestamp(),'hh24:mi:ss'), (clock_timestamp() - v_last_step_finish_dttm)::interval, v_row_cnt;
    v_last_step_finish_dttm :=  clock_timestamp();

    v_row_cnt_agg := v_row_cnt_agg + v_row_cnt;

    if v_row_cnt_agg > 0 then
        analyze dds.transport_bill_fs;
        get diagnostics v_row_cnt = row_count;
        raise notice '% [%] analyze target (%)', to_char(clock_timestamp(),'hh24:mi:ss'), (clock_timestamp() - v_last_step_finish_dttm)::interval, v_row_cnt;
        v_last_step_finish_dttm :=  clock_timestamp();
    end if;

    v_calc_time :=  clock_timestamp() - v_start_dttm ;
    raise notice '% FINISH (v_start_dttm = % ;  v_calc_time = %.)', to_char(clock_timestamp(), 'hh24:mi:ss'), v_start_dttm, v_calc_time;
end;
$$
