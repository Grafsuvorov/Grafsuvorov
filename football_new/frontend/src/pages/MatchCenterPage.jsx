// src/pages/MatchCenterPage.jsx
import React, { useEffect, useState, useMemo, lazy, Suspense } from "react";
import { useNavigate, useParams, useSearchParams } from "react-router-dom";
import clsx from "clsx";

import SafeImg from "@/components/SafeImg";
import TeamLogoLink from "@/components/TeamLogoLink";
import LineupsTab from "@/components/LineupsTab";
import MatchInsightsPanelFull from "@/components/MatchInsightsPanelFull";
import UnderstatShotHeatmap from "@/components/UnderstatShotHeatmap";
import { teamLogoMap } from "@/constants/teamLogoMap";
import { buildMatchPack } from "@/lib/matchInsights";
import { LEAGUE_ID_BY_NAME, decideOutcomeTier, decideTotalsTierByValues } from "@/lib/policyDecision";
import { authFetch } from "@/lib/authFetch";
import { loadFavorites, saveFavorites } from "@/lib/favoritesStorage.js";
import { saveRecentMatch } from "@/lib/recentMatches.js";
import { loadLineupsCached } from "@/lib/lineupsApi";
import { isStaleLiveStatus, isUpcomingMatch, liveMinuteLabel } from "@/lib/matchStatus";
import { useLanguage } from "@/context/LanguageContext.jsx";
import SegmentedTabs from "@/components/ui/SegmentedTabs";
 

const MatchStatsBlockV3 = lazy(() =>
  import("@/components/MatchStatsBlockV3")
);

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

const teamLogo = (name, id) =>
  id
    ? `/icons/team_logos/${id}.png`
    : teamLogoMap[name] || "/icons/team_logos/default.png";

const teamLogoFallback = (id) =>
  id
    ? `https://media.api-sports.io/football/teams/${id}.png`
    : "/icons/team_logos/default.png";

const parseScore = (s) => {
  const m = String(s || "").match(/(\d+)\s*[-:]\s*(\d+)/);
  return m ? [Number(m[1]), Number(m[2])] : [null, null];
};
const formatDateTime = (match) => {
  if (match?.kickoff_local) {
    const [d, t] = String(match.kickoff_local).split(" ");
    return { date: d || "", time: t || "" };
  }
  const raw = match?.datetime || match?.date || "";
  if (!raw) return { date: "", time: "" };
  const str = String(raw).replace(" ", "T");
  const [date, time] = str.split("T");
  return { date: date || "", time: time ? time.slice(0, 5) : "" };
};

const toPct = (v) =>
  v == null || !Number.isFinite(Number(v)) ? "—" : `${Math.round(Number(v) * 100)}%`;

const toPct1 = (v) =>
  v == null || !Number.isFinite(Number(v)) ? "—" : `${(Number(v) * 100).toFixed(1)}%`;

const fmt2 = (v) =>
  v == null || !Number.isFinite(Number(v)) ? "—" : Number(v).toFixed(2);

const MATCH_TAB_WRAP = "w-full min-w-0 mc-fade mt-2";
const MATCH_TAB_STACK = `${MATCH_TAB_WRAP} space-y-6`;
const MATCH_TAB_PANEL = "panel w-full overflow-hidden p-4 sm:p-6";

function MiniCompareRow({ label, left, right, format }) {
  const l = Number.isFinite(Number(left)) ? Number(left) : null;
  const r = Number.isFinite(Number(right)) ? Number(right) : null;
  if (l == null && r == null) return null;
  const max = Math.max(Math.abs(l || 0), Math.abs(r || 0), 1);
  const lPct = l != null ? (Math.abs(l) / max) * 50 : 0;
  const rPct = r != null ? (Math.abs(r) / max) * 50 : 0;
  const fmt = (v) => (v == null ? "—" : format ? format(v) : v);

  return (
    <div className="min-w-0 space-y-2">
        <div className="grid min-w-0 grid-cols-[minmax(0,1fr)_72px_minmax(0,1fr)] items-center gap-2 sm:grid-cols-[1fr_auto_1fr]">
          <div className="min-w-0 truncate text-left text-[14px] font-semibold text-white/90 tabular-nums sm:text-[15px]">
            {fmt(l)}
          </div>
        <div className="min-w-0 truncate px-1 text-center text-[10px] font-semibold uppercase tracking-[0.1em] text-white/85 sm:px-3 sm:text-[11px] sm:tracking-[0.16em]">
          {label}
        </div>
          <div className="min-w-0 truncate text-right text-[14px] font-semibold text-white/90 tabular-nums sm:text-[15px]">
            {fmt(r)}
          </div>
        </div>
      <div className="relative h-[6px] rounded-full bg-white/8 overflow-hidden">
        <div className="absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-white/12" />
        <div
          className="absolute right-1/2 top-0 h-full rounded-full bg-gradient-to-r from-violet-500 to-violet-400/60 shadow-[0_0_10px_rgba(167,139,250,0.35)]"
          style={{ width: `${lPct}%` }}
        />
        <div
          className="absolute left-1/2 top-0 h-full rounded-full bg-gradient-to-l from-sky-400/80 to-teal-400/70 shadow-[0_0_10px_rgba(56,189,248,0.18)]"
          style={{ width: `${rPct}%` }}
        />
      </div>
    </div>
  );
}

async function fetchJsonSafe(url, signal, { auth = true } = {}) {
  const r = auth ? await authFetch(url, { signal }) : await fetch(url, { signal });
  if (r.status === 401 || r.status === 403) return null;
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  const txt = await r.text();
  try {
    return JSON.parse(txt);
  } catch {
    const fixed = txt
      .replace(/\bNaN\b/g, "null")
      .replace(/\b-?Infinity\b/g, "null");
    return JSON.parse(fixed);
  }
}

/* events / subs helpers */
const ICON = {
  goal: "⚽",
  own_goal: "🥅",
  goal_cancelled: "🚫",
  pen_missed: "⛔",
  yellow: "🟨",
  red: "🟥",
  sub: "🔁",
  var: "🎥",
  other: "•",
};

const lower = (v) => (v == null ? "" : String(v).toLowerCase());

const DETAIL_RU = {
  "normal goal": "Гол",
  "own goal": "Автогол",
  "goal cancelled": "Гол отменён",
  penalty: "Пенальти",
  "missed penalty": "Нереализованный пенальти",
  "yellow card": "Жёлтая карточка",
  "red card": "Красная карточка",
};

const COMMENTS_RU = {
  foul: "Фол",
  simulation: "Симуляция",
  "time wasting": "Затяжка времени",
};

const translateDetailRu = (d) =>
  DETAIL_RU[lower(d)] || (d == null ? "" : String(d));

const translateCommentRu = (c) =>
  COMMENTS_RU[lower(c)] || (c == null ? "" : String(c));

const getElapsed = (ev) => {
  const cand = [ev?.elapsed, ev?.minute, ev?.elapsed_time, ev?.time?.elapsed];
  const v = cand.find((x) => x != null && x !== "");
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

const getExtra = (ev) => {
  const cand = [ev?.extra, ev?.time?.extra, ev?.extra_time];
  const v = cand.find((x) => x != null && x !== "");
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
};

const minuteStr = (elapsed, extra) => {
  const e = Number(elapsed);
  const x = Number(extra) || 0;
  if (!Number.isFinite(e)) return "—";
  if (e === 45 && x > 0) return `45+${x}'`;
  if (e >= 90 && x > 0) return `${e}+${x}'`;
  return `${e}'`;
};

const inferKind = (ev) => {
  const t = lower(ev?.type);
  const d = lower(ev?.detail);
  if (t.includes("goal") && !d.includes("cancel"))
    return d === "own goal" ? "own_goal" : "goal";
  if (d.includes("cancel")) return "goal_cancelled";
  if (d === "missed penalty") return "pen_missed";
  if (d === "yellow card") return "yellow";
  if (d === "red card") return "red";
  if (t.startsWith("subst")) return "sub";
  if (d.includes("var")) return "var";
  return "other";
};

function computeScoreProgress(events, homeId, awayId) {
  let h = 0;
  let a = 0;
  const sorted = [...(events || [])].sort((A, B) => {
    const ea = getElapsed(A) ?? -1;
    const eb = getElapsed(B) ?? -1;
    const xa = getExtra(A);
    const xb = getExtra(B);
    if (ea !== eb) return ea - eb;
    if (xa !== xb) return xa - xb;
    return (A.player_id || 0) - (B.player_id || 0);
  });
  return sorted.map((e) => {
    const side =
      e.team_id === homeId ? "home" : e.team_id === awayId ? "away" : null;
    const kind = inferKind(e);
    if (kind === "goal") {
      if (side === "home") h++;
      else if (side === "away") a++;
    }
    if (kind === "own_goal") {
      if (side === "home") a++;
      else if (side === "away") h++;
    }
    return { ...e, team_side: side, kind, score_after: `${h}-${a}` };
  });
}

const collectSubs = (events = []) =>
  events
    .filter((e) => {
      const t = lower(e?.type);
      const d = lower(e?.detail);
      return t.startsWith("subst") || d.startsWith("substitution");
    })
    .map((e) => ({
      team_id: e.team_id,
      minute: e.minute ?? e.elapsed ?? null,
      in_id: e.player_id,
      in_name: e.player_name,
      out_id: e.assist_id,
      out_name: e.assist_name,
    }));

function groupEventsByPeriod(events) {
  const out = {
    first: { home: [], away: [] },
    second: { home: [], away: [] },
    extra: { home: [], away: [] },
  };
  for (const ev of events) {
    const e = getElapsed(ev) ?? 0;
    const bucket = e <= 45 ? "first" : e <= 90 ? "second" : "extra";
    const side = ev.team_side === "away" ? "away" : "home";
    out[bucket][side].push(ev);
  }
  return out;
}

function MinutePill({ value }) {
  return (
    <span className="inline-flex items-center justify-center px-2.5 py-1 rounded-full bg-violet-500/12 text-[12px] font-semibold text-slate-100 tabular-nums">
      {value}
    </span>
  );
}

function BenchList({ title, list, alignRight = false }) {
  return (
    <div>
      {title ? (
        <div className={clsx("mb-2 text-xs font-medium text-white/75 tracking-wide", alignRight && "text-right")}>
          {title}
        </div>
      ) : null}
      <div className={clsx("grid grid-cols-2 gap-x-6 gap-y-3", alignRight && "text-right")}>
        {(list || []).map((p, i) => {
          const pid = p.player_id || i;
          const src = pid ? `/icons/player_photos/${pid}.png` : null;
          const name = p.name || p.player_name || `#${p.number || "?"}`;
          return (
            <div
              key={pid}
              className={clsx("inline-flex items-center gap-2 text-[14px] text-white/80", alignRight ? "justify-end" : "justify-start")}
            >
              {!alignRight && (
                <span className="inline-flex h-6 w-6 items-center justify-center rounded-full overflow-hidden bg-white/[0.02] border border-white/10">
                  {src ? (
                    <img src={src} className="h-full w-full object-cover" />
                  ) : (
                    <span className="text-[10px] font-semibold">
                      {p.number || "?"}
                    </span>
                  )}
                </span>
              )}
              <span className="max-w-[112px] truncate sm:max-w-[140px]">{name}</span>
              {alignRight && (
                <span className="inline-flex h-6 w-6 items-center justify-center rounded-full overflow-hidden bg-white/[0.02] border border-white/10">
                  {src ? (
                    <img src={src} className="h-full w-full object-cover" />
                  ) : (
                    <span className="text-[10px] font-semibold">
                      {p.number || "?"}
                    </span>
                  )}
                </span>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

export default function MatchCenterPage() {
  const { t, language } = useLanguage();
  const { matchId } = useParams();
  const [sp] = useSearchParams();
  const navigate = useNavigate();
  const league = sp.get("league") || "Premier League";
  const season = sp.get("season") || "2025";

  const [match, setMatch] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [tab, setTab] = useState("overview");
  const [marketTab, setMarketTab] = useState("outcome");
  const [lineupsData, setLineupsData] = useState(null);
  const [lineupsLoading, setLineupsLoading] = useState(false);
  const [lineupsError, setLineupsError] = useState("");
  const [pack, setPack] = useState(null);
  const [packLoading, setPackLoading] = useState(false);
  const [insight, setInsight] = useState(null);
  const [insightLoading, setInsightLoading] = useState(false);
  const [isFavoriteMatch, setIsFavoriteMatch] = useState(false);
  const mc = useMemo(
    () =>
      language === "ru"
        ? {
            back: "Назад",
            overview: "Обзор",
            stats: "Статистика",
            lineups: "Составы",
            form: "Форма",
            loadingMatch: "Загружаем матч…",
            analyticsTitle: "Аналитика матча",
            analyticsLoading: "Данные модели загружаются…",
            noEdge: "Выраженного преимущества в линии нет.",
            byOutcome: "По исходу",
            noOutcomeEdge: "Линия по исходу не даёт явного преимущества.",
            byTotal: "По тоталу",
            noTotalEdge: "По тоталу матч ближе к нейтральному сценарию — явного перекоса нет.",
            skipBet: "Рекомендация: пропустить ставку при текущей цене.",
            outcome12: "Исход (1X2)",
            total25: "Тотал 2.5",
            model: "Модель",
            market: "Рынок",
            noTotalMarketData: "По тоталам нет рыночных данных для сравнения.",
            positiveGapHint: "Положительная разница может означать недооценку рынком.",
            teamComparison: "Сравнение команд",
            preMatchAvg: "Последние 10 матчей · средние значения (до матча)",
            matchXg: "xG матча",
            formXg: "xG форма",
            shots: "Удары",
            shotsOn: "В створ",
            possession: "Владение",
            corners: "Угловые",
            playerXg: "xG по игрокам матча",
            homeFallback: "Хозяева",
            awayFallback: "Гости",
            liveStatsNote: "Матч идёт в лайве. Статистика и события обновляются по ходу игры.",
            noStatsYet: "Статистика матча пока недоступна. Данные появятся после завершения игры.",
            loading: "Загружаем…",
            lineupsLoading: "Загружаем составы…",
            lineupsUnavailable: "Составы недоступны для этого матча.",
            lineupsDataUnavailable: "Данные по составам и событиям недоступны.",
            lineupsLoadFailed: "Не удалось загрузить составы",
            formLoading: "Загружаем данные формы…",
            finished: "Закончен",
          }
        : {
            back: "Back",
            overview: "Overview",
            stats: "Stats",
            lineups: "Lineups",
            form: "Form",
            loadingMatch: "Loading match…",
            analyticsTitle: "Match analytics",
            analyticsLoading: "Model data is loading…",
            noEdge: "No clear edge in the line.",
            byOutcome: "Outcome",
            noOutcomeEdge: "The outcome line does not show a clear edge.",
            byTotal: "Total",
            noTotalEdge: "The totals market looks close to neutral with no clear skew.",
            skipBet: "Recommendation: skip at the current price.",
            outcome12: "Outcome (1X2)",
            total25: "Total 2.5",
            model: "Model",
            market: "Market",
            noTotalMarketData: "No market data available for totals comparison.",
            positiveGapHint: "A positive gap may indicate the market is underrating this side.",
            teamComparison: "Team comparison",
            preMatchAvg: "Last 10 matches · average values before kickoff",
            matchXg: "Match xG",
            formXg: "Form xG",
            shots: "Shots",
            shotsOn: "Shots on target",
            possession: "Possession",
            corners: "Corners",
            playerXg: "Match player xG",
            homeFallback: "Home",
            awayFallback: "Away",
            liveStatsNote: "The match is live. Stats and events update during play.",
            noStatsYet: "Match stats are not available yet. Data will appear after full time.",
            loading: "Loading…",
            lineupsLoading: "Loading lineups…",
            lineupsUnavailable: "Lineups are unavailable for this match.",
            formLoading: "Loading form data…",
            finished: "Finished",
            loadError: "Loading error",
            lineupsDataUnavailable: "Lineup and event data are unavailable.",
            lineupsLoadFailed: "Failed to load lineups",
          },
    [language]
  );

  const eventsFromLineups = useMemo(() => {
    if (!lineupsData?.events || !match?.home_team_id || !match?.away_team_id) return null;
    return computeScoreProgress(lineupsData.events, match.home_team_id, match.away_team_id);
  }, [lineupsData, match?.home_team_id, match?.away_team_id]);

  const eventsGrouped = useMemo(
    () => (eventsFromLineups ? groupEventsByPeriod(eventsFromLineups) : null),
    [eventsFromLineups]
  );

  useEffect(() => {
    if (!matchId) return;
    const ac = new AbortController();
    setLoading(true);
    setError("");
    const qs = new URLSearchParams({ fixture_id: String(matchId) });
    if (league) qs.set("league", league);
    if (season) qs.set("season", season);
    qs.set("include_understat", "true");
    fetchJsonSafe(
      `${API_BASE}/api/matches_v3?${qs.toString()}`,
      ac.signal
    )
      .then((rows) => {
        const list = Array.isArray(rows) ? rows : [];
        const mid = String(matchId);
        const item =
          list.find((r) => String(r?.fixture_id ?? r?.id ?? "") === mid) ||
          list[0] ||
          null;
        setMatch(item);
      })
      .catch((e) => {
        if (e?.name === "AbortError") return;
        if (String(e?.message || "").includes("aborted")) return;
        setError(e?.message || mc.loadError);
      })
      .finally(() => setLoading(false));
    return () => ac.abort();
  }, [matchId, league, season, mc.loadError]);

  useEffect(() => {
    if (!matchId) return;
    const ac = new AbortController();
    setInsightLoading(true);
    setInsight(null);
    fetchJsonSafe(
      `${API_BASE}/api/match-insight?fixture_id=${matchId}`,
      ac.signal
    )
      .then((data) => setInsight(data || null))
      .catch(() => setInsight(null))
      .finally(() => setInsightLoading(false));
    return () => ac.abort();
  }, [matchId]);

  const [homeGoals, awayGoals] = parseScore(match?.score);
  const hasScore = homeGoals != null && awayGoals != null;
  const liveStatusRaw = String(match?.status_short || match?.status_text || match?.status || "").trim().toUpperCase();
  const matchFinished =
    (!!liveStatusRaw &&
      ["FT", "AET", "PEN", "FT_PEN", "AET_PEN", "MATCH FINISHED", "FINISHED", "FULL TIME"].includes(liveStatusRaw)) ||
    isStaleLiveStatus(match);
  const matchLive =
    !!liveStatusRaw &&
    !matchFinished &&
    (
      liveStatusRaw === "1H" ||
      liveStatusRaw === "2H" ||
      liveStatusRaw === "ET" ||
      liveStatusRaw === "HT" ||
      liveStatusRaw === "PEN" ||
      liveStatusRaw.includes("FIRST HALF") ||
      liveStatusRaw.includes("SECOND HALF") ||
      liveStatusRaw.includes("HALF TIME") ||
      liveStatusRaw.includes("HALFTIME") ||
      liveStatusRaw.includes("EXTRA TIME") ||
      liveStatusRaw.includes("BREAK TIME")
    );
  useEffect(() => {
    if (!match?.fixture_id) return;
    setLineupsData(null);
    setLineupsError("");
    setLineupsLoading(false);
  }, [match?.fixture_id]);

  useEffect(() => {
    if (!match?.fixture_id) return;
    if (tab !== "lineups") return;
    if (isUpcomingMatch(match)) {
      setLineupsData(null);
      setLineupsError(mc.lineupsUnavailable);
      setLineupsLoading(false);
      return;
    }
    if (lineupsLoading || lineupsData || lineupsError) return;
    const ac = new AbortController();
    setLineupsLoading(true);
    setLineupsError("");
    loadLineupsCached(match.fixture_id, ac.signal)
      .then((res) => {
        if (res?.data) setLineupsData(res.data);
        else if (res?.error === "not_found")
          setLineupsError(mc.lineupsDataUnavailable);
        else if (res?.error)
          setLineupsError(`${mc.lineupsLoadFailed} (${res?.message || res?.error})`);
      })
      .catch((e) => {
        if (e?.name === "AbortError") return;
        setLineupsError(`${mc.lineupsLoadFailed} (${e?.message || "error"})`);
      })
      .finally(() => setLineupsLoading(false));
    return () => ac.abort();
  }, [match, match?.fixture_id, tab, mc.lineupsDataUnavailable, mc.lineupsLoadFailed, mc.lineupsUnavailable]);


  useEffect(() => {
    if (!match) return;
    let cancelled = false;
    (async () => {
      try {
        setPackLoading(true);
        const data = await buildMatchPack({ match, league });
        if (!cancelled) setPack(data);
      } catch {
        if (!cancelled) setPack(null);
      } finally {
        if (!cancelled) setPackLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [match, league]);

  useEffect(() => {
    if (!match?.fixture_id) return;
    saveRecentMatch({
      ...match,
      fixture_id: match.fixture_id || matchId,
      league: match.league || league,
      season: match.season || season,
    });
  }, [match, matchId, league, season]);

  useEffect(() => {
    if (!matchId) return;
    const syncFavoriteState = () => {
      const list = loadFavorites("favorites_matches");
      setIsFavoriteMatch(list.some((item) => String(item.fixture_id) === String(matchId)));
    };
    syncFavoriteState();
    window.addEventListener("favorites:update", syncFavoriteState);
    window.addEventListener("storage", syncFavoriteState);
    return () => {
      window.removeEventListener("favorites:update", syncFavoriteState);
      window.removeEventListener("storage", syncFavoriteState);
    };
  }, [matchId]);

  const toggleFavoriteMatch = () => {
    if (!match?.fixture_id) return;
    const list = loadFavorites("favorites_matches");
    const exists = list.some((item) => String(item.fixture_id) === String(match.fixture_id));
    const next = exists
      ? list.filter((item) => String(item.fixture_id) !== String(match.fixture_id))
      : [
          {
            fixture_id: String(match.fixture_id),
            league: match.league || league,
            season: String(match.season || season),
            home_team: match.home_team || "",
            away_team: match.away_team || "",
            home_team_id: match.home_team_id || null,
            away_team_id: match.away_team_id || null,
            home_goals: match.home_goals ?? null,
            away_goals: match.away_goals ?? null,
            status: match.status || "",
            status_short: match.status_short || "",
            is_live: !!match.is_live,
            kickoff_local: match.kickoff_local || match.datetime || match.date || "",
            favorited_at: new Date().toISOString(),
          },
          ...list,
        ].slice(0, 30);
    saveFavorites("favorites_matches", next);
    try {
      window.dispatchEvent(new CustomEvent("favorites:update"));
    } catch {}
    setIsFavoriteMatch(!exists);
  };

  const statusText = matchLive
    ? liveMinuteLabel(match, language, { prefix: true })
    : matchFinished
    ? mc.finished
    : match?.status_text || match?.status || "";
  const homeWin = homeGoals != null && awayGoals != null && homeGoals > awayGoals;
  const awayWin = homeGoals != null && awayGoals != null && awayGoals > homeGoals;
  const dt = formatDateTime(match);

  const pickVal = (obj, keys) => {
    for (const k of keys) {
      const v = obj?.[k];
      if (v == null || v === "") continue;
      const n = Number(v);
      if (Number.isFinite(n)) return n;
    }
    return null;
  };

  const pickFrom = (objs, keys) => {
    for (const o of objs) {
      const v = pickVal(o, keys);
      if (Number.isFinite(v)) return v;
    }
    return null;
  };

  const insProbs = insight?.probs_1x2 || insight?.triad || null;
  const insOdds = insight?.odds_1x2 || null;
  const recOutcome = insight?.recommendations?.outcome || null;
  const recTotal = insight?.recommendations?.total || null;

  const p1 = pickFrom([match, insProbs], [
    "p1",
    "prob_home",
    "home_win_prob",
    "home_prob",
    "signal_p_home",
    "home",
    "pH",
  ]);
  const px = pickFrom([match, insProbs], [
    "px",
    "prob_draw",
    "draw_prob",
    "signal_p_draw",
    "draw",
    "pD",
  ]);
  const p2 = pickFrom([match, insProbs], [
    "p2",
    "prob_away",
    "away_win_prob",
    "away_prob",
    "signal_p_away",
    "away",
    "pA",
  ]);
  const over25 =
    pickVal(match, ["prob_over25", "over25_prob", "p_over25"]) ??
    (recTotal?.outcome === "over" ? Number(recTotal?.p) : null);
  const under25 =
    pickVal(match, ["prob_under25", "under25_prob", "p_under25"]) ??
    (recTotal?.outcome === "under" ? Number(recTotal?.p) : null);

  const edgeFromRec =
    recOutcome?.p != null && recOutcome?.odds != null
      ? (Number(recOutcome.p) - 1 / Number(recOutcome.odds)) * 100
      : null;
  const valueFromRec =
    recOutcome?.ev != null ? Number(recOutcome.ev) * 100 : null;

  const edge =
    pickFrom([match], ["signal_edge", "edge", "edge_value"]) ?? edgeFromRec;
  const value =
    pickFrom([match], ["signal_value", "value", "ev"]) ?? valueFromRec;

  const recDecision = String(
    match?.rec_decision || (recOutcome || recTotal ? "BET" : "SKIP")
  ).toUpperCase();
  const signalPick =
    match?.signal_pick ||
    match?.signal ||
    recOutcome?.label ||
    recTotal?.label ||
    null;
  const hasLineTab =
    signalPick != null ||
    [p1, px, p2, over25, under25, edge, value].some((v) =>
      Number.isFinite(v)
    ) ||
    [
      match?.avg_odds_home,
      match?.avg_odds_draw,
      match?.avg_odds_away,
      match?.avg_odds_over25,
      match?.avg_odds_under25,
      insOdds?.home,
      insOdds?.draw,
      insOdds?.away,
    ]
      .some((v) => Number.isFinite(Number(v)));

  const thresholdEdgePct = 10;
  const thresholdConfPct = 55;
  const topProb = Math.max(Number(p1 || 0), Number(px || 0), Number(p2 || 0));
  const topProbPct = Number.isFinite(topProb) ? topProb * 100 : null;
  const minOdds = 1.7;
  const signalOdds = recOutcome?.odds != null ? Number(recOutcome.odds) : null;
  const labels = language === "ru"
    ? {
        play: "Играть",
        careful: "Аккуратно",
        skip: "Пропуск",
        noSignal: "Сигнала нет",
        homeWin: "П1",
        draw: "Х",
        awayWin: "П2",
        homeFallback: "Хозяева",
        awayFallback: "Гости",
        drawTeam: "ничья",
        over25: "ТБ 2.5",
        under25: "ТМ 2.5",
      }
    : {
        play: "Bet",
        careful: "Watch carefully",
        skip: "Skip",
        noSignal: "No signal",
        homeWin: "1",
        draw: "X",
        awayWin: "2",
        homeFallback: "Home",
        awayFallback: "Away",
        drawTeam: "draw",
        over25: "Over 2.5",
        under25: "Under 2.5",
      };

  const outcomeSignal =
    recDecision === "BET"
      ? labels.play
      : recDecision === "WATCH"
      ? labels.careful
      : labels.skip;
  const outcomeLabel = outcomeSignal === labels.skip ? labels.noSignal : outcomeSignal;

  const thresholdReason =
    outcomeSignal === labels.play
      ? language === "ru"
        ? "Модель видит заметное преимущество — сигнал проходит фильтр."
        : "The model sees a meaningful edge and the signal passes the filter."
      : outcomeSignal === labels.careful
      ? language === "ru"
        ? "Преимущество есть, но запас умеренный — стоит быть осторожнее."
        : "There is an edge, but the margin is moderate."
      : language === "ru"
      ? "Рынок почти совпадает с оценкой модели — выраженного value не обнаружено."
      : "The market is close to the model estimate, so no strong value is detected.";

  const signalTone =
    outcomeSignal === labels.play
      ? "emerald"
      : outcomeSignal === labels.careful
      ? "amber"
      : "neutral";

  const matchPlayed = homeGoals != null && awayGoals != null;

  const hasModelData =
    [p1, px, p2, over25, under25, edge, value].some((v) =>
      Number.isFinite(v)
    ) || signalPick != null;
  const analyticsPending = !hasModelData && insightLoading && !insight;

  const hAvg = pack?.homeAvg || null;
  const aAvg = pack?.awayAvg || null;
  const xgDiff =
    hAvg && aAvg && Number.isFinite(hAvg.xg) && Number.isFinite(aAvg.xg)
      ? hAvg.xg - aAvg.xg
      : null;
  const shotsDiff =
    hAvg && aAvg && Number.isFinite(hAvg.shots) && Number.isFinite(aAvg.shots)
      ? hAvg.shots - aAvg.shots
      : null;
  const possDiff =
    hAvg && aAvg && Number.isFinite(hAvg.possession) && Number.isFinite(aAvg.possession)
      ? hAvg.possession - aAvg.possession
      : null;

  const analysisText = (() => {
    if (!hAvg || !aAvg) return null;
    const h = hAvg;
    const a = aAvg;
    const lines = [];
    const home = match?.home_team;
    const away = match?.away_team;

    if (xgDiff != null || shotsDiff != null || possDiff != null) {
      let picture = language === "ru" ? "Картина матча выглядит сбалансированной." : "The match profile looks balanced.";
      if (xgDiff != null && shotsDiff != null) {
        if (xgDiff > 0.15 && shotsDiff > 1) {
          picture = language === "ru" ? `${home} контролирует темп и создаёт больше качественных моментов.` : `${home} controls the tempo and creates the better chances.`;
        } else if (xgDiff < -0.15 && shotsDiff < -1) {
          picture = language === "ru" ? `${away} контролирует темп и создаёт больше качественных моментов.` : `${away} controls the tempo and creates the better chances.`;
        } else if (xgDiff > 0.15 && shotsDiff <= 1) {
          picture = language === "ru" ? `${home} создаёт более качественные моменты при сопоставимом объёме ударов.` : `${home} creates the higher-quality chances with a similar shot volume.`;
        } else if (xgDiff < -0.15 && shotsDiff >= -1) {
          picture = language === "ru" ? `${away} создаёт более качественные моменты при сопоставимом объёме ударов.` : `${away} creates the higher-quality chances with a similar shot volume.`;
        }
      } else if (xgDiff != null) {
        picture = xgDiff > 0.15
          ? language === "ru" ? `${home} выглядит предпочтительнее по качеству моментов.` : `${home} looks better on chance quality.`
          : xgDiff < -0.15
            ? language === "ru" ? `${away} выглядит предпочтительнее по качеству моментов.` : `${away} looks better on chance quality.`
            : picture;
      }
      if (possDiff != null && Math.abs(possDiff) >= 6) {
        picture += language === "ru"
          ? ` По контролю мяча преимущество у ${possDiff > 0 ? home : away}.`
          : ` Possession control also favors ${possDiff > 0 ? home : away}.`;
      }
      lines.push(picture);
    }

    if (xgDiff != null && shotsDiff != null) {
      if (Math.abs(xgDiff) < 0.15 && Math.abs(shotsDiff) < 1) {
        lines.push(language === "ru" ? "Контекст формы: команды создают схожий объём моментов, сценарий чувствителен к реализации." : "Form context: both sides create a similar volume of chances, so finishing variance matters.");
      } else if (Math.abs(shotsDiff) >= 3 && Math.abs(xgDiff) < 0.2) {
        lines.push(language === "ru" ? "Контекст формы: объём атак различается, но качество моментов близко — возможен разброс по реализации." : "Form context: attack volume differs, but chance quality stays close, so conversion can swing the outcome.");
      }
    }

    lines.push(language === "ru" ? "Риск сценария: высокая вариативность реализации может изменить итог при равном объёме моментов." : "Scenario risk: high finishing variance can swing the final result even with similar chance volume.");
    return lines.length ? lines : null;
  })();

  const implied = (odds) => {
    const n = Number(odds);
    if (!Number.isFinite(n) || n <= 0) return null;
    return (1 / n) * 100;
  };

  const oddsHome =
    pickFrom([match, insOdds], ["avg_odds_home", "home", "odH"]) ?? null;
  const oddsDraw =
    pickFrom([match, insOdds], ["avg_odds_draw", "draw", "odD"]) ?? null;
  const oddsAway =
    pickFrom([match, insOdds], ["avg_odds_away", "away", "odA"]) ?? null;

  const modelVsMarket = [
    { label: labels.homeWin, model: p1, odds: oddsHome },
    { label: labels.draw, model: px, odds: oddsDraw },
    { label: labels.awayWin, model: p2, odds: oddsAway },
  ];

  const savedBetOutcome = String(match?.best_bet_outcome || "").trim();
  const savedBetType = String(match?.best_bet_type || "").trim().toUpperCase();
  const savedBetRating = String(match?.bet_rating || "").trim().toLowerCase();
  const savedOutcomePick =
    savedBetOutcome === "Home"
      ? { id: "home", label: labels.homeWin, name: "Home", team: match?.home_team || labels.homeFallback, p: p1, odds: oddsHome, ev: match?.best_bet_ev }
      : savedBetOutcome === "Draw"
        ? { id: "draw", label: labels.draw, name: "Draw", team: labels.drawTeam, p: px, odds: oddsDraw, ev: match?.best_bet_ev }
        : savedBetOutcome === "Away"
          ? { id: "away", label: labels.awayWin, name: "Away", team: match?.away_team || labels.awayFallback, p: p2, odds: oddsAway, ev: match?.best_bet_ev }
          : null;
  const savedOutcomeTier =
    savedOutcomePick &&
    (savedBetType === "1X2" || savedBetType === "NONE")
      ? savedBetRating === "strong"
        ? "A"
        : savedBetRating === "medium"
          ? "B"
          : "NO BET"
      : "NO BET";
  const savedTotalPick =
    savedBetOutcome === "Over2.5"
      ? labels.over25
      : savedBetOutcome === "Under2.5"
        ? labels.under25
        : null;
  const savedTotalTier =
    savedTotalPick &&
    (savedBetType === "TOTAL" || savedBetType === "NONE")
      ? savedBetRating === "strong"
        ? "A"
        : savedBetRating === "medium"
          ? "B"
          : "NO BET"
      : "NO BET";

  const analysisNarrative = (() => {
    if (!hasModelData) return null;
    const home = match?.home_team || labels.homeFallback;
    const away = match?.away_team || labels.awayFallback;
    const leagueId = Number(match?.league_id) || LEAGUE_ID_BY_NAME[league] || null;
    const outcomeCandidates = [
      { id: "home", label: labels.homeWin, name: "Home", team: home, p: p1, odds: oddsHome },
      { id: "draw", label: labels.draw, name: "Draw", team: labels.drawTeam, p: px, odds: oddsDraw },
      { id: "away", label: labels.awayWin, name: "Away", team: away, p: p2, odds: oddsAway },
    ]
      .filter((x) => Number.isFinite(Number(x.p)) && Number.isFinite(Number(x.odds)))
      .map((x) => ({ ...x, ev: Number(x.p) * Number(x.odds) - 1 }))
      .sort((a, b) => Number(b.ev) - Number(a.ev));

    const computedBestOutcome = outcomeCandidates[0] || null;
    const computedOutcomeTier =
      computedBestOutcome && leagueId != null
        ? decideOutcomeTier(computedBestOutcome.ev, computedBestOutcome.odds, leagueId, computedBestOutcome.name)
        : "NO BET";
    const bestOutcome = savedOutcomeTier !== "NO BET" ? savedOutcomePick : computedBestOutcome;
    const outcomeTier = savedOutcomeTier !== "NO BET" ? savedOutcomeTier : computedOutcomeTier;

    const domTeam =
      xgDiff != null && Math.abs(xgDiff) >= 0.25
        ? xgDiff > 0 ? home : away
        : shotsDiff != null && Math.abs(shotsDiff) >= 3
          ? shotsDiff > 0 ? home : away
          : possDiff != null && Math.abs(possDiff) >= 7
            ? possDiff > 0 ? home : away
            : null;

    const pickOver = Number(over25) >= Number(under25);
    const computedTotalPick =
      Number.isFinite(Number(over25)) || Number.isFinite(Number(under25))
        ? pickOver ? labels.over25 : labels.under25
        : null;
    const computedTotalTier =
      leagueId != null
        ? decideTotalsTierByValues({
            pOver25: over25,
            avgOddsOver25: match?.avg_odds_over25,
            avgOddsUnder25: match?.avg_odds_under25,
            leagueId,
          })
        : "NO BET";
    const totalPick = savedTotalTier !== "NO BET" ? savedTotalPick : computedTotalPick;
    const totalTier = savedTotalTier !== "NO BET" ? savedTotalTier : computedTotalTier;
    const totalState = totalTier === "A" || totalTier === "B" ? "positive" : "neutral";

    const [scoreHome, scoreAway] = parseScore(match?.score || "");
    const hg = Number.isFinite(Number(match?.home_goals)) ? Number(match?.home_goals) : scoreHome;
    const ag = Number.isFinite(Number(match?.away_goals)) ? Number(match?.away_goals) : scoreAway;
    const hasResult = Number.isFinite(hg) && Number.isFinite(ag);

    const outcomeProfitBase = (() => {
      if (!hasResult || !bestOutcome || !["A", "B"].includes(outcomeTier)) return null;
      const won =
        bestOutcome.name === "Home"
          ? hg > ag
          : bestOutcome.name === "Draw"
            ? hg === ag
            : hg < ag;
      return won ? Number(bestOutcome.odds) - 1 : -1;
    })();

    const totalProfitBase = (() => {
      if (!hasResult || totalTier === "NO BET" || !totalPick) return null;
      const goals = hg + ag;
      const won = totalPick === "ТБ 2.5" ? goals >= 3 : goals <= 2;
      const odds = totalPick === "ТБ 2.5" ? match?.avg_odds_over25 : match?.avg_odds_under25;
      if (!Number.isFinite(Number(odds))) return null;
      return won ? Number(odds) - 1 : -1;
    })();

    const anyBet = ["A", "B"].includes(outcomeTier) || ["A", "B"].includes(totalTier);
    const profitSumBase =
      (outcomeProfitBase ?? 0) + (totalProfitBase ?? 0);
    const resultTone =
      hasResult && anyBet
        ? profitSumBase > 0
          ? "green"
          : profitSumBase < 0
            ? "red"
            : "gray"
        : anyBet
          ? "neutral"
          : "none";

    const negativeSignal = bestOutcome?.ev != null && bestOutcome.ev <= -0.05;
    const state =
      outcomeTier === "A"
        ? "strong"
        : outcomeTier === "B"
          ? "moderate"
          : negativeSignal
            ? "negative"
            : "none";

    const tone =
      state === "strong"
        ? "emerald"
        : state === "moderate"
          ? "amber"
          : state === "negative"
            ? "rose"
            : "neutral";

    const sideLabel = bestOutcome?.label
      ? language === "ru"
        ? `по ${bestOutcome.label}`
        : `on ${bestOutcome.label}`
      : "";
    const keyLine =
      language === "ru"
        ? state === "strong"
          ? `Линия даёт выраженное преимущество ${sideLabel}.`
          : state === "moderate"
            ? `Баланс вероятностей смещён, но линия даёт лишь умеренное преимущество ${sideLabel}.`
            : state === "negative"
              ? `Баланс вероятностей смещён, но текущая линия ${sideLabel} не даёт преимущества.`
              : "Баланс вероятностей близок к нейтральному — преимущества в линии нет."
        : state === "strong"
          ? `The line shows a strong edge ${sideLabel}.`
          : state === "moderate"
            ? `The probability balance leans one way, but the line offers only a moderate edge ${sideLabel}.`
            : state === "negative"
              ? `The probability balance leans one way, but the current line offers no edge ${sideLabel}.`
              : "The probability balance is close to neutral with no clear edge in the line.";

    let context = "";
    let totalLine = "";
    let rec = "";

    if (state === "none") {
      context =
        language === "ru"
          ? "Линия по исходу нейтральна — дополнительного преимущества нет."
          : "The outcome line is neutral with no additional edge.";
      if (totalPick) {
        totalLine =
          totalState === "positive"
            ? language === "ru"
              ? `Линия недооценивает вероятность ${totalPick}.`
              : `The line underrates the probability of ${totalPick}.`
            : language === "ru"
              ? "Выраженного преимущества в линии нет. Цена соответствует базовому сценарию."
              : "There is no strong edge in the line. The price matches the baseline scenario.";
      }
      rec =
        totalState === "positive"
          ? language === "ru"
            ? `Рекомендация: по исходу — без действия. По тоталу — ${totalPick}, есть value.`
            : `Recommendation: no action on the outcome. On totals, ${totalPick} shows value.`
          : language === "ru"
            ? "Рекомендация: по исходу — без действия. По тоталу — без преимущества."
            : "Recommendation: no action on the outcome. No edge on totals.";
    } else if (state === "moderate") {
      context =
        language === "ru"
          ? "Один из исходов выглядит недооценённым рынком. Модель закладывает более высокую вероятность события, чем отражено в коэффициенте. При этом расхождение остаётся умеренным и чувствительным к изменению линии."
          : "One outcome looks underrated by the market. The model assigns a higher probability to the event than the odds imply, but the gap remains moderate and sensitive to line movement.";
      if (domTeam) {
        context += language === "ru"
          ? " По игровым показателям есть перевес, но сценарий допускает вариативность."
          : " The match profile points to an edge, but the scenario still allows for volatility.";
      }
      if (totalPick) {
        totalLine =
          totalState === "positive"
            ? language === "ru"
              ? `Линия недооценивает вероятность ${totalPick}.`
              : `The line underrates the probability of ${totalPick}.`
            : language === "ru"
              ? "Сценарий умеренного темпа выглядит вероятным, однако преимущество в линии минимально."
              : "A moderate-tempo match looks plausible, but the edge in the line is minimal.";
      }
      rec =
        totalState === "positive"
          ? language === "ru"
            ? `Рекомендация: рассмотреть аккуратно. По тоталу — ${totalPick}.`
            : `Recommendation: worth considering with caution. On totals, ${totalPick}.`
          : language === "ru"
            ? "Рекомендация: рассмотреть аккуратно. Риск остаётся умеренным."
            : "Recommendation: consider cautiously. Risk remains moderate.";
    } else if (state === "strong") {
      context =
        language === "ru"
          ? "Модель фиксирует устойчивый перевес в ключевых метриках — качестве моментов, темпе и структуре атак. Текущая линия не полностью отражает этот баланс. Коэффициент обеспечивает положительное математическое ожидание."
          : "The model sees a sustained edge in key metrics: chance quality, tempo, and attacking structure. The current line does not fully reflect that balance, so the price offers positive expected value.";
      if (domTeam) {
        context += language === "ru"
          ? " Сценарий матча соответствует оценке: структурное преимущество подтверждается статистикой."
          : " The expected match script fits the call: the structural edge is supported by the stats.";
      }
      if (totalPick) {
        totalLine =
          totalState === "positive"
            ? language === "ru"
              ? `Линия недооценивает вероятность ${totalPick}.`
              : `The line underrates the probability of ${totalPick}.`
            : language === "ru"
              ? "По тоталу выраженного преимущества в линии нет."
              : "There is no strong edge on totals.";
      }
      rec =
        totalState === "positive"
          ? language === "ru"
            ? `Рекомендация: ставка оправдана. По тоталу — ${totalPick}.`
            : `Recommendation: the bet is justified. On totals, ${totalPick}.`
          : language === "ru"
            ? "Рекомендация: ставка оправдана. Коэффициент даёт выраженное преимущество."
            : "Recommendation: the bet is justified. The price offers a clear edge.";
    } else if (state === "negative") {
      context =
        language === "ru"
          ? "Текущий коэффициент отражает более высокий сценарий, чем оправдывает расчётная оценка матча. При данной цене перевес выглядит переоценённым."
          : "The current odds imply a stronger scenario than the model supports. At this price, the edge looks overstated.";
      context += language === "ru"
        ? " Даже при статистическом преимуществе команды линия выглядит завышенной и не компенсирует риск."
        : " Even with a statistical edge for one team, the line looks inflated and does not compensate for the risk.";
      if (totalPick) {
        totalLine =
          totalState === "positive"
            ? language === "ru"
              ? `Линия недооценивает вероятность ${totalPick}.`
              : `The line underrates the probability of ${totalPick}.`
            : language === "ru"
              ? "По тоталу выраженного преимущества в линии нет. Цена соответствует базовому сценарию."
              : "There is no strong edge on totals. The price matches the baseline scenario.";
      }
      rec =
        totalState === "positive"
          ? language === "ru"
            ? `Рекомендация: по исходу пропустить. По тоталу — ${totalPick}.`
            : `Recommendation: skip the outcome market. On totals, ${totalPick}.`
          : language === "ru"
            ? "Рекомендация: пропустить матч. Value по основным рынкам отсутствует."
            : "Recommendation: skip the match. There is no value on the main markets.";
    }

    return { keyLine, context, totalLine, rec, tone, state, sideLabel, totalPick, totalState, totalTier, resultTone };
  })();

  return (
    <div className="w-full min-w-0 overflow-x-hidden px-1 py-5 pb-24 mc-fade sm:px-4 sm:py-8">
      <div className="w-full max-w-[1240px] mx-auto space-y-8">
      <div className="flex items-center">
        <div className="flex flex-wrap items-center gap-2 sm:gap-3">
          <button
            type="button"
            onClick={() => {
              if (window.history.length > 1) {
                navigate(-1);
              } else {
                navigate(
                  `/schedule?league=${encodeURIComponent(league || "")}&season=${encodeURIComponent(season || "")}`
                );
              }
            }}
            className="surface-button"
          >
            ← {mc.back}
          </button>
          <button
            type="button"
            onClick={toggleFavoriteMatch}
            className={clsx(
              "surface-button",
              isFavoriteMatch
                ? "surface-button-active"
                : null
            )}
          >
            {isFavoriteMatch ? `★ ${t("matchSaved")}` : `☆ ${t("saveMatch")}`}
          </button>
        </div>
      </div>
      {/* Header */}
      <section className="text-slate-50">
        <div className="surface-hero min-w-0 overflow-hidden p-4 sm:p-6 md:p-8">
          <div className="text-[11px] uppercase tracking-[0.18em] text-white/55 mb-3">
            {league} / {season}
            {match?.round ? ` / ${match.round}` : ""}
          </div>

            <div className="mx-auto mt-5 grid w-full min-w-0 grid-cols-[minmax(0,1fr)_88px_minmax(0,1fr)] items-center justify-center gap-2 sm:mt-6 sm:grid-cols-[180px_150px_180px] sm:gap-4 lg:grid-cols-[220px_180px_220px] lg:gap-5">
              <div className="min-w-0 justify-self-stretch flex flex-col items-center gap-1.5 sm:w-[180px] sm:justify-self-end sm:gap-2 lg:w-[220px]">
                <TeamLogoLink teamId={match?.home_team_id} className="block">
                  <SafeImg
                    src={teamLogo(match?.home_team, match?.home_team_id)}
                    fallbackSrc={teamLogoFallback(match?.home_team_id)}
                    className="h-10 w-10 translate-y-[2px] rounded-2xl border border-glass bg-surface-2/80 object-contain drop-shadow-[0_2px_6px_rgba(0,0,0,0.4)] transition-transform duration-200 hover:scale-[1.03] sm:h-16 sm:w-16 lg:h-[80px] lg:w-[80px]"
                  />
                </TeamLogoLink>
                <div className="w-full min-w-0 truncate px-0.5 text-center text-[11px] font-medium tracking-[0.02em] text-white/95 sm:w-[140px] sm:px-1 sm:text-[16px] lg:w-[160px] lg:text-[18px]">
                  {match?.home_team || "—"}
                </div>
              </div>

            <div className="flex items-center justify-center">
              <div className="whitespace-nowrap text-center text-[30px] font-medium leading-none tracking-[0.03em] tabular-nums drop-shadow-[0_0_24px_rgba(140,110,255,0.22)] sm:text-[54px] lg:text-[68px]">
                <span className={clsx(homeWin ? "text-white/95" : awayWin ? "text-white/60" : "text-white/95")}>
                  {homeGoals ?? "—"}
                </span>
                <span className="mx-1 text-white/70 sm:mx-2">–</span>
                <span className={clsx(awayWin ? "text-white/95" : homeWin ? "text-white/60" : "text-white/95")}>
                  {awayGoals ?? "—"}
                </span>
              </div>
            </div>

            <div className="min-w-0 justify-self-stretch flex flex-col items-center gap-1.5 sm:w-[180px] sm:justify-self-start sm:gap-2 lg:w-[220px]">
                <TeamLogoLink teamId={match?.away_team_id} className="block">
                  <SafeImg
                    src={teamLogo(match?.away_team, match?.away_team_id)}
                    fallbackSrc={teamLogoFallback(match?.away_team_id)}
                    className="h-10 w-10 translate-y-[2px] rounded-2xl border border-glass bg-surface-2/80 object-contain drop-shadow-[0_2px_6px_rgba(0,0,0,0.4)] transition-transform duration-200 hover:scale-[1.03] sm:h-16 sm:w-16 lg:h-[80px] lg:w-[80px]"
                  />
                </TeamLogoLink>
              <div className="w-full min-w-0 truncate px-0.5 text-center text-[11px] font-medium tracking-[0.02em] text-white/95 sm:w-[140px] sm:px-1 sm:text-[16px] lg:w-[160px] lg:text-[18px]">
                {match?.away_team || "—"}
              </div>
            </div>
          </div>

          <div className="mt-2 text-center">
            <div
              className={clsx(
                "text-[12px] leading-tight",
                matchLive ? "text-rose-200" : "text-white/55"
              )}
            >
              {dt.date}
              {dt.time ? ` • ${dt.time}` : ""}
              {statusText ? " • " : ""}
              {statusText}
            </div>
            {match?.venue ? (
              <div className="text-[11px] leading-tight text-white/45 mt-1">
                {match.venue}
              </div>
            ) : null}
          </div>

        </div>
      </section>

      <div className="w-full pt-8">
        <SegmentedTabs
          className="w-full mb-8"
          size="md"
          items={[
            { key: "overview", label: mc.overview },
            { key: "stats", label: mc.stats },
            { key: "lineups", label: mc.lineups },
            { key: "form", label: mc.form },
          ]}
          value={tab}
          onChange={setTab}
          listClassName="gap-x-3 gap-y-2 sm:gap-8"
          buttonClassName="tracking-[0.03em] sm:tracking-[0.1em]"
          activeClassName="text-white"
          inactiveClassName="text-white/55"
        />
      </div>

      {loading && (
        <div className="text-sm text-slate-400">{mc.loadingMatch}</div>
      )}
      {error && (
        <div className="text-sm text-rose-400">{mc.loadError}: {error}</div>
      )}

      {!loading && !error && match && (
        <>
          {tab === "overview" && (
            <div className={MATCH_TAB_STACK}>
              <div className="w-full min-w-0 overflow-hidden rounded-2xl bg-gradient-to-br from-[#141824] to-[#0f1320] border border-white/5 p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.06),_0_12px_35px_rgba(0,0,0,0.35)] space-y-6 sm:p-8">
                <div className="flex min-w-0 items-start justify-between gap-4">
                  <div className="min-w-0 break-words text-[17px] font-semibold tracking-[0.03em] text-white sm:text-[18px] sm:tracking-[0.04em]">{mc.analyticsTitle}</div>
                </div>

                {analyticsPending ? (
                  <div className="text-[13px] text-white/60">
                    {mc.analyticsLoading}
                  </div>
                ) : (
                  <>
                    <div className="grid w-full min-w-0 gap-6 md:grid-cols-[1fr]">
                      <div className="relative min-w-0 pl-4 sm:pl-5">
                        <div
                          className={clsx(
                            "absolute left-0 top-1 bottom-1 w-[3px] rounded-full",
                            analysisNarrative?.resultTone === "green"
                              ? "bg-violet-400/80 shadow-[0_0_12px_rgba(139,92,246,0.3)]"
                              : analysisNarrative?.resultTone === "red"
                              ? "bg-violet-300/70 shadow-[0_0_10px_rgba(139,92,246,0.22)]"
                              : "bg-white/30 shadow-[0_0_10px_rgba(255,255,255,0.08)]"
                          )}
                        />
                        <div className="w-full min-w-0">
                          <div className="mb-4 break-words text-[18px] font-semibold leading-snug text-white sm:text-[20px]">
                            {analysisNarrative?.keyLine || mc.noEdge}
                          </div>
                          <div className="text-[12px] uppercase tracking-[0.12em] text-white/60 mb-2">
                            {mc.byOutcome}
                          </div>
                          <div className="mb-4 break-words text-[14px] leading-relaxed text-white/75">
                            {analysisNarrative?.context || mc.noOutcomeEdge}
                          </div>
                          <div className="text-[12px] uppercase tracking-[0.12em] text-white/60 mb-2">
                            {mc.byTotal}
                          </div>
                          <div className="mb-4 break-words text-[14px] leading-relaxed text-white/75">
                            {analysisNarrative?.totalLine || mc.noTotalEdge}
                          </div>
                          <div className="break-words text-[14px] font-medium text-white/90 sm:text-[15px]">
                            {analysisNarrative?.rec || mc.skipBet}
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* narrative folded into the key block */}

                    <div className="min-w-0 overflow-hidden rounded-xl border border-white/10 bg-white/4 p-4">
                      <SegmentedTabs
                        className="mb-3 min-w-0 overflow-hidden"
                        size="xs"
                        items={[
                          { key: "outcome", label: mc.outcome12 },
                          { key: "total", label: mc.total25 },
                        ]}
                        value={marketTab}
                        onChange={setMarketTab}
                        listClassName="min-w-0 gap-3 sm:gap-4"
                        buttonClassName="min-w-0 max-w-full truncate"
                        activeClassName="text-white"
                        inactiveClassName="text-white/50"
                      />

                      {marketTab === "outcome" && (
                        <div className="min-w-0 text-[12px] text-white/80">
                          {modelVsMarket.map((row, idx) => {
                            const modelPct = row.model != null ? row.model * 100 : null;
                            const bookPct = implied(row.odds);
                            const diff =
                              modelPct != null && bookPct != null
                                ? modelPct - bookPct
                                : null;
                            const diffLabel =
                              diff == null ? "—" : `${diff > 0 ? "+" : ""}${Math.round(diff)}%`;
                            return (
                              <div key={row.label} className={clsx("py-3", idx > 0 && "border-t border-white/10")}>
                                <div className="mb-2 flex min-w-0 items-center justify-between gap-3">
                                  <div className="flex min-w-0 items-center gap-3">
                                    <span className="truncate text-white/85">{row.label}</span>
                                  </div>
                                  <span className={clsx("shrink-0 text-[12px] font-semibold tabular-nums", diff != null && diff > 0 ? "text-emerald-300" : "text-white/70")}>
                                    {diffLabel}
                                  </span>
                                </div>
                                <div className="space-y-2">
                                  <div>
                                    <div className="mb-1 flex items-center justify-between gap-3 text-[11px] text-white/70">
                                      <span className="truncate">{mc.model}</span>
                                      <span className="shrink-0 tabular-nums font-semibold">{modelPct != null ? `${Math.round(modelPct)}%` : "—"}</span>
                                    </div>
                                    <div className="h-[5px] rounded-full bg-white/6 overflow-hidden">
                                      <div
                                        className="h-full rounded-full bg-gradient-to-r from-violet-500/70 to-violet-400/35"
                                        style={{ width: `${modelPct ?? 0}%` }}
                                      />
                                    </div>
                                  </div>
                                  <div>
                                    <div className="mb-1 flex items-center justify-between gap-3 text-[11px] text-white/70">
                                      <span className="truncate">{mc.market}</span>
                                      <span className="shrink-0 tabular-nums font-semibold">{bookPct != null ? `${Math.round(bookPct)}%` : "—"}</span>
                                    </div>
                                    <div className="h-[5px] rounded-full bg-white/6 overflow-hidden">
                                      <div
                                        className="h-full rounded-full bg-white/25 shadow-[0_0_10px_rgba(255,255,255,0.08)]"
                                        style={{ width: `${bookPct ?? 0}%` }}
                                      />
                                    </div>
                                  </div>
                                </div>
                              </div>
                            );
                          })}
                        </div>
                      )}

                      {marketTab === "total" && (
                        (match?.avg_odds_over25 || match?.avg_odds_under25) ? (
                          <div className="min-w-0 text-[12px] text-white/80">
                            {[
                              { label: language === "ru" ? "ТБ" : "Over", model: over25, odds: match?.avg_odds_over25 },
                              { label: language === "ru" ? "ТМ" : "Under", model: under25, odds: match?.avg_odds_under25 },
                            ].map((row, idx) => {
                              const modelPct = row.model != null ? row.model * 100 : null;
                              const bookPct = implied(row.odds);
                              const diff =
                                modelPct != null && bookPct != null
                                  ? modelPct - bookPct
                                  : null;
                              const diffLabel =
                                diff == null ? "—" : `${diff > 0 ? "+" : ""}${Math.round(diff)}%`;
                              return (
                                <div key={`tot-${row.label}`} className={clsx("py-3", idx > 0 && "border-t border-white/10")}>
                                <div className="mb-2 flex min-w-0 items-center justify-between gap-3">
                                  <div className="flex min-w-0 items-center gap-3">
                                    <span className="truncate text-white/85">{row.label}</span>
                                  </div>
                                  <span className={clsx("shrink-0 text-[12px] font-semibold tabular-nums", diff != null && diff > 0 ? "text-emerald-300" : "text-white/70")}>
                                    {diffLabel}
                                  </span>
                                </div>
                                <div className="space-y-2">
                                  <div>
                                    <div className="mb-1 flex items-center justify-between gap-3 text-[11px] text-white/70">
                                      <span className="truncate">{mc.model}</span>
                                      <span className="shrink-0 tabular-nums font-semibold">{modelPct != null ? `${Math.round(modelPct)}%` : "—"}</span>
                                    </div>
                                    <div className="h-[5px] rounded-full bg-white/6 overflow-hidden">
                                      <div
                                        className="h-full rounded-full bg-gradient-to-r from-violet-500/70 to-violet-400/35"
                                        style={{ width: `${modelPct ?? 0}%` }}
                                      />
                                    </div>
                                  </div>
                                  <div>
                                    <div className="mb-1 flex items-center justify-between gap-3 text-[11px] text-white/70">
                                      <span className="truncate">{mc.market}</span>
                                      <span className="shrink-0 tabular-nums font-semibold">{bookPct != null ? `${Math.round(bookPct)}%` : "—"}</span>
                                    </div>
                                    <div className="h-[5px] rounded-full bg-white/6 overflow-hidden">
                                      <div
                                        className="h-full rounded-full bg-white/25 shadow-[0_0_10px_rgba(255,255,255,0.08)]"
                                        style={{ width: `${bookPct ?? 0}%` }}
                                      />
                                    </div>
                                  </div>
                                  </div>
                                </div>
                              );
                            })}
                          </div>
                        ) : (
                          <div className="text-[12px] text-white/50">
                            {mc.noTotalMarketData}
                          </div>
                        )
                      )}

                      <div className="pt-2 text-[11px] text-white/55">
                        {mc.positiveGapHint}
                      </div>
                    </div>

                    {/* expanded info removed in favor of narrative */}
                  </>
                )}
              </div>

              <div className="w-full min-w-0 overflow-hidden space-y-4 rounded-2xl border border-white/5 bg-gradient-to-br from-[#121827] via-[#101624] to-[#0b111e] p-4 shadow-[0_16px_45px_rgba(8,12,22,0.6)] sm:p-5">
                <div className="min-w-0">
                  <div className="break-words text-[16px] font-semibold text-white">{mc.teamComparison}</div>
                  <div className="mt-1 break-words text-[12px] text-white/55">
                    {mc.preMatchAvg}
                  </div>
                </div>

                {Number.isFinite(Number(match?.home_understat_xg)) || Number.isFinite(Number(match?.away_understat_xg)) ? (
                  <MiniCompareRow
                    label={mc.matchXg}
                    left={match?.home_understat_xg}
                    right={match?.away_understat_xg}
                    format={(v) => Number(v).toFixed(2)}
                  />
                ) : null}
                <MiniCompareRow label={mc.formXg} left={pack?.homeAvg?.xg} right={pack?.awayAvg?.xg} format={(v) => Number(v).toFixed(2)} />
                <MiniCompareRow label="xGA" left={pack?.homeAvg?.xga} right={pack?.awayAvg?.xga} format={(v) => Number(v).toFixed(2)} />
                <MiniCompareRow label="ΔxG" left={pack?.homeAvg?.xg_diff} right={pack?.awayAvg?.xg_diff} format={(v) => Number(v).toFixed(2)} />
                <MiniCompareRow label={mc.shots} left={pack?.homeAvg?.shots} right={pack?.awayAvg?.shots} format={(v) => Number(v).toFixed(1)} />
                <MiniCompareRow label={mc.shotsOn} left={pack?.homeAvg?.shots_on} right={pack?.awayAvg?.shots_on} format={(v) => Number(v).toFixed(1)} />
                <MiniCompareRow label={mc.possession} left={pack?.homeAvg?.possession} right={pack?.awayAvg?.possession} format={(v) => `${Number(v).toFixed(0)}%`} />
                <MiniCompareRow label={mc.corners} left={pack?.homeAvg?.corners} right={pack?.awayAvg?.corners} format={(v) => Number(v).toFixed(1)} />

                {(Array.isArray(match?.understat_top_players_home) && match.understat_top_players_home.length > 0) ||
                (Array.isArray(match?.understat_top_players_away) && match.understat_top_players_away.length > 0) ? (
                  <div className="pt-2 border-t border-white/10">
                    <div className="text-[12px] text-white/55 mb-2">{mc.playerXg}</div>
                    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                      <div>
                        <div className="text-[12px] text-white/75 mb-1">{match?.home_team || mc.homeFallback}</div>
                        <div className="space-y-1">
                          {(match?.understat_top_players_home || []).slice(0, 4).map((p) => (
                            <div key={`uh-${p.player_id}-${p.player_name}`} className="flex items-center justify-between text-[12px] text-white/80">
                              <span className="truncate pr-2">{p.player_name}</span>
                              <span className="tabular-nums text-violet-300">{Number(p.xg || 0).toFixed(2)} xG</span>
                            </div>
                          ))}
                        </div>
                      </div>
                      <div>
                        <div className="text-[12px] text-white/75 mb-1">{match?.away_team || mc.awayFallback}</div>
                        <div className="space-y-1">
                          {(match?.understat_top_players_away || []).slice(0, 4).map((p) => (
                            <div key={`ua-${p.player_id}-${p.player_name}`} className="flex items-center justify-between text-[12px] text-white/80">
                              <span className="truncate pr-2">{p.player_name}</span>
                              <span className="tabular-nums text-sky-300">{Number(p.xg || 0).toFixed(2)} xG</span>
                            </div>
                          ))}
                        </div>
                      </div>
                    </div>
                  </div>
                ) : null}

                {Array.isArray(match?.understat_shots) && match.understat_shots.length > 0 ? (
                  <div className="pt-2 border-t border-white/10">
                    <UnderstatShotHeatmap
                      shots={match.understat_shots}
                      homeTeam={match?.home_team || mc.homeFallback}
                      awayTeam={match?.away_team || mc.awayFallback}
                    />
                  </div>
                ) : null}
              </div>

            </div>
          )}

          {tab === "stats" && (
            <div className={MATCH_TAB_WRAP}>
              {!matchPlayed ? (
                <div className={`${MATCH_TAB_PANEL} text-sm text-white/60`}>
                  {matchLive
                    ? mc.liveStatsNote
                    : mc.noStatsYet}
                </div>
              ) : (
                <div className={MATCH_TAB_PANEL}>
                  <Suspense fallback={<div className="text-sm text-slate-400">{mc.loading}</div>}>
                    <MatchStatsBlockV3 stats={match} />
                  </Suspense>
                </div>
              )}
            </div>
          )}

          {tab === "lineups" && (
            <div className={MATCH_TAB_WRAP}>
              {lineupsError ? (
                <div className={`${MATCH_TAB_PANEL} text-sm text-white/60`}>
                  {lineupsError}
                </div>
              ) : lineupsLoading ? (
                <div className={`${MATCH_TAB_PANEL} text-sm text-white/60`}>
                  {mc.lineupsLoading}
                </div>
              ) : lineupsData ? (
                <div className="w-full">
                  <LineupsTab
                    data={lineupsData}
                    loading={lineupsLoading}
                    match={match}
                    onPlayer={(player) => {
                      const playerId = player?.player_id || player?.id;
                      if (!playerId) return;
                      navigate(`/player/${playerId}?league=${encodeURIComponent(league)}&season=${season}`);
                    }}
                  />
                </div>
              ) : (
                <div className={`${MATCH_TAB_PANEL} text-sm text-white/60`}>
                  {mc.lineupsUnavailable}
                </div>
              )}
            </div>
          )}

          {/* events tab removed; events shown in lineups */}

          {tab === "form" && (
            <div className={MATCH_TAB_STACK}>
              {packLoading && (
                <div className={`${MATCH_TAB_PANEL} text-sm text-slate-400`}>{mc.formLoading}</div>
              )}
              {!packLoading && (
                <div className={MATCH_TAB_PANEL}>
                  <MatchInsightsPanelFull
                    pack={pack}
                    home={match?.home_team}
                    away={match?.away_team}
                    variant="flat"
                    hideAvgs
                    onOpenMatchModal={(fixtureId) => {
                      const params = new URLSearchParams({ league, season, fixture_id: String(fixtureId) });
                      navigate(`/match/${fixtureId}?${params.toString()}`);
                    }}
                  />
                </div>
              )}
            </div>
          )}

        </>
      )}
      </div>
    </div>
  );
}
