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
import SegmentedTabs from "@/components/ui/SegmentedTabs";
 

const MatchStatsBlockV3 = lazy(() =>
  import("@/components/MatchStatsBlockV3")
);

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
const MATCH_TAB_PANEL = "panel w-full p-6";

const lineupsCache = new Map();
const lineupsInFlight = new Map();
const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

async function loadLineupsCached(fixtureId, signal) {
  if (!fixtureId) return { data: null, error: "no_id" };
  if (lineupsCache.has(fixtureId)) return lineupsCache.get(fixtureId);
  if (lineupsInFlight.has(fixtureId)) return lineupsInFlight.get(fixtureId);

  const endpoints = [
    `${API_BASE}/api/lineups-events?fixture_id=${fixtureId}`,
    `${API_BASE}/api/match/lineups-events?fixture_id=${fixtureId}`,
  ];

  const promise = (async () => {
    try {
      for (let i = 0; i < endpoints.length; i += 1) {
        try {
          const data = await fetchJsonSafe(endpoints[i], signal);
          if (data && (Array.isArray(data.lineups) || Array.isArray(data.events))) {
            const res = { data, error: null };
            lineupsCache.set(fixtureId, res);
            return res;
          }
        } catch (e) {
          if (e?.name === "AbortError" || String(e?.message || "").includes("aborted")) {
            throw e;
          }
          if (String(e?.message || "").includes("HTTP 404")) {
            if (i === endpoints.length - 1) {
              return { data: null, error: "not_found", message: e?.message || "HTTP 404" };
            }
            continue;
          }
          if (i === endpoints.length - 1) {
            return { data: null, error: "failed", message: e?.message || "failed" };
          }
        }
      }
      return { data: null, error: "empty", message: "empty" };
    } finally {
      lineupsInFlight.delete(fixtureId);
    }
  })();

  lineupsInFlight.set(fixtureId, promise);
  return promise;
}

function MiniCompareRow({ label, left, right, format }) {
  const l = Number.isFinite(Number(left)) ? Number(left) : null;
  const r = Number.isFinite(Number(right)) ? Number(right) : null;
  if (l == null && r == null) return null;
  const max = Math.max(Math.abs(l || 0), Math.abs(r || 0), 1);
  const lPct = l != null ? (Math.abs(l) / max) * 50 : 0;
  const rPct = r != null ? (Math.abs(r) / max) * 50 : 0;
  const fmt = (v) => (v == null ? "—" : format ? format(v) : v);

  return (
    <div className="space-y-2">
        <div className="grid grid-cols-[1fr_auto_1fr] items-center">
          <div className="text-left text-[15px] font-semibold text-white/90 tabular-nums">
            {fmt(l)}
          </div>
        <div className="px-3 text-[11px] font-semibold text-white/85 text-center uppercase tracking-[0.16em]">
          {label}
        </div>
          <div className="text-right text-[15px] font-semibold text-white/90 tabular-nums">
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

async function fetchJsonSafe(url, signal) {
  const r = await authFetch(url, { signal });
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

const isStaleLiveStatus = (match) => {
  const kickoffRaw = match?.kickoff_at;
  if (!kickoffRaw) return false;
  const kickoff = new Date(String(kickoffRaw).replace(" ", "T"));
  if (Number.isNaN(kickoff.getTime())) return false;

  const status = String(match?.status_short || match?.status_text || match?.status || "").trim().toUpperCase();
  const elapsed = Number(match?.elapsed);
  const diffMinutes = Math.floor((Date.now() - kickoff.getTime()) / 60000);
  if (!Number.isFinite(diffMinutes) || diffMinutes <= 0) return false;

  if (status === "1H" || status.includes("FIRST HALF")) {
    return diffMinutes > 65 || (Number.isFinite(elapsed) && elapsed <= 45 && diffMinutes > 60);
  }
  if (status === "HT" || status === "HALF TIME" || status === "HALFTIME" || status.includes("BREAK TIME")) {
    return diffMinutes > 80;
  }
  if (status === "2H" || status.includes("SECOND HALF")) {
    return diffMinutes > 125;
  }
  if (status === "ET" || status.includes("EXTRA TIME") || status === "PEN" || status.includes("PENALTY")) {
    return diffMinutes > 170;
  }
  return diffMinutes > 140;
};

const liveMinuteStatus = (match) => {
  const statusRaw = String(match?.status_short || match?.status_text || match?.status || "").trim().toUpperCase();
  const elapsed = Number(match?.elapsed);
  const extra = Number(match?.extra);
  const isHalfTime =
    statusRaw === "HT" ||
    statusRaw === "HALF TIME" ||
    statusRaw === "HALFTIME" ||
    statusRaw.includes("BREAK TIME");

  if (Number.isFinite(elapsed) && elapsed > 0) {
    const minute = minuteStr(elapsed, extra);
    return isHalfTime ? `Live • ${minute} • перерыв` : `Live • ${minute}`;
  }
  if (isHalfTime) return "Live • перерыв";
  if (statusRaw.includes("PEN")) return "Live • серия пенальти";
  return "Live";
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
              <span className="truncate max-w-[140px]">{name}</span>
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
        setError(e?.message || "Ошибка загрузки");
      })
      .finally(() => setLoading(false));
    return () => ac.abort();
  }, [matchId, league, season]);

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

  useEffect(() => {
    if (!match?.fixture_id) return;
    setLineupsData(null);
    setLineupsError("");
    setLineupsLoading(false);
  }, [match?.fixture_id]);

  useEffect(() => {
    if (!match?.fixture_id) return;
    if (tab !== "lineups") return;
    if (lineupsLoading) return;
    const ac = new AbortController();
    setLineupsLoading(true);
    setLineupsError("");
    loadLineupsCached(match.fixture_id, ac.signal)
      .then((res) => {
        if (res?.data) setLineupsData(res.data);
        else if (res?.error === "not_found")
          setLineupsError("Данные составов и событий недоступны");
        else if (res?.error)
          setLineupsError(`Не удалось загрузить составы (${res?.message || res?.error})`);
      })
      .catch((e) => {
        if (e?.name === "AbortError") return;
        setLineupsError(`Не удалось загрузить составы (${e?.message || "error"})`);
      })
      .finally(() => setLineupsLoading(false));
    return () => ac.abort();
  }, [match?.fixture_id, tab]);


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
  const statusText = matchLive
    ? liveMinuteStatus(match)
    : matchFinished
    ? "Закончен"
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

  const outcomeSignal =
    recDecision === "BET"
      ? "Играть"
      : recDecision === "WATCH"
      ? "Аккуратно"
      : "Пропуск";
  const outcomeLabel = outcomeSignal === "Пропуск" ? "Сигнала нет" : outcomeSignal;

  const thresholdReason =
    outcomeSignal === "Играть"
      ? "Модель видит заметное преимущество — сигнал проходит фильтр."
      : outcomeSignal === "Аккуратно"
      ? "Преимущество есть, но запас умеренный — стоит быть осторожнее."
      : "Рынок почти совпадает с оценкой модели — выраженного value не обнаружено.";

  const signalTone =
    outcomeSignal === "Играть"
      ? "emerald"
      : outcomeSignal === "Аккуратно"
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
      let picture = "Картина матча выглядит сбалансированной.";
      if (xgDiff != null && shotsDiff != null) {
        if (xgDiff > 0.15 && shotsDiff > 1) {
          picture = `${home} контролирует темп и создаёт больше качественных моментов.`;
        } else if (xgDiff < -0.15 && shotsDiff < -1) {
          picture = `${away} контролирует темп и создаёт больше качественных моментов.`;
        } else if (xgDiff > 0.15 && shotsDiff <= 1) {
          picture = `${home} создаёт более качественные моменты при сопоставимом объёме ударов.`;
        } else if (xgDiff < -0.15 && shotsDiff >= -1) {
          picture = `${away} создаёт более качественные моменты при сопоставимом объёме ударов.`;
        }
      } else if (xgDiff != null) {
        picture = xgDiff > 0.15 ? `${home} выглядит предпочтительнее по качеству моментов.` : xgDiff < -0.15 ? `${away} выглядит предпочтительнее по качеству моментов.` : picture;
      }
      if (possDiff != null && Math.abs(possDiff) >= 6) {
        picture += ` По контролю мяча преимущество у ${possDiff > 0 ? home : away}.`;
      }
      lines.push(picture);
    }

    if (xgDiff != null && shotsDiff != null) {
      if (Math.abs(xgDiff) < 0.15 && Math.abs(shotsDiff) < 1) {
        lines.push("Контекст формы: команды создают схожий объём моментов, сценарий чувствителен к реализации.");
      } else if (Math.abs(shotsDiff) >= 3 && Math.abs(xgDiff) < 0.2) {
        lines.push("Контекст формы: объём атак различается, но качество моментов близко — возможен разброс по реализации.");
      }
    }

    lines.push("Риск сценария: высокая вариативность реализации может изменить итог при равном объёме моментов.");
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
    { label: "П1", model: p1, odds: oddsHome },
    { label: "Х", model: px, odds: oddsDraw },
    { label: "П2", model: p2, odds: oddsAway },
  ];

  const savedBetOutcome = String(match?.best_bet_outcome || "").trim();
  const savedBetType = String(match?.best_bet_type || "").trim().toUpperCase();
  const savedBetRating = String(match?.bet_rating || "").trim().toLowerCase();
  const savedOutcomePick =
    savedBetOutcome === "Home"
      ? { id: "home", label: "П1", name: "Home", team: match?.home_team || "Хозяева", p: p1, odds: oddsHome, ev: match?.best_bet_ev }
      : savedBetOutcome === "Draw"
        ? { id: "draw", label: "Х", name: "Draw", team: "ничья", p: px, odds: oddsDraw, ev: match?.best_bet_ev }
        : savedBetOutcome === "Away"
          ? { id: "away", label: "П2", name: "Away", team: match?.away_team || "Гости", p: p2, odds: oddsAway, ev: match?.best_bet_ev }
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
      ? "ТБ 2.5"
      : savedBetOutcome === "Under2.5"
        ? "ТМ 2.5"
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
    const home = match?.home_team || "Хозяева";
    const away = match?.away_team || "Гости";
    const leagueId = Number(match?.league_id) || LEAGUE_ID_BY_NAME[league] || null;
    const outcomeCandidates = [
      { id: "home", label: "П1", name: "Home", team: home, p: p1, odds: oddsHome },
      { id: "draw", label: "Х", name: "Draw", team: "ничья", p: px, odds: oddsDraw },
      { id: "away", label: "П2", name: "Away", team: away, p: p2, odds: oddsAway },
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
        ? pickOver ? "ТБ 2.5" : "ТМ 2.5"
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

    const sideLabel = bestOutcome?.label ? `по ${bestOutcome.label}` : "";
    const keyLine =
      state === "strong"
        ? `Линия даёт выраженное преимущество ${sideLabel}.`
        : state === "moderate"
          ? `Баланс вероятностей смещён, но линия даёт лишь умеренное преимущество ${sideLabel}.`
          : state === "negative"
            ? `Баланс вероятностей смещён, но текущая линия ${sideLabel} не даёт преимущества.`
            : "Баланс вероятностей близок к нейтральному — преимущества в линии нет.";

    let context = "";
    let totalLine = "";
    let rec = "";

    if (state === "none") {
      context =
        "Линия по исходу нейтральна — дополнительного преимущества нет.";
      if (totalPick) {
        totalLine =
          totalState === "positive"
            ? `Линия недооценивает вероятность ${totalPick}.`
            : "Выраженного преимущества в линии нет. Цена соответствует базовому сценарию.";
      }
      rec =
        totalState === "positive"
          ? `Рекомендация: по исходу — без действия. По тоталу — ${totalPick}, есть value.`
          : "Рекомендация: по исходу — без действия. По тоталу — без преимущества.";
    } else if (state === "moderate") {
      context =
        "Один из исходов выглядит недооценённым рынком. Модель закладывает более высокую вероятность события, чем отражено в коэффициенте. При этом расхождение остаётся умеренным и чувствительным к изменению линии.";
      if (domTeam) {
        context += " По игровым показателям есть перевес, но сценарий допускает вариативность.";
      }
      if (totalPick) {
        totalLine =
          totalState === "positive"
            ? `Линия недооценивает вероятность ${totalPick}.`
            : "Сценарий умеренного темпа выглядит вероятным, однако преимущество в линии минимально.";
      }
      rec =
        totalState === "positive"
          ? `Рекомендация: рассмотреть аккуратно. По тоталу — ${totalPick}.`
          : "Рекомендация: рассмотреть аккуратно. Риск остаётся умеренным.";
    } else if (state === "strong") {
      context =
        "Модель фиксирует устойчивый перевес в ключевых метриках — качестве моментов, темпе и структуре атак. Текущая линия не полностью отражает этот баланс. Коэффициент обеспечивает положительное математическое ожидание.";
      if (domTeam) {
        context += " Сценарий матча соответствует оценке: структурное преимущество подтверждается статистикой.";
      }
      if (totalPick) {
        totalLine =
          totalState === "positive"
            ? `Линия недооценивает вероятность ${totalPick}.`
            : "По тоталу выраженного преимущества в линии нет.";
      }
      rec =
        totalState === "positive"
          ? `Рекомендация: ставка оправдана. По тоталу — ${totalPick}.`
          : "Рекомендация: ставка оправдана. Коэффициент даёт выраженное преимущество.";
    } else if (state === "negative") {
      context =
        "Текущий коэффициент отражает более высокий сценарий, чем оправдывает расчётная оценка матча. При данной цене перевес выглядит переоценённым.";
      context +=
        "Даже при статистическом преимуществе команды линия выглядит завышенной и не компенсирует риск.";
      if (totalPick) {
        totalLine =
          totalState === "positive"
            ? `Линия недооценивает вероятность ${totalPick}.`
            : "По тоталу выраженного преимущества в линии нет. Цена соответствует базовому сценарию.";
      }
      rec =
        totalState === "positive"
          ? `Рекомендация: по исходу пропустить. По тоталу — ${totalPick}.`
          : "Рекомендация: пропустить матч. Value по основным рынкам отсутствует.";
    }

    return { keyLine, context, totalLine, rec, tone, state, sideLabel, totalPick, totalState, totalTier, resultTone };
  })();

  return (
    <div className="w-full min-w-0 px-4 py-8 pb-24 mc-fade">
      <div className="w-full max-w-[1240px] mx-auto space-y-8">
      <div className="flex items-center">
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
          className="inline-flex h-10 items-center rounded-full border border-white/10 bg-white/[0.03] px-4 text-[13px] text-white/72 transition hover:bg-white/[0.05] hover:text-white/90"
        >
          ← Назад
        </button>
      </div>
      {/* Header */}
      <section className="text-slate-50">
        <div className="panel rounded-3xl p-6 md:p-8">
          <div className="text-[11px] uppercase tracking-[0.18em] text-white/55 mb-3">
            {league} / {season}
            {match?.round ? ` / ${match.round}` : ""}
          </div>

            <div className="mt-6 grid grid-cols-[220px_180px_220px] items-center justify-center gap-5 w-full mx-auto">
              <div className="w-[220px] justify-self-end flex flex-col items-center gap-2 min-w-0">
                <TeamLogoLink teamId={match?.home_team_id} className="block">
                  <SafeImg
                    src={teamLogo(match?.home_team, match?.home_team_id)}
                    fallbackSrc={teamLogoFallback(match?.home_team_id)}
                    className="h-[80px] w-[80px] translate-y-[2px] rounded-2xl border border-glass bg-surface-2/80 object-contain drop-shadow-[0_2px_6px_rgba(0,0,0,0.4)] transition-transform duration-200 hover:scale-[1.03]"
                  />
                </TeamLogoLink>
                <div className="w-[120px] text-[18px] font-medium tracking-[0.02em] truncate text-white/95 text-center">
                  {match?.home_team || "—"}
                </div>
              </div>

            <div className="flex items-center justify-center">
              <div className="text-[68px] font-medium tracking-[0.03em] drop-shadow-[0_0_24px_rgba(140,110,255,0.22)] leading-none text-center tabular-nums">
                <span className={clsx(homeWin ? "text-white/95" : awayWin ? "text-white/60" : "text-white/95")}>
                  {homeGoals ?? "—"}
                </span>
                <span className="text-white/70 mx-2">–</span>
                <span className={clsx(awayWin ? "text-white/95" : homeWin ? "text-white/60" : "text-white/95")}>
                  {awayGoals ?? "—"}
                </span>
              </div>
            </div>

            <div className="w-[220px] justify-self-start flex flex-col items-center gap-2 min-w-0">
                <TeamLogoLink teamId={match?.away_team_id} className="block">
                  <SafeImg
                    src={teamLogo(match?.away_team, match?.away_team_id)}
                    fallbackSrc={teamLogoFallback(match?.away_team_id)}
                    className="h-[80px] w-[80px] translate-y-[2px] rounded-2xl border border-glass bg-surface-2/80 object-contain drop-shadow-[0_2px_6px_rgba(0,0,0,0.4)] transition-transform duration-200 hover:scale-[1.03]"
                  />
                </TeamLogoLink>
              <div className="w-[120px] text-[18px] font-medium tracking-[0.02em] truncate text-white/95 text-center">
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
            { key: "overview", label: "Обзор" },
            { key: "stats", label: "Статистика" },
            { key: "lineups", label: "Составы" },
            { key: "form", label: "Форма" },
          ]}
          value={tab}
          onChange={setTab}
          listClassName="gap-8"
          buttonClassName="tracking-[0.1em]"
          activeClassName="text-white"
          inactiveClassName="text-white/55"
        />
      </div>

      {loading && (
        <div className="text-sm text-slate-400">Загружаем матч…</div>
      )}
      {error && (
        <div className="text-sm text-rose-400">Ошибка: {error}</div>
      )}

      {!loading && !error && match && (
        <>
          {tab === "overview" && (
            <div className={MATCH_TAB_STACK}>
              <div className="w-full rounded-2xl bg-gradient-to-br from-[#141824] to-[#0f1320] border border-white/5 shadow-[inset_0_1px_0_rgba(255,255,255,0.06),_0_12px_35px_rgba(0,0,0,0.35)] p-8 space-y-6">
                <div className="flex items-start justify-between gap-4">
                  <div className="text-[18px] font-semibold tracking-[0.04em] text-white">Аналитика матча</div>
                </div>

                {analyticsPending ? (
                  <div className="text-[13px] text-white/60">
                    Данные модели загружаются…
                  </div>
                ) : (
                  <>
                    <div className="grid md:grid-cols-[1fr] gap-6 w-full">
                      <div className="relative pl-5">
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
                        <div className="w-full">
                          <div className="text-[20px] font-semibold text-white leading-snug mb-4">
                            {analysisNarrative?.keyLine || "Выраженного преимущества в линии нет."}
                          </div>
                          <div className="text-[12px] uppercase tracking-[0.12em] text-white/60 mb-2">
                            По исходу
                          </div>
                          <div className="text-[14px] text-white/75 leading-relaxed mb-4">
                            {analysisNarrative?.context || "Линия по исходу не даёт явного преимущества."}
                          </div>
                          <div className="text-[12px] uppercase tracking-[0.12em] text-white/60 mb-2">
                            По тоталу
                          </div>
                          <div className="text-[14px] text-white/75 leading-relaxed mb-4">
                            {analysisNarrative?.totalLine || "По тоталу матч ближе к нейтральному сценарию — явного перекоса нет."}
                          </div>
                          <div className="text-[15px] font-medium text-white/90">
                            {analysisNarrative?.rec || "Рекомендация: пропустить ставку при текущей цене."}
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* narrative folded into the key block */}

                    <div className="rounded-xl bg-white/4 border border-white/10 p-4">
                      <SegmentedTabs
                        className="mb-3"
                        size="xs"
                        items={[
                          { key: "outcome", label: "Исход (1X2)" },
                          { key: "total", label: "Тотал 2.5" },
                        ]}
                        value={marketTab}
                        onChange={setMarketTab}
                        listClassName="gap-4"
                        activeClassName="text-white"
                        inactiveClassName="text-white/50"
                      />

                      {marketTab === "outcome" && (
                        <div className="text-[12px] text-white/80">
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
                                <div className="flex items-center justify-between mb-2">
                                  <div className="flex items-center gap-3">
                                    <span className="text-white/85">{row.label}</span>
                                  </div>
                                  <span className={clsx("text-[12px] font-semibold tabular-nums", diff != null && diff > 0 ? "text-emerald-300" : "text-white/70")}>
                                    {diffLabel}
                                  </span>
                                </div>
                                <div className="space-y-2">
                                  <div>
                                    <div className="flex items-center justify-between text-[11px] text-white/70 mb-1">
                                      <span>Модель</span>
                                      <span className="tabular-nums font-semibold">{modelPct != null ? `${Math.round(modelPct)}%` : "—"}</span>
                                    </div>
                                    <div className="h-[5px] rounded-full bg-white/6 overflow-hidden">
                                      <div
                                        className="h-full rounded-full bg-gradient-to-r from-violet-500/70 to-violet-400/35"
                                        style={{ width: `${modelPct ?? 0}%` }}
                                      />
                                    </div>
                                  </div>
                                  <div>
                                    <div className="flex items-center justify-between text-[11px] text-white/70 mb-1">
                                      <span>Рынок</span>
                                      <span className="tabular-nums font-semibold">{bookPct != null ? `${Math.round(bookPct)}%` : "—"}</span>
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
                          <div className="text-[12px] text-white/80">
                            {[
                              { label: "ТБ", model: over25, odds: match?.avg_odds_over25 },
                              { label: "ТМ", model: under25, odds: match?.avg_odds_under25 },
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
                                <div className="flex items-center justify-between mb-2">
                                  <div className="flex items-center gap-3">
                                    <span className="text-white/85">{row.label}</span>
                                  </div>
                                  <span className={clsx("text-[12px] font-semibold tabular-nums", diff != null && diff > 0 ? "text-emerald-300" : "text-white/70")}>
                                    {diffLabel}
                                  </span>
                                </div>
                                <div className="space-y-2">
                                  <div>
                                    <div className="flex items-center justify-between text-[11px] text-white/70 mb-1">
                                      <span>Модель</span>
                                      <span className="tabular-nums font-semibold">{modelPct != null ? `${Math.round(modelPct)}%` : "—"}</span>
                                    </div>
                                    <div className="h-[5px] rounded-full bg-white/6 overflow-hidden">
                                      <div
                                        className="h-full rounded-full bg-gradient-to-r from-violet-500/70 to-violet-400/35"
                                        style={{ width: `${modelPct ?? 0}%` }}
                                      />
                                    </div>
                                  </div>
                                  <div>
                                    <div className="flex items-center justify-between text-[11px] text-white/70 mb-1">
                                      <span>Рынок</span>
                                      <span className="tabular-nums font-semibold">{bookPct != null ? `${Math.round(bookPct)}%` : "—"}</span>
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
                            По тоталам нет рыночных данных для сравнения.
                          </div>
                        )
                      )}

                      <div className="pt-2 text-[11px] text-white/55">
                        Положительная разница может означать недооценку рынком.
                      </div>
                    </div>

                    {/* expanded info removed in favor of narrative */}
                  </>
                )}
              </div>

              <div className="w-full space-y-4 rounded-2xl bg-gradient-to-br from-[#121827] via-[#101624] to-[#0b111e] border border-white/5 p-5 shadow-[0_16px_45px_rgba(8,12,22,0.6)]">
                <div>
                  <div className="text-[16px] font-semibold text-white">Сравнение команд</div>
                  <div className="text-[12px] text-white/55 mt-1">
                    Последние 10 матчей · средние значения (до матча)
                  </div>
                </div>

                {Number.isFinite(Number(match?.home_understat_xg)) || Number.isFinite(Number(match?.away_understat_xg)) ? (
                  <MiniCompareRow
                    label="xG матча"
                    left={match?.home_understat_xg}
                    right={match?.away_understat_xg}
                    format={(v) => Number(v).toFixed(2)}
                  />
                ) : null}
                <MiniCompareRow label="xG форма" left={pack?.homeAvg?.xg} right={pack?.awayAvg?.xg} format={(v) => Number(v).toFixed(2)} />
                <MiniCompareRow label="xGA" left={pack?.homeAvg?.xga} right={pack?.awayAvg?.xga} format={(v) => Number(v).toFixed(2)} />
                <MiniCompareRow label="ΔxG" left={pack?.homeAvg?.xg_diff} right={pack?.awayAvg?.xg_diff} format={(v) => Number(v).toFixed(2)} />
                <MiniCompareRow label="Удары" left={pack?.homeAvg?.shots} right={pack?.awayAvg?.shots} format={(v) => Number(v).toFixed(1)} />
                <MiniCompareRow label="В створ" left={pack?.homeAvg?.shots_on} right={pack?.awayAvg?.shots_on} format={(v) => Number(v).toFixed(1)} />
                <MiniCompareRow label="Владение" left={pack?.homeAvg?.possession} right={pack?.awayAvg?.possession} format={(v) => `${Number(v).toFixed(0)}%`} />
                <MiniCompareRow label="Угловые" left={pack?.homeAvg?.corners} right={pack?.awayAvg?.corners} format={(v) => Number(v).toFixed(1)} />

                {(Array.isArray(match?.understat_top_players_home) && match.understat_top_players_home.length > 0) ||
                (Array.isArray(match?.understat_top_players_away) && match.understat_top_players_away.length > 0) ? (
                  <div className="pt-2 border-t border-white/10">
                    <div className="text-[12px] text-white/55 mb-2">xG по игрокам матча</div>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div>
                        <div className="text-[12px] text-white/75 mb-1">{match?.home_team || "Хозяева"}</div>
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
                        <div className="text-[12px] text-white/75 mb-1">{match?.away_team || "Гости"}</div>
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
                      homeTeam={match?.home_team || "Хозяева"}
                      awayTeam={match?.away_team || "Гости"}
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
                    ? "Матч идёт в лайве. Статистика и события обновляются по ходу игры."
                    : "Статистика матча пока недоступна. Данные появятся после завершения игры."}
                </div>
              ) : (
                <div className={MATCH_TAB_PANEL}>
                  <Suspense fallback={<div className="text-sm text-slate-400">Загружаем…</div>}>
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
                  Загружаем составы…
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
                  Составы недоступны для этого матча.
                </div>
              )}
            </div>
          )}

          {/* events tab removed; events shown in lineups */}

          {tab === "form" && (
            <div className={MATCH_TAB_STACK}>
              {packLoading && (
                <div className={`${MATCH_TAB_PANEL} text-sm text-slate-400`}>Загружаем данные формы…</div>
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
