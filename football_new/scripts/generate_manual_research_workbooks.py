#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

from api.core.config import settings  # noqa: E402


REPORTS_DIR = ROOT / "reports"
GUIDE_PATH = REPORTS_DIR / "01_manual_research_guide.xlsx"
EXISTING_PATH = REPORTS_DIR / "02_manual_research_existing_data.xlsx"
QUEUE_PATH = REPORTS_DIR / "03_manual_research_queue_and_gaps.xlsx"
LEGACY_FILES = [
    REPORTS_DIR / "manual_research_template.xlsx",
    REPORTS_DIR / "manual_research_overview.xlsx",
]


def normalize_database_url(url: str) -> str:
    return url.replace("host.docker.internal", "127.0.0.1")


def fetch_df(engine, sql: str) -> pd.DataFrame:
    return pd.read_sql(sql, engine)


def safe_unlink(path: Path) -> None:
    if path.exists():
        path.unlink()


def build_guide_workbook() -> None:
    instructions = pd.DataFrame(
        [
            {"step": 1, "topic": "С чего начинать", "details": "Сначала открыть 02_manual_research_existing_data.xlsx и 03_manual_research_queue_and_gaps.xlsx."},
            {"step": 2, "topic": "Что уже есть в базе", "details": "Не заносить повторно данные из User Upload 2025, Syngenta trial_pdf 2022-2024, Agroplazma map_widget 2020-2022, Agroplazma trial_page 2023."},
            {"step": 3, "topic": "Что искать", "details": "Фактические цифры из статей, кейсов, PDF, презентаций: урожайность, масличность, белок, влажность, крахмал, силос, корнаж."},
            {"step": 4, "topic": "Одна строка = один факт", "details": "Если в статье перечислены 5 гибридов с 5 урожайностями, это 5 отдельных строк."},
            {"step": 5, "topic": "Минимально обязательные поля", "details": "provider, source_type, source_url, crop_code, season_year, hybrid_name_raw, metric_type, metric_value, quote_raw."},
            {"step": 6, "topic": "review_status", "details": "Для нового ручного ввода ставить new. После самопроверки checked. После нашей финальной верификации approved."},
            {"step": 7, "topic": "Как не плодить дубли", "details": "Перед занесением искать совпадение по provider + crop + season_year + region + hybrid + metric_type + source_url."},
            {"step": 8, "topic": "Когда не заносить", "details": "Если это только описание гибрида без цифр или уже есть такая же строка в листах DO_NOT_DUPLICATE / TRIAL_LOADED / PRODUCT_LOADED."},
            {"step": 9, "topic": "Что делать с диапазоном", "details": "Если в статье указан диапазон, заносить отдельной строкой min или avg только если это явно понятно из текста, иначе писать диапазон в note и цитате."},
            {"step": 10, "topic": "Что делать с narrative claims", "details": "Если цифра из текста, а не из таблицы, source_type = article или case, comparison_basis = article_case или claim."},
        ]
    )

    field_rules = pd.DataFrame(
        [
            {"field": "provider", "rule": "Название компании-источника: Syngenta, Lidea, Limagrain, Agroplazma, MAS Seeds, KWS, Other."},
            {"field": "source_type", "rule": "article, blog, pdf, presentation, case, catalog, interview."},
            {"field": "crop_code", "rule": "corn, sunflower, soy, sorghum, chickpea."},
            {"field": "season_year", "rule": "Год, к которому относится результат, а не дата публикации."},
            {"field": "subject_rf", "rule": "Субъект РФ, если указан явно."},
            {"field": "district", "rule": "Район, если указан явно."},
            {"field": "farm_name", "rule": "Хозяйство / КФХ / ООО / СПК, если указан источник."},
            {"field": "hybrid_name_raw", "rule": "Название гибрида как в источнике, без нормализации."},
            {"field": "manufacturer_norm", "rule": "Нормализованный производитель гибрида, если очевиден."},
            {"field": "metric_type", "rule": "yield_c_ha, oil_pct, protein_pct, moisture_pct, starch_pct, silage_yield_c_ha, cornage_yield_c_ha, dry_matter_pct."},
            {"field": "comparison_basis", "rule": "standard_moisture, harvest_moisture, demo, production, claim, article_case."},
            {"field": "quote_raw", "rule": "Короткий сырой фрагмент из статьи с цифрой."},
        ]
    )

    template_columns = [
        "provider",
        "source_type",
        "source_url",
        "published_at",
        "crop_code",
        "season_year",
        "subject_rf",
        "district",
        "farm_name",
        "hybrid_name_raw",
        "manufacturer_norm",
        "metric_type",
        "metric_value",
        "metric_unit",
        "comparison_basis",
        "technology",
        "fao_raw",
        "oil_pct",
        "protein_pct",
        "moisture_pct",
        "quote_raw",
        "note",
        "entered_by",
        "review_status",
        "approved_by",
    ]
    entry_template = pd.DataFrame(columns=template_columns)

    examples = pd.DataFrame(
        [
            {
                "provider": "Limagrain",
                "source_type": "article",
                "source_url": "https://lgseeds.ru/blog/Itogisezona2025popodsolnechnikuvTSCHRglavnyevyzovyiurozhaynost/",
                "published_at": "2025-12-01",
                "crop_code": "sunflower",
                "season_year": 2025,
                "subject_rf": "Белгородская область",
                "district": "",
                "farm_name": "",
                "hybrid_name_raw": "ЛГ 50479 СХ",
                "manufacturer_norm": "Limagrain",
                "metric_type": "yield_c_ha",
                "metric_value": 38.0,
                "metric_unit": "c_ha",
                "comparison_basis": "article_case",
                "technology": "",
                "fao_raw": "",
                "oil_pct": "",
                "protein_pct": "",
                "moisture_pct": "",
                "quote_raw": "ЛГ 50479 СХ - 38 ц/га",
                "note": "Из narrative статьи, проверить контекст региона.",
                "entered_by": "colleague",
                "review_status": "new",
                "approved_by": "",
            },
            {
                "provider": "Lidea",
                "source_type": "article",
                "source_url": "https://lidea-seeds.ru/news/blog/soy-leaders",
                "published_at": "2025-01-13",
                "crop_code": "soy",
                "season_year": 2024,
                "subject_rf": "ЦФО",
                "district": "",
                "farm_name": "",
                "hybrid_name_raw": "Командор",
                "manufacturer_norm": "Lidea",
                "metric_type": "protein_pct",
                "metric_value": 41.5,
                "metric_unit": "pct",
                "comparison_basis": "article_case",
                "technology": "",
                "fao_raw": "",
                "oil_pct": 19.5,
                "protein_pct": 41.5,
                "moisture_pct": "",
                "quote_raw": "Содержание белка 41,5%",
                "note": "Можно завести второй строкой yield_c_ha из той же статьи.",
                "entered_by": "colleague",
                "review_status": "new",
                "approved_by": "",
            },
        ]
    )

    dictionaries = pd.DataFrame(
        [
            {"field": "provider", "allowed_values": "Agroplazma; Syngenta; Lidea; Limagrain; MAS Seeds; KWS; Other"},
            {"field": "source_type", "allowed_values": "article; blog; pdf; presentation; case; catalog; interview"},
            {"field": "crop_code", "allowed_values": "corn; sunflower; soy; sorghum; chickpea"},
            {"field": "metric_type", "allowed_values": "yield_c_ha; oil_pct; protein_pct; moisture_pct; starch_pct; silage_yield_c_ha; cornage_yield_c_ha; dry_matter_pct"},
            {"field": "metric_unit", "allowed_values": "c_ha; pct; t_ha; kg_ha"},
            {"field": "comparison_basis", "allowed_values": "standard_moisture; harvest_moisture; demo; production; claim; article_case"},
            {"field": "review_status", "allowed_values": "new; checked; approved; rejected"},
        ]
    )

    with pd.ExcelWriter(GUIDE_PATH, engine="openpyxl") as writer:
        instructions.to_excel(writer, sheet_name="README", index=False)
        field_rules.to_excel(writer, sheet_name="FIELD_RULES", index=False)
        entry_template.to_excel(writer, sheet_name="ENTRY_TEMPLATE", index=False)
        examples.to_excel(writer, sheet_name="EXAMPLES", index=False)
        dictionaries.to_excel(writer, sheet_name="DICTIONARIES", index=False)


def build_existing_workbook(engine) -> None:
    provider_matrix = fetch_df(
        engine,
        """
        select
          s.provider,
          s.source_type,
          coalesce(s.crop_code, tr.crop_code, ts.crop_code) as crop_code,
          coalesce(s.season_year, tr.season_year) as season_year,
          count(distinct s.id) as source_count,
          count(distinct tr.id) as trial_rows,
          count(distinct ts.id) as trait_rows
        from hybrids.sources s
        left join hybrids.trial_results tr on tr.source_id = s.id
        left join hybrids.trait_snapshots ts on ts.source_id = s.id
        group by s.provider, s.source_type, coalesce(s.crop_code, tr.crop_code, ts.crop_code), coalesce(s.season_year, tr.season_year)
        order by season_year nulls first, s.provider, s.source_type, crop_code
        """,
    )

    trial_loaded = fetch_df(
        engine,
        """
        select
          s.provider,
          s.source_type,
          tr.crop_code,
          tr.season_year,
          tr.subject_rf,
          tr.district,
          coalesce(tr.payload->>'site_name','') as site_name,
          v.name_raw as hybrid_name,
          v.manufacturer_norm as manufacturer,
          round(tr.yield_standard_c_ha::numeric,2) as yield_c_ha,
          tr.source_url
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        join hybrids.varieties v on v.id = tr.variety_id
        order by tr.season_year desc, s.provider, s.source_type, tr.crop_code, tr.subject_rf nulls last, tr.district nulls last, v.name_raw
        """,
    )

    product_loaded = fetch_df(
        engine,
        """
        select
          s.provider,
          s.source_type,
          s.crop_code,
          s.season_year,
          v.name_raw as hybrid_name,
          v.manufacturer_norm as manufacturer,
          ts.fao,
          ts.maturity_label,
          ts.oil_pct,
          ts.yield_min_c_ha,
          ts.yield_max_c_ha,
          ts.source_url
        from hybrids.trait_snapshots ts
        join hybrids.sources s on s.id = ts.source_id
        join hybrids.varieties v on v.id = ts.variety_id
        order by s.provider, s.season_year nulls last, s.source_type, s.crop_code, v.name_raw
        """,
    )

    do_not_duplicate = fetch_df(
        engine,
        """
        select
          s.provider,
          s.source_type,
          tr.crop_code,
          tr.season_year,
          coalesce(tr.subject_rf,'') as subject_rf,
          coalesce(tr.district,'') as district,
          coalesce(tr.payload->>'site_name','') as site_name,
          v.name_raw as hybrid_name,
          round(tr.yield_standard_c_ha::numeric,2) as yield_c_ha,
          tr.source_url
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        join hybrids.varieties v on v.id = tr.variety_id
        where
          (s.provider = 'User Upload' and tr.season_year = 2025)
          or (s.provider = 'Syngenta' and s.source_type = 'trial_pdf')
          or (s.provider = 'Agroplazma' and s.source_type in ('map_widget', 'trial_page'))
        order by tr.season_year desc, s.provider, s.source_type, tr.crop_code, subject_rf, district, hybrid_name
        """,
    )

    duplicate_risk = fetch_df(
        engine,
        """
        select
          tr.crop_code,
          tr.season_year,
          tr.subject_rf,
          tr.district,
          v.name_raw as hybrid_name,
          count(*) as cnt
        from hybrids.trial_results tr
        join hybrids.varieties v on v.id = tr.variety_id
        group by tr.crop_code, tr.season_year, tr.subject_rf, tr.district, v.name_raw
        having count(*) > 1
        order by cnt desc, tr.season_year desc, tr.crop_code, v.name_raw
        """,
    )

    with pd.ExcelWriter(EXISTING_PATH, engine="openpyxl") as writer:
        provider_matrix.to_excel(writer, sheet_name="YEAR_SOURCE_MATRIX", index=False)
        trial_loaded.to_excel(writer, sheet_name="TRIAL_LOADED", index=False)
        product_loaded.to_excel(writer, sheet_name="PRODUCT_LOADED", index=False)
        do_not_duplicate.to_excel(writer, sheet_name="DO_NOT_DUPLICATE", index=False)
        duplicate_risk.to_excel(writer, sheet_name="DUPLICATE_RISK", index=False)


def build_queue_workbook(engine) -> None:
    fresh_coverage = fetch_df(
        engine,
        """
        select
          tr.season_year,
          tr.crop_code,
          count(*) as rows,
          count(distinct s.provider || '|' || s.source_type) as provider_layers
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        where tr.season_year between 2024 and 2026
        group by tr.season_year, tr.crop_code
        order by tr.season_year, tr.crop_code
        """,
    )

    gaps = pd.DataFrame(
        [
            {"priority": "high", "crop_code": "corn", "season_year": 2024, "gap": "Нужны новые источники кроме Syngenta trial_pdf", "why": "Сейчас 2024 по кукурузе почти весь слой держится на Syngenta."},
            {"priority": "high", "crop_code": "sunflower", "season_year": 2024, "gap": "Нужны новые источники кроме Syngenta trial_pdf", "why": "Нужна межвендорная картина."},
            {"priority": "high", "crop_code": "corn", "season_year": 2025, "gap": "Есть Excel, но мало статей и кейсов", "why": "Нужно обогатить свежими narrative/case sources."},
            {"priority": "high", "crop_code": "sunflower", "season_year": 2025, "gap": "Есть Excel, но нужны статьи и PDF по кейсам", "why": "Нужно сопоставление product vs actual."},
            {"priority": "high", "crop_code": "soy", "season_year": 2024, "gap": "Есть отдельные article facts, нет широкого trial-layer", "why": "Нужно добрать кейсы и публикации по сое."},
            {"priority": "high", "crop_code": "soy", "season_year": 2025, "gap": "Почти пусто", "why": "Свежий год без нормального фактического слоя."},
            {"priority": "medium", "crop_code": "corn", "season_year": 2026, "gap": "Пока нет завершенного сезона", "why": "Можно собирать только ранние кейсы и product layer."},
            {"priority": "medium", "crop_code": "sunflower", "season_year": 2026, "gap": "Пока нет завершенного сезона", "why": "Ожидаемо нет полноценного trial-layer."},
        ]
    )

    source_queue = pd.DataFrame(
        [
            {"provider": "Syngenta", "year_hint": 2024, "crop_code": "sunflower", "source_type": "product_page_pdf", "priority": "high", "status": "not_started", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/avenger", "what_to_extract": "region, hybrid, yield, moisture, technology", "note": "На странице есть PDF results 2024."},
            {"provider": "Syngenta", "year_hint": 2024, "crop_code": "sunflower", "source_type": "product_page_pdf", "priority": "high", "status": "not_started", "source_url": "https://www.syngenta.ru/products/seeds/sunflower/suomi", "what_to_extract": "region, hybrid, yield, moisture, technology", "note": "На странице есть PDF results 2024."},
            {"provider": "Lidea", "year_hint": 2024, "crop_code": "soy", "source_type": "article", "priority": "high", "status": "not_started", "source_url": "https://lidea-seeds.ru/news/blog/soy-leaders", "what_to_extract": "yield, protein, oil, region, variety", "note": "Часть уже есть, нужно дочистить и разложить вручную."},
            {"provider": "Lidea", "year_hint": 2024, "crop_code": "corn", "source_type": "article", "priority": "high", "status": "not_started", "source_url": "https://lidea-seeds.ru/news/katamaran-stable", "what_to_extract": "district, hybrid, yield, benchmark context", "note": "Точечные результаты по кукурузе."},
            {"provider": "Lidea", "year_hint": 2025, "crop_code": "soy", "source_type": "article", "priority": "high", "status": "not_started", "source_url": "https://lidea-seeds.ru/", "what_to_extract": "опыты/кейсы 2025 по сое, yield/protein/oil", "note": "Проверять свежие публикации 2025-2026."},
            {"provider": "Limagrain", "year_hint": 2024, "crop_code": "corn", "source_type": "catalog_pdf", "priority": "high", "status": "not_started", "source_url": "https://lgseeds.ru/upload/Catalog_Limagrain_2025-2026.pdf", "what_to_extract": "region, district, hybrid, yield, moisture, oil", "note": "Каталог содержит фактические кейсы 2024."},
            {"provider": "Limagrain", "year_hint": 2025, "crop_code": "sunflower", "source_type": "article", "priority": "high", "status": "not_started", "source_url": "https://lgseeds.ru/blog/Itogisezona2025popodsolnechnikuvTSCHRglavnyevyzovyiurozhaynost/", "what_to_extract": "yield, region, hybrid, comparison", "note": "Narrative article with цифры."},
            {"provider": "Limagrain", "year_hint": 2025, "crop_code": "corn", "source_type": "article", "priority": "medium", "status": "not_started", "source_url": "https://lgseeds.ru/blog/Itogisezonakukuruzy2025itendentsiirazvitiyakultury/", "what_to_extract": "yield, region, agronomy thresholds", "note": "Narrative results and thresholds."},
            {"provider": "Agroplazma", "year_hint": 2025, "crop_code": "corn", "source_type": "pdf", "priority": "medium", "status": "not_started", "source_url": "https://agroplazma.com/files/price2025.pdf", "what_to_extract": "claimed FAO, use, technology, price", "note": "Не trial, но полезно для claimed-layer."},
            {"provider": "MAS Seeds", "year_hint": 2025, "crop_code": "corn", "source_type": "tech_sheet_or_article", "priority": "medium", "status": "not_started", "source_url": "https://www.masseeds.ru/poisk-produktov/?seed=kukuruza", "what_to_extract": "если есть техлисты/кейсы: yield, silage traits", "note": "Проверять карточки и PDF."},
        ]
    )

    fresh_loaded = fetch_df(
        engine,
        """
        select
          s.provider,
          s.source_type,
          tr.crop_code,
          tr.season_year,
          count(*) as rows,
          round(avg(tr.yield_standard_c_ha)::numeric,2) as avg_yield
        from hybrids.trial_results tr
        join hybrids.sources s on s.id = tr.source_id
        where tr.season_year between 2024 and 2026
        group by s.provider, s.source_type, tr.crop_code, tr.season_year
        order by tr.season_year, s.provider, s.source_type, tr.crop_code
        """,
    )

    not_processed_notes = pd.DataFrame(
        [
            {"topic": "Что уже загружено полностью", "details": "User Upload 2025 corn/sunflower, Syngenta trial_pdf 2022-2024, Agroplazma map_widget 2020-2022, Agroplazma trial_page 2023."},
            {"topic": "Что частично проработано", "details": "Lidea и Limagrain article/case layer найден, но не весь разобран в structured facts."},
            {"topic": "Что пока не найдено", "details": "Полноценный public trial-layer 2026 по corn/sunflower/soy."},
            {"topic": "Главная задача коллеги", "details": "Ручной разбор narrative sources 2024-2025 и внесение фактов в ENTRY_TEMPLATE."},
        ]
    )

    with pd.ExcelWriter(QUEUE_PATH, engine="openpyxl") as writer:
        fresh_coverage.to_excel(writer, sheet_name="FRESH_2024_2026_LOADED", index=False)
        gaps.to_excel(writer, sheet_name="GAPS", index=False)
        source_queue.to_excel(writer, sheet_name="SOURCE_QUEUE", index=False)
        not_processed_notes.to_excel(writer, sheet_name="NOTES", index=False)


def main() -> None:
    REPORTS_DIR.mkdir(exist_ok=True)
    for path in LEGACY_FILES + [GUIDE_PATH, EXISTING_PATH, QUEUE_PATH]:
        safe_unlink(path)

    database_url = normalize_database_url(os.getenv("DATABASE_URL", settings.DATABASE_URL))
    engine = create_engine(database_url, pool_pre_ping=True)

    build_guide_workbook()
    build_existing_workbook(engine)
    build_queue_workbook(engine)

    print(GUIDE_PATH)
    print(EXISTING_PATH)
    print(QUEUE_PATH)


if __name__ == "__main__":
    main()
