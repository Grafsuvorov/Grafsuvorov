import argparse
import re
from pathlib import Path
from typing import List, Dict, Any, Tuple

import pandas as pd
from bs4 import BeautifulSoup, Comment

BASE_URL = "https://fbref.com"
SEASON_URL = "https://fbref.com/en/comps/9/schedule/Premier-League-Scores-and-Fixtures"


def _norm(s: str) -> str:
    return re.sub(r"\s+", " ", str(s or "").strip())


def _slug(s: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_.-]+", "_", str(s or "").strip()).strip("_") or "table"


def _to_abs_fbref_url(href: str) -> str:
    if not href:
        return ""
    return f"{BASE_URL}{href}" if href.startswith("/") else href


MONTHS = {
    "january": 1,
    "february": 2,
    "march": 3,
    "april": 4,
    "may": 5,
    "june": 6,
    "july": 7,
    "august": 8,
    "september": 9,
    "october": 10,
    "november": 11,
    "december": 12,
}

EPL_TEAMS = [
    "Arsenal",
    "Aston Villa",
    "Bournemouth",
    "Brentford",
    "Brighton",
    "Burnley",
    "Chelsea",
    "Crystal Palace",
    "Everton",
    "Fulham",
    "Ipswich Town",
    "Leicester City",
    "Liverpool",
    "Manchester City",
    "Manchester United",
    "Newcastle United",
    "Nottingham Forest",
    "Southampton",
    "Tottenham Hotspur",
    "West Ham United",
    "Wolves",
    "Wolverhampton Wanderers",
    "Sunderland",
]


def _team_tokens(team: str) -> List[str]:
    return [t.lower() for t in re.split(r"[\s-]+", team) if t]


TEAM_TOKENS = {team: _team_tokens(team) for team in EPL_TEAMS}


def _parse_match_url_parts(url: str) -> Dict[str, str]:
    """
    Парсит URL формата:
    /en/matches/<id>/Arsenal-Chelsea-March-4-2026-Premier-League
    """
    out = {"date": "", "home_team": "", "away_team": ""}
    if not url:
        return out
    slug = url.rstrip("/").split("/")[-1]
    tokens = [t for t in slug.split("-") if t]
    if len(tokens) < 5:
        return out
    # Team names are before first month token.
    month_idx = next((i for i, t in enumerate(tokens) if t.lower() in MONTHS), -1)
    if month_idx <= 1:
        return out
    if month_idx + 2 >= len(tokens):
        return out
    pre = [t.lower() for t in tokens[:month_idx]]
    home = ""
    away = ""
    # Try exact EPL team-token match for robust split.
    best_split = None
    for home_name, h_toks in TEAM_TOKENS.items():
        if not pre[: len(h_toks)] == h_toks:
            continue
        rem = pre[len(h_toks) :]
        for away_name, a_toks in TEAM_TOKENS.items():
            if rem == a_toks:
                score = len(h_toks) + len(a_toks)
                if best_split is None or score > best_split[0]:
                    best_split = (score, home_name, away_name)
    if best_split:
        _, home, away = best_split
    else:
        split_at = max(1, len(pre) // 2)
        home = " ".join(tokens[:split_at]).strip()
        away = " ".join(tokens[split_at:month_idx]).strip()

    month_name = tokens[month_idx].lower()
    day = tokens[month_idx + 1]
    year = tokens[month_idx + 2]
    try:
        date_iso = pd.Timestamp(year=int(year), month=MONTHS[month_name], day=int(day)).strftime("%Y-%m-%d")
    except Exception:
        date_iso = ""

    out["date"] = date_iso
    out["home_team"] = home
    out["away_team"] = away
    return out


def fetch_html_playwright(
    url: str,
    headless: bool = True,
    timeout_ms: int = 90000,
    wait_ms: int = 8000,
    manual_pause: bool = False,
    profile_dir: str = ".playwright-fbref-profile",
    challenge_wait_sec: int = 120,
) -> str:
    try:
        from playwright.sync_api import sync_playwright
    except Exception as e:
        raise RuntimeError(
            "Playwright не установлен. Установите: pip install playwright && playwright install chromium"
        ) from e

    with sync_playwright() as p:
        context = p.chromium.launch_persistent_context(
            user_data_dir=profile_dir,
            headless=headless,
            args=["--disable-blink-features=AutomationControlled"],
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/123.0.0.0 Safari/537.36"
            ),
            viewport={"width": 1440, "height": 900},
        )
        page = context.new_page()
        page.goto(url, wait_until="networkidle", timeout=timeout_ms)
        page.wait_for_timeout(wait_ms)
        if manual_pause and not headless:
            print("[MANUAL] Пройдите Cloudflare-проверку в браузере. Скрипт продолжит автоматически.")
        # Wait until challenge disappears (best effort, no terminal input required).
        max_checks = max(1, challenge_wait_sec)
        for _ in range(max_checks):
            html_probe = page.content().lower()
            if not any(x in html_probe for x in ["cloudflare", "just a moment", "attention required"]):
                break
            page.wait_for_timeout(1000)
        html = page.content()
        context.close()
        return html


def parse_schedule_rows(html: str) -> List[Dict[str, Any]]:
    soup = BeautifulSoup(html, "html.parser")
    rows: List[Dict[str, Any]] = []

    def extract_from_table(table):
        tbody = table.find("tbody")
        if not tbody:
            return
        for tr in tbody.find_all("tr"):
            if tr.get("class") and "thead" in tr.get("class"):
                continue
            date_cell = tr.find(attrs={"data-stat": "date"})
            home_cell = tr.find(attrs={"data-stat": "home_team"})
            away_cell = tr.find(attrs={"data-stat": "away_team"})
            score_cell = tr.find(attrs={"data-stat": "score"})
            rep_cell = tr.find(attrs={"data-stat": "match_report"})
            if not (date_cell and home_cell and away_cell):
                continue

            a = rep_cell.find("a") if rep_cell else None
            href = a.get("href") if a else None
            score = _norm(score_cell.get_text()) if score_cell else ""
            rows.append(
                {
                    "date": _norm(date_cell.get_text()),
                    "home_team": _norm(home_cell.get_text()),
                    "away_team": _norm(away_cell.get_text()),
                    "score": score,
                    "match_report_url": _to_abs_fbref_url(href),
                }
            )

    def extract_generic(s: BeautifulSoup):
        for tr in s.find_all("tr"):
            a = tr.find("a", href=re.compile(r"^/en/matches/"))
            if not a:
                continue
            tds = tr.find_all("td")
            if len(tds) < 4:
                continue
            txt = [_norm(td.get_text(" ", strip=True)) for td in tds]
            # Heuristic for schedule row: date + teams + score
            date_val = txt[0] if txt else ""
            home = txt[2] if len(txt) > 2 else ""
            score = txt[3] if len(txt) > 3 else ""
            away = txt[4] if len(txt) > 4 else ""
            if not (home and away and score):
                continue
            rows.append(
                {
                    "date": date_val,
                    "home_team": home,
                    "away_team": away,
                    "score": score,
                    "match_report_url": _to_abs_fbref_url(a.get("href")),
                }
            )

    def extract_from_links(s: BeautifulSoup):
        """
        Универсальный fallback: ищем любые ссылки на матч и достаем команды/дату
        из строки таблицы или URL.
        """
        for a in s.find_all("a", href=re.compile(r"^/en/matches/")):
            href = a.get("href", "")
            tr = a.find_parent("tr")
            date_val = ""
            home = ""
            away = ""
            score = ""

            if tr:
                date_cell = tr.find(attrs={"data-stat": "date"})
                home_cell = tr.find(attrs={"data-stat": "home_team"})
                away_cell = tr.find(attrs={"data-stat": "away_team"})
                score_cell = tr.find(attrs={"data-stat": "score"})
                if date_cell:
                    date_val = _norm(date_cell.get_text())
                if home_cell:
                    home = _norm(home_cell.get_text())
                if away_cell:
                    away = _norm(away_cell.get_text())
                if score_cell:
                    score = _norm(score_cell.get_text())

            if not (home and away):
                parts = _parse_match_url_parts(href)
                home = home or parts["home_team"]
                away = away or parts["away_team"]
                # URL date in ISO keeps matching stable even when table locale changes
                date_val = date_val or parts["date"]

            if not (home and away):
                continue

            rows.append(
                {
                    "date": date_val,
                    "home_team": home,
                    "away_team": away,
                    "score": score,
                    "match_report_url": _to_abs_fbref_url(href),
                }
            )

    for table in soup.find_all("table"):
        extract_from_table(table)
    for comment in soup.find_all(string=lambda t: isinstance(t, Comment)):
        if "<table" not in comment:
            continue
        c_soup = BeautifulSoup(comment, "html.parser")
        for table in c_soup.find_all("table"):
            extract_from_table(table)
        extract_generic(c_soup)
        extract_from_links(c_soup)

    # generic parse on visible html (fallback when data-stat attrs changed)
    extract_generic(soup)
    extract_from_links(soup)

    # unique by date/home/away
    seen = set()
    uniq = []
    for r in rows:
        k = (r["date"], r["home_team"], r["away_team"], r["match_report_url"])
        if k in seen:
            continue
        seen.add(k)
        uniq.append(r)
    return uniq


def extract_all_tables(html: str) -> List[Tuple[str, pd.DataFrame]]:
    soup = BeautifulSoup(html, "html.parser")
    out: List[Tuple[str, pd.DataFrame]] = []

    def parse_table(table, idx: int):
        table_id = table.get("id") or f"table_{idx}"
        try:
            dfs = pd.read_html(str(table))
        except Exception:
            return
        for j, df in enumerate(dfs):
            if isinstance(df.columns, pd.MultiIndex):
                df.columns = [" | ".join([str(x) for x in col if str(x) != "nan"]).strip() for col in df.columns]
            out.append((f"{table_id}_{j}", df))

    idx = 0
    for table in soup.find_all("table"):
        parse_table(table, idx)
        idx += 1

    for comment in soup.find_all(string=lambda t: isinstance(t, Comment)):
        if "<table" not in comment:
            continue
        c_soup = BeautifulSoup(comment, "html.parser")
        for table in c_soup.find_all("table"):
            parse_table(table, idx)
            idx += 1

    return out


def parse_args():
    p = argparse.ArgumentParser(description="Полная выгрузка статистики матча с FBref (через Playwright).")
    p.add_argument("--date", required=True, help="Дата матча YYYY-MM-DD, например 2026-03-04")
    p.add_argument("--home", required=False, default="", help="Домашняя команда (опционально)")
    p.add_argument("--away", required=False, default="", help="Гостевая команда (опционально)")
    p.add_argument("--season-url", default=SEASON_URL, help="URL страницы расписания FBref")
    p.add_argument("--match-url", default="", help="Прямой URL match report FBref (если указан, расписание не парсится)")
    p.add_argument("--schedule-html", default="", help="Локальный HTML страницы расписания FBref (обход Cloudflare)")
    p.add_argument("--match-html", default="", help="Локальный HTML страницы match report FBref (обход Cloudflare)")
    p.add_argument("--outdir", default="fbref_match_dump", help="Папка для выгрузки")
    p.add_argument("--headed", action="store_true", help="Запускать браузер не в headless режиме")
    p.add_argument("--wait-ms", type=int, default=8000, help="Дополнительное ожидание после загрузки страницы")
    p.add_argument("--manual-pause", action="store_true", help="Пауза в headed-режиме для ручного прохождения антибот-экрана")
    p.add_argument("--profile-dir", default=".playwright-fbref-profile", help="Папка профиля браузера Playwright (cookies/session)")
    p.add_argument("--challenge-wait-sec", type=int, default=120, help="Сколько секунд ждать окончания Cloudflare-челленджа")
    return p.parse_args()


def main():
    args = parse_args()
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    date_target = pd.to_datetime(args.date, errors="coerce")
    if pd.isna(date_target):
        raise RuntimeError("Неверная дата. Используйте YYYY-MM-DD.")
    date_target_str = date_target.strftime("%Y-%m-%d")

    if args.match_html:
        match = {
            "date": date_target_str,
            "home_team": args.home or "Home",
            "away_team": args.away or "Away",
            "score": "",
            "match_report_url": args.match_url.strip() or "local://match_html",
        }
    elif args.match_url:
        parts = _parse_match_url_parts(args.match_url)
        match = {
            "date": parts.get("date", "") or date_target_str,
            "home_team": parts.get("home_team", "") or (args.home or "Home"),
            "away_team": parts.get("away_team", "") or (args.away or "Away"),
            "score": "",
            "match_report_url": args.match_url.strip(),
        }
    else:
        # 1) schedule page
        if args.schedule_html:
            schedule_html = Path(args.schedule_html).read_text(encoding="utf-8")
        else:
            schedule_html = fetch_html_playwright(
                args.season_url,
                headless=not args.headed,
                wait_ms=args.wait_ms,
                manual_pause=args.manual_pause,
                profile_dir=args.profile_dir,
                challenge_wait_sec=args.challenge_wait_sec,
            )
        matches = parse_schedule_rows(schedule_html)
        if not matches:
            dbg = outdir / "debug_schedule.html"
            dbg.write_text(schedule_html, encoding="utf-8")
            lower_html = schedule_html.lower()
            cloudflare_hint = ""
            if any(x in lower_html for x in ["cloudflare", "just a moment", "attention required"]):
                cloudflare_hint = (
                    " Похоже, страница Cloudflare-челленджа. "
                    "Запустите --headed --challenge-wait-sec 300 и пройдите проверку вручную."
                )
            raise RuntimeError(
                "Не удалось распарсить матчи из расписания FBref. "
                f"Сохранен debug HTML: {dbg}. "
                "Попробуйте --headed --wait-ms 15000."
                f"{cloudflare_hint}"
            )

        filtered = []
        for m in matches:
            md = pd.to_datetime(m["date"], errors="coerce")
            if pd.isna(md):
                continue
            if md.strftime("%Y-%m-%d") != date_target_str:
                continue
            if args.home and _norm(args.home).lower() not in m["home_team"].lower():
                continue
            if args.away and _norm(args.away).lower() not in m["away_team"].lower():
                continue
            filtered.append(m)

        if not filtered:
            raise RuntimeError(f"Матчей за {date_target_str} не найдено (с учетом фильтров home/away).")

        match = filtered[0]
        if not match.get("match_report_url"):
            raise RuntimeError("У матча нет ссылки Match Report на странице расписания.")

    if args.match_html and not match.get("match_report_url"):
        match["match_report_url"] = "local://match_html"

    # 2) match report page
    if args.match_html:
        match_html = Path(args.match_html).read_text(encoding="utf-8")
    else:
        match_html = fetch_html_playwright(
            match["match_report_url"],
            headless=not args.headed,
            wait_ms=args.wait_ms,
            manual_pause=args.manual_pause,
            profile_dir=args.profile_dir,
            challenge_wait_sec=args.challenge_wait_sec,
        )
    tables = extract_all_tables(match_html)
    if not tables:
        raise RuntimeError("Не удалось извлечь таблицы со страницы match report.")

    stem = _slug(f"{date_target_str}_{match['home_team']}_vs_{match['away_team']}")
    meta = {
        "date": date_target_str,
        "home_team": match["home_team"],
        "away_team": match["away_team"],
        "score": match["score"],
        "match_report_url": match["match_report_url"],
        "tables_count": len(tables),
    }
    pd.DataFrame([meta]).to_json(outdir / f"{stem}_meta.json", orient="records", force_ascii=False, indent=2)

    for table_id, df in tables:
        fname = outdir / f"{stem}__{_slug(table_id)}.csv"
        df.to_csv(fname, index=False)

    print(f"[OK] Match: {match['home_team']} vs {match['away_team']} ({match['score']})")
    print(f"[OK] URL: {match['match_report_url']}")
    print(f"[OK] Tables saved: {len(tables)}")
    print(f"[OK] Outdir: {outdir.resolve()}")


if __name__ == "__main__":
    main()
