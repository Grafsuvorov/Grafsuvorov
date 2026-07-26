// src/pages/LeagueTablePage.jsx
import { useEffect, useMemo, useState } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import clsx from "clsx";
import { Layers3, Sparkles } from "lucide-react";
import {
  Table,
  TableHeader,
  TableRow,
  TableHead,
  TableBody,
  TableCell,
} from "@/components/ui/table";
import SafeImg from "@/components/SafeImg";
import SegmentedTabs from "@/components/ui/SegmentedTabs";
import { useLanguage } from "@/context/LanguageContext.jsx";

/* =============================
   CONSTANTS & HELPERS
============================= */

const makeSeasonList = (startYear = 2010) => {
  const now = new Date();
  const current = now.getFullYear();
  const list = [];
  for (let y = current; y >= startYear; y -= 1) {
    list.push(String(y));
  }
  return list;
};
const DEFAULT_SEASONS = makeSeasonList(2010);
const LEAGUE_SEASONS = {
  "UEFA Champions League": ["2025", "2024"],
  "UEFA Europa League": ["2025", "2024"],
  "World Cup": ["2026", "2022"],
  "Euro Championship": ["2024", "2020"],
  "Euro Championship - Qualification": ["2023"],
  "World Cup - Qualification Europe": ["2024", "2020"],
  "World Cup - Qualification Africa": ["2026", "2022"],
  "World Cup - Qualification Asia": ["2026", "2022"],
  "World Cup - Qualification CONCACAF": ["2026", "2022"],
  "World Cup - Qualification South America": ["2026", "2022"],
  "World Cup - Qualification Oceania": ["2026", "2022"],
  "World Cup - Qualification Intercontinental Play-offs": ["2026", "2022"],
};

const SEASON_LABELS = {
  "Euro Championship - Qualification": {
    "2023": "Отбор к Евро 2024",
  },
  "World Cup - Qualification Europe": {
    "2024": "Отбор к ЧМ 2026",
    "2020": "Отбор к ЧМ 2022",
  },
  "World Cup - Qualification Africa": {
    "2023": "Отбор к ЧМ 2026",
    "2022": "Отбор к ЧМ 2022",
  },
  "World Cup - Qualification Asia": {
    "2026": "Отбор к ЧМ 2026",
    "2022": "Отбор к ЧМ 2022",
  },
  "World Cup - Qualification CONCACAF": {
    "2026": "Отбор к ЧМ 2026",
    "2022": "Отбор к ЧМ 2022",
  },
  "World Cup - Qualification South America": {
    "2026": "Отбор к ЧМ 2026",
    "2022": "Отбор к ЧМ 2022",
  },
  "World Cup - Qualification Oceania": {
    "2026": "Отбор к ЧМ 2026",
    "2022": "Отбор к ЧМ 2022",
  },
  "World Cup - Qualification Intercontinental Play-offs": {
    "2026": "Плей-офф к ЧМ 2026",
    "2022": "Плей-офф к ЧМ 2022",
  },
};

const seasonLabel = (league, season, language = "ru") => {
  const label = SEASON_LABELS[league]?.[season];
  if (!label) return season;
  if (language === "en") {
    return label
      .replace("Отбор к Евро", "Euro Qualifiers")
      .replace("Отбор к ЧМ", "World Cup Qualifiers")
      .replace("Плей-офф к ЧМ", "World Cup Play-offs");
  }
  return label;
};
const ageFromDate = (val) => {
  if (!val) return null;
  const d = new Date(val);
  if (Number.isNaN(+d)) return null;
  const now = new Date();
  let age = now.getFullYear() - d.getFullYear();
  const m = now.getMonth() - d.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < d.getDate())) age -= 1;
  return age > 0 ? age : null;
};
const getPlayerPosition = (p) =>
  p?.position ||
  p?.player_position ||
  p?.pos ||
  p?.player?.position ||
  p?.player?.player_position ||
  p?.player?.pos ||
  p?.statistics?.[0]?.games?.position ||
  p?.games?.position ||
  null;
const getPlayerAge = (p) =>
  p?.age ||
  p?.player_age ||
  p?.age_years ||
  p?.player?.age ||
  p?.player?.player_age ||
  p?.player?.age_years ||
  ageFromDate(
    p?.birth_date ||
      p?.birthdate ||
      p?.dob ||
      p?.player?.birth?.date ||
      p?.player?.birth_date ||
      p?.player?.birthdate ||
      p?.player?.dob
  ) ||
  null;

const formatPlayerMeta = (p, language = "ru") => {
  const bits = [];
  const position = getPlayerPosition(p);
  const age = getPlayerAge(p);
  if (position) bits.push(position);
  if (age) bits.push(language === "ru" ? `${age} лет` : `${age} y.o.`);
  return bits.length ? bits.join(" • ") : "—";
};

const INTL_GROUPED_LEAGUES = new Set([
  "World Cup",
  "Euro Championship",
  "Euro Championship - Qualification",
  "World Cup - Qualification Europe",
  "World Cup - Qualification Africa",
  "World Cup - Qualification Asia",
  "World Cup - Qualification CONCACAF",
  "World Cup - Qualification South America",
  "World Cup - Qualification Oceania",
  "World Cup - Qualification Intercontinental Play-offs",
]);

const INTL_BRACKET_LEAGUES = new Set(["World Cup", "Euro Championship"]);
const EURO_CUP_LEAGUES = new Set(["UEFA Champions League", "UEFA Europa League"]);

/* =============================
   PREMIUM GLASS UI TOKENS
============================= */

const BG_PANEL =
  "rounded-[18px] border border-white/5 bg-white/[0.02]";

const TABLE_GLASS =
  "bg-white/[0.02] rounded-2xl overflow-hidden border border-white/5";

const TEXT_MUTED = "text-white/55";

const HOVER_ROW = "hover:bg-white/[0.025] transition-all duration-150";

const TH_STICKY =
  "sticky top-0 z-20 bg-white/[0.02] border-b border-white/8";

const ACCENT_BG =
  "bg-white/[0.08] text-white border border-white/20";

const teamLogo = (id) =>
  id
    ? `/icons/team_logos/${id}.png`
    : "/icons/team_logos/default.png";

const teamLogoFallback = (id) =>
  id
    ? `https://media.api-sports.io/football/teams/${id}.png`
    : "/icons/team_logos/default.png";

const playerPhotoFallback = (id) =>
  id
    ? `https://media.api-sports.io/football/players/${id}.png`
    : "/icons/player_photos/default.png";

const getGroupTableLabel = (groupName, language, isIntlGroupedLeague) => {
  if (!groupName) {
    return language === "ru" ? "Основная таблица" : "Main table";
  }
  if (isIntlGroupedLeague && groupName === "Group Stage") {
    return language === "ru" ? "Третьи места" : "Best Third-Placed Teams";
  }
  return groupName;
};

/* =============================
   SORTING
============================= */

const SORT_DEFAULT = { key: "rank", dir: "asc" };

const SORT_FIELDS = {
  rank: "rank",
  team: "team",
  games_played: "games_played",
  wins: "wins",
  draws: "draws",
  losses: "losses",
  goal_diff: "goal_diff",
  points: "points",
};

const getSortValue = (row, key) => {
  switch (key) {
    case "team":
      return String(row.team || "").toLowerCase();
    case "goal_diff": {
      const gf = Number(row.goals_for ?? 0);
      const ga = Number(row.goals_against ?? 0);
      if (row.goal_difference != null) return Number(row.goal_difference);
      return gf - ga;
    }
    default:
      return Number(row[key] ?? 0);
  }
};

/* =============================
   PAGE
============================= */

export default function LeagueTablePage() {
  const { t, language } = useLanguage();
  const [searchParams, setSearchParams] = useSearchParams();
  const navigate = useNavigate();

  const leagueParam = searchParams.get("league") || "Premier League";
  const seasonParam = searchParams.get("season") || "2025";
  const viewParam = searchParams.get("view") || "total";
  const isEuroCup = EURO_CUP_LEAGUES.has(leagueParam);
  const isIntlBracketCup = INTL_BRACKET_LEAGUES.has(leagueParam);
  const isIntlGroupedLeague = INTL_GROUPED_LEAGUES.has(leagueParam);
  const seasonOptions = LEAGUE_SEASONS[leagueParam] || DEFAULT_SEASONS;
  const viewLabel = (code, fallback) =>
    ({
      total: isIntlGroupedLeague ? t("groups") : t("table"),
      home: t("homeView"),
      away: t("awayView"),
      scorers: t("scorers"),
      assists: t("assists"),
      playoff: t("playoff"),
    }[code] || fallback);
  const availableViews = useMemo(
    () =>
      (isEuroCup || isIntlBracketCup
        ? ["total", "playoff", "scorers", "assists"]
        : ["total", "home", "away", "scorers", "assists"]).map((code) => ({
        code,
        label: viewLabel(code, code),
      })),
    [isEuroCup, isIntlBracketCup, isIntlGroupedLeague, t]
  );

  const [season, setSeason] = useState(
    seasonOptions.includes(seasonParam) ? seasonParam : seasonOptions[0]
  );
  const [view, setView] = useState(viewParam);

  const [rows, setRows] = useState([]);
  const [bracket, setBracket] = useState([]);
  const [loading, setLoading] = useState(false);
  const [sort, setSort] = useState(SORT_DEFAULT);
  const [expandedTies, setExpandedTies] = useState({});

  /* sync URL */
  useEffect(() => {
    if (!availableViews.some((item) => item.code === view)) {
      setView(availableViews[0].code);
    }
  }, [availableViews, view]);

  useEffect(() => {
    if (!seasonOptions.includes(season)) {
      setSeason(seasonOptions[0]);
    }
  }, [seasonOptions, season]);

  useEffect(() => {
    setSearchParams({
      league: leagueParam,
      season,
      view,
    });
  }, [leagueParam, season, view, setSearchParams]);

  /* fetch data */
  useEffect(() => {
    let endpoint = "";

    if (view === "playoff" && (isEuroCup || isIntlBracketCup)) {
      endpoint = `/api/cup/bracket?league=${encodeURIComponent(
        leagueParam
      )}&season=${season}`;
    } else if (view === "scorers") {
      endpoint = `/api/top-scorers?league=${encodeURIComponent(
        leagueParam
      )}&season=${season}`;
    } else if (view === "assists") {
      endpoint = `/api/top-assists?league=${encodeURIComponent(
        leagueParam
      )}&season=${season}`;
    } else {
      endpoint = `/api/league-table?league=${encodeURIComponent(
        leagueParam
      )}&season=${season}&view=${view}`;
    }

    setLoading(true);
    fetch(endpoint)
      .then((r) => r.json())
      .then((data) => {
        if (view === "playoff" && (isEuroCup || isIntlBracketCup)) {
          setBracket(Array.isArray(data?.rounds) ? data.rounds : []);
          setRows([]);
        } else {
          setRows(Array.isArray(data) ? data : []);
          setBracket([]);
        }
      })
      .catch((e) => {
        console.error("LeagueTablePage fetch error:", e);
        setRows([]);
        setBracket([]);
      })
      .finally(() => setLoading(false));
  }, [leagueParam, season, view, isEuroCup, isIntlBracketCup]);

  /* SORTED TABLE (для обычной турнирной таблицы) */
  const sortedTable = useMemo(() => {
    if (!Array.isArray(rows) || view === "scorers" || view === "assists")
      return [];

    const data = rows.filter(
      (t) => t && t.team && t.team_id != null && t.rank != null
    );
    const deduped = new Map();
    for (const t of data) {
      const key =
        t.team_id != null ? `id:${t.team_id}` : `name:${t.team}`;
      const prev = deduped.get(key);
      if (!prev) {
        deduped.set(key, t);
        continue;
      }
      const prevRank = Number(prev.rank ?? Infinity);
      const nextRank = Number(t.rank ?? Infinity);
      if (nextRank < prevRank) deduped.set(key, t);
    }

    const key = SORT_FIELDS[sort.key] || "rank";
    const dir = sort.dir === "desc" ? -1 : 1;

    return [...deduped.values()].sort((a, b) => {
      const av = getSortValue(a, key);
      const bv = getSortValue(b, key);

      if (typeof av === "string" || typeof bv === "string") {
        return av.localeCompare(bv, "ru", { sensitivity: "base" }) * dir;
      }

      if (av === bv) {
        return (Number(a.rank ?? 0) - Number(b.rank ?? 0)) * dir;
      }
      return (av - bv) * dir;
    });
  }, [rows, sort, view]);

  const groupedTable = useMemo(() => {
    if (!isIntlGroupedLeague || view === "scorers" || view === "assists" || view === "playoff") {
      return [];
    }
    const base = Array.isArray(rows)
      ? rows.filter((row) => row && row.team && row.team_id != null && row.rank != null)
      : [];
    const groups = new Map();
    for (const row of base) {
      const key = getGroupTableLabel(row.group_name, language, isIntlGroupedLeague);
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(row);
    }
    return Array.from(groups.entries())
      .sort((a, b) => a[0].localeCompare(b[0], "ru", { numeric: true, sensitivity: "base" }))
      .map(([groupName, groupRows]) => ({
        groupName,
        rows: [...groupRows].sort((a, b) => Number(a.rank ?? 999) - Number(b.rank ?? 999)),
      }));
  }, [isIntlGroupedLeague, rows, view, language]);

  /* БОМБАРДИРЫ */
  const scorersRows = useMemo(() => {
    if (view !== "scorers") return [];
    return [...rows]
      .filter((p) => p.player_id && p.player_name)
      .sort(
        (a, b) =>
          Number(b.goals ?? 0) - Number(a.goals ?? 0) ||
          Number(b.minutes ?? 0) - Number(a.minutes ?? 0)
      );
  }, [rows, view]);

  /* АССИСТЫ */
  const assistsRows = useMemo(() => {
    if (view !== "assists") return [];
    return [...rows]
      .filter((p) => p.player_id && p.player_name)
      .sort(
        (a, b) =>
          Number(b.assists ?? b.goals_assists ?? 0) -
            Number(a.assists ?? a.goals_assists ?? 0) ||
          Number(b.key_passes ?? b.passes_key ?? 0) -
            Number(a.key_passes ?? a.passes_key ?? 0)
      );
  }, [rows, view]);

  /* SORT BUTTON */
  const toggleSort = (field) => {
    setSort((prev) => {
      if (prev.key === field) {
        return { key: field, dir: prev.dir === "asc" ? "desc" : "asc" };
      }
      const defaultDir =
        field === "team" || field === "rank" ? "asc" : "desc";
      return { key: field, dir: defaultDir };
    });
  };

  const sortButton = (field, label, align = "center") => {
    const active = sort.key === field;
    const dirIcon = !active ? "↕" : sort.dir === "asc" ? "↑" : "↓";

    const alignClass =
      align === "left"
        ? "w-full justify-start text-left"
        : align === "right"
        ? "w-full justify-end text-right"
        : "w-full justify-center text-center";

    return (
      <button
        type="button"
        onClick={() => toggleSort(field)}
        className={clsx(
          "inline-flex items-center gap-1 text-[11px] font-semibold uppercase tracking-[0.18em]",
          alignClass,
          active ? "text-white" : "text-white/45 hover:text-white"
        )}
      >
        <span className="min-w-0 truncate">{label}</span>
        <span className="w-3 shrink-0 text-center text-[10px] opacity-60">{dirIcon}</span>
      </button>
    );
  };

  const zoneHighlight = (rank) => {
    if (rank == null) return "";
    if (isEuroCup) {
      if (rank <= 8)
        return "before:absolute before:left-0 before:inset-y-0 before:w-1 before:bg-cyan-400";
      if (rank <= 24)
        return "before:absolute before:left-0 before:inset-y-0 before:w-1 before:bg-emerald-400";
      return "before:absolute before:left-0 before:inset-y-0 before:w-1 before:bg-rose-500";
    }
    if (rank <= 4)
      return "before:absolute before:left-0 before:inset-y-0 before:w-1 before:bg-cyan-400";
    if (rank === 5)
      return "before:absolute before:left-0 before:inset-y-0 before:w-1 before:bg-emerald-400";
    if (rank >= 18)
      return "before:absolute before:left-0 before:inset-y-0 before:w-1 before:bg-rose-500";
    return "";
  };

  const legendItems = isEuroCup
    ? [
        { color: "bg-cyan-400", label: language === "ru" ? "1/8 финала" : "Round of 16" },
        { color: "bg-emerald-400", label: language === "ru" ? "Плей-офф 9-24" : "Play-offs 9-24" },
        { color: "bg-rose-500", label: language === "ru" ? "Вылет 25-36" : "Eliminated 25-36" },
      ]
    : [
        { color: "bg-cyan-400", label: language === "ru" ? "Лига чемпионов" : "Champions League" },
        { color: "bg-emerald-400", label: language === "ru" ? "Еврокубки" : "European spots" },
        { color: "bg-rose-500", label: language === "ru" ? "Зона вылета" : "Relegation zone" },
      ];

  /* =============================
     DESKTOP TABLE (ОБЩАЯ/ДОМА/В ГОСТЯХ)
  ============================= */

  const renderMainTableDesktop = (tableRows = sortedTable, compact = false) => {
    const desktopGridClass = compact
      ? "grid-cols-[48px_minmax(220px,1fr)_56px_56px_56px_56px_96px_64px]"
      : "grid-cols-[48px_minmax(240px,1fr)_56px_56px_56px_56px_96px_64px]";

    return (
      <div className={clsx("hidden md:block", BG_PANEL)}>
        <div className={TABLE_GLASS}>
          <div className={clsx("grid text-sm", desktopGridClass)}>
            <div className={clsx(TH_STICKY, "px-4 py-3 text-center font-semibold text-slate-200")}>
              {sortButton("rank", "#", "center")}
            </div>
            <div className={clsx(TH_STICKY, "px-4 py-3 text-left font-semibold text-slate-200")}>
              {sortButton("team", t("team"), "left")}
            </div>
            <div className={clsx(TH_STICKY, "px-4 py-3 text-center font-semibold text-slate-200")}>
              {sortButton("games_played", t("playedShort"))}
            </div>
            <div className={clsx(TH_STICKY, "px-4 py-3 text-center font-semibold text-slate-200")}>
              {sortButton("wins", t("winsShort"))}
            </div>
            <div className={clsx(TH_STICKY, "px-4 py-3 text-center font-semibold text-slate-200")}>
              {sortButton("draws", t("drawsShort"))}
            </div>
            <div className={clsx(TH_STICKY, "px-4 py-3 text-center font-semibold text-slate-200")}>
              {sortButton("losses", t("lossesShort"))}
            </div>
            <div className={clsx(TH_STICKY, "px-4 py-3 text-center font-semibold text-slate-200")}>
              {sortButton("goal_diff", t("goalsShort"))}
            </div>
            <div className={clsx(TH_STICKY, "px-4 py-3 text-center font-semibold text-slate-200")}>
              {sortButton("points", t("pointsShort"))}
            </div>

            {tableRows.map((row, idx) => {
              const rank = Number(row.rank ?? idx + 1);
              const gf = Number(row.goals_for ?? 0);
              const ga = Number(row.goals_against ?? 0);
              const diff =
                row.goal_difference != null ? Number(row.goal_difference) : gf - ga;
              const diffClass =
                diff > 0
                  ? "text-emerald-400"
                  : diff < 0
                  ? "text-rose-400"
                  : "text-slate-200";
              const rowClass = clsx(
                "border-t border-white/8",
                HOVER_ROW,
                zoneHighlight(rank)
              );

              return [
                <div key={`${row.team_id}-rank`} className={clsx("px-4 py-3 text-center text-slate-200 tabular-nums", rowClass)}>
                  {rank}
                </div>,
                <div key={`${row.team_id}-team`} className={clsx("px-4 py-3", rowClass)}>
                  <button
                    type="button"
                    onClick={() =>
                      navigate(
                        `/team/${row.team_id}?league=${encodeURIComponent(
                          leagueParam
                        )}&season=${season}`
                      )
                    }
                    className="flex w-full min-w-0 items-center gap-2 text-left text-white hover:text-white"
                  >
                    <SafeImg
                      src={teamLogo(row.team_id)}
                      alt={row.team}
                      className="h-6 w-6 shrink-0 object-contain"
                      fallbackSrc={teamLogoFallback(row.team_id)}
                      fallback="team"
                    />
                    <span className="min-w-0 truncate font-medium">
                      {row.team ?? "—"}
                    </span>
                  </button>
                </div>,
                <div key={`${row.team_id}-gp`} className={clsx("px-4 py-3 text-center text-slate-200 tabular-nums whitespace-nowrap", rowClass)}>
                  {row.games_played ?? "—"}
                </div>,
                <div key={`${row.team_id}-w`} className={clsx("px-4 py-3 text-center text-slate-200 tabular-nums whitespace-nowrap", rowClass)}>
                  {row.wins ?? "—"}
                </div>,
                <div key={`${row.team_id}-d`} className={clsx("px-4 py-3 text-center text-slate-200 tabular-nums whitespace-nowrap", rowClass)}>
                  {row.draws ?? "—"}
                </div>,
                <div key={`${row.team_id}-l`} className={clsx("px-4 py-3 text-center text-slate-200 tabular-nums whitespace-nowrap", rowClass)}>
                  {row.losses ?? "—"}
                </div>,
                <div key={`${row.team_id}-g`} className={clsx("px-4 py-3 text-center tabular-nums whitespace-nowrap", rowClass)}>
                  <span className={clsx("font-mono whitespace-nowrap", diffClass)}>
                    {Number.isFinite(gf) && Number.isFinite(ga)
                      ? `${gf} – ${ga}`
                      : "—"}
                  </span>
                </div>,
                <div key={`${row.team_id}-pts`} className={clsx("px-4 py-3 text-center font-semibold text-white tabular-nums whitespace-nowrap", rowClass)}>
                  {row.points ?? "—"}
                </div>,
              ];
            })}

            {!loading && tableRows.length === 0 && (
              <div className="col-span-8 py-6 text-center text-slate-400">
                {t("noData")}
              </div>
            )}
          </div>
        </div>
      </div>
    );
  };

  /* =============================
     MOBILE VERSION (ОБЩАЯ/ДОМА/В ГОСТЯХ)
  ============================= */

  const renderMainTableMobile = (tableRows = sortedTable) => (
    <div className="space-y-2.5 md:hidden">
      {tableRows.map((t, idx) => {
        const gf = Number(t.goals_for ?? 0);
        const ga = Number(t.goals_against ?? 0);
        const diff =
          t.goal_difference != null ? Number(t.goal_difference) : gf - ga;
        const diffClass =
          diff > 0
            ? "text-emerald-400"
            : diff < 0
            ? "text-rose-400"
            : "text-slate-200";

        const rank = Number(t.rank ?? idx + 1);

        return (
          <button
            type="button"
            onClick={() =>
              navigate(
                `/team/${t.team_id}?league=${encodeURIComponent(
                  leagueParam
                )}&season=${season}`
              )
            }
            key={t.team_id}
            className="relative grid w-full grid-cols-[36px_minmax(0,1fr)_auto] items-center gap-3 overflow-hidden rounded-[22px] border border-white/[0.05] bg-gradient-to-br from-white/[0.035] to-white/[0.015] px-3.5 py-3 text-left ring-1 ring-white/[0.025] transition hover:border-white/[0.08] hover:bg-white/[0.045]"
          >
            <span className="grid h-8 w-8 place-items-center rounded-full border border-white/[0.07] bg-white/[0.045] text-[11px] font-semibold tabular-nums text-slate-200">
              {rank}
            </span>
            <div className="flex min-w-0 items-center gap-2">
              <SafeImg
                src={teamLogo(t.team_id)}
                alt={t.team}
                className="h-6 w-6 shrink-0 object-contain"
                fallbackSrc={teamLogoFallback(t.team_id)}
                fallback="team"
              />
              <div className="min-w-0">
                <div className="truncate text-sm font-semibold text-white">
                  {t.team ?? "—"}
                </div>
                <div className="mt-1 flex items-center gap-2 text-[10px] text-slate-500">
                  <span>{t.wins ?? "—"}W</span>
                  <span>{t.draws ?? "—"}D</span>
                  <span>{t.losses ?? "—"}L</span>
                </div>
              </div>
            </div>
            <div className="grid grid-cols-3 gap-1.5">
              <div className="rounded-2xl border border-white/[0.05] bg-white/[0.04] px-2 py-1.5 text-center">
                <div className="text-[9px] uppercase tracking-[0.14em] text-slate-500">P</div>
                <div className="mt-0.5 text-[12px] font-semibold tabular-nums text-white">{t.games_played ?? "—"}</div>
              </div>
              <div className="rounded-2xl border border-white/[0.05] bg-white/[0.04] px-2 py-1.5 text-center">
                <div className="text-[9px] uppercase tracking-[0.14em] text-slate-500">GD</div>
                <div className={clsx("mt-0.5 text-[12px] font-semibold tabular-nums", diffClass)}>
                  {Number.isFinite(diff) ? (diff > 0 ? `+${diff}` : diff) : "—"}
                </div>
              </div>
              <div className="rounded-2xl border border-white/[0.05] bg-white/[0.055] px-2 py-1.5 text-center">
                <div className="text-[9px] uppercase tracking-[0.14em] text-slate-500">PTS</div>
                <div className="mt-0.5 text-[12px] font-semibold tabular-nums text-white">{t.points ?? "—"}</div>
              </div>
            </div>

            <div
              className={clsx(
                "absolute inset-y-2 left-0 w-[3px] rounded-full",
                isEuroCup
                  ? rank <= 8
                    ? "bg-cyan-400"
                    : rank <= 24
                    ? "bg-emerald-400"
                    : "bg-rose-500"
                  : rank <= 4
                  ? "bg-cyan-400"
                  : rank === 5
                  ? "bg-emerald-400"
                  : rank >= 18
                  ? "bg-rose-500"
                  : "bg-transparent"
              )}
            />
          </button>
        );
      })}

      {!loading && tableRows.length === 0 && (
        <div className="rounded-[22px] border border-white/[0.05] bg-gradient-to-br from-white/[0.035] to-white/[0.015] px-4 py-6 text-center ring-1 ring-white/[0.025]">
          <div className="mx-auto grid h-10 w-10 place-items-center rounded-2xl border border-white/[0.06] bg-white/[0.03] text-white/55">
            <svg className="h-4 w-4" viewBox="0 0 20 20" fill="none" aria-hidden="true">
              <path d="M6 10h8M6 6h8M6 14h5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
              <circle cx="10" cy="10" r="7.25" stroke="currentColor" strokeOpacity="0.55" />
            </svg>
          </div>
          <div className="mt-3 text-sm text-slate-400">
          {t("noData")}
          </div>
        </div>
      )}
    </div>
  );

  const renderGroupedTables = () => (
    <div className="space-y-5">
      {groupedTable.map((group) => (
        <section key={group.groupName} className="space-y-3">
          <div className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-full bg-cyan-400 shadow-[0_0_10px_rgba(34,211,238,0.55)]" />
            <h3 className="text-sm font-semibold text-white">{group.groupName}</h3>
          </div>
          {renderMainTableDesktop(group.rows, true)}
          {renderMainTableMobile(group.rows)}
        </section>
      ))}

      {!loading && groupedTable.length === 0 && (
        <div
          className={clsx(
            "rounded-2xl border border-white/5 bg-white/[0.02]",
            "px-4 py-5 text-center text-sm text-slate-400"
          )}
        >
          {t("noData")}
        </div>
      )}
    </div>
  );

  /* =============================
     SCORERS BLOCK (кликабельно → /player/:id)
  ============================= */

  const renderScorers = () => (
    <div className={clsx(BG_PANEL)}>
      <div className={TABLE_GLASS}>
        <Table className="min-w-full text-sm">
        <TableHeader>
          <TableRow className="border-b border-white/8 bg-white/[0.015]">
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "w-10 px-3 py-3 text-center text-[11px] uppercase tracking-[0.18em] text-white/45"
                )}
              >
                #
              </TableHead>
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "px-3 py-3 text-[11px] uppercase tracking-[0.18em] text-white/45"
                )}
              >
                {t("player")}
              </TableHead>
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "w-32 px-3 py-3 text-center text-[11px] uppercase tracking-[0.18em] text-white/45"
                )}
              >
                {t("goals")}
              </TableHead>
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "w-32 px-3 py-3 text-center text-[11px] uppercase tracking-[0.18em] text-white/45"
                )}
              >
                {t("penalties")}
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {scorersRows.map((p, idx) => (
              <TableRow
                key={p.player_id}
                className={clsx("border-t border-white/8", HOVER_ROW)}
              >
                <TableCell className="px-3 py-2 text-center text-slate-300">
                  {idx + 1}
                </TableCell>
                <TableCell className="px-3 py-2">
                  <div
                    className="flex items-center gap-2 cursor-pointer group"
                    onClick={() =>
                      navigate(
                        `/player/${p.player_id}?league=${encodeURIComponent(
                          leagueParam
                        )}&season=${season}`
                      )
                    }
                  >
                    <SafeImg
                      src={
                        p.player_id
                          ? `/icons/player_photos/${p.player_id}.png`
                          : "/icons/player_photos/default.png"
                      }
                      alt={p.player_name}
                      className="h-8 w-8 rounded-full border border-white/20 object-cover"
                      fallbackSrc={playerPhotoFallback(p.player_id)}
                      fallback="player"
                    />
                    <div className="min-w-0">
                      <div className="truncate text-sm font-semibold text-white group-hover:text-[#b18cff]">
                        {p.player_name}
                      </div>
                      <div className="truncate text-xs text-slate-400">
                        {p.team_name}
                      </div>
                      <div className="truncate text-[11px] text-slate-500">
                        {formatPlayerMeta(p, language)}
                      </div>
                    </div>
                  </div>
                </TableCell>
                <TableCell className="px-3 py-2 text-center text-white font-semibold">
                  {p.goals ?? 0}
                </TableCell>
                <TableCell className="px-3 py-2 text-center text-slate-200">
                  {p.penalties_scored ?? 0}
                </TableCell>
              </TableRow>
            ))}
            {scorersRows.length === 0 && !loading && (
              <TableRow>
                <TableCell
                  colSpan={4}
                  className="py-6 text-center text-slate-400"
                >
                  {t("noData")}
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </div>
  );

  /* =============================
     ASSISTS BLOCK (кликабельно → /player/:id)
  ============================= */

  const renderAssists = () => (
    <div className={clsx(BG_PANEL)}>
      <div className={TABLE_GLASS}>
        <Table className="min-w-full text-sm">
        <TableHeader>
          <TableRow className="border-b border-white/8 bg-white/[0.015]">
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "w-10 px-3 py-3 text-center text-[11px] uppercase tracking-[0.18em] text-white/45"
                )}
              >
                #
              </TableHead>
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "px-3 py-3 text-[11px] uppercase tracking-[0.18em] text-white/45"
                )}
              >
                {t("player")}
              </TableHead>
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "w-32 px-3 py-3 text-center text-[11px] uppercase tracking-[0.18em] text-white/45"
                )}
              >
                {t("assists")}
              </TableHead>
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "w-32 px-3 py-3 text-center text-[11px] uppercase tracking-[0.18em] text-white/45"
                )}
              >
                Key passes
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {assistsRows.map((p, idx) => (
              <TableRow
                key={p.player_id}
                className={clsx("border-t border-white/8", HOVER_ROW)}
              >
                <TableCell className="px-3 py-2 text-center text-slate-300">
                  {idx + 1}
                </TableCell>
                <TableCell className="px-3 py-2">
                  <div
                    className="flex items-center gap-2 cursor-pointer group"
                    onClick={() =>
                      navigate(
                        `/player/${p.player_id}?league=${encodeURIComponent(
                          leagueParam
                        )}&season=${season}`
                      )
                    }
                  >
                    <SafeImg
                      src={
                        p.player_id
                          ? `/icons/player_photos/${p.player_id}.png`
                          : "/icons/player_photos/default.png"
                      }
                      alt={p.player_name}
                      className="h-8 w-8 rounded-full border border-white/20 object-cover"
                      fallbackSrc={playerPhotoFallback(p.player_id)}
                      fallback="player"
                    />
                    <div className="min-w-0">
                      <div className="truncate text-sm font-semibold text-white group-hover:text-[#b18cff]">
                        {p.player_name}
                      </div>
                      <div className="truncate text-xs text-slate-400">
                        {p.team_name}
                      </div>
                      <div className="truncate text-[11px] text-slate-500">
                        {formatPlayerMeta(p, language)}
                      </div>
                    </div>
                  </div>
                </TableCell>
                <TableCell className="px-3 py-2 text-center text-white font-semibold">
                  {p.assists ?? p.goals_assists ?? 0}
                </TableCell>
                <TableCell className="px-3 py-2 text-center text-slate-200">
                  {p.key_passes ?? p.passes_key ?? 0}
                </TableCell>
              </TableRow>
            ))}
            {assistsRows.length === 0 && !loading && (
              <TableRow>
                <TableCell
                  colSpan={4}
                  className="py-6 text-center text-slate-400"
                >
                  {t("noData")}
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </div>
  );

  const renderBracketMatch = (match) => {
    const hasMultipleLegs = Array.isArray(match.legs) && match.legs.length > 1;
    const expanded = Boolean(expandedTies[match.id]);
    const leftWon =
      match.winner_team_id && Number(match.winner_team_id) === Number(match.left_id);
    const rightWon =
      match.winner_team_id && Number(match.winner_team_id) === Number(match.right_id);
    const hasPens =
      match.pen_left != null &&
      match.pen_right != null &&
      Number.isFinite(Number(match.pen_left)) &&
      Number.isFinite(Number(match.pen_right));
    const clickable = !!match.first_fixture_id;
    const handleCardClick = () => {
      if (hasMultipleLegs) {
        setExpandedTies((prev) => ({ ...prev, [match.id]: !prev[match.id] }));
        return;
      }
      if (clickable) {
        navigate(
          `/match/${match.first_fixture_id}?league=${encodeURIComponent(
            leagueParam
          )}&season=${season}`
        );
      }
    };

    const legRows = (match.legs || []).map((leg, idx) => {
      const leftHome = Number(leg.home_id) === Number(match.left_id);
      const legLeft = leftHome
        ? (leg.final_home ?? leg.gh)
        : (leg.final_away ?? leg.ga);
      const legRight = leftHome
        ? (leg.final_away ?? leg.ga)
        : (leg.final_home ?? leg.gh);
      const legFtLeft = leftHome
        ? (leg.ft_home ?? leg.gh)
        : (leg.ft_away ?? leg.ga);
      const legFtRight = leftHome
        ? (leg.ft_away ?? leg.ga)
        : (leg.ft_home ?? leg.gh);
      const legHasPens =
        leg.pen_home != null &&
        leg.pen_away != null &&
        Number.isFinite(Number(leg.pen_home)) &&
        Number.isFinite(Number(leg.pen_away));
      const penLeft = leftHome ? leg.pen_home : leg.pen_away;
      const penRight = leftHome ? leg.pen_away : leg.pen_home;

      return (
        <button
          key={leg.fixture_id || `${match.id}-${idx}`}
          type="button"
          onClick={(e) => {
            e.stopPropagation();
            if (!leg.fixture_id) return;
            navigate(
              `/match/${leg.fixture_id}?league=${encodeURIComponent(
                leagueParam
              )}&season=${season}`
            );
          }}
          className="w-full rounded-xl border border-white/6 bg-white/[0.02] px-2.5 py-2 text-left transition hover:bg-white/[0.05]"
        >
          <div className="flex items-center justify-between gap-2 text-[10px] uppercase tracking-[0.12em] text-white/40">
            <span>
              {idx === 0
                ? language === "ru"
                  ? "Первый матч"
                  : "First leg"
                : idx === 1
                ? language === "ru"
                  ? "Ответный матч"
                  : "Second leg"
                : language === "ru"
                ? `Матч ${idx + 1}`
                : `Match ${idx + 1}`}
            </span>
            <span>{leg.date ? new Date(leg.date).toLocaleDateString(language === "ru" ? "ru-RU" : "en-GB") : "—"}</span>
          </div>
          <div className="mt-1.5 flex items-center justify-between gap-2 text-xs text-white/80">
            <span className="min-w-0 flex-1 truncate">{match.left}</span>
            <span className="shrink-0 tabular-nums font-semibold text-white">
              {legLeft ?? "—"}:{legRight ?? "—"}
            </span>
            <span className="min-w-0 flex-1 truncate text-right">{match.right}</span>
          </div>
          {legHasPens ? (
            <div className="mt-1 text-[11px] text-white/45">
              {language === "ru" ? "Осн./доп.:" : "FT/AET:"} <span className="tabular-nums text-white/65">{legFtLeft ?? "—"}:{legFtRight ?? "—"}</span>
              {" "}• {language === "ru" ? "пен." : "pens"}: <span className="tabular-nums text-white/65">{penLeft}:{penRight}</span>
            </div>
          ) : null}
        </button>
      );
    });

    return (
      <div
        key={match.id}
        onClick={handleCardClick}
        className={clsx(
          "glass-card rounded-2xl p-2.5 md:p-3 transition-colors",
          clickable ? "cursor-pointer hover:bg-white/[0.04]" : ""
        )}
      >
        <div className="space-y-1.5 md:space-y-2">
          <div
            className={clsx(
              "flex items-center justify-between gap-2 text-[13px] md:text-sm",
              leftWon ? "text-white" : rightWon ? "text-white/48" : "text-white/72"
            )}
          >
            <div className="min-w-0 flex flex-1 items-center gap-2">
              <SafeImg
                src={teamLogo(match.left_id)}
                alt={match.left}
                className="h-4 w-4 shrink-0 object-contain md:h-5 md:w-5"
                fallbackSrc={teamLogoFallback(match.left_id)}
                fallback="team"
              />
              <span className="min-w-0 flex-1 truncate">{match.left || "—"}</span>
              {leftWon && (
                <span
                  title={language === "ru" ? "Прошёл дальше" : "Advanced"}
                  className="shrink-0 rounded-full border border-emerald-400/25 bg-emerald-400/12 px-1.5 py-0.5 text-[9px] font-medium uppercase tracking-[0.1em] text-emerald-200"
                >
                  ✓
                </span>
              )}
            </div>
            <span className={clsx("tabular-nums font-semibold", leftWon ? "text-white" : rightWon ? "text-white/28" : "text-white/78")}>
              {match.display_left ?? "—"}
            </span>
          </div>
          <div
            className={clsx(
              "flex items-center justify-between gap-2 text-[13px] md:text-sm",
              rightWon ? "text-white" : leftWon ? "text-white/48" : "text-white/72"
            )}
          >
            <div className="min-w-0 flex flex-1 items-center gap-2">
              <SafeImg
                src={teamLogo(match.right_id)}
                alt={match.right}
                className="h-4 w-4 shrink-0 object-contain md:h-5 md:w-5"
                fallbackSrc={teamLogoFallback(match.right_id)}
                fallback="team"
              />
              <span className="min-w-0 flex-1 truncate">{match.right || "—"}</span>
              {rightWon && (
                <span
                  title={language === "ru" ? "Прошёл дальше" : "Advanced"}
                  className="shrink-0 rounded-full border border-emerald-400/25 bg-emerald-400/12 px-1.5 py-0.5 text-[9px] font-medium uppercase tracking-[0.1em] text-emerald-200"
                >
                  ✓
                </span>
              )}
            </div>
            <span className={clsx("tabular-nums font-semibold", rightWon ? "text-white" : leftWon ? "text-white/28" : "text-white/78")}>
              {match.display_right ?? "—"}
            </span>
          </div>
        </div>

        <div className="mt-2.5 border-t border-white/8 pt-2 text-[10px] md:text-[11px] text-white/45">
          {hasMultipleLegs ? (
            <div className="flex items-center justify-between gap-2">
              <span>{language === "ru" ? "Общий счёт" : "Aggregate"}</span>
              <span className="tabular-nums text-white/72">
                {match.agg_left ?? "—"}:{match.agg_right ?? "—"}
              </span>
            </div>
          ) : null}
          {hasPens ? (
            <div className={clsx("flex items-center justify-between gap-2", hasMultipleLegs ? "mt-1" : "")}>
              <span>{language === "ru" ? "Основное/доп. время" : "FT/AET"}</span>
              <span className="tabular-nums text-white/68">
                {match.ft_left ?? "—"}:{match.ft_right ?? "—"} • {language === "ru" ? "пен." : "pens"} {match.pen_left}:{match.pen_right}
              </span>
            </div>
          ) : null}
          {hasMultipleLegs ? (
            <div className="mt-1 text-white/35">
              {expanded
                ? language === "ru"
                  ? "Нажмите, чтобы свернуть пару"
                  : "Tap to collapse the tie"
                : language === "ru"
                ? "Нажмите, чтобы раскрыть оба матча пары"
                : "Tap to expand both legs"}
            </div>
          ) : clickable ? (
            <div className="mt-1 text-white/35">
              {language === "ru"
                ? "Нажмите на карточку, чтобы открыть статистику матча"
                : "Tap the card to open match stats"}
            </div>
          ) : null}
          {expanded && hasMultipleLegs ? (
            <div className="mt-2.5 space-y-2 border-t border-white/8 pt-2.5">
              {legRows}
            </div>
          ) : null}
        </div>
      </div>
    );
  };

  const renderBracketRound = (title, matches, extraClass = "") => (
    <div className={clsx(BG_PANEL, "h-full p-3 md:p-4", extraClass)}>
      <div className="mb-2.5 md:mb-3">
        <div className="text-[11px] uppercase tracking-[0.18em] text-white/45">
          {t("stage")}
        </div>
        <div className="mt-1 text-sm font-semibold text-white md:text-base">{title}</div>
      </div>
      <div className="space-y-2.5 md:space-y-3">
        {matches.length > 0 ? (
          matches.map(renderBracketMatch)
        ) : (
          <div className="rounded-2xl border border-white/5 bg-white/[0.02] px-4 py-5 text-center text-sm text-slate-400">
            {t("noData")}
          </div>
        )}
      </div>
    </div>
  );

  const renderPlayoffBracket = () => {
    const orderedRounds = bracket.filter((round) => Array.isArray(round?.matches));
    const desktopGridStyle = {
      gridTemplateColumns: `repeat(${Math.max(orderedRounds.length, 1)}, minmax(0, 1fr))`,
    };

    return (
      <div className="space-y-4">
        <div className="overflow-hidden rounded-[22px] bg-white/[0.02]">
          <div className="overflow-x-auto overscroll-x-contain px-3 py-3 md:px-4 md:py-4 xl:hidden [scrollbar-width:thin]">
            <div className="flex w-max min-w-full snap-x snap-mandatory items-start gap-3 md:gap-4">
              {orderedRounds.map((round, index) => (
                <div
                  key={round.code || round.name || index}
                  className="w-[220px] shrink-0 snap-start md:w-[238px]"
                >
                  {renderBracketRound(round.name, round.matches)}
                </div>
              ))}
            </div>
          </div>
          <div className="hidden xl:block px-4 py-4">
            <div className="grid items-start gap-3 2xl:gap-4" style={desktopGridStyle}>
              {orderedRounds.map((round, index) => (
                <div
                  key={round.code || round.name || index}
                  className={clsx(
                    index === 0 ? "mt-0" : index === 1 ? "mt-6" : index === 2 ? "mt-10" : index === 3 ? "mt-14" : "mt-16"
                  )}
                >
                  {renderBracketRound(round.name, round.matches)}
                </div>
              ))}
            </div>
          </div>
        </div>
        <div className="text-xs text-slate-400">
          {language === "ru"
            ? "На широких экранах сетка ужимается в ширину страницы, на узких листается по горизонтали."
            : "On wide screens the bracket fits the page width, and on narrow screens it scrolls horizontally."}
        </div>
      </div>
    );
  };

  /* =============================
     PAGE LAYOUT
  ============================= */

  const headerSubtitle =
    view === "playoff"
      ? t("playoffSubtitle")
      : view === "scorers"
      ? t("scorersSubtitle")
      : view === "assists"
      ? t("assistsSubtitle")
      : isIntlGroupedLeague
      ? t("groupedTableSubtitle")
      : t("tableSubtitle");
  const tableHint =
    view === "playoff"
      ? t("playoffSubtitle")
      : view === "scorers"
      ? t("scorersSubtitle")
      : view === "assists"
      ? t("assistsSubtitle")
      : isIntlGroupedLeague
      ? t("groupedTableSubtitle")
      : t("tableHint");

  return (
    <div className="type-page w-full min-w-0 overflow-x-hidden px-1 py-5 sm:px-4 sm:py-8">
      {/* HEADER */}
      <div>
        <div className="surface-hero p-4 sm:p-6 md:p-8">
          <div className="mb-5 flex flex-wrap items-center gap-2">
            <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] px-2.5 py-1.5 text-[10px] font-medium uppercase tracking-[0.16em] text-white/65 sm:px-3 sm:text-[11px] sm:tracking-[0.18em]">
              <Sparkles className="h-3.5 w-3.5 text-violet-200" />
              Competition view
            </div>
            <div className="inline-flex items-center gap-2 rounded-full border border-cyan-400/16 bg-cyan-400/8 px-2.5 py-1.5 text-[10px] uppercase tracking-[0.16em] text-cyan-100/78 sm:px-3 sm:text-[11px] sm:tracking-[0.18em]">
              <Layers3 className="h-3.5 w-3.5" />
              {viewLabel(view, view)}
            </div>
          </div>
          <div className="flex flex-col items-start justify-between gap-4 sm:flex-row">
            <div className="min-w-0 space-y-1.5">
              <div className="type-eyebrow">
                {view === "scorers"
                  ? t("playerStatsEyebrow")
                  : view === "assists"
                  ? t("playerStatsEyebrow")
                  : t("standingsEyebrow")}
              </div>

              <div className="type-page-title break-words text-xl sm:text-2xl">
                {view === "scorers"
                  ? `${t("scorers")} · ${leagueParam}`
                  : view === "assists"
                  ? `${t("assists")} · ${leagueParam}`
                  : leagueParam}
              </div>

              <p className="type-subtitle max-w-[640px]">
                {headerSubtitle}
              </p>
            </div>

            {!(isEuroCup && view === "playoff") && (
              <div className="flex w-full min-w-0 flex-col gap-2 sm:w-auto sm:items-end">
                <span className="text-[10px] uppercase tracking-[0.18em] text-muted mb-1">
                  {t("seasonUpper")}
                </span>
                <select
                  value={season}
                  onChange={(e) => setSeason(e.target.value)}
                  className="surface-select h-9 w-full max-w-full text-[13px] text-white/80 sm:h-8 sm:w-auto"
                >
                  {seasonOptions.map((s) => (
                    <option key={s} value={s} className="bg-slate-900">
                      {seasonLabel(leagueParam, s, language)}
                    </option>
                  ))}
                </select>
              </div>
            )}
          </div>

          {/* tabs */}
          <SegmentedTabs
            className="surface-toolbar mt-5 px-3 py-2 sm:px-4"
            items={availableViews.map((v) => ({ key: v.code, label: viewLabel(v.code, v.label) }))}
            value={view}
            onChange={setView}
          />
          <div className="mt-3 text-xs text-slate-400">{tableHint}</div>
        </div>
      </div>

      {/* loading */}
      {loading && (
        <div className="surface-loading">{t("dataLoading")}</div>
      )}

      {/* content */}
      {view === "scorers"
        ? renderScorers()
        : view === "assists"
        ? renderAssists()
        : view === "playoff"
        ? renderPlayoffBracket()
        : (
          <div className="glass-card p-4 sm:p-5">
            {isIntlGroupedLeague ? renderGroupedTables() : (
              <>
                {renderMainTableDesktop()}
                {renderMainTableMobile()}
              </>
            )}

            {/* legend */}
            {!isIntlGroupedLeague && (
              <div className="mt-5 flex flex-wrap gap-6 border-t border-white/6 pt-4 text-xs text-white/45">
                {legendItems.map((item) => (
                  <div key={item.label} className="inline-flex items-center gap-2">
                    <span className={clsx("h-2 w-2 rounded-full", item.color)} />
                    <span>{item.label}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
    </div>
  );
}
