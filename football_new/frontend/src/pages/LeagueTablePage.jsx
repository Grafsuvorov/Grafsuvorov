// src/pages/LeagueTablePage.jsx
import { useEffect, useMemo, useState } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import clsx from "clsx";
import { Card, CardContent } from "@/components/ui/card";
import {
  Table,
  TableHeader,
  TableRow,
  TableHead,
  TableBody,
  TableCell,
} from "@/components/ui/table";
import SafeImg from "@/components/SafeImg";

/* =============================
   CONSTANTS & HELPERS
============================= */

const SEASONS = ["2025", "2024", "2023", "2022"];

const VIEWS = [
  { code: "total", label: "Общая" },
  { code: "home", label: "Дома" },
  { code: "away", label: "В гостях" },
  { code: "scorers", label: "Бомбардиры" },
  { code: "assists", label: "Ассисты" },
];

/* =============================
   PREMIUM GLASS UI TOKENS
============================= */

const BG_PANEL =
  "rounded-3xl border border-white/10 bg-white/[0.04] backdrop-blur-xl shadow-[0_8px_35px_rgba(0,0,0,0.55)]";

const TABLE_GLASS =
  "bg-white/[0.03] backdrop-blur-xl border border-white/5 rounded-3xl overflow-hidden";

const TEXT_MUTED = "text-slate-300";

const HOVER_ROW = "hover:bg-white/[0.06] transition-all duration-150";

const TH_STICKY =
  "sticky top-0 z-20 bg-white/[0.08] backdrop-blur-xl border-b border-white/10";

const ACCENT_BG =
  "bg-gradient-to-r from-pink-500/80 via-fuchsia-500/80 to-violet-500/80 text-white border-none shadow-[0_0_25px_rgba(236,72,153,0.55)]";

const teamLogo = (id) =>
  id ? `/icons/team_logos/${id}.png` : "/icons/team_logos/default.png";

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
  const [searchParams, setSearchParams] = useSearchParams();
  const navigate = useNavigate();

  const leagueParam = searchParams.get("league") || "Premier League";
  const seasonParam = searchParams.get("season") || "2025";
  const viewParam = searchParams.get("view") || "total";

  const [season, setSeason] = useState(seasonParam);
  const [view, setView] = useState(viewParam);

  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [sort, setSort] = useState(SORT_DEFAULT);

  /* sync URL */
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

    if (view === "scorers") {
      endpoint = `http://localhost:8001/api/top-scorers?league=${encodeURIComponent(
        leagueParam
      )}&season=${season}`;
    } else if (view === "assists") {
      endpoint = `http://localhost:8001/api/top-assists?league=${encodeURIComponent(
        leagueParam
      )}&season=${season}`;
    } else {
      endpoint = `http://localhost:8001/api/league-table?league=${encodeURIComponent(
        leagueParam
      )}&season=${season}&view=${view}`;
    }

    setLoading(true);
    fetch(endpoint)
      .then((r) => r.json())
      .then((data) => setRows(Array.isArray(data) ? data : []))
      .catch((e) => {
        console.error("LeagueTablePage fetch error:", e);
        setRows([]);
      })
      .finally(() => setLoading(false));
  }, [leagueParam, season, view]);

  /* SORTED TABLE (для обычной турнирной таблицы) */
  const sortedTable = useMemo(() => {
    if (!Array.isArray(rows) || view === "scorers" || view === "assists")
      return [];

    const data = rows.filter(
      (t) => t && t.team && t.team_id != null && t.rank != null
    );

    const key = SORT_FIELDS[sort.key] || "rank";
    const dir = sort.dir === "desc" ? -1 : 1;

    return [...data].sort((a, b) => {
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
        ? "justify-start text-left"
        : align === "right"
        ? "justify-end text-right"
        : "justify-center text-center";

    return (
      <button
        type="button"
        onClick={() => toggleSort(field)}
        className={clsx(
          "flex w-full items-center gap-1 text-[11px] font-semibold uppercase tracking-[0.18em]",
          alignClass,
          active ? "text-white" : "text-slate-400 hover:text-white"
        )}
      >
        <span>{label}</span>
        <span className="text-[10px] opacity-60">{dirIcon}</span>
      </button>
    );
  };

  const zoneHighlight = (rank) => {
    if (rank == null) return "";
    if (rank <= 4)
      return "before:absolute before:left-0 before:inset-y-0 before:w-1 before:bg-cyan-400";
    if (rank === 5)
      return "before:absolute before:left-0 before:inset-y-0 before:w-1 before:bg-emerald-400";
    if (rank >= 18)
      return "before:absolute before:left-0 before:inset-y-0 before:w-1 before:bg-rose-500";
    return "";
  };

  /* =============================
     DESKTOP TABLE (ОБЩАЯ/ДОМА/В ГОСТЯХ)
  ============================= */

  const renderMainTableDesktop = () => (
    <Card className={clsx("hidden md:block", BG_PANEL)}>
      <CardContent className="p-0">
        <div className={TABLE_GLASS}>
          <Table className="min-w-full text-sm border-separate border-spacing-0">
            <TableHeader>
              <TableRow className="border-b border-white/10 bg-white/[0.08]">
                <TableHead
                  className={clsx(TH_STICKY, "w-12 px-4 py-3 text-center")}
                >
                  {sortButton("rank", "#", "center")}
                </TableHead>

                <TableHead
                  className={clsx(
                    TH_STICKY,
                    "min-w-[220px] px-4 py-3 text-left"
                  )}
                >
                  {sortButton("team", "Команда", "left")}
                </TableHead>

                <TableHead
                  className={clsx(TH_STICKY, "w-14 px-4 py-3 text-center")}
                >
                  {sortButton("games_played", "И")}
                </TableHead>

                <TableHead
                  className={clsx(TH_STICKY, "w-14 px-4 py-3 text-center")}
                >
                  {sortButton("wins", "В")}
                </TableHead>

                <TableHead
                  className={clsx(TH_STICKY, "w-14 px-4 py-3 text-center")}
                >
                  {sortButton("draws", "Н")}
                </TableHead>

                <TableHead
                  className={clsx(TH_STICKY, "w-14 px-4 py-3 text-center")}
                >
                  {sortButton("losses", "П")}
                </TableHead>

                <TableHead
                  className={clsx(TH_STICKY, "w-20 px-4 py-3 text-center")}
                >
                  {sortButton("goal_diff", "М")}
                </TableHead>

                <TableHead
                  className={clsx(TH_STICKY, "w-16 px-4 py-3 text-center")}
                >
                  {sortButton("points", "О")}
                </TableHead>
              </TableRow>
            </TableHeader>

            <TableBody>
              {sortedTable.map((t, idx) => {
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
                  <TableRow
                    key={t.team_id}
                    className={clsx(
                      "relative border-t border-white/10 bg-white/[0.02]",
                      HOVER_ROW,
                      zoneHighlight(rank)
                    )}
                  >
                    <TableCell className="px-4 py-3 text-center text-slate-200 tabular-nums">
                      {rank}
                    </TableCell>

                    <TableCell className="px-4 py-3">
                      <button
                        type="button"
                        onClick={() =>
                          navigate(
                            `/team/${t.team_id}?league=${encodeURIComponent(
                              leagueParam
                            )}&season=${season}`
                          )
                        }
                        className="flex items-center gap-2 text-left text-white hover:text-white"
                      >
                        <SafeImg
                          src={teamLogo(t.team_id)}
                          alt={t.team}
                          className="h-6 w-6 object-contain"
                          fallback="team"
                        />
                        <span className="truncate font-medium">
                          {t.team ?? "—"}
                        </span>
                      </button>
                    </TableCell>

                    <TableCell className="px-4 py-3 text-center text-slate-200 tabular-nums">
                      {t.games_played ?? "—"}
                    </TableCell>

                    <TableCell className="px-4 py-3 text-center text-slate-200 tabular-nums">
                      {t.wins ?? "—"}
                    </TableCell>

                    <TableCell className="px-4 py-3 text-center text-slate-200 tabular-nums">
                      {t.draws ?? "—"}
                    </TableCell>

                    <TableCell className="px-4 py-3 text-center text-slate-200 tabular-nums">
                      {t.losses ?? "—"}
                    </TableCell>

                    <TableCell className="px-4 py-3 text-center tabular-nums">
                      <span className={clsx("font-mono", diffClass)}>
                        {Number.isFinite(gf) && Number.isFinite(ga)
                          ? `${gf} – ${ga}`
                          : "—"}
                      </span>
                    </TableCell>

                    <TableCell className="px-4 py-3 text-center font-semibold text-white tabular-nums">
                      {t.points ?? "—"}
                    </TableCell>
                  </TableRow>
                );
              })}

              {!loading && sortedTable.length === 0 && (
                <TableRow>
                  <TableCell
                    colSpan={8}
                    className="py-6 text-center text-slate-400"
                  >
                    Нет данных
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </div>
      </CardContent>
    </Card>
  );

  /* =============================
     MOBILE VERSION (ОБЩАЯ/ДОМА/В ГОСТЯХ)
  ============================= */

  const renderMainTableMobile = () => (
    <div className="space-y-3 md:hidden">
      {sortedTable.map((t, idx) => {
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
          <Card
            key={t.team_id}
            className="relative overflow-hidden rounded-3xl border border-white/10 bg-white/[0.05] backdrop-blur-xl shadow-[0_8px_30px_rgba(0,0,0,0.45)]"
          >
            <CardContent className="p-3">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold uppercase tracking-wide text-slate-300">
                  #{rank}
                </span>
                <span className="rounded-full bg-white/[0.08] px-2 py-0.5 text-xs font-semibold text-white">
                  {t.points ?? "—"} очков
                </span>
              </div>

              <div className="mt-2 flex items-center gap-3">
                <SafeImg
                  src={teamLogo(t.team_id)}
                  alt={t.team}
                  className="h-9 w-9 flex-shrink-0 object-contain"
                  fallback="team"
                />
                <div className="flex-1">
                  <button
                    type="button"
                    onClick={() =>
                      navigate(
                        `/team/${t.team_id}?league=${encodeURIComponent(
                          leagueParam
                        )}&season=${season}`
                      )
                    }
                    className="text-left text-sm font-semibold text-white hover:text-white"
                  >
                    {t.team ?? "—"}
                  </button>
                  <div className="mt-1 grid grid-cols-3 gap-2 text-[11px] text-slate-300">
                    <div>
                      <div className="text-[10px] uppercase tracking-wide text-slate-500">
                        Игры
                      </div>
                      <div className="font-medium">
                        {t.games_played ?? "—"}
                      </div>
                    </div>
                    <div>
                      <div className="text-[10px] uppercase tracking-wide text-slate-500">
                        В / Н / П
                      </div>
                      <div className="font-medium">
                        {t.wins ?? "—"}/{t.draws ?? "—"}/{t.losses ?? "—"}
                      </div>
                    </div>
                    <div>
                      <div className="text-[10px] uppercase tracking-wide text-slate-500">
                        Мячи
                      </div>
                      <div className={clsx("font-mono", diffClass)}>
                        {Number.isFinite(gf) && Number.isFinite(ga)
                          ? `${gf} – ${ga}`
                          : "—"}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>

            <div
              className={clsx(
                "absolute inset-y-0 left-0 w-[3px]",
                rank <= 4
                  ? "bg-cyan-400"
                  : rank === 5
                  ? "bg-emerald-400"
                  : rank >= 18
                  ? "bg-rose-500"
                  : "bg-transparent"
              )}
            />
          </Card>
        );
      })}

      {!loading && sortedTable.length === 0 && (
        <div
          className={clsx(
            "rounded-3xl border border-white/10 bg-white/[0.04] backdrop-blur-xl shadow-[0_8px_30px_rgba(0,0,0,0.45)]",
            "px-4 py-5 text-center text-sm text-slate-400"
          )}
        >
          Нет данных
        </div>
      )}
    </div>
  );

  /* =============================
     SCORERS BLOCK (кликабельно → /player/:id)
  ============================= */

  const renderScorers = () => (
    <Card className={clsx(BG_PANEL)}>
      <CardContent className="p-0">
        <Table className="min-w-full text-sm">
          <TableHeader>
            <TableRow className="border-b border-white/10 bg-white/[0.08]">
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "w-10 px-3 py-3 text-center text-[11px] uppercase tracking-[0.18em] text-slate-300"
                )}
              >
                #
              </TableHead>
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "px-3 py-3 text-[11px] uppercase tracking-[0.18em] text-slate-300"
                )}
              >
                Игрок
              </TableHead>
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "w-32 px-3 py-3 text-center text-[11px] uppercase tracking-[0.18em] text-slate-300"
                )}
              >
                Голы
              </TableHead>
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "w-32 px-3 py-3 text-center text-[11px] uppercase tracking-[0.18em] text-slate-300"
                )}
              >
                Пенальти
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {scorersRows.map((p, idx) => (
              <TableRow
                key={p.player_id}
                className={clsx(
                  "border-t border-white/10 bg-white/[0.02]",
                  HOVER_ROW
                )}
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
                      fallback="player"
                    />
                    <div className="min-w-0">
                      <div className="truncate text-sm font-semibold text-white group-hover:text-pink-300">
                        {p.player_name}
                      </div>
                      <div className="truncate text-xs text-slate-400">
                        {p.team_name}
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
                  Нет данных
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );

  /* =============================
     ASSISTS BLOCK (кликабельно → /player/:id)
  ============================= */

  const renderAssists = () => (
    <Card className={clsx(BG_PANEL)}>
      <CardContent className="p-0">
        <Table className="min-w-full text-sm">
          <TableHeader>
            <TableRow className="border-b border-white/10 bg-white/[0.08]">
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "w-10 px-3 py-3 text-center text-[11px] uppercase tracking-[0.18em] text-slate-300"
                )}
              >
                #
              </TableHead>
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "px-3 py-3 text-[11px] uppercase tracking-[0.18em] text-slate-300"
                )}
              >
                Игрок
              </TableHead>
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "w-32 px-3 py-3 text-center text-[11px] uppercase tracking-[0.18em] text-slate-300"
                )}
              >
                Ассисты
              </TableHead>
              <TableHead
                className={clsx(
                  TH_STICKY,
                  "w-32 px-3 py-3 text-center text-[11px] uppercase tracking-[0.18em] text-slate-300"
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
                className={clsx(
                  "border-t border-white/10 bg-white/[0.02]",
                  HOVER_ROW
                )}
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
                      fallback="player"
                    />
                    <div className="min-w-0">
                      <div className="truncate text-sm font-semibold text-white group-hover:text-pink-300">
                        {p.player_name}
                      </div>
                      <div className="truncate text-xs text-slate-400">
                        {p.team_name}
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
                  Нет данных
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );

  /* =============================
     PAGE LAYOUT
  ============================= */

  const headerSubtitle =
    view === "scorers"
      ? "Топ бомбардиров выбранной лиги и сезона. Нажмите на игрока, чтобы открыть детальную статистику."
      : view === "assists"
      ? "Топ ассистентов выбранной лиги и сезона. Нажмите на игрока, чтобы открыть детальную статистику."
      : "Позиции команд, очки и форма в выбранном сезоне. Нажмите на команду, чтобы открыть детальную аналитику.";

  return (
    <div className="mx-auto max-w-6xl space-y-6 px-4 py-6">
      {/* HEADER */}
      <div className={clsx(BG_PANEL, "p-6")}>
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full bg-white/[0.08] px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-300">
              <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
              {view === "scorers"
                ? "Статистика игроков — Бомбардиры"
                : view === "assists"
                ? "Статистика игроков — Ассисты"
                : "Таблица турнира"}
            </div>
            <h1 className="mt-3 text-2xl font-semibold text-white">
              {leagueParam}
            </h1>
            <p className={clsx("mt-1 text-sm", TEXT_MUTED)}>{headerSubtitle}</p>
          </div>

          <div className="flex items-center gap-3">
            <span className="text-xs uppercase tracking-[0.22em] text-slate-400">
              Сезон
            </span>
            <select
              value={season}
              onChange={(e) => setSeason(e.target.value)}
              className="rounded-xl border border-white/10 bg-white/[0.06] px-3 py-1.5 text-sm font-medium text-white shadow-inner focus:ring-2 focus:ring-pink-400/40"
            >
              {SEASONS.map((s) => (
                <option key={s} value={s} className="bg-slate-900">
                  {s}
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* tabs */}
        <div className="mt-5 flex flex-wrap gap-2">
          {VIEWS.map((v) => (
            <button
              key={v.code}
              type="button"
              onClick={() => setView(v.code)}
              className={clsx(
                "rounded-full border px-4 py-1.5 text-sm font-semibold transition",
                view === v.code
                  ? ACCENT_BG
                  : "border-white/10 text-slate-300 bg-white/[0.04] hover:bg-white/[0.08]"
              )}
            >
              {v.label}
            </button>
          ))}
        </div>
      </div>

      {/* loading */}
      {loading && (
        <div className="text-sm text-slate-400">Загрузка данных…</div>
      )}

      {/* content */}
      {view === "scorers"
        ? renderScorers()
        : view === "assists"
        ? renderAssists()
        : (
          <>
            {renderMainTableDesktop()}
            {renderMainTableMobile()}

            {/* legend */}
            <div className="mt-3 flex flex-wrap gap-6 text-xs text-slate-400">
              <div className="inline-flex items-center gap-2">
                <span className="h-2 w-2 rounded-full bg-cyan-400" />
                <span>Лига чемпионов</span>
              </div>
              <div className="inline-flex items-center gap-2">
                <span className="h-2 w-2 rounded-full bg-emerald-400" />
                <span>Еврокубки</span>
              </div>
              <div className="inline-flex items-center gap-2">
                <span className="h-2 w-2 rounded-full bg-rose-500" />
                <span>Зона вылета</span>
              </div>
            </div>
          </>
        )}
    </div>
  );
}
