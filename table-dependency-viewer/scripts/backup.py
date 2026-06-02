import argparse
import sys
import uuid
from datetime import date, datetime

import psycopg2


EXCLUDED_COLUMNS = {
    "dttm_inserted",
    "dttm_updated",
    "job_name",
    "deleted_flag",
}


def qident(name):
    return '"' + str(name).replace('"', '""') + '"'


def fqtn(schema, table):
    return "{}.{}".format(qident(schema), qident(table))


def get_tables(conn, entity_id, table_schema):
    with conn.cursor() as cur:
        cur.execute(
            """
            select table_name
            from tech_etl.tables_meta
            where entity_id = %s
              and table_schema = %s
            order by table_name
            """,
            (entity_id, table_schema),
        )
        return [row[0] for row in cur.fetchall()]


def table_exists(conn, table_schema, table_name):
    with conn.cursor() as cur:
        cur.execute(
            """
            select 1
            from information_schema.tables
            where table_schema = %s
              and table_name = %s
            limit 1
            """,
            (table_schema, table_name),
        )
        return cur.fetchone() is not None


def get_business_columns(conn, table_schema, table_name):
    with conn.cursor() as cur:
        cur.execute(
            """
            select column_name
            from information_schema.columns
            where table_schema = %s
              and table_name = %s
            order by ordinal_position
            """,
            (table_schema, table_name),
        )
        return [
            row[0]
            for row in cur.fetchall()
            if row[0] not in EXCLUDED_COLUMNS
        ]


def get_count(conn, table_schema, table_name):
    sql = "select count(*) from {}".format(fqtn(table_schema, table_name))
    with conn.cursor() as cur:
        cur.execute(sql)
        return cur.fetchone()[0]


def get_diff_count(conn, table_schema, source_table, backup_table, columns):
    cols = ", ".join(qident(col) for col in columns)
    sql = """
        select count(*)
        from (
            (select {cols} from {source_table_fq}
             except all
             select {cols} from {backup_table_fq})
            union all
            (select {cols} from {backup_table_fq}
             except all
             select {cols} from {source_table_fq})
        ) q
    """.format(
        cols=cols,
        source_table_fq=fqtn(table_schema, source_table),
        backup_table_fq=fqtn(table_schema, backup_table),
    )
    with conn.cursor() as cur:
        cur.execute(sql)
        return cur.fetchone()[0]


def delete_existing_progress(conn, run_id):
    with conn.cursor() as cur:
        cur.execute(
            "delete from tech_etl.entity_backup_check_progress where run_id = %s",
            (run_id,),
        )


def insert_progress(
    conn,
    run_id,
    entity_id,
    table_schema,
    backup_date,
    status,
    total_tables,
    processed_tables,
    current_table,
    started_at,
    error_message,
    finished_at,
):
    with conn.cursor() as cur:
        cur.execute(
            """
            insert into tech_etl.entity_backup_check_progress (
                run_id,
                entity_id,
                table_schema,
                backup_date,
                status,
                total_tables,
                processed_tables,
                current_table,
                started_at,
                finished_at,
                error_message
            )
            values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                run_id,
                entity_id,
                table_schema,
                backup_date,
                status,
                total_tables,
                processed_tables,
                current_table,
                started_at,
                finished_at,
                error_message,
            ),
        )


def replace_progress(
    conn,
    run_id,
    entity_id,
    table_schema,
    backup_date,
    status,
    total_tables,
    processed_tables,
    current_table=None,
    started_at=None,
    error_message=None,
    finished=False,
):
    if started_at is None:
        started_at = datetime.now()
    finished_at = datetime.now() if finished else None
    delete_existing_progress(conn, run_id)
    insert_progress(
        conn,
        run_id,
        entity_id,
        table_schema,
        backup_date,
        status,
        total_tables,
        processed_tables,
        current_table,
        started_at,
        error_message,
        finished_at,
    )


def insert_result(
    conn,
    run_id,
    backup_date,
    entity_id,
    table_schema,
    source_table,
    backup_table,
    status,
    source_cnt=None,
    backup_cnt=None,
    diff_cnt=None,
    error_message=None,
):
    with conn.cursor() as cur:
        cur.execute(
            """
            insert into tech_etl.entity_backup_check_results (
                run_id,
                checked_at,
                backup_date,
                entity_id,
                table_schema,
                source_table,
                backup_table,
                status,
                source_cnt,
                backup_cnt,
                diff_cnt,
                error_message
            )
            values (%s, now(), %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                run_id,
                backup_date,
                entity_id,
                table_schema,
                source_table,
                backup_table,
                status,
                source_cnt,
                backup_cnt,
                diff_cnt,
                error_message,
            ),
        )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--dbname", required=True)
    parser.add_argument("--user", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--entity-id", type=int, required=True)
    parser.add_argument("--table-schema", required=True)
    parser.add_argument("--backup-date", default=str(date.today()))
    args = parser.parse_args()

    backup_date = date.fromisoformat(args.backup_date)
    backup_suffix = backup_date.strftime("%Y_%m_%d")
    run_id = str(uuid.uuid4())
    run_started_at = datetime.now()

    conn = psycopg2.connect(
        host=args.host,
        port=args.port,
        dbname=args.dbname,
        user=args.user,
        password=args.password,
    )
    conn.autocommit = False

    try:
        tables = get_tables(conn, args.entity_id, args.table_schema)
        total = len(tables)

        replace_progress(
            conn,
            run_id,
            args.entity_id,
            args.table_schema,
            backup_date,
            "running",
            total,
            0,
            started_at=run_started_at,
        )
        conn.commit()

        for idx, table_name in enumerate(tables, start=1):
            backup_table = "{}_backup_{}".format(table_name, backup_suffix)
            source_name = "{}.{}".format(args.table_schema, table_name)
            backup_name = "{}.{}".format(args.table_schema, backup_table)

            print("[{}/{}] checking {}".format(idx, total, source_name))

            replace_progress(
                conn,
                run_id,
                args.entity_id,
                args.table_schema,
                backup_date,
                "running",
                total,
                idx - 1,
                current_table=source_name,
                started_at=run_started_at,
            )
            conn.commit()

            try:
                if not table_exists(conn, args.table_schema, backup_table):
                    insert_result(
                        conn,
                        run_id,
                        backup_date,
                        args.entity_id,
                        args.table_schema,
                        source_name,
                        backup_name,
                        "backup_not_found",
                    )
                    conn.commit()
                    continue

                columns = get_business_columns(conn, args.table_schema, table_name)
                if not columns:
                    insert_result(
                        conn,
                        run_id,
                        backup_date,
                        args.entity_id,
                        args.table_schema,
                        source_name,
                        backup_name,
                        "no_business_columns",
                    )
                    conn.commit()
                    continue

                source_cnt = get_count(conn, args.table_schema, table_name)
                backup_cnt = get_count(conn, args.table_schema, backup_table)
                diff_cnt = get_diff_count(
                    conn,
                    args.table_schema,
                    table_name,
                    backup_table,
                    columns,
                )

                status = "ok" if source_cnt == backup_cnt and diff_cnt == 0 else "mismatch"

                insert_result(
                    conn,
                    run_id,
                    backup_date,
                    args.entity_id,
                    args.table_schema,
                    source_name,
                    backup_name,
                    status,
                    source_cnt,
                    backup_cnt,
                    diff_cnt,
                )
                conn.commit()

            except Exception as exc:
                conn.rollback()
                insert_result(
                    conn,
                    run_id,
                    backup_date,
                    args.entity_id,
                    args.table_schema,
                    source_name,
                    backup_name,
                    "error",
                    error_message=str(exc)[:4000],
                )
                conn.commit()

            replace_progress(
                conn,
                run_id,
                args.entity_id,
                args.table_schema,
                backup_date,
                "running",
                total,
                idx,
                current_table=source_name,
                started_at=run_started_at,
            )
            conn.commit()

        replace_progress(
            conn,
            run_id,
            args.entity_id,
            args.table_schema,
            backup_date,
            "finished",
            total,
            total,
            started_at=run_started_at,
            finished=True,
        )
        conn.commit()

        print("done, run_id={}".format(run_id))
        return 0

    except Exception as exc:
        conn.rollback()
        try:
            replace_progress(
                conn,
                run_id,
                args.entity_id,
                args.table_schema,
                backup_date,
                "failed",
                0,
                0,
                started_at=run_started_at,
                error_message=str(exc)[:4000],
                finished=True,
            )
            conn.commit()
        except Exception:
            conn.rollback()
        print("failed, run_id={}, error={}".format(run_id, exc), file=sys.stderr)
        return 1
    finally:
        conn.close()


if __name__ == "__main__":
    raise SystemExit(main())
