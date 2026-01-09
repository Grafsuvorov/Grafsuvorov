// src/pages/TeamPageaAll.jsx
import React, {
  useEffect,
  useMemo,
  useState,
  lazy,
  Suspense,
  useCallback,
} from "react";
import { useParams, useSearchParams, useNavigate } from "react-router-dom";
import { teamLogoMap } from "@/constants/teamLogoMap";
import MatchInsightsPanelFull from "@/components/MatchInsightsPanelFull";

import FootballPitchPro from "@/components/FootballPitchPro";
import PlayerCard from "@/components/PlayerCard";
import {
  normalizeLineups,
  autoLayout,
  layoutFromGrid,
  buildMetaMaps,
} from "@/lib/lineupsLayout";

// календарь-пак
import { buildMatchPack } from "@/lib/matchInsights";

const MatchStatsBlockV3 = lazy(() => import("@/components/MatchStatsBlockV3"));

/* ===== общие токены под EdgeScore ===== */
const BG_PANEL = "panel";
const BORDER_GLASS = "border-glass";
const TEXT_MUTED = "text-muted";

/* ================= helpers & fallbacks ================= */
const FALLBACK_SVG = {
  team:
    "data:image/svg+xml;utf8," +
    encodeURIComponent(
      `<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>
         <rect width='100%' height='100%' fill='#020617'/>
         <path d='M20 4l12 6v8c0 8-6 14-12 18C14 32 8 26 8 18V10l12-6z' fill='#0f172a'/>
       </svg>`
    ),
  league:
    "data:image/svg+xml;utf8," +
    encodeURIComponent(
      `<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>
         <rect width='100%' height='100%' fill='#020617'/>
         <path d='M10 8h20v8c0 6-4 10-10 12C14 26 10 22 10 16V8z' fill='#0f172a'/>
         <rect x='14' y='28' width='12' height='4' rx='2' fill='#1e293b'/>
       </svg>`
    ),
};

const SafeImg = ({ src, alt = "", className = "", fallback = "team" }) => {
  const onErr = (e) => {
    e.currentTarget.onerror = null;
    e.currentTarget.srcset = "";
    e.currentTarget.src = FALLBACK_SVG[fallback] || FALLBACK_SVG.team;
  };
  return (
    <img
      src={src}
      alt={alt}
      className={className}
      onError={onErr}
      loading="lazy"
      decoding="async"
      draggable={false}
    />
  );
};

const teamLogo = (id) =>
  id ? `/icons/team_logos/${id}.png` : FALLBACK_SVG.team;
const leagueLogo = (name) =>
  name ? `/icons/${String(name).replace(/\s/g, "_")}.png` : FALLBACK_SVG.league;
const playerPhoto = (pid) => (pid ? `/icons/player_photos/${pid}.png` : "");
const fmtNum = (v, d = 0) => (v == null ? "—" : Number(v).toFixed(d));

/* ===== логотипы как в MatchSchedulePage ===== */
const teamLogoPath = (id) => (id ? `/icons/team_logos/${id}.png` : null);
const fallbackTeam = (name) =>
  teamLogoMap[name] || "/icons/team_logos/default.png";
const logoSafe = (id, name) => teamLogoPath(id) || fallbackTeam(name);

const LogoBadge = ({ id, name }) => (
  <span className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-glass bg-surface-2/80 shadow-sm">
    <img src={logoSafe(id, name)} alt="" className="h-6 w-6 object-contain" />
  </span>
);

/* форматтер даты DD.MM */
const toDDMM = (val) => {
  if (!val) return "";
  const s = String(val);
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (m) return `${m[3]}.${m[2]}`;
  const m2 = s.match(/^(\d{4})-(\d{2})-(\d{2})T/);
  if (m2) return `${m2[3]}.${m2[2]}`;
  if (/^\d{2}\.\d{2}/.test(s)) return s.slice(0, 5);
  return s;
};

/* супер-надёжный вывод счёта */
const fmtScore = (m) => {
  if (typeof m?.score === "string" && /[-:]/.test(m.score))
    return m.score.replace("-", ":");
  if (m?.home_goals != null && m?.away_goals != null)
    return `${m.home_goals}:${m.away_goals}`;
  const gh = m?.goals?.home ?? m?.scores?.home;
  const ga = m?.goals?.away ?? m?.scores?.away;
  if (Number.isFinite(Number(gh)) && Number.isFinite(Number(ga)))
    return `${gh}:${ga}`;
  if (m?.score && typeof m.score === "object") {
    const cand = [
      m.score.fulltime,
      m.score.ft,
      m.score.display,
      m.score.regular,
      m.score.current,
      m.score.final,
      m.score.full_time,
      m.score.result,
    ].find((s) => typeof s === "string" && /[-:]/.test(s));
    if (cand) return cand.replace("-", ":");
    const sh = m.score.home ?? m.score.home_goals ?? m.score.home_ft;
    const sa = m.score.away ?? m.score.away_goals ?? m.score.away_ft;
    if (Number.isFinite(Number(sh)) && Number.isFinite(Number(sa)))
      return `${sh}:${sa}`;
  }
  const s2 = m?.ft_score || m?.fulltime_score || m?.result;
  if (typeof s2 === "string" && /[-:]/.test(s2)) return s2.replace("-", ":");
  return "—";
};

const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : null);

/* === нормализация строки матча (минимально нужна для overlay-пака) === */
const normalizeRow = (x) => {
  const homeId =
    x.home_team_id ??
    x.home_id ??
    x.localteam_id ??
    x?.teams?.home?.id ??
    x?.home?.id;
  const awayId =
    x.away_team_id ??
    x.away_id ??
    x.visitorteam_id ??
    x?.teams?.away?.id ??
    x?.away?.id;

  const homeName =
    x.home_team ??
    x.home_name ??
    x.localteam_name ??
    x?.teams?.home?.name ??
    x?.home?.name ??
    "";
  const awayName =
    x.away_team ??
    x.away_name ??
    x.visitorteam_name ??
    x?.teams?.away?.name ??
    x?.away?.name ??
    "";

  const date = x.date || x.datetime || x?.fixture?.date || "";

  const gHome = x.home_goals ?? x?.goals?.home ?? x?.score?.home;
  const gAway = x.away_goals ?? x?.goals?.away ?? x?.score?.away;

  const strScore =
    x.score ||
    x?.score?.fulltime ||
    x?.score?.display ||
    x?.ft_score ||
    x?.result;

  let hg = Number.isFinite(Number(gHome)) ? Number(gHome) : null;
  let ag = Number.isFinite(Number(gAway)) ? Number(gAway) : null;

  if (hg == null || ag == null) {
    const s = typeof strScore === "string" ? strScore : "";
    const m = s.match(/(\d+)\s*[-:]\s*(\d+)/);
    if (m) {
      hg = parseInt(m[1], 10);
      ag = parseInt(m[2], 10);
    }
  }
  const score =
    hg != null && ag != null
      ? `${hg}-${ag}`
      : typeof strScore === "string"
      ? strScore
      : "";

  const leagueName =
    x.league ||
    x.league_name ||
    x.competition ||
    x.tournament ||
    x?.league?.name ||
    "";
  const seasonName =
    x.season ||
    x.season_name ||
    x?.league?.season ||
    x?.fixture?.season ||
    x?.seasonDisplay ||
    "";

  const standingOf = (side) => {
    const candidates = [
      x?.[`${side}_standing`],
      x?.[`${side}_rank`],
      x?.[`${side}_position`],
      x?.standings?.[side],
      x?.[`standings_${side}`],
      x?.[`table_${side}_pos`],
    ];
    const v = candidates.find((vv) => Number.isFinite(Number(vv)));
    return Number.isFinite(Number(v)) ? Number(v) : null;
  };

  return {
    fixture_id:
      x.fixture_id ||
      x.id ||
      `${homeId || homeName}-${awayId || awayName}-${date}`,
    date,
    home_team_id: Number.isFinite(Number(homeId)) ? Number(homeId) : undefined,
    away_team_id: Number.isFinite(Number(awayId)) ? Number(awayId) : undefined,
    home_team: homeName,
    away_team: awayName,
    home_goals: hg != null ? hg : undefined,
    away_goals: ag != null ? ag : undefined,
    score,
    league: leagueName,
    season: seasonName,
    home_rank: standingOf("home"),
    away_rank: standingOf("away"),
  };
};

const enrichRowForH2H = (row) => {
  const hg = Number.isFinite(Number(row.home_goals))
    ? Number(row.home_goals)
    : null;
  const ag = Number.isFinite(Number(row.away_goals))
    ? Number(row.away_goals)
    : null;
  const full =
    typeof row.score === "string" && /[-:]/.test(row.score)
      ? row.score.replace("-", ":")
      : hg != null && ag != null
      ? `${hg}:${ag}`
      : "";

  return {
    ...row,
    teams: {
      home: { id: row.home_team_id, name: row.home_team },
      away: { id: row.away_team_id, name: row.away_team },
    },
    fixture: {
      date: row.date,
      id: row.fixture_id,
    },
    goals: { home: hg, away: ag },
    score: {
      fulltime: full || (hg != null && ag != null ? `${hg}-${ag}` : ""),
      home: hg,
      away: ag,
      display: full || "",
    },
    ft_score: full || "",
  };
};

/* ===== Хелперы для формы и W/D/L ===== */
function matchSideForTeam(m, teamId) {
  if (m == null || teamId == null) return null;
  const hid = Number(m.home_team_id);
  const aid = Number(m.away_team_id);
  if (Number.isFinite(hid) && hid === Number(teamId)) return "home";
  if (Number.isFinite(aid) && aid === Number(teamId)) return "away";
  return null;
}

function parseScorePair(value) {
  if (!value) return [null, null];
  const match = String(value).match(/(\d+)\s*[-:]\s*(\d+)/);
  if (!match) return [null, null];
  return [Number(match[1]), Number(match[2])];
}

function goalsSummaryFor(match, teamId) {
  const side = matchSideForTeam(match, teamId);
  if (!side) return { for: 0, against: 0 };
  const altSide = side === "home" ? "away" : "home";
  let gf = Number(match?.[`${side}_goals`]);
  let ga = Number(match?.[`${altSide}_goals`]);
  if (!Number.isFinite(gf) || !Number.isFinite(ga)) {
    const fromScore = match?.score?.fulltime || match?.score || match?.ft_score;
    const [homeScore, awayScore] = parseScorePair(fromScore);
    if (Number.isFinite(homeScore) && Number.isFinite(awayScore)) {
      gf = side === "home" ? homeScore : awayScore;
      ga = side === "home" ? awayScore : homeScore;
    }
  }
  return {
    for: Number.isFinite(gf) ? gf : 0,
    against: Number.isFinite(ga) ? ga : 0,
  };
}

function resultForTeam(m, teamId) {
  const hg = Number.isFinite(Number(m?.home_goals)) ? Number(m.home_goals) : null;
  const ag = Number.isFinite(Number(m?.away_goals)) ? Number(m.away_goals) : null;
  if (hg == null || ag == null) return null;
  if (hg === ag) return "D";
  const isHome = m.home_team_id === teamId;
  const win = isHome ? hg > ag : ag > hg;
  return win ? "W" : "L";
}

function resultBadgeClasses(r) {
  if (r === "W") return "bg-emerald-500/10 text-emerald-300 border-emerald-400/60";
  if (r === "L") return "bg-rose-500/10 text-rose-300 border-rose-400/60";
  return "bg-surface-2 text-slate-200 border-glass";
}

/* ===== UI для KPI ===== */

/* Вариант 2 — табы с линией снизу, как на подборках */
const Segmented = ({ value, onChange }) => (
  <div className="mt-5 flex flex-wrap gap-6 border-b border-glass">
    {[
      { code: "stats", label: "Статистика" },
      { code: "results", label: "Результаты" },
      { code: "schedule", label: "Календарь" },
    ].map((t) => {
      const active = value === t.code;
      return (
        <button
          key={t.code}
          onClick={() => onChange(t.code)}
          className={`relative pb-2 text-xs sm:text-sm font-semibold tracking-wide transition-colors ${
            active
              ? "text-white"
              : "text-slate-400 hover:text-slate-100"
          }`}
        >
          {t.label}
          {active && (
            <span className="pointer-events-none absolute inset-x-0 -bottom-[2px] h-[2px] rounded-full bg-gradient-to-r from-fuchsia-400 via-pink-400 to-amber-300 shadow-[0_0_18px_rgba(251,113,133,0.65)]" />
          )}
        </button>
      );
    })}
  </div>
);

const IconWrap = ({ children }) => (
  <span className="h-7 w-7 rounded-xl grid place-items-center bg-surface-2 text-fuchsia-300 border border-glass shadow-sm">
    {children}
  </span>
);

const KpiCard = ({ title, value, sub, icon }) => (
  <div className="rounded-2xl border border-glass bg-surface-1/90 p-4 shadow-[0_22px_70px_rgba(0,0,0,0.85)] hover:shadow-[0_24px_90px_rgba(236,72,153,0.45)] transition-shadow">
    <div className="flex items-center gap-2 text-[11px] uppercase tracking-wide text-slate-400">
      {icon ? <IconWrap>{icon}</IconWrap> : null}
      <span>{title}</span>
    </div>
    <div className="mt-2 text-2xl font-semibold tracking-tight text-white">
      {value ?? "—"}
    </div>
    {sub ? (
      <div className="text-[11px] text-slate-400 mt-1">{sub}</div>
    ) : null}
  </div>
);

/* локальные бейджи */
function MinutePill({ value }) {
  return (
    <span className="inline-flex items-center justify-center w-[56px] px-0 py-[2px] rounded-full border border-glass bg-surface-2 text-[11px] text-slate-100 tabular-nums">
      {value}
    </span>
  );
}
function SubPill({ minute }) {
  return (
    <span className="inline-flex items-center gap-1 rounded-full border border-glass bg-surface-2 text-slate-100 text-[10px] px-1.5 py-0.5">
      🔁 {minute}'
    </span>
  );
}
function BenchPill() {
  return (
    <span className="inline-flex items-center rounded-full border border-glass bg-surface-2 text-slate-200 text-[10px] px-1.5 py-0.5">
      Bench
    </span>
  );
}
function AvatarCircle({ pid, number, ring = "" }) {
  return (
    <span
      className={`inline-flex items-center justify-center rounded-full ring-2 ${ring}`}
      style={{ width: 22, height: 22 }}
    >
      {pid ? (
        <img
          src={playerPhoto(pid)}
          onError={(e) => {
            e.currentTarget.style.display = "none";
          }}
          alt=""
          className="w-full h-full rounded-full object-cover"
        />
      ) : (
        <span className="text-[10px] font-semibold text-slate-100">
          {number || "?"}
        </span>
      )}
    </span>
  );
}

/* ================= fetch helpers ================= */
async function fetchJsonSafe(url) {
  const r = await fetch(url);
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

const seasonDateRange = (seasonStr, def = 2025) => {
  const y = Number(seasonStr) || Number(def);
  return { from: `${y}-07-01`, to: `${y + 1}-06-30` };
};

const aroundDate = (dateStr, days = 7) => {
  const d = new Date(dateStr);
  if (isNaN(+d)) return null;
  const a = new Date(d);
  const b = new Date(d);
  a.setDate(d.getDate() - days);
  b.setDate(d.getDate() + days);
  const fmt = (x) => x.toISOString().slice(0, 10);
  return { from: fmt(a), to: fmt(b) };
};

/* ================= lineups cache ================= */
const lineupsCache = new Map();

async function fetchLineupsCached(fixture_id) {
  if (!fixture_id) return null;
  if (lineupsCache.has(fixture_id)) return lineupsCache.get(fixture_id);
  const r = await fetch(
    `http://localhost:8001/api/lineups-events?fixture_id=${fixture_id}`
  );
  const j = await r.json();
  lineupsCache.set(fixture_id, j);
  return j;
}

/* ================= misc: validate+fetch one match ================= */
function validateTeams(m, seed) {
  if (!m || !seed) return true;
  const h = Number(m.home_team_id),
    a = Number(m.away_team_id);
  const t = Number(seed.team_id),
    o = Number(seed.opponent_id);
  if (
    Number.isFinite(h) &&
    Number.isFinite(a) &&
    Number.isFinite(t) &&
    Number.isFinite(o)
  ) {
    return (h === t && a === o) || (h === o && a === t);
  }
  return true;
}

async function fetchOneMatch({ fixtureId, league, season, seed }) {
  const seedWindow = seed?.date ? aroundDate(seed.date, 7) : null;
  const seasonWin = seasonDateRange(season);
  const win = seedWindow || seasonWin;

  try {
    const u1 = `http://localhost:8001/api/matches_v3?fixture_id=${fixtureId}&league=${encodeURIComponent(
      league
    )}&season=${season}&from_date=${win.from}&to_date=${win.to}`;
    const d1 = await fetchJsonSafe(u1);
    const cand = Array.isArray(d1)
      ? d1.find((x) => String(x.fixture_id) === String(fixtureId))
      : d1;
    if (cand && validateTeams(cand, seed)) return cand;
  } catch {}
  try {
    const u2 = `http://localhost:8001/api/matches_v3?league=${encodeURIComponent(
      league
    )}&season=${season}&from_date=${seasonWin.from}&to_date=${seasonWin.to}`;
    const pool = await fetchJsonSafe(u2);
    const arr = Array.isArray(pool) ? pool : pool ? [pool] : [];
    const hit = arr.find((x) => String(x.fixture_id) === String(fixtureId));
    if (hit && validateTeams(hit, seed)) return hit;
  } catch {}
  try {
    const d3 = await fetchJsonSafe(
      `http://localhost:8001/api/matches_v3?fixture_id=${fixtureId}`
    );
    const one = Array.isArray(d3) ? d3[0] : d3;
    if (one && validateTeams(one, seed)) return one;
  } catch {}
  return null;
}

/* ================= events / subs helpers ================= */
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
const lower = (v) => (v == null ? "" : String(v).toLowerCase());
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
  if (d.includes("cancel") && (t.includes("goal") || d.includes("goal")))
    return "goal_cancelled";
  if (t.includes("missed") || d === "missed penalty") return "pen_missed";
  if (d === "yellow card") return "yellow";
  if (d.startsWith("red card") || d === "red card") return "red";
  if (t.startsWith("subst") || d.startsWith("substitution")) return "sub";
  if (d.includes("var") || d.includes("review") || d.includes("confirmed"))
    return "var";
  return "other";
};
function computeScoreProgress(events, homeId, awayId) {
  let h = 0,
    a = 0;
  const sorted = [...(events || [])].sort((A, B) => {
    const ea = getElapsed(A) ?? -1,
      eb = getElapsed(B) ?? -1;
    const xa = getExtra(A),
      xb = getExtra(B);
    if (ea !== eb) return ea - eb;
    if (xa !== xb) return xa - xb;
    return (A.player_id || 0) - (B.player_id || 0);
  });
  return sorted.map((e) => {
    const side =
      e.team_id === homeId ? "home" : e.team_id === awayId ? "away" : null;
    const kind = inferKind(e);
    if (kind === "goal") {
      if (side === "home") h += 1;
      else if (side === "away") a += 1;
    } else if (kind === "own_goal") {
      if (side === "home") a += 1;
      else if (side === "away") h += 1;
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

/* ================= OneMatchOverlay ================= */
function OneMatchOverlay({ fixtureId, seed, league, season, onClose }) {
  const [m, setM] = useState(null);
  const [err, setErr] = useState("");
  const [tab, setTab] = useState("stats");
  const [lineups, setLineups] = useState(null);
  const [loadingLineups, setLoadingLineups] = useState(false);
  const [openCard, setOpenCard] = useState(null); // {side, player, meta, isMVP}

  // перехват fetch для MatchStatsBlockV3
  useEffect(() => {
    const orig = window.fetch;
    window.fetch = (input, init) => {
      try {
        const raw = typeof input === "string" ? input : input?.url || "";
        const u = new URL(raw, window.location.origin);
        if (u.pathname === "/api/matches_v3" && u.searchParams.has("fixture_id")) {
          const w = seed?.date ? aroundDate(seed.date, 7) : seasonDateRange(season);
          if (!u.searchParams.has("league")) u.searchParams.set("league", league);
          if (!u.searchParams.has("season")) u.searchParams.set("season", season);
          if (!u.searchParams.has("from_date")) u.searchParams.set("from_date", w.from);
          if (!u.searchParams.has("to_date")) u.searchParams.set("to_date", w.to);
          return orig(u.toString(), init);
        }
      } catch {}
      return orig(input, init);
    };
    return () => {
      window.fetch = orig;
    };
  }, [league, season, seed?.date]);

  // матч
  useEffect(() => {
    let c = false;
    (async () => {
      try {
        setErr("");
        setM(null);
        const obj = await fetchOneMatch({ fixtureId, league, season, seed });
        if (!c) setM(obj || null);
      } catch (e) {
        if (!c) setErr(e.message || String(e));
      }
    })();
    return () => {
      c = true;
    };
  }, [fixtureId, league, season, seed?.team_id, seed?.opponent_id, seed?.date]);

  // lineups
  useEffect(() => {
    if (tab !== "lineups" || !fixtureId) return;
    let c = false;
    (async () => {
      try {
        setLoadingLineups(true);
        const j = await fetchLineupsCached(fixtureId);
        if (!c) setLineups(j);
      } finally {
        if (!c) setLoadingLineups(false);
      }
    })();
    return () => {
      c = true;
    };
  }, [tab, fixtureId]);

  // нормализация и раскладка
  const norm = useMemo(() => normalizeLineups(lineups, m), [lineups, m]);

  const homePins =
    (norm?.home?.starters?.length &&
      (layoutFromGrid(norm.home.starters, "home", norm.home.formation).length
        ? layoutFromGrid(norm.home.starters, "home", norm.home.formation)
        : autoLayout(norm.home.formation, norm.home.starters, "home"))) || [];
  const awayPins =
    (norm?.away?.starters?.length &&
      (layoutFromGrid(norm.away.starters, "away", norm.away.formation).length
        ? layoutFromGrid(norm.away.starters, "away", norm.away.formation)
        : autoLayout(norm.away.formation, norm.away.starters, "away"))) || [];

  const metaMaps = useMemo(() => buildMetaMaps(norm), [norm]);

  // MVP
  const allRated = [...homePins, ...awayPins].filter(
    (p) => p.rating != null && Number.isFinite(Number(p.rating))
  );
  const mvp = allRated.length
    ? allRated.reduce((a, b) =>
        Number(a.rating) >= Number(b.rating) ? a : b
      )
    : null;
  const mvpId = mvp?.player_id || mvp?.id || null;

  // preload photos
  useEffect(() => {
    const photos = [...(norm?.home?.starters || []), ...(norm?.away?.starters || [])]
      .slice(0, 30)
      .map((p) => p?.player_id && `/icons/player_photos/${p.player_id}.png`)
      .filter(Boolean);
    (typeof window !== "undefined" && window.requestIdleCallback
      ? window.requestIdleCallback
      : (cb) => setTimeout(() => cb({}), 200))(() =>
      photos.forEach((src) => {
        const img = new Image();
        img.decoding = "async";
        img.loading = "eager";
        img.src = src;
      })
    );
  }, [norm?.home?.starters, norm?.away?.starters]);

  const sideHome = seed?.side === "H";
  const homeTeam =
    m?.home_team ||
    (sideHome ? seed?.team_name : seed?.opponent_name) ||
    "—";
  const awayTeam =
    m?.away_team ||
    (!sideHome ? seed?.team_name : seed?.opponent_name) ||
    "—";
  const homeId =
    m?.home_team_id || (sideHome ? seed?.team_id : seed?.opponent_id);
  const awayId =
    m?.away_team_id || (!sideHome ? seed?.team_id : seed?.opponent_id);
  const scoreStr =
    m?.score ||
    (seed?.team_goals != null && seed?.opp_goals != null
      ? sideHome
        ? `${seed.team_goals}-${seed.opp_goals}`
        : `${seed.opp_goals}-${seed.team_goals}`
      : "—");

  // события / замены
  const eventsEnriched = useMemo(
    () => computeScoreProgress(norm?.events || [], homeId, awayId),
    [norm?.events, homeId, awayId]
  );
  const groups = useMemo(
    () => groupEventsByPeriod(eventsEnriched),
    [eventsEnriched]
  );

  const subs = useMemo(() => collectSubs(norm?.events || []), [norm]);
  const homeTeamId = norm?.home?.team_id || m?.home_team_id;
  const awayTeamId = norm?.away?.team_id || m?.away_team_id;
  const subsHome = subs.filter((s) => s.team_id === homeTeamId);
  const subsAway = subs.filter((s) => s.team_id === awayTeamId);

  const minuteByInHome = new Map(subsHome.map((s) => [s.in_id, s.minute]));
  const minuteByInAway = new Map(subsAway.map((s) => [s.in_id, s.minute]));
  const playersHomeList = [...homePins, ...(norm?.home?.bench || [])];
  const playersAwayList = [...awayPins, ...(norm?.away?.bench || [])];

  return (
    <div className="fixed inset-0 z-[100]">
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />
      <div className="absolute left-1/2 top-6 -translate-x-1/2 w-[min(980px,96vw)] rounded-3xl bg-slate-950 shadow-[0_40px_120px_rgba(0,0,0,0.75)] border border-glass grid grid-rows-[auto,1fr] max-h-[92vh] overflow-hidden">
        {/* header */}
        <div className="p-4 border-b border-glass bg-gradient-to-r from-fuchsia-600 via-pink-500 to-amber-400 text-white relative">
          <button
            onClick={onClose}
            className="absolute right-3 top-3 h-8 w-8 rounded-full bg-black/25 hover:bg-black/40 grid place-items-center text-sm"
            title="Закрыть"
            aria-label="close"
          >
            ✕
          </button>
          <div className="absolute right-12 top-3">
            <div className="bg-black/25 rounded-2xl p-1 border border-white/20">
              <button
                onClick={() => setTab("stats")}
                className={`h-7 px-3 rounded-xl text-xs font-semibold ${
                  tab === "stats" ? "bg-white text-fuchsia-600" : "text-white/80"
                }`}
              >
                Статистика
              </button>
              <button
                onClick={() => setTab("lineups")}
                className={`h-7 px-3 rounded-xl text-xs font-semibold ${
                  tab === "lineups" ? "bg-white text-fuchsia-600" : "text-white/80"
                }`}
              >
                Составы
              </button>
            </div>
          </div>

          <div className="flex flex-col items-center gap-1 pt-4">
            <div className="flex items-center justify-center gap-3">
              <span className="h-11 w-11 rounded-2xl bg-white/10 grid place-items-center overflow-hidden border border-white/40">
                <SafeImg
                  src={teamLogo(homeId)}
                  alt={homeTeam}
                  className="h-8 w-8 object-contain"
                />
              </span>
              <div className="text-lg font-semibold truncate">{homeTeam}</div>
              <div className="text-xl font-extrabold tabular-nums px-3 py-1 rounded-xl bg-black/30">
                {scoreStr || "—"}
              </div>
              <div className="text-lg font-semibold truncate">{awayTeam}</div>
              <span className="h-11 w-11 rounded-2xl bg-white/10 grid place-items-center overflow-hidden border border-white/40">
                <SafeImg
                  src={teamLogo(awayId)}
                  alt={awayTeam}
                  className="h-8 w-8 object-contain"
                />
              </span>
            </div>
            <div className="text-[11px] bg-black/35 px-3 py-0.5 rounded-full mt-1">
              Завершённый матч
            </div>
          </div>
        </div>

        {/* body */}
        <div className="p-4 overflow-auto bg-slate-950">
          {tab === "stats" ? (
            m ? (
              <div className="rounded-2xl border border-glass bg-surface-1/80 shadow-[0_24px_80px_rgba(0,0,0,0.9)] p-3">
                <Suspense
                  fallback={
                    <div className="text-sm text-slate-400">
                      Загружаем статистику…
                    </div>
                  }
                >
                  <MatchStatsBlockV3 stats={m} />
                </Suspense>
              </div>
            ) : err ? (
              <div className="text-sm text-rose-400">Ошибка: {err}</div>
            ) : (
              <div className="h-40 rounded-2xl border border-glass bg-surface-1/60 animate-pulse" />
            )
          ) : (
            <>
              {loadingLineups ? (
                <div className="text-sm text-slate-400">
                  Загружаем составы…
                </div>
              ) : norm ? (
                <div className="space-y-4">
                  <FootballPitchPro
                    homePlayers={homePins}
                    awayPlayers={awayPins}
                    homeMeta={metaMaps.get?.(homeTeamId)}
                    awayMeta={metaMaps.get?.(awayTeamId)}
                    mvpId={mvpId}
                    onOpenCard={(payload) => setOpenCard(payload)}
                  />

                  {/* списки игроков */}
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                    <div className="rounded-2xl border border-glass bg-surface-1/80 p-3">
                      <div className="font-medium text-slate-100 mb-2">
                        Игроки • {homeTeam}
                      </div>
                      <div className="flex flex-wrap gap-2">
                        {(playersHomeList || []).map((p, i) => {
                          const last =
                            (p.name || p.player_name || "")
                              .trim()
                              .split(" ")
                              .slice(-1)
                              .join(" ") ||
                            p.name ||
                            `#${p.number || "?"}`;
                          const minute = minuteByInHome.get(p.player_id);
                          const meta = metaMaps
                            .get?.(homeTeamId)
                            ?.get?.(p.player_id);
                          const benchButNotUsed =
                            !minute &&
                            (norm?.home?.bench || []).some(
                              (b) => b.player_id === p.player_id
                            );
                          return (
                            <button
                              key={`h-${p.player_id || i}`}
                              onClick={() =>
                                setOpenCard({
                                  side: "home",
                                  player: p,
                                  meta,
                                  isMVP:
                                    !!mvpId &&
                                    (p.player_id === mvpId || p.id === mvpId),
                                })
                              }
                              className={`px-2 py-1 rounded-full border inline-flex items-center gap-1 text-slate-100 text-[13px] ${
                                benchButNotUsed
                                  ? "border-glass bg-surface-1/70 hover:bg-surface-2/80"
                                  : "border-glass bg-surface-2/80 hover:bg-surface-2"
                              }`}
                              title={p.name}
                            >
                              <AvatarCircle
                                pid={p.player_id}
                                number={p.number}
                                ring="ring-emerald-400/70"
                              />
                              <span className="truncate max-w-[130px]">
                                {last}
                              </span>
                              {minute ? (
                                <SubPill minute={minute} />
                              ) : benchButNotUsed ? (
                                <BenchPill />
                              ) : null}
                            </button>
                          );
                        })}
                      </div>
                    </div>
                    <div className="rounded-2xl border border-glass bg-surface-1/80 p-3">
                      <div className="font-medium text-slate-100 mb-2">
                        Игроки • {awayTeam}
                      </div>
                      <div className="flex flex-wrap gap-2">
                        {(playersAwayList || []).map((p, i) => {
                          const last =
                            (p.name || p.player_name || "")
                              .trim()
                              .split(" ")
                              .slice(-1)
                              .join(" ") ||
                            p.name ||
                            `#${p.number || "?"}`;
                          const minute = minuteByInAway.get(p.player_id);
                          const meta = metaMaps
                            .get?.(awayTeamId)
                            ?.get?.(p.player_id);
                          const benchButNotUsed =
                            !minute &&
                            (norm?.away?.bench || []).some(
                              (b) => b.player_id === p.player_id
                            );
                          return (
                            <button
                              key={`a-${p.player_id || i}`}
                              onClick={() =>
                                setOpenCard({
                                  side: "away",
                                  player: p,
                                  meta,
                                  isMVP:
                                    !!mvpId &&
                                    (p.player_id === mvpId || p.id === mvpId),
                                })
                              }
                              className={`px-2 py-1 rounded-full border inline-flex items-center gap-1 text-slate-100 text-[13px] ${
                                benchButNotUsed
                                  ? "border-glass bg-surface-1/70 hover:bg-surface-2/80"
                                  : "border-glass bg-surface-2/80 hover:bg-surface-2"
                              }`}
                              title={p.name}
                            >
                              <AvatarCircle
                                pid={p.player_id}
                                number={p.number}
                                ring="ring-sky-400/70"
                              />
                              <span className="truncate max-w-[130px]">
                                {last}
                              </span>
                              {minute ? (
                                <SubPill minute={minute} />
                              ) : benchButNotUsed ? (
                                <BenchPill />
                              ) : null}
                            </button>
                          );
                        })}
                      </div>
                    </div>
                  </div>

                  {/* ЗАМЕНЫ */}
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                    <div className="rounded-2xl border border-glass bg-surface-1/80 p-3">
                      <div className="font-medium text-slate-100 mb-2">
                        Замены • {homeTeam}
                      </div>
                      {subsHome.length ? (
                        subsHome.map((s, i) => (
                          <div
                            key={`hs-${i}`}
                            className="grid grid-cols-[minmax(0,1fr)_64px_minmax(0,1fr)] items-center gap-2 py-1.5 border-b border-surface-2 last:border-0"
                          >
                            <div className="flex items-center gap-2 min-w-0">
                              <AvatarCircle
                                pid={s.in_id}
                                ring="ring-emerald-400/70"
                              />
                              <span
                                className="text-emerald-200 font-medium truncate"
                                title={s.in_name}
                              >
                                ↗︎ {s.in_name || "—"}
                              </span>
                            </div>
                            <div className="flex items-center justify-center">
                              <MinutePill value={`${s.minute}'`} />
                            </div>
                            <div className="flex items-center gap-2 min-w-0 justify-end">
                              <span
                                className="text-rose-200 font-medium truncate text-right"
                                title={s.out_name}
                              >
                                ↘︎ {s.out_name || "—"}
                              </span>
                              <AvatarCircle
                                pid={s.out_id}
                                ring="ring-rose-400/80"
                              />
                            </div>
                          </div>
                        ))
                      ) : (
                        <div className="text-slate-500 text-[12px]">—</div>
                      )}
                    </div>

                    <div className="rounded-2xl border border-glass bg-surface-1/80 p-3">
                      <div className="font-medium text-slate-100 mb-2">
                        Замены • {awayTeam}
                      </div>
                      {subsAway.length ? (
                        subsAway.map((s, i) => (
                          <div
                            key={`as-${i}`}
                            className="grid grid-cols-[minmax(0,1fr)_64px_minmax(0,1fr)] items-center gap-2 py-1.5 border-b border-surface-2 last:border-0"
                          >
                            <div className="flex items-center gap-2 min-w-0">
                              <AvatarCircle
                                pid={s.in_id}
                                ring="ring-sky-400/80"
                              />
                              <span
                                className="text-emerald-200 font-medium truncate"
                                title={s.in_name}
                              >
                                ↗︎ {s.in_name || "—"}
                              </span>
                            </div>
                            <div className="flex items-center justify-center">
                              <MinutePill value={`${s.minute}'`} />
                            </div>
                            <div className="flex items-center gap-2 min-w-0 justify-end">
                              <span
                                className="text-rose-200 font-medium truncate text-right"
                                title={s.out_name}
                              >
                                ↘︎ {s.out_name || "—"}
                              </span>
                              <AvatarCircle
                                pid={s.out_id}
                                ring="ring-rose-400/80"
                              />
                            </div>
                          </div>
                        ))
                      ) : (
                        <div className="text-[12px] text-slate-500 text-right">
                          —
                        </div>
                      )}
                    </div>
                  </div>

                  {/* СОБЫТИЯ */}
                  <div className="mt-2 rounded-2xl border border-glass bg-surface-1/80 p-3">
                    <div className="font-medium text-slate-100 mb-3">
                      События матча
                    </div>
                    {["first", "second", "extra"].map((k) => {
                      const title =
                        k === "first"
                          ? "1-й тайм"
                          : k === "second"
                          ? "2-й тайм"
                          : "Доп. время";
                      const homeList = groups[k].home;
                      const awayList = groups[k].away;
                      if (!homeList.length && !awayList.length && k !== "first")
                        return null;
                      return (
                        <div key={k} className="mb-4 last:mb-0">
                          <div className="text-[11px] uppercase tracking-wide text-slate-500 mb-1">
                            {title}
                          </div>
                          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                            <div className="space-y-2">
                              {homeList.length ? (
                                homeList.map((ev, i) => (
                                  <div
                                    key={`h-${k}-${i}`}
                                    className="flex justify-start"
                                  >
                                    <div className="inline-flex items-center gap-2 px-2 py-1 rounded-full border border-glass bg-surface-2/90 shadow-sm text-slate-100">
                                      <span className="text-base leading-none">
                                        {ICON[ev.kind] || ICON.other}
                                      </span>
                                      <MinutePill
                                        value={minuteStr(
                                          getElapsed(ev),
                                          getExtra(ev)
                                        )}
                                      />
                                      <span className="text-[13px]">
                                        <span className="font-medium">
                                          {ev.player_name || "—"}
                                        </span>
                                        {ev.assist_name &&
                                          !/^substitution/i.test(
                                            ev.detail || ""
                                          ) && (
                                            <span className="text-slate-400">
                                              {" "}
                                              (ассист {ev.assist_name})
                                            </span>
                                          )}
                                        {translateDetailRu(ev.detail) && (
                                          <span className="text-slate-300">
                                            {" "}
                                            — {translateDetailRu(ev.detail)}
                                          </span>
                                        )}
                                        {translateCommentRu(ev.comments) && (
                                          <span className="text-slate-400">
                                            {" "}
                                            ({translateCommentRu(ev.comments)})
                                          </span>
                                        )}
                                        {(ev.kind === "goal" ||
                                          ev.kind === "own_goal") &&
                                          ev.score_after && (
                                            <span className="ml-2 font-semibold text-emerald-300">
                                              {ev.score_after}
                                            </span>
                                          )}
                                      </span>
                                    </div>
                                  </div>
                                ))
                              ) : (
                                <div className="text-[12px] text-slate-500">
                                  —
                                </div>
                              )}
                            </div>
                            <div className="space-y-2">
                              {awayList.length ? (
                                awayList.map((ev, i) => (
                                  <div
                                    key={`a-${k}-${i}`}
                                    className="flex justify-end"
                                  >
                                    <div className="inline-flex items-center gap-2 px-2 py-1 rounded-full border border-glass bg-surface-2/90 shadow-sm text-slate-100 text-right">
                                      <span className="text-base leading-none">
                                        {ICON[ev.kind] || ICON.other}
                                      </span>
                                      <MinutePill
                                        value={minuteStr(
                                          getElapsed(ev),
                                          getExtra(ev)
                                        )}
                                      />
                                      <span className="text-[13px]">
                                        <span className="font-medium">
                                          {ev.player_name || "—"}
                                        </span>
                                        {ev.assist_name &&
                                          !/^substitution/i.test(
                                            ev.detail || ""
                                          ) && (
                                            <span className="text-slate-400">
                                              {" "}
                                              (ассист {ev.assist_name})
                                            </span>
                                          )}
                                        {translateDetailRu(ev.detail) && (
                                          <span className="text-slate-300">
                                            {" "}
                                            — {translateDetailRu(ev.detail)}
                                          </span>
                                        )}
                                        {translateCommentRu(ev.comments) && (
                                          <span className="text-slate-400">
                                            {" "}
                                            ({translateCommentRu(ev.comments)})
                                          </span>
                                        )}
                                        {(ev.kind === "goal" ||
                                          ev.kind === "own_goal") &&
                                          ev.score_after && (
                                            <span className="ml-2 font-semibold text-emerald-300">
                                              {ev.score_after}
                                            </span>
                                          )}
                                      </span>
                                    </div>
                                  </div>
                                ))
                              ) : (
                                <div className="text-[12px] text-slate-500 text-right">
                                  —
                                </div>
                              )}
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              ) : (
                <div className="text-sm text-slate-400">
                  Нет данных по составам.
                </div>
              )}
            </>
          )}
        </div>

        <PlayerCard
          visible={!!openCard}
          player={openCard?.player}
          meta={openCard?.meta}
          side={openCard?.side}
          isMVP={openCard?.isMVP}
          onClose={() => setOpenCard(null)}
        />
      </div>
    </div>
  );
}

/* ================= PAGE ================= */

const SEASONS = ["2025", "2024", "2023", "2022"];

export default function TeamPageaAll() {
  const { id } = useParams();
  const teamId = Number(id || 0);

  const [sp, setSp] = useSearchParams();
  const navigate = useNavigate();

  const league = sp.get("league") || "Premier League";
  const seasonParam = sp.get("season") || "2025";
  const tabParam = sp.get("tab") || "stats"; // stats | results | schedule

  const [season, setSeason] = useState(seasonParam);
  const [tab, setTabState] = useState(tabParam);

  const [overview, setOverview] = useState(null);
  const [results, setResults] = useState([]);
  const [schedule, setSchedule] = useState([]);
  const [loadingO, setLoadingO] = useState(false);
  const [loadingR, setLoadingR] = useState(false);
  const [loadingS, setLoadingS] = useState(false);

  const [openedMatch, setOpenedMatch] = useState(null);

  // для разворота календаря — один раскрытый матч + pack
  const [expandedId, setExpandedId] = useState(null);
  const [expandedData, setExpandedData] = useState({}); // { [fixture_id]: {loading, error, ...pack} }

  const setTab = (t) => {
    setTabState(t);
    const next = new URLSearchParams(sp);
    next.set("tab", t);
    setSp(next, { replace: true });
  };

  const handleSeasonChange = (sn) => {
    setSeason(sn);
    const next = new URLSearchParams(sp);
    next.set("season", sn);
    setSp(next, { replace: true });
  };

  const goToTeam = useCallback(
    (otherTeamId) => {
      if (!otherTeamId) return;
      navigate(
        `/team/${otherTeamId}?league=${encodeURIComponent(
          league
        )}&season=${season}`
      );
    },
    [navigate, league, season]
  );

  // overview
  useEffect(() => {
    if (!teamId) return;
    let cancel = false;
    (async () => {
      setLoadingO(true);
      try {
        const qs = new URLSearchParams({
          team_id: String(teamId),
          league,
          season,
        });
        const o = await fetch(
          `http://localhost:8001/api/team/overview?${qs}`
        ).then((r) => r.json());
        if (!cancel) setOverview(o || null);
      } catch {
        if (!cancel) setOverview(null);
      } finally {
        if (!cancel) setLoadingO(false);
      }
    })();
    return () => {
      cancel = true;
    };
  }, [teamId, league, season]);

  // results — сыгранные матчи
  useEffect(() => {
    if (!teamId) return;
    let cancel = false;

    (async () => {
      setLoadingR(true);
      try {
        const qs = new URLSearchParams({
          team_id: String(teamId),
          league,
          season,
        });

        const rows = await fetch(
          `http://localhost:8001/api/team/results?${qs}`
        ).then((r) => r.json());

        if (!cancel) {
          setResults(Array.isArray(rows) ? rows : []);
        }
      } catch {
        if (!cancel) setResults([]);
      } finally {
        if (!cancel) setLoadingR(false);
      }
    })();

    return () => {
      cancel = true;
    };
  }, [teamId, league, season]);

  // schedule — будущие матчи команды
  useEffect(() => {
    if (!teamId) return;
    let cancel = false;

    (async () => {
      setLoadingS(true);
      try {
        const { from, to } = seasonDateRange(season);

        const qsFull = new URLSearchParams({
          league,
          season,
          from_date: from,
          to_date: to,
          include_upcoming: "true",
        });

        const rows = await fetch(
          `http://localhost:8001/api/matches_v3?${qsFull}`
        ).then((r) => r.json());

        const arr = Array.isArray(rows) ? rows : [];

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const upcoming = arr.filter((m) => {
          const isTeam =
            Number(m.home_team_id) === teamId ||
            Number(m.away_team_id) === teamId;

          if (!isTeam) return false;

          const dStr = m.date || m.datetime || null;
          if (!dStr) return true;

          const d = new Date(dStr);
          if (isNaN(+d)) return true;

          d.setHours(0, 0, 0, 0);
          return d >= today;
        });

        if (!cancel) {
          setSchedule(upcoming);
        }
      } catch {
        if (!cancel) setSchedule([]);
      } finally {
        if (!cancel) setLoadingS(false);
      }
    })();

    return () => {
      cancel = true;
    };
  }, [teamId, league, season]);

  /* ===== группировка календаря по турам ===== */
  const groupedSchedule = useMemo(() => {
    if (!schedule?.length) return [];
    const groups = {};
    for (const m of schedule) {
      const rawWeek = m.week ?? m.round_label ?? m.round ?? "—";
      const key =
        rawWeek == null || rawWeek === "" ? "—" : String(rawWeek).trim();
      if (!groups[key]) groups[key] = [];
      groups[key].push(m);
    }
    const sortByDate = (a, b) => {
      const da = new Date(a.date || a.datetime || 0);
      const db = new Date(b.date || b.datetime || 0);
      return da - db;
    };
    const entries = Object.entries(groups).map(([week, matches]) => [
      week,
      matches.sort(sortByDate),
    ]);
    entries.sort((a, b) => {
      const na = parseInt(a[0], 10);
      const nb = parseInt(b[0], 10);
      if (Number.isFinite(na) && Number.isFinite(nb)) return na - nb;
      return String(a[0]).localeCompare(String(b[0]));
    });
    return entries;
  }, [schedule]);

  /* ===== загрузка данных для разворота календаря через buildMatchPack() ===== */
  const loadExpandedPack = useCallback(
    async (m) => {
      if (!m?.fixture_id) return;
      const key = m.fixture_id;

      setExpandedData((prev) => ({
        ...prev,
        [key]: {
          ...(prev[key] || {}),
          loading: true,
          error: null,
        },
      }));

      try {
        const pack = await buildMatchPack({ match: m, league });
        setExpandedData((prev) => ({
          ...prev,
          [key]: {
            ...pack,
            loaded: true,
            loading: false,
            error: null,
          },
        }));
      } catch (e) {
        setExpandedData((prev) => ({
          ...prev,
          [key]: {
            ...(prev[key] || {}),
            loading: false,
            error: e.message || String(e),
          },
        }));
      }
    },
    [league]
  );

  const handleToggleSchedule = useCallback(
    (m) => {
      if (!m?.fixture_id) return;
      setExpandedId((prev) => {
        const next = prev === m.fixture_id ? null : m.fixture_id;
        if (next === m.fixture_id) {
          loadExpandedPack(m);
        }
        return next;
      });
    },
    [loadExpandedPack]
  );

  const titleTeamName = useMemo(
    () => overview?.team_name || "Команда",
    [overview]
  );

  return (
    <div className="max-w-6xl mx-auto px-4 pb-24 pt-4 space-y-6">
      {/* HERO / HEADER – в стиле EdgeScore, как таблица/подборки */}
      <section className={`relative overflow-hidden rounded-3xl ${BG_PANEL} border ${BORDER_GLASS} text-slate-50 shadow-[0_32px_120px_rgba(0,0,0,0.9)]`}>
        {/* мягкие блики */}
        <div className="pointer-events-none absolute -left-28 top-[-40px] h-72 w-72 rounded-full bg-fuchsia-500/25 blur-3xl" />
        <div className="pointer-events-none absolute -right-32 bottom-[-60px] h-80 w-80 rounded-full bg-violet-500/20 blur-3xl" />
        <div className="relative px-6 py-5 sm:px-8 sm:py-6">
          <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            <div className="flex items-center gap-4 min-w-0">
              <span className="inline-flex h-14 w-14 items-center justify-center rounded-2xl border border-glass bg-surface-2/80 shadow-[0_18px_70px_rgba(0,0,0,0.9)] overflow-hidden">
                <SafeImg
                  src={teamLogo(teamId)}
                  alt={titleTeamName}
                  className="h-10 w-10 object-contain"
                />
              </span>
              <div className="min-w-0 space-y-1">
                <div className="text-xs uppercase tracking-[0.24em] text-slate-400">
                  Команда • {season}
                </div>
                <h1 className="text-2xl sm:text-3xl font-black leading-tight truncate">
                  {titleTeamName}
                </h1>
                <div className="flex flex-wrap items-center gap-2 text-xs text-slate-400">
                  <span className="inline-flex items-center gap-1.5 rounded-full border border-glass bg-surface-2/80 px-2.5 py-1">
                    <SafeImg
                      src={leagueLogo(league)}
                      className="w-4 h-4 object-contain"
                      alt=""
                      fallback="league"
                    />
                    <span className="font-medium text-slate-100">
                      {league}
                    </span>
                    <span className="text-slate-400/90">•</span>
                    <span>{season}</span>
                  </span>
                </div>
              </div>
            </div>

            <div className="flex flex-col items-end gap-3 sm:flex-row sm:items-center sm:gap-6">
              <div className="flex items-center gap-2">
                <span className="text-xs uppercase tracking-[0.22em] text-slate-400">
                  Сезон
                </span>
                <select
                  value={season}
                  onChange={(e) => handleSeasonChange(e.target.value)}
                  className="rounded-xl border border-glass bg-surface-2 px-3 py-1.5 text-sm font-medium text-white shadow-sm focus:outline-none focus:ring-2 focus:ring-fuchsia-400/60"
                >
                  {SEASONS.map((s) => (
                    <option key={s} value={s} className="bg-surface-1">
                      {s}
                    </option>
                  ))}
                </select>
              </div>

              {overview?.rank != null && (
                <div className="inline-flex items-center gap-2 rounded-full border border-glass bg-surface-2/80 px-3 py-1 text-xs text-slate-300">
                  <span className="uppercase tracking-[0.18em] text-slate-500">
                    Место в лиге
                  </span>
                  <span className="font-semibold text-amber-300 tabular-nums">
                    {overview.rank}
                  </span>
                </div>
              )}
            </div>
          </div>

          {/* табы – вариант 2 */}
          <Segmented value={tab} onChange={setTab} />
        </div>
      </section>

      {/* ТАБЫ */}
      {tab === "stats" ? (
        <section className="space-y-4">
          {loadingO ? (
            <>
              <div className={`${BG_PANEL} h-28 rounded-3xl border ${BORDER_GLASS} animate-pulse`} />
              <div className={`${BG_PANEL} h-40 rounded-3xl border ${BORDER_GLASS} animate-pulse`} />
            </>
          ) : overview ? (
            <>
              {/* Верхний ряд KPI */}
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                <KpiCard
                  title="Матчей"
                  value={overview.matches_played ?? "—"}
                  icon={
                    <svg
                      viewBox="0 0 24 24"
                      className="h-4 w-4"
                      fill="currentColor"
                    >
                      <path d="M7 3h10a2 2 0 0 1 2 2v3H5V5a2 2 0 0 1 2-2zm-2 8h14v6a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-6zm4 1v6h2v-6H9zm4 0v6h2v-6h-2z" />
                    </svg>
                  }
                />
                <KpiCard
                  title="Очки / Место"
                  value={overview.points != null ? `${overview.points}` : "—"}
                  sub={overview.rank != null ? `Ранг: ${overview.rank}` : undefined}
                  icon={
                    <svg
                      viewBox="0 0 24 24"
                      className="h-4 w-4"
                      fill="currentColor"
                    >
                      <path d="M12 2l2.39 4.84 5.34.78-3.86 3.76.91 5.32L12 14.77 6.22 16.7l.91-5.32L3.27 7.62l5.34-.78L12 2z" />
                    </svg>
                  }
                />
                <KpiCard
                  title="В-Н-П"
                  value={`${overview.wins ?? 0}-${overview.draws ?? 0}-${overview.losses ?? 0}`}
                  sub="Распределение результатов"
                  icon={
                    <svg
                      viewBox="0 0 24 24"
                      className="h-4 w-4"
                      fill="currentColor"
                    >
                      <path d="M3 3h18v4H3zM3 10h18v4H3zM3 17h18v4H3z" />
                    </svg>
                  }
                />
                <KpiCard
                  title="Голы (за / проп.)"
                  value={`${overview.goals_for ?? 0} / ${
                    overview.goals_against ?? 0
                  }`}
                  sub={`Разница: ${overview.goal_diff ?? 0}`}
                  icon={
                    <svg
                      viewBox="0 0 24 24"
                      className="h-4 w-4"
                      fill="currentColor"
                    >
                      <path d="M12 5a7 7 0 100 14 7 7 0 000-14zm-1 10l-3-3 1.41-1.41L11 11.17l3.59-3.58L16 9l-5 6z" />
                    </svg>
                  }
                />
              </div>

              {/* Расширенные метрики */}
              <div className={`rounded-3xl border ${BORDER_GLASS} bg-surface-1/90 shadow-[0_24px_80px_rgba(0,0,0,0.9)] p-5`}>
                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                  <KpiCard
                    title="Голы за игру"
                    value={fmtNum(overview.goals_per_game, 2)}
                  />
                  <KpiCard
                    title="Пропускает за игру"
                    value={fmtNum(overview.conceded_per_game, 2)}
                  />
                  <KpiCard
                    title="xG за игру"
                    value={fmtNum(overview.xg_per_game, 2)}
                  />
                  <KpiCard
                    title="xGA за игру"
                    value={fmtNum(overview.xga_per_game, 2)}
                  />
                  <KpiCard
                    title="Удары (сред.)"
                    value={fmtNum(overview.shots_avg, 1)}
                  />
                  <KpiCard
                    title="Владение (сред.)"
                    value={
                      overview.possession_avg != null
                        ? `${fmtNum(overview.possession_avg, 1)}%`
                        : "—"
                    }
                  />
                  <KpiCard
                    title="Темп (уд./игру)"
                    value={fmtNum(overview.tempo_shots_per_game, 1)}
                  />
                </div>
              </div>
            </>
          ) : (
            <div className={`${BG_PANEL} rounded-3xl border ${BORDER_GLASS} p-6 text-sm ${TEXT_MUTED}`}>
              Нет данных по сводке.
            </div>
          )}
        </section>
      ) : tab === "results" ? (
        <section className="space-y-3">
          {loadingR && (
            <div className={`${BG_PANEL} h-28 rounded-3xl border ${BORDER_GLASS} animate-pulse`} />
          )}

          {!loadingR && results.length === 0 && (
            <div className={`${BG_PANEL} rounded-3xl border ${BORDER_GLASS} p-6 text-sm ${TEXT_MUTED}`}>
              Нет сыгранных матчей.
            </div>
          )}

          {!loadingR &&
            results.map((m, idx) => {
              const sideHome = m.side === "H";
              const leftId = sideHome ? teamId : m.opponent_id;
              const rightId = sideHome ? m.opponent_id : teamId;
              const leftName = sideHome ? titleTeamName : m.opponent_name;
              const rightName = sideHome ? m.opponent_name : titleTeamName;
              const score =
                m.team_goals != null && m.opp_goals != null
                  ? `${m.team_goals}–${m.opp_goals}`
                  : "—";

              const res = resultForTeam(
                {
                  home_team_id: sideHome ? teamId : m.opponent_id,
                  away_team_id: sideHome ? m.opponent_id : teamId,
                  home_goals: sideHome ? m.team_goals : m.opp_goals,
                  away_goals: sideHome ? m.opp_goals : m.team_goals,
                },
                teamId
              );

              return (
                <div
                  key={
                    m.fixture_id ||
                    `${m.home_team_id}-${m.away_team_id}-${idx}`
                  }
                  className={`${BG_PANEL} rounded-3xl border ${BORDER_GLASS} px-4 py-3 shadow-[0_18px_60px_rgba(0,0,0,0.85)]`}
                >
                  <div
                    onClick={() => {
                      if (!m.fixture_id) return;
                      const params = new URLSearchParams({
                        league,
                        season,
                        fixture_id: String(m.fixture_id),
                      });
                      // Переход на страницу MatchesPageV3 с нужным матчем
                      navigate(`/matches?${params.toString()}`);
                    }}
                    className="grid grid-cols-[minmax(0,1fr)_140px_minmax(0,1fr)] items-center gap-4 cursor-pointer"
                  >
                    {/* LEFT */}
                    <div className="flex items-center gap-3 min-w-0">
                      <LogoBadge id={leftId} name={leftName} />
                      <span className="text-[15px] font-medium text-slate-50 truncate">
                        {leftName}
                      </span>
                    </div>

                    {/* CENTER */}
                    <div className="flex flex-col items-center gap-1">
                      <span className="text-[12px] font-medium text-slate-300 tabular-nums">
                        {m.datetime || toDDMM(m.date)}
                      </span>
                      <span className="text-[15px] font-semibold text-slate-50 tabular-nums">
                        {score}
                      </span>
                      <div
                        className={`mt-1 inline-flex items-center rounded-full border px-2 py-[2px] text-[10px] ${resultBadgeClasses(
                          res
                        )}`}
                      >
                        {res === "W"
                          ? "Победа"
                          : res === "L"
                          ? "Поражение"
                          : "Ничья"}
                      </div>
                    </div>

                    {/* RIGHT */}
                    <div className="flex items-center gap-3 min-w-0 justify-end">
                      <span className="text-[15px] font-medium text-slate-50 truncate text-right">
                        {rightName}
                      </span>
                      <LogoBadge id={rightId} name={rightName} />
                    </div>
                  </div>
                </div>
              );
            })}
        </section>
      ) : tab === "schedule" ? (
        <section className="space-y-4">
          {loadingS && (
            <div className={`${BG_PANEL} h-28 rounded-3xl border ${BORDER_GLASS} animate-pulse`} />
          )}

          {!loadingS && groupedSchedule.length === 0 && (
            <div className={`${BG_PANEL} rounded-3xl border ${BORDER_GLASS} p-6 text-sm ${TEXT_MUTED}`}>
              Нет будущих матчей.
            </div>
          )}

          {!loadingS &&
            groupedSchedule.map(([week, matches]) => (
              <div
                key={week}
                className={`${BG_PANEL} rounded-3xl border ${BORDER_GLASS} p-4 shadow-[0_22px_80px_rgba(0,0,0,0.92)]`}
              >
                <div className="flex items-center justify-between gap-3 mb-3">
                  <div className="text-[11px] uppercase tracking-[0.28em] text-slate-400">
                    Тур {week}
                  </div>
                </div>
                <div className="space-y-3">
                  {matches.map((m, idx) => {
                    const isHome = Number(m.home_team_id) === teamId;
                    const leftId = isHome ? m.home_team_id : m.away_team_id;
                    const rightId = isHome ? m.away_team_id : m.home_team_id;
                    const leftName = isHome ? m.home_team : m.away_team;
                    const rightName = isHome ? m.away_team : m.home_team;

                    return (
                      <div
                        key={
                          m.fixture_id ||
                          `${m.home_team_id}-${m.away_team_id}-${idx}`
                        }
                        className="rounded-2xl border border-glass bg-surface-1/80 px-4 py-3"
                      >
                        <div
                          onClick={() => handleToggleSchedule(m)}
                          className="grid grid-cols-[minmax(0,1fr)_140px_minmax(0,1fr)] items-center gap-4 cursor-pointer"
                        >
                          {/* LEFT (своя команда) */}
                          <div className="flex items-center gap-3 min-w-0">
                            <LogoBadge id={leftId} name={leftName} />
                            <span className="text-[15px] font-medium text-slate-50 truncate">
                              {leftName}
                            </span>
                          </div>

                          {/* CENTER */}
                          <div className="flex flex-col items-center gap-1">
                            <span className="text-[12px] font-medium text-slate-300 tabular-nums">
                              {m.datetime || toDDMM(m.date)}
                            </span>
                            {m.round_label && (
                              <span className="text-[11px] text-slate-500">
                                Round{" "}
                                {String(m.round_label).replace(/\D/g, "")}
                              </span>
                            )}
                          </div>

                          {/* RIGHT (оппонент) */}
                          <div className="flex items-center gap-3 min-w-0 justify-end">
                            <span className="text-[15px] font-medium text-slate-50 truncate text-right">
                              {rightName}
                            </span>
                            <LogoBadge id={rightId} name={rightName} />
                          </div>
                        </div>

                        {/* раскрытие только в календаре */}
                        {expandedId === m.fixture_id && (
                          <div className="mt-3">
                            <MatchInsightsPanelFull
                              pack={expandedData[m.fixture_id]}
                              teamId={teamId}
                              home={m.home_team}
                              away={m.away_team}
                              onOpenMatchModal={(fixture_id, match) => {
                                const sideHomeInner =
                                  Number(match.home_team_id) === Number(teamId);

                                const seed = {
                                  side: sideHomeInner ? "H" : "A",
                                  team_name: sideHomeInner
                                    ? match.home_team
                                    : match.away_team,
                                  team_id: sideHomeInner
                                    ? match.home_team_id
                                    : match.away_team_id,
                                  opponent_name: sideHomeInner
                                    ? match.away_team
                                    : match.home_team,
                                  opponent_id: sideHomeInner
                                    ? match.away_team_id
                                    : match.home_team_id,
                                  team_goals: Number(match.home_goals),
                                  opp_goals: Number(match.away_goals),
                                  date: match.date,
                                };

                                setOpenedMatch({ fixture_id, seed });
                              }}
                            />
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
        </section>
      ) : null}

      {/* === MODAL ТОЛЬКО ДЛЯ РЕЗУЛЬТАТОВ / КАЛЕНДАРЯ === */}
      {openedMatch?.fixture_id && openedMatch.seed && (
        <OneMatchOverlay
          fixtureId={openedMatch.fixture_id}
          seed={openedMatch.seed}
          league={league}
          season={season}
          onClose={() => setOpenedMatch(null)}
        />
      )}
    </div>
  );
}
