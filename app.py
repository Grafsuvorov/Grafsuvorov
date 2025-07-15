import os
import pandas as pd
import plotly.express as px
from flask import Flask, request, render_template, jsonify
from sqlalchemy import create_engine
import graphviz
import logging
from tabulate import tabulate

app = Flask(__name__)

# Параметры подключения к базе данных PostgreSQL
DB_HOST = 'localhost'
DB_PORT = '5432'
DB_NAME = 'dwh'
DB_USER = 'postgres'
DB_PASS = '0506'

# Настройка логирования
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s %(levelname)s %(message)s',
                    handlers=[logging.StreamHandler(), logging.FileHandler("app.log")])


def get_data(engine, target_schema, target_table):
    query = f"""
    WITH RECURSIVE cte AS (
        SELECT source_schema, source_table, target_schema, target_table, flag_active_source, flag_active_target,
               coalesce(start_data_source, start_data_target) AS start_data_source,
               coalesce(finish_data_source, finish_data_target) AS finish_data_source
        FROM source_target_time
        WHERE target_schema = '{target_schema}' AND target_table = '{target_table}'
        UNION ALL
        SELECT st.source_schema, st.source_table, st.target_schema, st.target_table, st.flag_active_source, st.flag_active_target,
               st.start_data_source, st.finish_data_source
        FROM source_target_time st
        INNER JOIN cte ON st.target_schema = cte.source_schema AND st.target_table = cte.source_table
    )
    SELECT * FROM cte;
    """
    df = pd.read_sql(query, engine)
    return df


def get_gantt_data(engine, target_table):
    query = f"""
    WITH RECURSIVE cte AS (
        SELECT source_schema, source_table, target_schema, target_table, flag_active_source, flag_active_target,
               coalesce(start_data_source, start_data_target) AS start_data_source,
               coalesce(finish_data_source, finish_data_target) AS finish_data_source
        FROM source_target_time
        WHERE target_table = '{target_table}'
        UNION ALL
        SELECT st.source_schema, st.source_table, st.target_schema, st.target_table, st.flag_active_source, st.flag_active_target,
               st.start_data_source, st.finish_data_source
        FROM source_target_time st
        INNER JOIN cte ON st.target_schema = cte.source_schema AND st.target_table = cte.source_table
    )
    SELECT * FROM cte;
    """
    df = pd.read_sql(query, engine)

    # Преобразование столбцов в datetime
    df['start_data_source'] = pd.to_datetime(df['start_data_source'], errors='coerce')
    df['finish_data_source'] = pd.to_datetime(df['finish_data_source'], errors='coerce')

    # Remove rows with NaT in any datetime column
    df.dropna(subset=['start_data_source', 'finish_data_source'], inplace=True)

    # Concatenate schema and table name
    df['source_full'] = df['source_schema'] + '.' + df['source_table']
    df['target_full'] = df['target_schema'] + '.' + df['target_table']

    # Добавляем минимальный интервал, чтобы сделать маленькие блоки видимыми
    min_interval = pd.Timedelta(minutes=5)
    df['adjusted_finish_data_source'] = df['finish_data_source']
    df.loc[(df['finish_data_source'] - df['start_data_source']) < min_interval, 'adjusted_finish_data_source'] = df['start_data_source'] + min_interval

    # Записываем данные в лог
    logging.debug(tabulate(df, headers='keys', tablefmt='psql'))  # Выводим все данные DataFrame в лог в виде таблицы

    return df


def get_table_list(engine):
    query = "SELECT DISTINCT target_schema || '.' || target_table as full_table FROM source_target_time"
    df = pd.read_sql(query, engine)
    return df['full_table'].tolist()


def create_graph(df):
    dot = graphviz.Digraph(comment='Table Dependencies')
    dot.attr(rankdir='LR', splines='polyline', nodesep='0.3', ranksep='0.3', fontsize='8', fontname='Arial', dpi='72',
             size='100,20')  # Увеличьте значения размера для ширины и высоты

    node_attrs = {
        'shape': 'rect',
        'style': 'filled',
        'fontname': 'Arial',
        'fontsize': '8',
        'height': '0.2',
        'width': '0.8',
        'fixedsize': 'false'
    }

    added_edges = set()

    for _, row in df.iterrows():
        source = f"{row['source_schema']}.{row['source_table']}"
        target = f"{row['target_schema']}.{row['target_table']}"

        if row['flag_active_source']:
            node_attrs['fillcolor'] = 'lightyellow' if 'dict_dds' in source else 'lightblue'
        else:
            node_attrs['fillcolor'] = 'lightcoral'
        dot.node(source, href=f"/table_info/{row['source_schema']}/{row['source_table']}", target="_blank",
                 **node_attrs)

        if row['flag_active_target']:
            node_attrs['fillcolor'] = 'lightyellow' if 'dict_dds' in target else 'lightblue'
        else:
            node_attrs['fillcolor'] = 'lightcoral'
        dot.node(target, href=f"/table_info/{row['target_schema']}/{row['target_table']}", target="_blank",
                 **node_attrs)

        if (source, target) not in added_edges:
            dot.edge(source, target, color='black', penwidth='1', arrowsize='0.5', fontname='Arial', fontsize='8')
            added_edges.add((source, target))

    # Легенда
    with dot.subgraph(name='cluster_legend') as c:
        c.attr(label='Легенда', fontsize='8', fontname='Arial')
        c.node('key1', 'dict_dds Справочник', shape='rect', style='filled', fontname='Arial', fontsize='8',
               fillcolor='lightyellow')
        c.node('key2', 'other schemas', shape='rect', style='filled', fontname='Arial', fontsize='8',
               fillcolor='lightblue')
        c.node('key3', 'таблица выключена', shape='rect', style='filled', fontname='Arial', fontsize='8',
               fillcolor='lightcoral')
        c.edge('key1', 'key2', style='invis')
        c.edge('key2', 'key3', style='invis')

    return dot


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/graph', methods=['GET', 'POST'])
def graph():
    if request.method == 'POST':
        full_table = request.form['target_table']
        target_schema, target_table = full_table.split('.')
        conn_str = f"postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
        logging.debug("Connecting to database with connection string: %s", conn_str)
        engine = create_engine(conn_str)
        try:
            df = get_data(engine, target_schema, target_table)
            dot = create_graph(df)

            # Получаем путь к директории, где находится скрипт
            script_dir = os.path.dirname(os.path.abspath(__file__))

            # Директория static для сохранения изображений
            static_dir = os.path.join(script_dir, 'static')

            # Формируем полный путь к файлу
            file_path = os.path.join(static_dir, f'{target_schema}_{target_table}_dependencies')

            dot.render(file_path, format='svg', cleanup=True)
            return render_template('graph.html', graph_path=f'{target_schema}_{target_table}_dependencies.svg', tables=get_table_list(engine), target_table=full_table)
        except Exception as e:
            logging.error("Error in graph generation: %s", e)
            return str(e)
    else:
        conn_str = f"postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
        engine = create_engine(conn_str)
        tables = get_table_list(engine)
        return render_template('graph.html', tables=tables)


@app.route('/tables')
def tables():
    conn_str = f"postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    logging.debug("Connecting to database with connection string: %s", conn_str)
    engine = create_engine(conn_str)
    try:
        table_list = get_table_list(engine)
        return jsonify(table_list)
    except Exception as e:
        logging.error("Error in tables endpoint: %s", e)
        return str(e)


@app.route('/show_graph')
def show_graph():
    conn_str = f"postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    logging.debug("Connecting to database with connection string: %s", conn_str)
    engine = create_engine(conn_str)
    try:
        tables = get_table_list(engine)
        return render_template('graph.html', tables=tables)
    except Exception as e:
        logging.error("Error in show_graph endpoint: %s", e)
        return str(e)


@app.route('/table_info/<schema>/<table>')
def table_info(schema, table):
    conn_str = f"postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    logging.debug("Connecting to database with connection string: %s", conn_str)
    engine = create_engine(conn_str)
    query = f"""
    SELECT source_schema, source_table, load_date, query_insert
    FROM source_target_time
    WHERE source_schema = '{schema}' AND source_table = '{table}'
    """
    try:
        df = pd.read_sql(query, engine)

        if df.empty:
            return f"Информация о таблице {schema}.{table} не найдена."

        table_info = df.iloc[0].to_dict()
        return render_template('table_info.html', table_info=table_info)
    except Exception as e:
        logging.error("Error in table_info endpoint: %s", e)
        return str(e)


@app.route('/other')
def other():
    conn_str = f"postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    logging.debug("Connecting to database with connection string: %s", conn_str)
    engine = create_engine(conn_str)
    try:
        tables = get_table_list(engine)
        return render_template('gantt.html', tables=tables)
    except Exception as e:
        logging.error("Error in other endpoint: %s", e)
        return str(e)


@app.route('/gantt', methods=['POST'])
def gantt():
    full_table = request.form['target_table']
    target_schema, target_table = full_table.split('.')
    conn_str = f"postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    logging.debug("Connecting to database with connection string: %s", conn_str)
    engine = create_engine(conn_str)
    try:
        df = get_gantt_data(engine, target_table)

        # Сортируем данные по start_data_source
        df.sort_values(by='start_data_source', inplace=True)

        # Выводим все данные DataFrame в лог
        logging.debug(tabulate(df, headers='keys', tablefmt='psql'))

        # Построение диаграммы Ганта с использованием Plotly
        fig = px.timeline(df, x_start="start_data_source", x_end="adjusted_finish_data_source", y="source_full",
                          color="source_full",
                          title="Диаграмма Ганта для Source",
                          hover_data={"start_data_source": True, "finish_data_source": True})

        fig.update_yaxes(categoryorder="total ascending", automargin=True)

        # Настройка размеров графика и линий
        fig.update_layout(
            height=max(400, 40 * len(df['source_full'].unique())),  # Высота графика
            width=2400,  # Ширина графика
            margin=dict(l=20, r=20, t=50, b=20),  # Отступы
            xaxis_title="Время",
            yaxis_title="Таблицы",
            font=dict(size=12),  # Размер шрифта
            yaxis=dict(tickmode='linear'),  # Обеспечить линейное отображение всех значений на оси Y
            xaxis=dict(
                tickformat="%H:%M:%S",  # Форматирование меток времени на оси X
                dtick=60000,  # Интервал между метками на оси X (в миллисекундах)
                tickangle=-45,  # Угол наклона меток времени
                showgrid=True,  # Показать сетку для улучшения видимости
                gridwidth=1,  # Ширина линии сетки
                gridcolor='LightGray',  # Цвет линии сетки
                zeroline=True,  # Показать ось нулевого значения
                zerolinewidth=2,  # Ширина линии нулевого значения
                zerolinecolor='Gray',  # Цвет линии нулевого значения
                showline=True,  # Показать ось X
                linewidth=2,  # Ширина оси X
                linecolor='Black',  # Цвет оси X
                tickmode='auto',
                nticks=20  # Количество меток на оси X
            )
        )
        fig.update_traces(marker=dict(line=dict(width=4), opacity=1), selector=dict(type='bar'))

        gantt_html = fig.to_html(full_html=False)
        return render_template('gantt.html', gantt_html=gantt_html, tables=get_table_list(engine))
    except Exception as e:
        logging.error("Error in gantt endpoint: %s", e)
        return str(e)

if __name__ == '__main__':
    app.run(debug=True)