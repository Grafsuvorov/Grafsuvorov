// src/pages/MatchCenterPage.jsx
import React, { useEffect, useState, useMemo, lazy, Suspense } from "react";
import { useNavigate, useParams, useSearchParams } from "react-router-dom";
import clsx from "clsx";

import MatchCenterHero from "@/components/match/MatchCenterHero";
import MatchFormSection from "@/components/match/MatchFormSection";
import MatchLineupsSection from "@/components/match/MatchLineupsSection";
import MatchOverviewAnalytics from "@/components/match/MatchOverviewAnalytics";
import MatchTeamComparison from "@/components/match/MatchTeamComparison";
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
  const statusToneClass = matchLive
    ? "border-rose-400/24 bg-rose-400/10 text-rose-100"
    : matchFinished
    ? "border-emerald-400/24 bg-emerald-400/10 text-emerald-100"
    : "border-white/10 bg-white/[0.05] text-white/78";
  const headerMeta = [
    dt.date || null,
    dt.time || null,
    statusText || null,
  ].filter(Boolean);

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

  const matchPlayed = homeGoals != null && awayGoals != null;

  const hasModelData =
    [p1, px, p2, over25, under25, edge, value].some((v) =>
      Number.isFinite(v)
    ) || signalPick != null;
  const analyticsPending = !hasModelData && insightLoading && !insight;

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
        <MatchCenterHero
          league={league}
          season={season}
          match={match}
          matchLive={matchLive}
          statusText={statusText}
          statusToneClass={statusToneClass}
          homeGoals={homeGoals}
          awayGoals={awayGoals}
          homeWin={homeWin}
          awayWin={awayWin}
          headerMeta={headerMeta}
          isFavoriteMatch={isFavoriteMatch}
          labels={{
            back: mc.back,
            save: t("saveMatch"),
            saved: t("matchSaved"),
          }}
          onBack={() => {
            if (window.history.length > 1) {
              navigate(-1);
            } else {
              navigate(
                `/schedule?league=${encodeURIComponent(league || "")}&season=${encodeURIComponent(season || "")}`
              );
            }
          }}
          onToggleFavorite={toggleFavoriteMatch}
          teamLogo={teamLogo}
          teamLogoFallback={teamLogoFallback}
        />

      <div className="w-full pt-8">
        <SegmentedTabs
          className="surface-toolbar w-full mb-8 px-3 py-2 sm:px-4"
          size="md"
          items={[
            { key: "overview", label: mc.overview },
            { key: "stats", label: mc.stats },
            { key: "lineups", label: mc.lineups },
            { key: "form", label: mc.form },
          ]}
          value={tab}
          onChange={setTab}
          listClassName="gap-x-2 gap-y-2 sm:gap-8"
          buttonClassName="text-[12px] tracking-[0.02em] sm:text-[14px] sm:tracking-[0.1em]"
          activeClassName="text-white"
          inactiveClassName="text-white/55"
        />
      </div>

      {loading && (
        <div className="surface-loading">{mc.loadingMatch}</div>
      )}
      {error && (
        <div className="surface-error text-sm">{mc.loadError}: {error}</div>
      )}

      {!loading && !error && match && (
        <>
          {tab === "overview" && (
            <div className={MATCH_TAB_STACK}>
              <MatchOverviewAnalytics
                title={mc.analyticsTitle}
                analyticsPending={analyticsPending}
                analyticsLoadingLabel={mc.analyticsLoading}
                keyLine={analysisNarrative?.keyLine || mc.noEdge}
                outcomeLabel={mc.byOutcome}
                outcomeText={analysisNarrative?.context || mc.noOutcomeEdge}
                totalLabel={mc.byTotal}
                totalText={analysisNarrative?.totalLine || mc.noTotalEdge}
                recommendation={analysisNarrative?.rec || mc.skipBet}
                marketTab={marketTab}
                onMarketTabChange={setMarketTab}
                outcomeTabLabel={mc.outcome12}
                totalTabLabel={mc.total25}
                modelVsMarket={modelVsMarket}
                implied={implied}
                modelLabel={mc.model}
                marketLabel={mc.market}
                totalMarketRows={
                  match?.avg_odds_over25 || match?.avg_odds_under25
                    ? [
                        { label: language === "ru" ? "ТБ" : "Over", model: over25, odds: match?.avg_odds_over25 },
                        { label: language === "ru" ? "ТМ" : "Under", model: under25, odds: match?.avg_odds_under25 },
                      ]
                    : []
                }
                noTotalMarketData={mc.noTotalMarketData}
                positiveGapHint={mc.positiveGapHint}
              />

              <MatchTeamComparison
                title={mc.teamComparison}
                subtitle={mc.preMatchAvg}
                match={match}
                labels={{
                  matchXg: mc.matchXg,
                  formXg: mc.formXg,
                  shots: mc.shots,
                  shotsOn: mc.shotsOn,
                  possession: mc.possession,
                  corners: mc.corners,
                  playerXg: mc.playerXg,
                  homeFallback: mc.homeFallback,
                  awayFallback: mc.awayFallback,
                }}
                pack={pack}
                MiniCompareRow={MiniCompareRow}
              />

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
            <MatchLineupsSection
              wrapClassName={MATCH_TAB_WRAP}
              panelClassName={MATCH_TAB_PANEL}
              error={lineupsError}
              loading={lineupsLoading}
              loadingLabel={mc.lineupsLoading}
              lineupsData={lineupsData}
              match={match}
              emptyLabel={mc.lineupsUnavailable}
              onPlayerOpen={(player) => {
                const playerId = player?.player_id || player?.id;
                if (!playerId) return;
                navigate(`/player/${playerId}?league=${encodeURIComponent(league)}&season=${season}`);
              }}
            />
          )}

          {/* events tab removed; events shown in lineups */}

          {tab === "form" && (
            <MatchFormSection
              wrapClassName={MATCH_TAB_STACK}
              panelClassName={MATCH_TAB_PANEL}
              loading={packLoading}
              loadingLabel={mc.formLoading}
              pack={pack}
              homeTeam={match?.home_team}
              awayTeam={match?.away_team}
              onOpenMatchModal={(fixtureId) => {
                const params = new URLSearchParams({ league, season, fixture_id: String(fixtureId) });
                navigate(`/match/${fixtureId}?${params.toString()}`);
              }}
            />
          )}

        </>
      )}
      </div>
    </div>
  );
}
