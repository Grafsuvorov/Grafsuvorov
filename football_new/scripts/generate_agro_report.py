#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
from pathlib import Path

import pandas as pd
from jinja2 import Template
from sqlalchemy import create_engine

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

from api.core.config import settings  # noqa: E402


def normalize_database_url(url: str) -> str:
    return url.replace("host.docker.internal", "127.0.0.1")


def fetch_df(engine, sql: str) -> pd.DataFrame:
    return pd.read_sql(sql, engine)


def fmt(v) -> str:
    if pd.isna(v):
        return ""
    if isinstance(v, float):
        return f"{v:,.2f}".replace(",", " ")
    return str(v)


def render_table(df: pd.DataFrame, max_rows: int | None = None) -> str:
    if max_rows is not None:
        df = df.head(max_rows)
    headers = "".join(f"<th>{col}</th>" for col in df.columns)
    rows = []
    for _, row in df.iterrows():
        cells = "".join(f"<td>{fmt(val)}</td>" for val in row.tolist())
        rows.append(f"<tr>{cells}</tr>")
    return f"<table><thead><tr>{headers}</tr></thead><tbody>{''.join(rows)}</tbody></table>"


def render_bar_list(df: pd.DataFrame, label_col: str, value_col: str, suffix: str = "") -> str:
    if df.empty:
        return "<p>Нет данных.</p>"
    max_value = df[value_col].max() or 1
    items = []
    for _, row in df.iterrows():
        label = fmt(row[label_col])
        value = row[value_col]
        width = max(float(value) / float(max_value) * 100.0, 1.5)
        items.append(
            f"""
            <div class="bar-row">
              <div class="bar-label">{label}</div>
              <div class="bar-track"><div class="bar-fill" style="width:{width:.2f}%"></div></div>
              <div class="bar-value">{fmt(value)}{suffix}</div>
            </div>
            """
        )
    return "".join(items)


def main() -> None:
    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    engine = create_engine(database_url, pool_pre_ping=True)

    overview = fetch_df(
        engine,
        """
        select
          (select count(*) from hybrids.sources) as sources,
          (select count(*) from hybrids.varieties) as varieties,
          (select count(*) from hybrids.trait_snapshots) as trait_snapshots,
          (select count(*) from hybrids.trial_results) as trial_results,
          (select count(*) from hybrids.trial_geo_links) as trial_geo_links,
          (select count(*) from agro.daily_weather_observations) as weather_rows,
          (select count(*) from agro.daily_agronomy_metrics) as agronomy_rows
        """,
    )
    trial_years = fetch_df(
        engine,
        """
        select s.provider as provider, s.source_type as source_type, tr.crop_code as crop, tr.season_year as year,
               count(*) as rows, round(avg(tr.yield_standard_c_ha)::numeric,2) as avg_yield
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        group by s.provider, s.source_type, tr.crop_code, tr.season_year
        order by tr.season_year, s.provider, s.source_type, tr.crop_code
        """,
    )
    agroplazma_trial = fetch_df(
        engine,
        """
        select s.source_type, tr.crop_code as crop, tr.season_year as year,
               count(*) as rows,
               count(distinct coalesce(tr.payload->>'site_name', tr.district, tr.subject_rf)) as sites,
               round(avg(tr.yield_standard_c_ha)::numeric,2) as avg_yield
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        where s.provider = 'Agroplazma'
          and s.source_type in ('map_widget', 'trial_page')
        group by s.source_type, tr.crop_code, tr.season_year
        order by tr.season_year, s.source_type, tr.crop_code
        """,
    )
    agroplazma_map_examples = fetch_df(
        engine,
        """
        select
          tr.season_year as year,
          tr.crop_code as crop,
          coalesce(tr.payload->>'site_name', v.name_raw) as site_name,
          v.name_raw as hybrid,
          round(tr.yield_standard_c_ha::numeric,2) as yield_c_ha,
          tr.payload->>'oil_pct' as oil_pct,
          tr.payload->>'coordinates' as coordinates
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        join hybrids.varieties v on v.id = tr.variety_id
        where s.provider = 'Agroplazma'
          and s.source_type = 'map_widget'
        order by tr.season_year desc, tr.crop_code, tr.yield_standard_c_ha desc
        limit 20
        """,
    )
    trial_provider_totals = fetch_df(
        engine,
        """
        select
          s.provider,
          s.source_type,
          count(*) as rows,
          count(distinct tr.season_year) as years,
          count(distinct tr.crop_code) as crops,
          round(avg(tr.yield_standard_c_ha)::numeric,2) as avg_yield
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        group by s.provider, s.source_type
        order by rows desc, s.provider, s.source_type
        """
    )
    provider_matrix = fetch_df(
        engine,
        """
        with t as (
          select provider, count(*) as trial_rows
          from hybrids.sources s
          join hybrids.trial_results tr on tr.source_id = s.id
          group by provider
        ),
        p as (
          select provider, count(*) as product_rows
          from hybrids.sources s
          join hybrids.trait_snapshots ts on ts.source_id = s.id
          group by provider
        )
        select
          coalesce(t.provider, p.provider) as provider,
          coalesce(trial_rows, 0) as trial_rows,
          coalesce(product_rows, 0) as product_rows
        from t
        full outer join p on p.provider = t.provider
        order by coalesce(trial_rows, 0) desc, coalesce(product_rows, 0) desc, coalesce(t.provider, p.provider)
        """
    )
    region_2025 = fetch_df(
        engine,
        """
        select tr.subject_rf as region, count(*) as trials,
               round(avg(tr.yield_standard_c_ha)::numeric,2) as avg_yield,
               round(min(tr.yield_standard_c_ha)::numeric,2) as min_yield,
               round(max(tr.yield_standard_c_ha)::numeric,2) as max_yield
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        where s.code = 'USER_XLSX_CORN_DEMO_2025' and tr.subject_rf is not null
        group by tr.subject_rf
        order by avg_yield desc, trials desc
        """,
    )
    district_2025 = fetch_df(
        engine,
        """
        select tr.subject_rf as region, trim(tr.district) as district, count(*) as trials,
               round(avg(tr.yield_standard_c_ha)::numeric,2) as avg_yield
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        where s.code = 'USER_XLSX_CORN_DEMO_2025' and tr.subject_rf is not null and tr.district is not null
        group by tr.subject_rf, trim(tr.district)
        having count(*) >= 3
        order by avg_yield desc, trials desc
        limit 25
        """,
    )
    hybrids_2025 = fetch_df(
        engine,
        """
        select v.name_raw as hybrid, v.manufacturer_norm as producer, count(*) as trials,
               round(avg(tr.yield_standard_c_ha)::numeric,2) as avg_yield,
               round((stddev_pop(tr.yield_standard_c_ha)/nullif(avg(tr.yield_standard_c_ha),0)*100)::numeric,2) as cv_pct
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        join hybrids.varieties v on v.id = tr.variety_id
        where s.code = 'USER_XLSX_CORN_DEMO_2025'
        group by v.name_raw, v.manufacturer_norm
        having count(*) >= 3
        order by avg_yield desc, trials desc
        limit 20
        """,
    )
    producers_2025 = fetch_df(
        engine,
        """
        select v.manufacturer_norm as producer, count(*) as trials,
               round(avg(tr.yield_standard_c_ha)::numeric,2) as avg_yield,
               round((stddev_pop(tr.yield_standard_c_ha)/nullif(avg(tr.yield_standard_c_ha),0)*100)::numeric,2) as cv_pct
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        join hybrids.varieties v on v.id = tr.variety_id
        where s.code = 'USER_XLSX_CORN_DEMO_2025'
        group by v.manufacturer_norm
        having count(*) >= 5
        order by avg_yield desc, trials desc
        """,
    )
    fao_2025 = fetch_df(
        engine,
        """
        select coalesce(tr.payload->>'fao_group_raw','n/a') as fao_group,
               count(*) as trials,
               round(avg(tr.yield_standard_c_ha)::numeric,2) as avg_yield
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        where s.code = 'USER_XLSX_CORN_DEMO_2025'
        group by coalesce(tr.payload->>'fao_group_raw','n/a')
        order by trials desc
        """,
    )
    sunflower_region_2025 = fetch_df(
        engine,
        """
        select tr.subject_rf as region, count(*) as trials,
               round(avg(tr.yield_standard_c_ha)::numeric,2) as avg_yield,
               round(avg(ts.oil_pct)::numeric,2) as avg_oil_pct
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        left join hybrids.trait_snapshots ts on ts.variety_id = tr.variety_id and ts.source_id = s.id
        where s.code = 'USER_XLSX_SUNFLOWER_DEMO_2025' and tr.subject_rf is not null
        group by tr.subject_rf
        order by avg_yield desc, trials desc
        """
    )
    sunflower_hybrids_2025 = fetch_df(
        engine,
        """
        select v.name_raw as hybrid, v.manufacturer_norm as producer, count(*) as trials,
               round(avg(tr.yield_standard_c_ha)::numeric,2) as avg_yield,
               round(avg(ts.oil_pct)::numeric,2) as avg_oil_pct
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        join hybrids.varieties v on v.id = tr.variety_id
        left join hybrids.trait_snapshots ts on ts.variety_id = tr.variety_id and ts.source_id = s.id
        where s.code = 'USER_XLSX_SUNFLOWER_DEMO_2025'
        group by v.name_raw, v.manufacturer_norm
        having count(*) >= 3
        order by avg_yield desc, trials desc
        limit 20
        """
    )
    sunflower_producers_2025 = fetch_df(
        engine,
        """
        select v.manufacturer_norm as producer, count(*) as trials,
               round(avg(tr.yield_standard_c_ha)::numeric,2) as avg_yield,
               round(avg(ts.oil_pct)::numeric,2) as avg_oil_pct
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        join hybrids.varieties v on v.id = tr.variety_id
        left join hybrids.trait_snapshots ts on ts.variety_id = tr.variety_id and ts.source_id = s.id
        where s.code = 'USER_XLSX_SUNFLOWER_DEMO_2025'
        group by v.manufacturer_norm
        having count(*) >= 3
        order by avg_yield desc, trials desc
        """
    )
    kws_grain_silage = fetch_df(
        engine,
        """
        select v.name_raw as hybrid, ts.fao,
               ts.yield_min_c_ha as grain_potential_c_ha,
               ts.yield_max_c_ha as silage_potential_c_ha,
               ts.payload->>'grain_type' as grain_type,
               ts.payload->>'moisture_release' as moisture_release,
               ts.payload->>'direction_of_use' as direction_of_use
        from hybrids.trait_snapshots ts
        join hybrids.sources s on s.id = ts.source_id
        join hybrids.varieties v on v.id = ts.variety_id
        where s.provider = 'KWS' and s.season_year = 2026
        order by ts.fao nulls last, v.name_raw
        """
    )
    trait_provider_coverage = fetch_df(
        engine,
        """
        select s.provider,
               s.season_year as year,
               s.crop_code as crop,
               count(*) as products,
               count(ts.fao) as fao_filled,
               count(ts.maturity_label) as maturity_filled,
               count(ts.yield_min_c_ha) as yield_filled,
               count(ts.oil_pct) as oil_filled
        from hybrids.trait_snapshots ts
        join hybrids.sources s on s.id = ts.source_id
        group by s.provider, s.season_year, s.crop_code
        order by s.provider, s.season_year, s.crop_code
        """
    )
    trait_provider_totals = fetch_df(
        engine,
        """
        select s.provider,
               count(*) as products,
               count(distinct s.crop_code) as crops,
               min(s.season_year) as min_year,
               max(s.season_year) as max_year
        from hybrids.trait_snapshots ts
        join hybrids.sources s on s.id = ts.source_id
        group by s.provider
        order by products desc, s.provider
        """
    )
    weather_2025 = fetch_df(
        engine,
        """
        select l.name as location,
               round(avg(w.temperature_mean_c)::numeric,2) as avg_temp,
               round(sum(w.precipitation_mm)::numeric,1) as precip_mm,
               round(sum(w.reference_et0_mm)::numeric,1) as et0_mm,
               round(sum(coalesce(w.precipitation_mm,0)-coalesce(w.reference_et0_mm,0))::numeric,1) as moisture_balance,
               sum(case when w.temperature_max_c >= 30 then 1 else 0 end) as heat_days
        from agro.daily_weather_observations w
        join agro.locations l on l.id = w.location_id
        join agro.data_sources ds on ds.id = w.source_id
        where ds.code = 'OPEN_METEO'
          and w.observation_date between date '2025-04-01' and date '2025-09-30'
        group by l.name
        order by moisture_balance asc
        """,
    )
    weather_compare = fetch_df(
        engine,
        """
        with x as (
          select extract(year from w.observation_date)::int as yr, l.name,
                 sum(w.precipitation_mm) as precip_mm,
                 sum(w.reference_et0_mm) as et0_mm,
                 avg(w.temperature_mean_c) as avg_temp,
                 sum(case when w.temperature_max_c >= 30 then 1 else 0 end) as heat_days
          from agro.daily_weather_observations w
          join agro.locations l on l.id = w.location_id
          join agro.data_sources ds on ds.id = w.source_id
          where ds.code = 'OPEN_METEO'
            and extract(month from w.observation_date) between 4 and 9
            and extract(year from w.observation_date) in (2024, 2025)
          group by yr, l.name
        )
        select a.name as location,
               round(a.avg_temp::numeric,2) as temp_2024,
               round(b.avg_temp::numeric,2) as temp_2025,
               round(a.precip_mm::numeric,1) as precip_2024,
               round(b.precip_mm::numeric,1) as precip_2025,
               round((a.precip_mm-a.et0_mm)::numeric,1) as balance_2024,
               round((b.precip_mm-b.et0_mm)::numeric,1) as balance_2025,
               a.heat_days as heat_2024,
               b.heat_days as heat_2025
        from x a
        join x b on a.name = b.name and a.yr = 2024 and b.yr = 2025
        order by a.name
        """,
    )

    template = Template(
        """
<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <title>Agro Report</title>
  <style>
    body { font-family: Inter, Arial, sans-serif; margin: 24px; color: #1f2937; background: #f8fafc; }
    h1, h2 { margin: 0 0 12px 0; }
    p { margin: 6px 0 14px 0; color: #475569; }
    .grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin: 16px 0 24px; }
    .card { background: white; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px; }
    .metric { font-size: 28px; font-weight: 700; color: #0f172a; }
    .label { font-size: 12px; color: #64748b; text-transform: uppercase; margin-bottom: 8px; }
    .section { margin: 0 0 24px 0; background: white; border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th, td { padding: 8px 10px; border-bottom: 1px solid #e2e8f0; text-align: left; vertical-align: top; }
    th { color: #475569; font-weight: 600; background: #f8fafc; position: sticky; top: 0; }
    .bar-row { display: grid; grid-template-columns: 240px 1fr 90px; gap: 12px; align-items: center; margin: 8px 0; }
    .bar-label, .bar-value { font-size: 13px; }
    .bar-track { height: 16px; background: #e2e8f0; border-radius: 999px; overflow: hidden; }
    .bar-fill { height: 100%; background: #16a34a; border-radius: 999px; }
    .bar-fill.alt { background: #2563eb; }
    .two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
    .small { font-size: 12px; color: #64748b; }
  </style>
</head>
<body>
  <h1>Агроотчет по базе</h1>
  <p>Сводка по trial-данным, продуктовым слоям и погоде. Источники: Syngenta, Agroplazma, Limagrain, Lidea, MAS Seeds, KWS, пользовательские Excel 2025, Open-Meteo, NASA POWER.</p>

  <div class="grid">
    {% for key, value in overview.items() %}
    <div class="card">
      <div class="label">{{ key }}</div>
      <div class="metric">{{ value }}</div>
    </div>
    {% endfor %}
  </div>

  <div class="section">
    <h2>Executive Summary</h2>
    <p>
      В базе уже разделены два класса данных: <b>trial-results</b> с фактической урожайностью и <b>product-layer</b> с официальными характеристиками гибридов.
      Самые свежие полевые массивы сейчас дают пользовательские Excel 2025, а по Agroplazma удалось добрать еще исторический слой из demo-страниц и карты урожайности за 2020-2023.
    </p>
    {{ provider_matrix_table | safe }}
  </div>

  <div class="section">
    <h2>Покрытие по годам</h2>
    {{ trial_years_table | safe }}
  </div>

  <div class="section two-col">
    <div>
      <h2>Провайдеры product-layer</h2>
      <p>Какие официальные слои гибридов уже собраны по провайдерам, культурам и сезонам.</p>
      {{ trait_provider_coverage_table | safe }}
    </div>
    <div>
      <h2>Итоги по провайдерам</h2>
      {{ trait_provider_totals_table | safe }}
    </div>
  </div>

  <div class="section two-col">
    <div>
      <h2>Trial Layer по провайдерам</h2>
      <p>Только реальные полевые результаты: PDF, Excel, demo-страницы, карта урожайности.</p>
      {{ trial_provider_totals_table | safe }}
    </div>
    <div>
      <h2>Agroplazma Trial Layer</h2>
      <p>Исторические данные из `map_widget` и табличные demo-результаты `trial_page`.</p>
      {{ agroplazma_trial_table | safe }}
    </div>
  </div>

  <div class="section">
    <h2>Agroplazma: примеры точек карты</h2>
    <p>Это сырые точки из карты урожайности: хозяйство, гибрид, урожайность, год и координаты.</p>
    {{ agroplazma_map_examples_table | safe }}
  </div>

  <div class="section">
    <h2>Кукуруза 2025 по регионам</h2>
    <p>Показатель: средняя урожайность на зерно при 14% влажности, ц/га.</p>
    {{ region_bars | safe }}
    <div style="margin-top:16px;">{{ region_table | safe }}</div>
  </div>

  <div class="section">
    <h2>Лучшие районы 2025</h2>
    {{ district_table | safe }}
  </div>

  <div class="section two-col">
    <div>
      <h2>Топ гибридов 2025</h2>
      {{ hybrids_bars | safe }}
    </div>
    <div>
      <h2>Производители 2025</h2>
      {{ producers_bars | safe }}
    </div>
  </div>

  <div class="section two-col">
    <div>
      <h2>Таблица гибридов</h2>
      {{ hybrids_table | safe }}
    </div>
    <div>
      <h2>Таблица производителей</h2>
      {{ producers_table | safe }}
    </div>
  </div>

  <div class="section two-col">
    <div>
      <h2>FAO-группы 2025</h2>
      {{ fao_bars | safe }}
    </div>
    <div>
      <h2>Подсолнечник 2025 по регионам</h2>
      {{ sunflower_region_bars | safe }}
    </div>
  </div>

  <div class="section two-col">
    <div>
      <h2>Подсолнечник 2025, регионы</h2>
      {{ sunflower_region_table | safe }}
    </div>
    <div>
      <h2>Подсолнечник 2025, гибриды</h2>
      {{ sunflower_hybrids_table | safe }}
    </div>
  </div>

  <div class="section two-col">
    <div>
      <h2>Подсолнечник 2025, производители</h2>
      {{ sunflower_producers_table | safe }}
    </div>
    <div>
      <h2>Погода 2025, апрель-сентябрь</h2>
      {{ weather_bars | safe }}
      <p class="small">Бар показывает величину дефицита влаги по модулю. Чем больше минус, тем сложнее сезон.</p>
    </div>
  </div>

  <div class="section two-col">
    <div>
      <h2>Погода 2025 по точкам</h2>
      {{ weather_table | safe }}
    </div>
    <div>
      <h2>Сравнение 2025 vs 2024</h2>
      {{ weather_compare_table | safe }}
    </div>
  </div>

  <div class="section two-col">
    <div>
      <h2>Портфель Syngenta 2025</h2>
      {{ syngenta_table | safe }}
    </div>
    <div>
      <h2>Портфель Limagrain 2026</h2>
      {{ limagrain_table | safe }}
    </div>
  </div>

  <div class="section">
    <h2>KWS: зерно и силос</h2>
    <p>Официальный product-layer KWS по кукурузе: потенциал зерна и зеленой массы, FAO и направление использования.</p>
    {{ kws_table | safe }}
  </div>
</body>
</html>
        """
    )

    output_html = template.render(
        overview=overview.iloc[0].to_dict(),
        provider_matrix_table=render_table(provider_matrix),
        trial_years_table=render_table(trial_years),
        trait_provider_coverage_table=render_table(trait_provider_coverage),
        trait_provider_totals_table=render_table(trait_provider_totals),
        trial_provider_totals_table=render_table(trial_provider_totals),
        agroplazma_trial_table=render_table(agroplazma_trial),
        agroplazma_map_examples_table=render_table(agroplazma_map_examples),
        region_bars=render_bar_list(region_2025.head(10), "region", "avg_yield", " ц/га"),
        region_table=render_table(region_2025),
        district_table=render_table(district_2025),
        hybrids_bars=render_bar_list(hybrids_2025.head(12), "hybrid", "avg_yield", " ц/га"),
        producers_bars=render_bar_list(producers_2025.head(12), "producer", "avg_yield", " ц/га"),
        hybrids_table=render_table(hybrids_2025),
        producers_table=render_table(producers_2025),
        fao_bars=render_bar_list(fao_2025, "fao_group", "avg_yield", " ц/га"),
        sunflower_region_bars=render_bar_list(sunflower_region_2025.head(10), "region", "avg_yield", " ц/га"),
        sunflower_region_table=render_table(sunflower_region_2025),
        sunflower_hybrids_table=render_table(sunflower_hybrids_2025),
        sunflower_producers_table=render_table(sunflower_producers_2025),
        weather_bars=render_bar_list(weather_2025.assign(deficit_abs=weather_2025["moisture_balance"].abs()), "location", "deficit_abs", " мм"),
        weather_table=render_table(weather_2025),
        weather_compare_table=render_table(weather_compare),
        syngenta_table=render_table(fetch_df(engine, "select s.crop_code as crop, count(*) as products, count(ts.fao) as fao_filled, count(ts.maturity_label) as maturity_filled from hybrids.trait_snapshots ts join hybrids.sources s on s.id=ts.source_id where s.provider='Syngenta' and s.season_year=2025 group by s.crop_code order by s.crop_code")),
        limagrain_table=render_table(fetch_df(engine, "select s.crop_code as crop, count(*) as products, count(ts.fao) as fao_filled, count(ts.maturity_label) as maturity_filled from hybrids.trait_snapshots ts join hybrids.sources s on s.id=ts.source_id where s.provider='Limagrain' and s.season_year=2026 group by s.crop_code order by s.crop_code")),
        kws_table=render_table(kws_grain_silage),
    )

    reports_dir = ROOT / "reports"
    reports_dir.mkdir(exist_ok=True)
    out_path = reports_dir / "agro_report.html"
    out_path.write_text(output_html, encoding="utf-8")
    print(out_path)


if __name__ == "__main__":
    main()
