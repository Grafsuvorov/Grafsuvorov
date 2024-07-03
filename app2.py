import os
import sys
import psycopg2
import pandas as pd
from sqlalchemy import create_engine
import graphviz

# Параметры подключения к базе данных PostgreSQL
DB_HOST = 'localhost'
DB_PORT = '5432'
DB_NAME = 'dwh'
DB_USER = 'postgres'
DB_PASS = '0506'


def get_data(engine, target_table):
    query = f"""
    WITH RECURSIVE cte AS (
        SELECT source_schema, source_table, target_schema, target_table, flag_active_source, flag_active_target
        FROM source_target
        WHERE target_table = '{target_table}'
        UNION ALL
        SELECT st.source_schema, st.source_table, st.target_schema, st.target_table, st.flag_active_source, st.flag_active_target
        FROM source_target st
        INNER JOIN cte ON st.target_schema = cte.source_schema AND st.target_table = cte.source_table
    )
    SELECT * FROM cte;
    """
    df = pd.read_sql(query, engine)
    return df


def create_graph(df):
    dot = graphviz.Digraph(comment='Table Dependencies')
    dot.attr(rankdir='LR', splines='polyline', nodesep='2', ranksep='1.5', fontsize='22', fontname='Arial')

    node_attrs = {
        'shape': 'rect',
        'style': 'filled',
        'fontname': 'Arial',
        'fontsize': '22',
        'height': '1.0',
        'fixedsize': 'true'
    }

    # Найдем максимальную длину текста
    max_length = 0
    for _, row in df.iterrows():
        source = f"{row['source_schema']}.{row['source_table']}"
        target = f"{row['target_schema']}.{row['target_table']}"
        max_length = max(max_length, len(source), len(target))

    # Ширина узлов основывается на максимальной длине текста
    node_attrs['width'] = str(max_length * 0.2)

    added_edges = set()

    for _, row in df.iterrows():
        source = f"{row['source_schema']}.{row['source_table']}"
        target = f"{row['target_schema']}.{row['target_table']}"

        if row['flag_active_source']:
            if 'dict_dds' in source:
                node_attrs['fillcolor'] = 'lightyellow'
            elif 'dm' in source:
                node_attrs['fillcolor'] = 'lightblue'
            else:
                node_attrs['fillcolor'] = 'lightblue'
        else:
            node_attrs['fillcolor'] = 'lightcoral'
        dot.node(source, **node_attrs)

        if row['flag_active_target']:
            if 'dict_dds' in target:
                node_attrs['fillcolor'] = 'lightyellow'
            elif 'dm' in target:
                node_attrs['fillcolor'] = 'lightblue'
            else:
                node_attrs['fillcolor'] = 'lightblue'
        else:
            node_attrs['fillcolor'] = 'lightcoral'
        dot.node(target, **node_attrs)

        if (source, target) not in added_edges:
            dot.edge(source, target, color='black', penwidth='2', arrowsize='1.5', fontname='Arial', fontsize='20')
            added_edges.add((source, target))

    # Легенда
    with dot.subgraph(name='cluster_legend') as c:
        c.attr(label='Легенда', fontsize='22', fontname='Arial')
        c.node('key1', 'dict_dds Справочник', shape='rect', style='filled', fontname='Arial', fontsize='22',
               fillcolor='lightyellow')
        c.node('key2', 'other schemas', shape='rect', style='filled', fontname='Arial', fontsize='22',
               fillcolor='lightblue')
        c.node('key3', 'таблица выключена', shape='rect', style='filled', fontname='Arial', fontsize='22',
               fillcolor='lightcoral')
        c.edge('key1', 'key2', style='invis')
        c.edge('key2', 'key3', style='invis')

    return dot


def main(target_table):
    conn_str = f"postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    engine = create_engine(conn_str)
    df = get_data(engine, target_table)
    dot = create_graph(df)

    # Получаем путь к директории, где находится скрипт
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Формируем полный путь к файлу
    file_path = os.path.join(script_dir, f'{target_table}_dependencies')

    dot.render(file_path, format='png', cleanup=True)
    print(f"Graph generated and saved as {file_path}.png")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python generate_graph.py <target_table>")
        sys.exit(1)
    target_table = sys.argv[1]
    main(target_table)