// src/pages/TeamPageaAll.jsx
import React, {
  useEffect,
  useMemo,
  useState,
  lazy,
  Suspense,
  useCallback,
} from "react";
import clsx from "clsx";
import { useParams, useSearchParams, useNavigate, useLocation } from "react-router-dom";
import { authFetch } from "@/lib/authFetch";
import { teamLogoMap } from "@/constants/teamLogoMap";
import { useAuth } from "@/auth/AuthContext.jsx";
import { http } from "@/lib/http.js";
import { hasPilotFullAccess, shouldHideMonetization } from "@/lib/pilotAccess.js";

import FootballPitchPro from "@/components/FootballPitchPro";
import PlayerCard from "@/components/PlayerCard";
import {
  normalizeLineups,
  autoLayout,
  layoutFromGrid,
  buildMetaMaps,
} from "@/lib/lineupsLayout";
import { loadFavorites, saveFavorites } from "@/lib/favoritesStorage.js";
import MatchInsightsPanelFull from "@/components/MatchInsightsPanelFull";
import { buildMatchPack } from "@/lib/matchInsights";
import SegmentedTabs from "@/components/ui/SegmentedTabs";

// календарь-пак

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

const SafeImg = ({ src, alt = "", className = "", fallback = "team", fallbackSrc = "" }) => {
  const onErr = (e) => {
    if (fallbackSrc && e.currentTarget.dataset.fallbackTried !== "1") {
      e.currentTarget.dataset.fallbackTried = "1";
      e.currentTarget.src = fallbackSrc;
      return;
    }
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
      data-fallback-tried="0"
      loading="lazy"
      decoding="async"
      draggable={false}
    />
  );
};

const teamLogo = (id) =>
  id ? `/icons/team_logos/${id}.png` : FALLBACK_SVG.team;
const teamLogoFallback = (id, name = "") =>
  id ? `https://media.api-sports.io/football/teams/${id}.png` : fallbackTeam(name);
const leagueLogo = (name) =>
  name ? `/icons/${String(name).replace(/\s/g, "_")}.png` : FALLBACK_SVG.league;
const playerPhoto = (pid) => (pid ? `/icons/player_photos/${pid}.png` : "");
const fmtNum = (v, d = 0) => (v == null ? "—" : Number(v).toFixed(d));
const toNumSafe = (v) => {
  if (v == null) return null;
  const s = String(v).replace("%", "").replace(",", ".").trim();
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
};

/* ===== логотипы как в MatchSchedulePage ===== */
const teamLogoPath = (id) => (id ? `/icons/team_logos/${id}.png` : null);
const fallbackTeam = (name) =>
  teamLogoMap[name] || "/icons/team_logos/default.png";
const logoSafe = (id, name) => teamLogoPath(id) || fallbackTeam(name);

const LogoBadge = ({ id, name, size = 24, imgSize = null }) => (
  <span
    className="inline-flex items-center justify-center rounded-md border border-glass bg-surface-2/80 shadow-sm"
    style={{ width: size, height: size }}
  >
    <SafeImg
      src={logoSafe(id, name)}
      alt=""
      fallback="team"
      fallbackSrc={teamLogoFallback(id, name)}
      className="object-contain"
      style={{
        width: imgSize != null ? imgSize : Math.max(14, Math.round(size * 0.65)),
        height: imgSize != null ? imgSize : Math.max(14, Math.round(size * 0.65)),
      }}
    />
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

const parseMatchDate = (m) => {
  const src = m?.datetime || m?.date;
  if (!src) return null;
  const d = new Date(src);
  if (!Number.isNaN(d.getTime())) return d;
  if (typeof src === "string") {
    const d2 = new Date(src.replace(" ", "T"));
    if (!Number.isNaN(d2.getTime())) return d2;
  }
  return null;
};

const formatHHMM = (d) => {
  if (!d) return "";
  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  return `${hh}:${mm}`;
};

const getScheduleStatus = (d) => {
  if (!d) {
    return { label: "Скоро", className: "text-white/60" };
  }
  const now = new Date();
  const diffMs = d - now;
  const diffHours = diffMs / (1000 * 60 * 60);
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  const isToday = d.toDateString() === now.toDateString();
  const tomorrow = new Date(now);
  tomorrow.setDate(now.getDate() + 1);
  const isTomorrow = d.toDateString() === tomorrow.toDateString();

  if (diffMs <= 0) {
    return { label: "Скоро", className: "text-white/60" };
  }
  if (diffHours <= 3) {
    return { label: `Через ${Math.max(1, Math.round(diffHours))} ч`, className: "text-amber-300" };
  }
  if (isToday) {
    return { label: "Сегодня", className: "text-[#8B5CF6]" };
  }
  if (isTomorrow) {
    return { label: "Завтра", className: "text-white/70" };
  }
  if (diffDays >= 1 && diffDays <= 7) {
    return { label: `Через ${diffDays} дн`, className: "text-emerald-300" };
  }
  return { label: `Через ${Math.max(1, diffDays)} дн`, className: "text-white/60" };
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

const LEAGUE_ID_MAP = {
  premierleague: 39,
  epl: 39,
  laliga: 140,
  liga: 140,
  "laligasantander": 140,
  "la-liga": 140,
  seriea: 135,
  bundesliga: 78,
  ligue1: 61,
  "uefachampionsleague": 2,
  championsleague: 2,
  ucl: 2,
};
const INTERNATIONAL_LEAGUES = new Set([
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

const TEAM_SCHEDULE_LIVE_HINTS = [
  "1H",
  "2H",
  "HT",
  "ET",
  "P",
  "PEN",
  "LIVE",
  "FIRST HALF",
  "SECOND HALF",
  "HALF TIME",
  "HALFTIME",
  "BREAK TIME",
  "PENALTY",
];

const isTeamScheduleLive = (match) => {
  const status = String(match?.status_short || match?.status || "")
    .trim()
    .toUpperCase();
  if (!status) return false;
  return TEAM_SCHEDULE_LIVE_HINTS.some((hint) =>
    hint.length <= 3 ? status === hint : status.includes(hint)
  );
};

const normalizeLeagueKey = (value) =>
  String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9а-я]+/gi, "");

const resolveTeamLeagueName = (overview) =>
  overview?.league ||
  overview?.league_name ||
  overview?.competition ||
  overview?.tournament ||
  overview?.league_title ||
  "";

const leagueIdFromName = (leagueName) => {
  const key = normalizeLeagueKey(leagueName);
  if (!key) return null;
  return LEAGUE_ID_MAP[key] || null;
};

const rankFromValue = (val) => {
  if (Number.isFinite(Number(val))) return Number(val);
  if (val && typeof val === "object") {
    const picks = [
      val.rank,
      val.position,
      val.place,
      val.standing,
      val.table_position,
    ];
    const hit = picks.find((v) => Number.isFinite(Number(v)));
    return Number.isFinite(Number(hit)) ? Number(hit) : null;
  }
  return null;
};

const pickLeagueRank = (overview, leagueName) => {
  if (!overview) return null;
  const target = normalizeLeagueKey(leagueName);
  const targetId = leagueIdFromName(leagueName);
  const ownLeague =
    normalizeLeagueKey(
      overview.league ||
        overview.league_name ||
        overview.competition ||
        overview.tournament ||
        ""
    ) || null;
  const ownLeagueId = Number.isFinite(Number(overview.league_id))
    ? Number(overview.league_id)
    : null;
  if (target && ownLeague && target === ownLeague) {
    return Number.isFinite(Number(overview.rank)) ? Number(overview.rank) : null;
  }
  if (targetId != null && ownLeagueId != null && targetId === ownLeagueId) {
    return Number.isFinite(Number(overview.rank)) ? Number(overview.rank) : null;
  }

  const mapCandidates = [
    overview.rank_by_league,
    overview.rank_by_league_id,
    overview.league_rank_id_map,
    overview.league_rank_map,
    overview.positions_by_league,
    overview.standings_by_league,
    overview.league_positions,
    overview.league_ranks,
  ];
  for (const mp of mapCandidates) {
    if (!mp || typeof mp !== "object") continue;
    for (const key of Object.keys(mp)) {
      const keyNum = Number(key);
      if (Number.isFinite(keyNum) && targetId != null && keyNum === targetId) {
        const v = rankFromValue(mp[key]);
        if (v != null) return v;
      }
      if (normalizeLeagueKey(key) === target) {
        const v = rankFromValue(mp[key]);
        if (v != null) return v;
      }
    }
  }

  const listCandidates = [
    overview.leagues,
    overview.tournaments,
    overview.competitions,
    overview.standings,
    overview.rankings,
  ];
  for (const arr of listCandidates) {
    if (!Array.isArray(arr)) continue;
    for (const item of arr) {
      const name =
        item?.league ||
        item?.league_name ||
        item?.competition ||
        item?.tournament ||
        item?.name ||
        "";
      const itemId = Number.isFinite(Number(item?.league_id))
        ? Number(item.league_id)
        : Number.isFinite(Number(item?.competition_id))
        ? Number(item.competition_id)
        : Number.isFinite(Number(item?.id))
        ? Number(item.id)
        : null;
      if (targetId != null && itemId != null && itemId === targetId) {
        const v = rankFromValue(item);
        if (v != null) return v;
      }
      if (normalizeLeagueKey(name) !== target) continue;
      const v = rankFromValue(item);
      if (v != null) return v;
    }
  }

  const hasMulti =
    listCandidates.some((arr) => Array.isArray(arr) && arr.length > 1) ||
    mapCandidates.some((mp) => mp && typeof mp === "object" && Object.keys(mp).length > 1);

  if (!target || (ownLeague && target === ownLeague && !hasMulti)) {
    return Number.isFinite(Number(overview.rank)) ? Number(overview.rank) : null;
  }
  return null;
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
  if (r === "W") return "bg-emerald-500/15 text-[#0FB77A] border-emerald-400/40";
  if (r === "L") return "bg-rose-500/12 text-rose-300/90 border-rose-400/30";
  return "bg-slate-400/12 text-slate-300 border-slate-400/20";
}

const InlineMatchStats = ({ match, accentSide }) => {
  if (!match) {
    return (
      <div className="text-sm text-slate-400">
        Нет данных по статистике матча.
      </div>
    );
  }

  return (
    <div className="mt-1">
      <Suspense fallback={<div className="text-muted text-sm">Загружаем…</div>}>
        <MatchStatsBlockV3 stats={match} accentSide={accentSide} />
      </Suspense>
    </div>
  );
};

const ForecastHero = ({ match, locked = false, onUpgrade, blurBody = false }) => {
  if (!match) return null;
  const p1 = toNumSafe(match.p_home);
  const px = toNumSafe(match.p_draw);
  const p2 = toNumSafe(match.p_away);
  const pov = toNumSafe(match.p_over25);
  const pun = toNumSafe(match.p_under25);
  const hasOutcome = [p1, px, p2].some((v) => v != null);
  const hasTotal = [pov, pun].some((v) => v != null);

  if (!hasOutcome && !hasTotal && !match.rec_decision) {
    return (
      <div className="text-sm text-white/60">
        Нет данных по прогнозу модели.
      </div>
    );
  }

  const toPct = (v) => (v == null ? "—" : `${Math.round(v * 100)}%`);
  const outcomes = [
    { label: "П1", p: p1 },
    { label: "Х", p: px },
    { label: "П2", p: p2 },
  ].filter((o) => o.p != null);
  const top = outcomes.length
    ? outcomes.reduce((a, b) => (a.p >= b.p ? a : b))
    : null;

  const strength = match.signal_strength || "none";
  const strengthLabel =
    strength === "strong"
      ? "Сильный сигнал"
      : strength === "medium"
      ? "Средний сигнал"
      : strength === "weak"
      ? "Слабый сигнал"
      : "Сигнала нет";

  const isBet = match.rec_decision === "BET";
  const decision = isBet ? "Ставка" : "Пропуск";
  const pickLabel = match.signal_pick || (top ? top.label : null);

  const verdictLine =
    top?.label === "П1"
      ? "Модель видит умеренное преимущество хозяев."
      : top?.label === "П2"
      ? "Модель видит умеренное преимущество гостей."
      : top?.label === "Х"
      ? "Модель видит сценарий равной игры."
      : null;

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2 text-[11px] text-white/60">
          <span className="uppercase tracking-[0.18em] text-white/50">
            {locked ? "🔒 Прогноз модели" : "Прогноз модели"}
          </span>
          <span className="text-white/55">• {strengthLabel}</span>
          <span className="text-white/55">• {decision}</span>
        </div>
      </div>

      {locked ? (
        <div className="relative overflow-hidden rounded-[20px] border border-white/10 bg-[linear-gradient(135deg,rgba(13,18,29,0.98),rgba(20,26,39,0.96))] px-5 py-5 shadow-[0_16px_42px_rgba(0,0,0,0.34)]">
          <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(168,85,247,0.12),transparent_34%),radial-gradient(circle_at_bottom_right,rgba(59,130,246,0.08),transparent_26%)]" />
          <div className="relative z-10 flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div className="space-y-2">
              <div className="text-[11px] font-semibold uppercase tracking-[0.24em] text-white/45">
                EdgeScore Premium
              </div>
              <div className="text-[22px] font-semibold tracking-tight text-white">
                Открой прогноз модели и полный разбор матча
              </div>
              <div className="max-w-[720px] text-sm leading-relaxed text-white/68">
                Подписка открывает итоговый сигнал, вероятности 1X2 и тоталов, сценарий игры и расширенную аналитику по форме команд.
              </div>
            </div>
            <button
              type="button"
              onClick={onUpgrade}
              className="inline-flex min-h-11 items-center justify-center rounded-2xl border border-white/12 bg-[#0d111b]/96 px-5 py-3 text-sm font-semibold text-white shadow-[0_16px_35px_rgba(0,0,0,0.34),inset_0_1px_0_rgba(255,255,255,0.12)] transition hover:bg-[#121827] hover:shadow-[0_20px_45px_rgba(0,0,0,0.42),inset_0_1px_0_rgba(255,255,255,0.16)]"
            >
              Оформить подписку
            </button>
          </div>
        </div>
      ) : null}

      {!locked ? (
        <div className={blurBody ? "pointer-events-none select-none blur-md opacity-10" : ""}>
          {isBet && pickLabel && (
            <div className="text-[30px] font-semibold text-white drop-shadow-[0_0_18px_rgba(139,92,246,0.25)]">
              {pickLabel} — {top ? toPct(top.p) : "—"}
            </div>
          )}
          {!isBet && (
            <div className="text-[24px] font-semibold text-white/90">
              Пропуск
            </div>
          )}
          {verdictLine && (
            <div className="text-[12px] text-white/65">{verdictLine}</div>
          )}

          {hasOutcome && (
            <div className="flex flex-wrap gap-4 text-[12px] text-white/70">
              <span>П1 {toPct(p1)}</span>
              <span>Х {toPct(px)}</span>
              <span>П2 {toPct(p2)}</span>
            </div>
          )}

          {hasTotal && (
            <div className="flex flex-wrap gap-4 text-[12px] text-white/70">
              <span>ТБ 2.5 {toPct(pov)}</span>
              <span>ТМ 2.5 {toPct(pun)}</span>
            </div>
          )}
          {!isBet && hasOutcome && (
            <div className="text-[11px] text-white/55 mt-1">
              Наиболее вероятный исход: П1 {toPct(p1)} / Х {toPct(px)} / П2 {toPct(p2)}
            </div>
          )}
          {!isBet && (
            <div className="text-[12px] text-white/55 mt-1">
              Разницы по форме и xG недостаточно, линия близка к справедливой — лучше пропустить.
            </div>
          )}
        </div>
      ) : null}
    </div>
  );
};

const VenueFilterTabs = ({ value, onChange }) => (
  <SegmentedTabs
    size="sm"
    items={[
      { key: "all", label: "Общая" },
      { key: "home", label: "Дома" },
      { key: "away", label: "В гостях" },
    ]}
    value={value}
    onChange={onChange}
    listClassName="gap-6"
    buttonClassName="tracking-wide"
    activeClassName="text-white"
  />
);

const AvgCompareRow = ({ label, left, right, isPercent = false, decimals = 1 }) => {
  const l = toNumSafe(left);
  const r = toNumSafe(right);
  if (l == null && r == null) return null;
  const total = Math.max(Math.abs(l || 0) + Math.abs(r || 0), 1);
  const minWidth = 8;
  const lw = l != null ? Math.max((Math.abs(l) / total) * 100, minWidth) : 0;
  const rw = r != null ? Math.max((Math.abs(r) / total) * 100, minWidth) : 0;
  const fmt = (v) =>
    v == null ? "—" : isPercent ? `${fmtNum(v, 0)}%` : fmtNum(v, decimals);

  return (
    <div className="flex items-center justify-between gap-3">
      <div className="w-[72px] text-[12px] text-white/85 tabular-nums text-left">{fmt(l)}</div>
      <div className="flex-1">
        <div className="text-[11px] text-white/45 text-center mb-1">{label}</div>
        <div className="relative h-[6px] rounded-full bg-white/10 overflow-hidden w-[85%] mx-auto">
          <div className="absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-white/12" />
          <div
            className="absolute right-1/2 top-0 h-full rounded-full bg-gradient-to-r from-[#8B5CF6] to-[#7C3AED] shadow-[0_0_8px_rgba(139,92,246,0.25)]"
            style={{ width: `${lw}%` }}
          />
          <div
            className="absolute left-1/2 top-0 h-full rounded-full bg-gradient-to-l from-sky-400/80 to-teal-400/70"
            style={{ width: `${rw}%` }}
          />
        </div>
      </div>
      <div className="w-[72px] text-[12px] text-white/85 tabular-nums text-right">{fmt(r)}</div>
    </div>
  );
};

const CompactMetricRow = ({ label, left, right, isPercent = false, accentSide = "left" }) => {
  const l = toNumSafe(left);
  const r = toNumSafe(right);
  if (l == null && r == null) return null;
  const max = Math.max(Math.abs(l || 0), Math.abs(r || 0), 1);
  const minWidth = 12;
  const lw = l != null ? Math.max((Math.abs(l) / max) * 100, minWidth) : 0;
  const rw = r != null ? Math.max((Math.abs(r) / max) * 100, minWidth) : 0;
  const leftAccent = accentSide === "left";
  const fmt = (v) =>
    v == null ? "—" : isPercent ? `${fmtNum(v, 0)}%` : fmtNum(v, 2);

  return (
    <div className="flex items-center justify-between gap-3">
      <div className="w-[80px] text-[13px] text-white/90 tabular-nums text-left">{fmt(l)}</div>
      <div className="flex-1">
        <div className="text-[11px] text-white/50 text-center mb-1">{label}</div>
        <div className="relative h-[4px] rounded-full bg-white/8 overflow-hidden w-[85%] mx-auto">
          <div className="absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-white/15" />
          <div
            className="absolute right-1/2 top-0 h-full rounded-full transition-all duration-300 ease-out bg-gradient-to-r from-[#8B5CF6] to-[#7C3AED] shadow-[0_0_8px_rgba(139,92,246,0.35)]"
            style={{ width: `${lw}%` }}
          />
          <div
            className="absolute left-1/2 top-0 h-full rounded-full transition-all duration-300 ease-out bg-gradient-to-l from-sky-400/80 to-teal-400/70 shadow-[0_0_8px_rgba(56,189,248,0.22)]"
            style={{ width: `${rw}%` }}
          />
        </div>
      </div>
      <div className="w-[80px] text-[13px] text-white/90 tabular-nums text-right">{fmt(r)}</div>
    </div>
  );
};

const InlineLineups = ({ match, lineups }) => {
  if (!lineups) {
    return (
      <div className="text-sm text-slate-400">
        Данные по составам недоступны.
      </div>
    );
  }

  const norm = normalizeLineups(lineups, match);
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

  const metaMaps = buildMetaMaps(norm);
  const homeId = norm?.home?.team_id || match?.home_team_id;
  const awayId = norm?.away?.team_id || match?.away_team_id;
  const homeTeam = match?.home_team || norm?.home?.team_name || "—";
  const awayTeam = match?.away_team || norm?.away?.team_name || "—";

  const allRated = [...homePins, ...awayPins].filter(
    (p) => p.rating != null && Number.isFinite(Number(p.rating))
  );
  const mvp = allRated.length
    ? allRated.reduce((a, b) =>
        Number(a.rating) >= Number(b.rating) ? a : b
      )
    : null;
  const mvpId = mvp?.player_id || mvp?.id || null;

  const eventsEnriched = computeScoreProgress(norm?.events || [], homeId, awayId);
  const groups = groupEventsByPeriod(eventsEnriched);
  const subs = collectSubs(norm?.events || []);
  const subsHome = subs.filter((s) => s.team_id === homeId);
  const subsAway = subs.filter((s) => s.team_id === awayId);

  const groupSubsByMinute = (list) => {
    const map = new Map();
    for (const s of list) {
      const key = Number(s.minute) || 0;
      if (!map.has(key)) map.set(key, []);
      map.get(key).push(s);
    }
    return [...map.entries()]
      .sort((a, b) => a[0] - b[0])
      .map(([minute, items]) => ({ minute, items }));
  };

  const subsHomeGrouped = groupSubsByMinute(subsHome);
  const subsAwayGrouped = groupSubsByMinute(subsAway);

  const benchHome = norm?.home?.bench || [];
  const benchAway = norm?.away?.bench || [];

  const formatName = (p) => {
    const name = p?.name || p?.player_name || "";
    const parts = name.trim().split(" ");
    return parts.slice(-1).join(" ") || name || `#${p?.number || "?"}`;
  };

  const renderBench = (list, alignRight = false) =>
    list.length ? (
      <div
        className={`grid grid-cols-2 gap-3 ${
          alignRight ? "text-right" : "text-left"
        }`}
      >
        {list.map((p, idx) => (
          <div
            key={`${p.player_id || idx}`}
            className={`inline-flex items-center gap-2 text-[12px] text-slate-200/85 ${
              alignRight ? "justify-end" : "justify-start"
            }`}
          >
            {!alignRight && (
              <AvatarCircle
                pid={p.player_id}
                number={p.number}
                ring="ring-white/10"
              />
            )}
            <span className="truncate max-w-[140px]">{formatName(p)}</span>
            {alignRight && (
              <AvatarCircle
                pid={p.player_id}
                number={p.number}
                ring="ring-white/10"
              />
            )}
          </div>
        ))}
      </div>
    ) : (
      <div className="text-xs text-slate-400">—</div>
    );

  return (
    <div className="mt-3 space-y-4">
      <FootballPitchPro
        homePlayers={homePins}
        awayPlayers={awayPins}
        homeMeta={metaMaps.get?.(homeId)}
        awayMeta={metaMaps.get?.(awayId)}
        mvpId={mvpId}
        onOpenCard={() => {}}
      />

      <div className="w-full rounded-2xl border border-white/5 bg-gradient-to-b from-white/3 to-white/1 p-6">
        <div className="grid grid-cols-[1fr_auto_1fr] items-center mb-4 text-[11px] uppercase tracking-[0.18em] text-white/50">
          <div className="text-left">{homeTeam}</div>
          <div className="px-3">Запас</div>
          <div className="text-right">{awayTeam}</div>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 text-sm">
          <div className="w-[380px] max-w-full">
            {renderBench(benchHome, false)}
          </div>
          <div className="w-[380px] max-w-full justify-self-end text-right">
            <div className="text-right">{renderBench(benchAway, true)}</div>
          </div>
        </div>
      </div>

      <div className="rounded-2xl border border-white/5 bg-gradient-to-b from-white/3 to-white/1 p-4 text-sm">
        <div className="grid grid-cols-1 md:grid-cols-[1fr_1px_1fr] gap-4">
          <div>
            <div className="mb-2 text-xs font-medium text-white/60 tracking-wide">
              Замены • {homeTeam}
            </div>
            <div className="space-y-1.5">
              {subsHomeGrouped.length ? (
                subsHomeGrouped.flatMap((g, i) =>
                  g.items.map((s, idx) => (
                    <div
                      key={`hs-${i}-${idx}`}
                      className="flex items-center gap-3 py-1"
                    >
                      <MinutePill value={`${g.minute}'`} />
                      <div className="text-[13px] text-white/85">
                        <span className="text-rose-200 font-medium">
                          {s.out_name || "—"}
                        </span>{" "}
                        <span className="text-white/60">→</span>{" "}
                        <span className="text-emerald-200 font-medium">
                          {s.in_name || "—"}
                        </span>
                      </div>
                    </div>
                  ))
                )
              ) : (
                <div className="text-xs text-white/45">—</div>
              )}
            </div>
          </div>

          <div className="hidden md:block w-px bg-white/6" />

          <div>
            <div className="mb-2 text-xs font-medium text-white/75 tracking-wide text-right">
              Замены • {awayTeam}
            </div>
            <div className="space-y-1.5">
              {subsAwayGrouped.length ? (
                subsAwayGrouped.flatMap((g, i) =>
                  g.items.map((s, idx) => (
                    <div
                      key={`as-${i}-${idx}`}
                      className="flex items-center gap-3 py-1 justify-end"
                    >
                      <div className="text-[13px] text-white/85 text-right">
                        <span className="text-rose-200 font-medium">
                          {s.out_name || "—"}
                        </span>{" "}
                        <span className="text-white/60">→</span>{" "}
                        <span className="text-emerald-200 font-medium">
                          {s.in_name || "—"}
                        </span>
                      </div>
                      <MinutePill value={`${g.minute}'`} />
                    </div>
                  ))
                )
              ) : (
                <div className="text-xs text-white/45 text-right">—</div>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="rounded-2xl border border-white/5 bg-gradient-to-b from-white/3 to-white/1 p-4 relative overflow-hidden">
        <div className="mb-3 text-xs font-medium text-white/75 tracking-wide">
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

          if (!homeList.length && !awayList.length) return null;

          return (
            <div key={k} className="mb-4 last:mb-0">
              <div className="mb-2 text-[11px] uppercase tracking-[0.18em] text-white/70 font-semibold">
                {title}
              </div>

              <div className="grid grid-cols-1 md:grid-cols-[1fr_1px_1fr] gap-4">
                <div className="relative space-y-2 pl-5">
                  <div className="pointer-events-none absolute left-2 top-0 bottom-0 w-px bg-white/6" />
                  {homeList.length ? (
                    homeList.map((ev, i) => (
                      <div
                        key={`h-${k}-${i}`}
                        className="flex items-center gap-2 rounded-lg pl-2 pr-6 py-1.5 transition-colors hover:bg-white/3"
                      >
                        <span className="text-base">
                          {ICON[ev.kind] || ICON.other}
                        </span>
                        <MinutePill
                          value={minuteStr(getElapsed(ev), getExtra(ev))}
                        />
                        <div className="text-[13px] text-white/90">
                          <div className="font-medium">{ev.player_name}</div>
                          {(ev.assist_name ||
                            translateDetailRu(ev.detail) ||
                            translateCommentRu(ev.comments)) && (
                            <div className="text-white/60">
                              {ev.assist_name &&
                              !/^substitution/i.test(ev.detail || "")
                                ? `ассист ${ev.assist_name}`
                                : translateDetailRu(ev.detail) ||
                                  translateCommentRu(ev.comments)}
                            </div>
                          )}
                        </div>
                      </div>
                    ))
                  ) : (
                    <div className="text-xs text-white/45">—</div>
                  )}
                </div>

                <div className="hidden md:block w-px bg-white/8" />

                <div className="relative space-y-2 text-right pr-5">
                  <div className="pointer-events-none absolute right-2 top-0 bottom-0 w-px bg-white/6" />
                  {awayList.length ? (
                    awayList.map((ev, i) => (
                      <div
                        key={`a-${k}-${i}`}
                        className="flex items-center gap-2 justify-end rounded-lg pl-6 pr-2 py-1.5 transition-colors hover:bg-white/3"
                      >
                        <div className="text-[13px] text-white/90">
                          <div className="font-medium">{ev.player_name}</div>
                          {(ev.assist_name ||
                            translateDetailRu(ev.detail) ||
                            translateCommentRu(ev.comments)) && (
                            <div className="text-white/60">
                              {ev.assist_name &&
                              !/^substitution/i.test(ev.detail || "")
                                ? `ассист ${ev.assist_name}`
                                : translateDetailRu(ev.detail) ||
                                  translateCommentRu(ev.comments)}
                            </div>
                          )}
                        </div>
                        <MinutePill
                          value={minuteStr(getElapsed(ev), getExtra(ev))}
                        />
                        <span className="text-base">
                          {ICON[ev.kind] || ICON.other}
                        </span>
                      </div>
                    ))
                  ) : (
                    <div className="text-xs text-white/45 text-right">—</div>
                  )}
                </div>
              </div>
            </div>
          );
        })}
        <div className="pointer-events-none absolute inset-x-0 bottom-0 h-10 bg-gradient-to-t from-slate-900/40 to-transparent" />
      </div>
    </div>
  );
};


/* ===== UI для KPI ===== */

/* Вариант 2 — табы с линией снизу, как на подборках */
const Segmented = ({ value, onChange }) => (
  <SegmentedTabs
    className="mt-5"
    size="md"
    items={[
      { key: "stats", label: "Статистика" },
      { key: "results", label: "Результаты" },
      { key: "schedule", label: "Календарь" },
    ]}
    value={value}
    onChange={onChange}
    listClassName="gap-5"
  />
);

const IconWrap = ({ children }) => (
  <span className="h-7 w-7 rounded-xl grid place-items-center bg-white/5 text-[#8B5CF6] border border-white/10">
    {children}
  </span>
);

const KpiCard = ({ title, value, sub, icon, tooltip }) => (
  <div className="glass-card min-h-[144px] p-4">
    <div className="flex items-center gap-2 text-[11px] uppercase tracking-wide text-white/60">
      {icon ? <IconWrap>{icon}</IconWrap> : null}
      <span title={tooltip || title}>{title}</span>
    </div>
    <div className="mt-2 text-[27px] font-semibold tracking-tight text-white transition-all duration-300">
      {value ?? "—"}
    </div>
    {sub ? (
      <div className="text-[11px] text-white/50 mt-1">{sub}</div>
    ) : null}
  </div>
);

const PeriodSwitch = ({ value, onChange }) => (
  <div
    className="flex items-center gap-6 text-[12px] text-white/60"
    title="5 / 10 / 15 — последние сыгранные матчи команды"
  >
    {[
      { id: "season", label: "Сезон" },
      { id: "5", label: "5" },
      { id: "10", label: "10" },
      { id: "15", label: "15" },
    ].map((opt) => {
      const active = value === opt.id;
      return (
        <button
          key={opt.id}
          onClick={() => onChange(opt.id)}
          className={`rounded-full px-3 py-1.5 text-xs sm:text-sm font-semibold tracking-wide transition-colors ${
            active
              ? "bg-white/10 text-white shadow-[0_0_10px_rgba(139,92,246,0.18)]"
              : "text-white/60 hover:text-white/85"
          }`}
        >
          {opt.label}
        </button>
      );
    })}
  </div>
);

const RadarChart = ({ data }) => {
  if (!data) return null;
  const metrics = [
    { key: "xg", label: "xG", max: 3 },
    { key: "conceded", label: "xGA", max: 3 },
    { key: "shots", label: "Shots", max: 20 },
    { key: "possession", label: "Poss", max: 70, min: 30 },
    { key: "tempo", label: "Tempo", max: 30 },
  ];
  const cx = 70;
  const cy = 70;
  const r = 52;
  const step = (Math.PI * 2) / metrics.length;
  const scale = (v, min, max) => {
    if (v == null) return 0.1;
    const lo = min ?? 0;
    const hi = max ?? 1;
    const t = (v - lo) / (hi - lo || 1);
    return Math.max(0.12, Math.min(1, t));
  };
  const points = metrics
    .map((m, i) => {
      const ang = -Math.PI / 2 + i * step;
      const val = scale(data[m.key], m.min, m.max);
      const x = cx + Math.cos(ang) * r * val;
      const y = cy + Math.sin(ang) * r * val;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");

  const rings = [0.35, 0.65, 1].map((k) => (
    <circle
      key={k}
      cx={cx}
      cy={cy}
      r={r * k}
      fill="none"
      stroke="rgba(255,255,255,0.08)"
      strokeWidth="1"
    />
  ));

  return (
    <svg
      viewBox="0 0 140 140"
      className="h-[120px] w-[120px] transition-opacity duration-300"
      title="Средние значения за выбранный период"
    >
      {rings}
      {metrics.map((m, i) => {
        const ang = -Math.PI / 2 + i * step;
        const x = cx + Math.cos(ang) * r;
        const y = cy + Math.sin(ang) * r;
        return (
          <line
            key={m.key}
            x1={cx}
            y1={cy}
            x2={x}
            y2={y}
            stroke="rgba(255,255,255,0.06)"
            strokeWidth="1"
          />
        );
      })}
      <polygon
        points={points}
        fill="rgba(168,85,247,0.22)"
        stroke="rgba(168,85,247,0.65)"
        strokeWidth="1.2"
      />
    </svg>
  );
};

/* локальные бейджи */
function MinutePill({ value }) {
  return (
    <span className="inline-flex items-center justify-center px-2.5 py-1 rounded-full bg-violet-500/12 text-[12px] font-semibold text-slate-100 tabular-nums">
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
  const r = await authFetch(url);
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
const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

async function fetchLineupsCached(fixture_id) {
  if (!fixture_id) return null;
  if (lineupsCache.has(fixture_id)) return lineupsCache.get(fixture_id);
  const r = await fetch(
    `${API_BASE}/api/lineups-events?fixture_id=${fixture_id}`
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
    const u1 = `/api/matches_v3?fixture_id=${fixtureId}&league=${encodeURIComponent(
      league
    )}&season=${season}&from_date=${win.from}&to_date=${win.to}`;
    const d1 = await fetchJsonSafe(u1);
    const cand = Array.isArray(d1)
      ? d1.find((x) => String(x.fixture_id) === String(fixtureId))
      : d1;
    if (cand && validateTeams(cand, seed)) return cand;
  } catch {}
  try {
    const u2 = `/api/matches_v3?league=${encodeURIComponent(
      league
    )}&season=${season}&from_date=${seasonWin.from}&to_date=${seasonWin.to}`;
    const pool = await fetchJsonSafe(u2);
    const arr = Array.isArray(pool) ? pool : pool ? [pool] : [];
    const hit = arr.find((x) => String(x.fixture_id) === String(fixtureId));
    if (hit && validateTeams(hit, seed)) return hit;
  } catch {}
  try {
    const d3 = await fetchJsonSafe(
      `/api/matches_v3?fixture_id=${fixtureId}`
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

function eventToneClass(kind) {
  if (kind === "goal") return "text-emerald-200";
  if (kind === "own_goal") return "text-amber-200";
  if (kind === "yellow" || kind === "red") return "text-white/85";
  if (kind === "sub") return "text-sky-200";
  return "text-white/80";
}

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
            <SegmentedTabs
              size="xs"
              items={[
                { key: "stats", label: "Статистика" },
                { key: "lineups", label: "Составы" },
              ]}
              value={tab}
              onChange={setTab}
              listClassName="gap-4"
            />
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
                  <div className="rounded-2xl border border-glass bg-surface-1/80 p-3 text-sm">
                    <div className="grid grid-cols-1 md:grid-cols-[1fr_1px_1fr] gap-4">
                      <div>
                        <div className="font-medium text-slate-100 mb-2">
                          Замены • {homeTeam}
                        </div>
                        <div className="space-y-2">
                          {subsHome.length ? (
                            subsHome.map((s, i) => (
                              <div
                                key={`hs-${i}`}
                                className="rounded-xl border border-white/5 bg-gradient-to-b from-white/2 to-white/1 px-3 py-2"
                              >
                                <div className="flex items-center gap-2">
                                  <MinutePill value={`${s.minute}'`} />
                                  <span className="text-rose-200 font-medium">
                                    ⬇ {s.out_name || "—"}
                                  </span>
                                </div>
                                <div className="flex items-center gap-2 mt-1">
                                  <span className="text-emerald-200 font-medium">
                                    ⬆ {s.in_name || "—"}
                                  </span>
                                </div>
                              </div>
                            ))
                          ) : (
                            <div className="text-slate-500 text-[12px]">—</div>
                          )}
                        </div>
                      </div>
                      <div className="hidden md:block w-px bg-white/5" />
                      <div>
                        <div className="font-medium text-slate-100 mb-2">
                          Замены • {awayTeam}
                        </div>
                        <div className="space-y-2">
                          {subsAway.length ? (
                            subsAway.map((s, i) => (
                              <div
                                key={`as-${i}`}
                                className="rounded-xl border border-white/5 bg-gradient-to-b from-white/2 to-white/1 px-3 py-2"
                              >
                                <div className="flex items-center gap-2">
                                  <MinutePill value={`${s.minute}'`} />
                                  <span className="text-rose-200 font-medium">
                                    ⬇ {s.out_name || "—"}
                                  </span>
                                </div>
                                <div className="flex items-center gap-2 mt-1">
                                  <span className="text-emerald-200 font-medium">
                                    ⬆ {s.in_name || "—"}
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
                      </div>
                    </div>
                  </div>

                  {/* СОБЫТИЯ */}
                  <div className="mt-4 rounded-2xl border border-glass bg-surface-1/80 p-3 relative overflow-hidden">
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

                      const flat = [
                        ...homeList.map((ev) => ({ ...ev, side: "home" })),
                        ...awayList.map((ev) => ({ ...ev, side: "away" })),
                      ].sort((a, b) => {
                        const aMin = Number(getElapsed(a) || 0);
                        const bMin = Number(getElapsed(b) || 0);
                        const aEx = Number(getExtra(a) || 0);
                        const bEx = Number(getExtra(b) || 0);
                        return aMin !== bMin ? aMin - bMin : aEx - bEx;
                      });

                      return (
                        <div key={k} className="mb-5 last:mb-0">
                          <div className="text-[11px] uppercase tracking-wide text-slate-500 mb-2">
                            {title}
                          </div>
                          <div className="relative">
                            <div className="pointer-events-none absolute left-1/2 top-0 bottom-0 w-px bg-white/6" />
                            <div className="space-y-2">
                              {flat.length ? (
                                flat.map((ev, i) => {
                                  const kind = (ev.kind || "").toLowerCase();
                                  const isCard = kind.includes("card");
                                  const isSub = kind.includes("sub");
                                  const isVar = kind.includes("var");
                                  const isGoal =
                                    kind.includes("goal") || kind.includes("own");
                                  const dot =
                                    isGoal
                                      ? "bg-emerald-400"
                                      : isCard
                                      ? "bg-amber-400"
                                      : isSub
                                      ? "bg-sky-400"
                                      : isVar
                                      ? "bg-violet-400"
                                      : "bg-slate-400";
                                  return (
                                    <div
                                      key={`${k}-${i}`}
                                      className="grid grid-cols-[1fr_96px_1fr] items-center gap-2 rounded-lg px-2 py-1.5 transition-colors hover:bg-white/3"
                                    >
                                      <div className="text-right">
                                        {ev.side === "home" ? (
                                          <div className="inline-flex items-center gap-2 justify-end text-[13px] text-slate-100">
                                            <span className="text-base leading-none">
                                              {ICON[ev.kind] || ICON.other}
                                            </span>
                                            <div className="text-right leading-snug">
                                              <div className="font-medium">
                                                {ev.player_name || "—"}
                                              </div>
                                              {(ev.assist_name ||
                                                translateDetailRu(ev.detail) ||
                                                translateCommentRu(ev.comments)) && (
                                                <div className="text-slate-400">
                                                  {ev.assist_name &&
                                                  !/^substitution/i.test(
                                                    ev.detail || ""
                                                  )
                                                    ? `ассист ${ev.assist_name}`
                                                    : translateDetailRu(
                                                        ev.detail
                                                      ) ||
                                                      translateCommentRu(
                                                        ev.comments
                                                      )}
                                                </div>
                                              )}
                                            </div>
                                          </div>
                                        ) : null}
                                      </div>

                                      <div className="flex items-center justify-center gap-2">
                                        <span
                                          className={`h-2 w-2 rounded-full ${dot}`}
                                        />
                                        <MinutePill
                                          value={minuteStr(
                                            getElapsed(ev),
                                            getExtra(ev)
                                          )}
                                        />
                                      </div>

                                      <div>
                                        {ev.side === "away" ? (
                                          <div className="inline-flex items-center gap-2 text-[13px] text-slate-100">
                                            <div className="leading-snug">
                                              <div className="font-medium">
                                                {ev.player_name || "—"}
                                              </div>
                                              {(ev.assist_name ||
                                                translateDetailRu(ev.detail) ||
                                                translateCommentRu(ev.comments)) && (
                                                <div className="text-slate-400">
                                                  {ev.assist_name &&
                                                  !/^substitution/i.test(
                                                    ev.detail || ""
                                                  )
                                                    ? `ассист ${ev.assist_name}`
                                                    : translateDetailRu(
                                                        ev.detail
                                                      ) ||
                                                      translateCommentRu(
                                                        ev.comments
                                                      )}
                                                </div>
                                              )}
                                            </div>
                                            <span className="text-base leading-none">
                                              {ICON[ev.kind] || ICON.other}
                                            </span>
                                          </div>
                                        ) : null}
                                      </div>
                                    </div>
                                  );
                                })
                              ) : (
                                <div className="text-[12px] text-slate-500">
                                  —
                                </div>
                              )}
                            </div>
                          </div>
                        </div>
                      );
                    })}
                    <div className="pointer-events-none absolute inset-x-0 bottom-0 h-10 bg-gradient-to-t from-slate-900/40 to-transparent" />
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
  const location = useLocation();
  const { user, checkAuth } = useAuth();

  const league = sp.get("league") || "Premier League";
  const seasonParam = sp.get("season") || "2025";
  const tabParam = sp.get("tab") || "stats"; // stats | results | schedule
  const isInternationalTeamContext = INTERNATIONAL_LEAGUES.has(league);

  const [season, setSeason] = useState(seasonParam);
  const [tab, setTabState] = useState(tabParam);

  const [overview, setOverview] = useState(null);
  const [results, setResults] = useState([]);
  const [schedule, setSchedule] = useState([]);
  const [loadingO, setLoadingO] = useState(false);
  const [loadingR, setLoadingR] = useState(false);
  const [loadingS, setLoadingS] = useState(false);
  const [loadingRank, setLoadingRank] = useState(false);
  const [tableRank, setTableRank] = useState(null);
  const [subscriptionActive, setSubscriptionActive] = useState(null);

  // календарь — один раскрытый матч + pack
  const [expandedScheduleId, setExpandedScheduleId] = useState(null);
  const [expandedScheduleData, setExpandedScheduleData] = useState({});

  const [expandedResultId, setExpandedResultId] = useState(null);
  const [expandedResultData, setExpandedResultData] = useState({});
  const [expandedResultTab, setExpandedResultTab] = useState({});

  const getStoredToken = (key) => {
    try {
      return localStorage.getItem(key) || sessionStorage.getItem(key);
    } catch {
      return null;
    }
  };

  useEffect(() => {
    if (!user && getStoredToken("access_token")) {
      checkAuth();
    }
  }, [user, checkAuth]);


  const statusBasedAccess = (() => {
    const status = String(user?.subscription_status || user?.subscription?.status || "").toLowerCase();
    if (["active", "premium", "pro", "elite", "paid"].includes(status)) return true;
    if (user?.is_premium || user?.is_subscribed) return true;
    if (Array.isArray(user?.active_subscriptions) && user.active_subscriptions.length > 0) return true;
    if (!status) return false;
    return status !== "free";
  })();
  const pilotFullAccess = hasPilotFullAccess(user);
  const hideMonetization = shouldHideMonetization();
  const hasSubscription =
    pilotFullAccess || (subscriptionActive != null ? subscriptionActive : statusBasedAccess);

  useEffect(() => {
    if (pilotFullAccess) {
      setSubscriptionActive(true);
      return;
    }
    let alive = true;
    (async () => {
      if (!user) return;
      try {
        const response = await http.get("/api/subscriptions/me");
        const payload = response?.data || {};
        const subs = Array.isArray(payload?.active_subscriptions)
          ? payload.active_subscriptions
          : [];
        const now = Date.now();
        const active = (() => {
          const topStatus = String(payload?.subscription_status || "").toLowerCase();
          if (["active", "paid", "premium", "pro", "elite"].includes(topStatus)) return true;
          const until = payload?.subscription_until || payload?.subscription_end;
          if (until) {
            const exp = new Date(until).getTime();
            if (Number.isFinite(exp) && exp > now) return true;
          }
          return subs.some((s) => {
            if (!s) return false;
            if (s.is_active === true) return true;
            const status = String(s.status || "").toLowerCase();
            if (["active", "paid", "premium", "pro", "elite"].includes(status)) return true;
            const end = s.end_at || s.expires_at;
            if (!end) return false;
            const exp = new Date(end).getTime();
            return Number.isFinite(exp) ? exp > now : false;
          });
        })();
        if (alive) setSubscriptionActive(active);
      } catch (err) {
        if (String(err?.status) === "401") {
          try {
            await checkAuth();
            const response = await http.get("/api/subscriptions/me");
            const payload = response?.data || {};
            const subs = Array.isArray(payload?.active_subscriptions)
              ? payload.active_subscriptions
              : [];
            const now = Date.now();
            const active = (() => {
              const topStatus = String(payload?.subscription_status || "").toLowerCase();
              if (["active", "paid", "premium", "pro", "elite"].includes(topStatus)) return true;
              const until = payload?.subscription_until || payload?.subscription_end;
              if (until) {
                const exp = new Date(until).getTime();
                if (Number.isFinite(exp) && exp > now) return true;
              }
              return subs.some((s) => {
                if (!s) return false;
                if (s.is_active === true) return true;
                const status = String(s.status || "").toLowerCase();
                if (["active", "paid", "premium", "pro", "elite"].includes(status)) return true;
                const end = s.end_at || s.expires_at;
                if (!end) return false;
                const exp = new Date(end).getTime();
                return Number.isFinite(exp) ? exp > now : false;
              });
            })();
            if (alive) setSubscriptionActive(active);
            return;
          } catch {}
        }
        if (alive) setSubscriptionActive(null);
      }
    })();
    return () => {
      alive = false;
    };
  }, [pilotFullAccess, user, checkAuth]);

  const openSubscription = useCallback(() => {
    if (hideMonetization) return;
    const back = encodeURIComponent(`${location.pathname}${location.search}`);
    navigate(`/subscriptions?redirect_back=${back}#plans`);
  }, [hideMonetization, location.pathname, location.search, navigate]);

  const openMatchInResults = useCallback(
    (fixtureId) => {
      if (!fixtureId) return;
      const params = new URLSearchParams({
        league,
        season,
        fixture_id: String(fixtureId),
      });
      navigate(`/matches-v3?${params.toString()}`);
    },
    [navigate, league, season]
  );

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
          `/api/team/overview?${qs}`
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

  // lock league to team's primary league if user tries to switch
  useEffect(() => {
    if (isInternationalTeamContext) return;
    const teamLeague = resolveTeamLeagueName(overview);
    if (!teamLeague) return;
    const cur = normalizeLeagueKey(league);
    const target = normalizeLeagueKey(teamLeague);
    if (!cur || cur === target) return;
    const next = new URLSearchParams(sp);
    next.set("league", teamLeague);
    setSp(next, { replace: true });
  }, [overview, league, setSp, sp, isInternationalTeamContext]);

  // league table rank (authoritative for selected league)
  useEffect(() => {
    if (!teamId) return;
    let cancel = false;
    (async () => {
      setLoadingRank(true);
      try {
        const qs = new URLSearchParams({
          league,
          season,
          view: "total",
        });
        const rows = await fetch(
          `/api/league-table?${qs.toString()}`
        ).then((r) => r.json());
        const list = Array.isArray(rows) ? rows : [];
        const row = list.find(
          (x) => Number(x?.team_id) === Number(teamId)
        );
        const rank =
          row?.rank ??
          row?.position ??
          row?.place ??
          row?.standing ??
          null;
        if (!cancel) {
          const num = Number(rank);
          setTableRank(
            Number.isFinite(num) && num > 0 ? num : null
          );
        }
      } catch {
        if (!cancel) setTableRank(null);
      } finally {
        if (!cancel) setLoadingRank(false);
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
          limit: isInternationalTeamContext ? "100" : "50",
        });
        if (season && !isInternationalTeamContext) qs.set("season", season);
        if (!isInternationalTeamContext) qs.set("league", league);

        const rows = await fetch(
          `/api/team/results?${qs}`
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
  }, [teamId, league, season, isInternationalTeamContext]);

  // schedule — будущие матчи команды
  useEffect(() => {
    if (!teamId) return;
    let cancel = false;

    (async () => {
      setLoadingS(true);
      try {
        const qs = new URLSearchParams({
          team_id: String(teamId),
          limit: isInternationalTeamContext ? "40" : "30",
        });
        if (season && !isInternationalTeamContext) qs.set("season", season);
        if (!isInternationalTeamContext) qs.set("league", league);

        const rows = await fetch(`/api/team/schedule?${qs}`).then((r) => r.json());

        const arr = Array.isArray(rows) ? rows : [];

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const upcoming = arr.filter((m) => {
          const isTeam =
            Number(m.home_team_id) === teamId ||
            Number(m.away_team_id) === teamId;

          if (!isTeam) return false;
          if (isTeamScheduleLive(m)) return true;

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
  }, [teamId, league, season, isInternationalTeamContext]);

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

  useEffect(() => {
    setExpandedScheduleId(null);
    setExpandedScheduleData({});
  }, [teamId, league, season]);

  /* ===== загрузка данных для разворота календаря через buildMatchPack() ===== */
  const loadExpandedPack = useCallback(
    async (m) => {
      if (!m?.fixture_id) return;
      const key = m.fixture_id;

      setExpandedScheduleData((prev) => ({
        ...prev,
        [key]: {
          ...(prev[key] || {}),
          loading: true,
          error: null,
        },
      }));

      try {
        const pack = await buildMatchPack({ match: m, league });
        setExpandedScheduleData((prev) => ({
          ...prev,
          [key]: {
            ...pack,
            loaded: true,
            loading: false,
            error: null,
          },
        }));
      } catch (e) {
        setExpandedScheduleData((prev) => ({
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
      setExpandedScheduleId((prev) => {
        const next = prev === m.fixture_id ? null : m.fixture_id;
        if (next === m.fixture_id) {
          loadExpandedPack(m);
        }
        return next;
      });
    },
    [loadExpandedPack]
  );

  const loadResultDetails = useCallback(
    async (m, seed) => {
      if (!m?.fixture_id) return;
      const key = m.fixture_id;
      setExpandedResultData((prev) => ({
        ...prev,
        [key]: { ...(prev[key] || {}), loading: true, error: null },
      }));
      try {
        const match = await fetchOneMatch({
          fixtureId: m.fixture_id,
          league,
          season,
          seed,
        });
        setExpandedResultData((prev) => ({
          ...prev,
          [key]: { match, lineups: null, loading: false, error: null },
        }));
      } catch (e) {
        setExpandedResultData((prev) => ({
          ...prev,
          [key]: { ...(prev[key] || {}), loading: false, error: e.message || String(e) },
        }));
      }
    },
    [league, season]
  );

  const handleToggleResult = useCallback(
    (m, seed) => {
      if (!m?.fixture_id) return;
      setExpandedResultId((prev) => {
        const next = prev === m.fixture_id ? null : m.fixture_id;
        if (next === m.fixture_id) {
          const cached = expandedResultData[m.fixture_id];
          if (!cached || (!cached.loading && !cached.match && !cached.error)) {
            loadResultDetails(m, seed);
          }
        }
        return next;
      });
      setExpandedResultTab((prev) => ({
        ...prev,
        [m.fixture_id]: "stats",
      }));
    },
    [expandedResultData, loadResultDetails]
  );

  const titleTeamName = useMemo(
    () => overview?.team_name || "Команда",
    [overview]
  );
  const [isFav, setIsFav] = useState(false);
  const [resultFilter, setResultFilter] = useState("all");
  const [period, setPeriod] = useState("season");
  const favKey = "favorites_teams";
  const emitFavUpdate = () => {
    try {
      window.dispatchEvent(new CustomEvent("favorites:update"));
    } catch {}
  };

  useEffect(() => {
    try {
      const list = loadFavorites(favKey);
      setIsFav(list.some((x) => Number(x.id) === Number(teamId)));
    } catch {}
  }, [teamId]);

  const toggleFavorite = () => {
    let nextIsFav = !isFav;
    try {
      const list = loadFavorites(favKey);
      const exists = list.some((x) => Number(x.id) === Number(teamId));
      const next = exists
        ? list.filter((x) => Number(x.id) !== Number(teamId))
        : [
            ...list,
            {
              id: Number(teamId),
              name: titleTeamName,
              league,
              season,
            },
          ];
      saveFavorites(favKey, next);
      const refreshed = loadFavorites(favKey);
      nextIsFav = refreshed.some((x) => Number(x.id) === Number(teamId));
    } catch {}
    setIsFav(nextIsFav);
    emitFavUpdate();
  };
  const selectedRank = useMemo(() => {
    if (Number.isFinite(Number(tableRank))) return Number(tableRank);
    return pickLeagueRank(overview, league);
  }, [overview, league, tableRank]);
  const matchesPlayed = Number(overview?.matches_played);
  const showLowDataNote =
    overview && Number.isFinite(matchesPlayed) && matchesPlayed < 5;

  const periodLabel =
    period === "season" ? "за сезон" : `за последние ${period} матчей`;

  const periodStats = useMemo(() => {
    const mapFromOverview = () => ({
      matches: Number(overview?.matches_played) || null,
      wins: Number(overview?.wins) || null,
      draws: Number(overview?.draws) || null,
      losses: Number(overview?.losses) || null,
      goalsFor: Number(overview?.goals_for) || null,
      goalsAgainst: Number(overview?.goals_against) || null,
      points: overview?.points != null ? Number(overview.points) : null,
      goalsPer: overview?.goals_per_game != null ? Number(overview.goals_per_game) : null,
      concededPer: overview?.conceded_per_game != null ? Number(overview.conceded_per_game) : null,
      xgPer: overview?.xg_per_game != null ? Number(overview.xg_per_game) : null,
      xgaPer: overview?.xga_per_game != null ? Number(overview.xga_per_game) : null,
      shotsAvg: overview?.shots_avg != null ? Number(overview.shots_avg) : null,
      possessionAvg: overview?.possession_avg != null ? Number(overview.possession_avg) : null,
      tempoAvg: overview?.tempo_shots_per_game != null ? Number(overview.tempo_shots_per_game) : null,
    });

    if (period === "season" || !results?.length) return mapFromOverview();

    const take = Number(period);
    const base = [...results].slice(0, take);
    if (!base.length) return mapFromOverview();

    let wins = 0, draws = 0, losses = 0;
    let gf = 0, ga = 0;
    let xgSum = 0, xgCnt = 0;
    let shotsSum = 0, shotsCnt = 0;
    let possSum = 0, possCnt = 0;

    base.forEach((m) => {
      const tg = Number(m.team_goals);
      const og = Number(m.opp_goals);
      if (Number.isFinite(tg) && Number.isFinite(og)) {
        gf += tg;
        ga += og;
        if (tg > og) wins += 1;
        else if (tg < og) losses += 1;
        else draws += 1;
      }
      const xg = toNumSafe(m.xg);
      if (xg != null) {
        xgSum += xg;
        xgCnt += 1;
      }
      const shots = toNumSafe(m.shots);
      if (shots != null) {
        shotsSum += shots;
        shotsCnt += 1;
      }
      const poss = toNumSafe(m.possession);
      if (poss != null) {
        possSum += poss;
        possCnt += 1;
      }
    });

    const matches = base.length;
    const points = wins * 3 + draws;
    const goalsPer = matches ? gf / matches : null;
    const concededPer = matches ? ga / matches : null;
    const xgPer = xgCnt ? xgSum / xgCnt : null;
    const shotsAvg = shotsCnt ? shotsSum / shotsCnt : null;
    const possessionAvg = possCnt ? possSum / possCnt : null;
    const tempoAvg = shotsAvg;

    return {
      matches,
      wins,
      draws,
      losses,
      goalsFor: gf,
      goalsAgainst: ga,
      points,
      goalsPer,
      concededPer,
      xgPer,
      xgaPer: overview?.xga_per_game != null ? Number(overview.xga_per_game) : null,
      shotsAvg,
      possessionAvg,
      tempoAvg,
    };
  }, [period, overview, results]);

  const recentResults = useMemo(() => {
    const list = Array.isArray(results) ? [...results] : [];
    const toDateVal = (m) => {
      const raw = m?.datetime || m?.date || "";
      const d = new Date(raw);
      return Number.isNaN(+d) ? 0 : +d;
    };
    list.sort((a, b) => toDateVal(b) - toDateVal(a));
    return list.slice(0, 5);
  }, [results]);

  const filteredResults = useMemo(() => {
    if (resultFilter === "home") return results.filter((m) => m.side === "H");
    if (resultFilter === "away") return results.filter((m) => m.side === "A");
    return results;
  }, [results, resultFilter]);

  const recentResultsFiltered = useMemo(() => {
    const list = Array.isArray(filteredResults) ? [...filteredResults] : [];
    const toDateVal = (m) => {
      const raw = m?.datetime || m?.date || "";
      const d = new Date(raw);
      return Number.isNaN(+d) ? 0 : +d;
    };
    list.sort((a, b) => toDateVal(b) - toDateVal(a));
    return list.slice(0, 5);
  }, [filteredResults]);

  const formSummary = useMemo(() => {
    const getPair = (m, keysTeam, keysOpp) => {
      let a = null;
      let b = null;
      for (let i = 0; i < keysTeam.length; i++) {
        const v = toNumSafe(m[keysTeam[i]]);
        if (v != null) {
          a = v;
          break;
        }
      }
      for (let j = 0; j < keysOpp.length; j++) {
        const v = toNumSafe(m[keysOpp[j]]);
        if (v != null) {
          b = v;
          break;
        }
      }
      return a != null && b != null ? [a, b] : null;
    };

    const xgFor = [];
    const xgAgainst = [];
    const shots = [];
    const poss = [];

    let gf5 = 0;
    let ga5 = 0;
    for (const m of recentResultsFiltered) {
      const gs = goalsSummaryFor(
        {
          home_team_id: m.side === "H" ? teamId : m.opponent_id,
          away_team_id: m.side === "H" ? m.opponent_id : teamId,
          home_goals: m.side === "H" ? m.team_goals : m.opp_goals,
          away_goals: m.side === "H" ? m.opp_goals : m.team_goals,
        },
        teamId
      );
      gf5 += gs.for;
      ga5 += gs.against;
      const sideHome = m.side === "H";
      const xgPair = getPair(
        m,
        ["xg", "xg_for", "team_xg", "xg_team", "xg_home", "home_xg"],
        ["xg_opp", "xg_against", "opp_xg", "xg_away", "away_xg"]
      );
      const shotsPair = getPair(
        m,
        ["shots", "shots_for", "team_shots", "shots_home"],
        ["shots_opp", "shots_against", "opp_shots", "shots_away"]
      );
      const possPair = getPair(
        m,
        ["possession", "possession_for", "team_possession", "poss_home"],
        ["possession_opp", "possession_against", "opp_possession", "poss_away"]
      );
      if (xgPair) {
        xgFor.push(sideHome ? xgPair[0] : xgPair[1]);
        xgAgainst.push(sideHome ? xgPair[1] : xgPair[0]);
      }
      if (shotsPair) {
        shots.push(sideHome ? shotsPair[0] : shotsPair[1]);
      }
      if (possPair) {
        poss.push(sideHome ? possPair[0] : possPair[1]);
      }
    }

    const avg = (arr) => (arr.length ? arr.reduce((a, b) => a + b, 0) / arr.length : null);
    return {
      results: recentResultsFiltered.map((m) =>
        resultForTeam(
          {
            home_team_id: m.side === "H" ? teamId : m.opponent_id,
            away_team_id: m.side === "H" ? m.opponent_id : teamId,
            home_goals: m.side === "H" ? m.team_goals : m.opp_goals,
            away_goals: m.side === "H" ? m.opp_goals : m.team_goals,
          },
          teamId
        )
      ),
      xg: avg(xgFor),
      xga: avg(xgAgainst),
      shots: avg(shots),
      poss: avg(poss),
      gd: gf5 - ga5,
    };
  }, [recentResultsFiltered, teamId]);

  return (
    <div className="w-full px-4 py-8">
      <div className="w-full space-y-8">
      {/* HERO / HEADER – в стиле EdgeScore, как таблица/подборки */}
      <section className="relative overflow-hidden rounded-[24px] bg-white/5 backdrop-blur-[8px] border border-white/10 text-slate-50">
        <div className="relative p-6 md:p-8">
          <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            <div className="flex items-center gap-4 min-w-0">
              <span className="inline-flex h-16 w-16 items-center justify-center rounded-2xl border border-glass bg-surface-2/80 shadow-[0_18px_70px_rgba(0,0,0,0.9)] overflow-hidden">
                <SafeImg
                  src={teamLogo(teamId)}
                  alt={titleTeamName}
                  className="h-12 w-12 object-contain"
                  fallbackSrc={teamLogoFallback(teamId, titleTeamName)}
                />
              </span>
              <div className="min-w-0 type-title-block">
                <div className="type-eyebrow">
                  Команда
                </div>
                <h1 className="type-page-title whitespace-normal break-words">
                  {titleTeamName}
                </h1>
                <div className="type-subtitle">
                  {league} · Сезон {season}
                  {selectedRank != null && !loadingRank ? ` · Место: ${selectedRank}` : ""}
                </div>
              </div>
            </div>

            <div className="relative z-10 flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  toggleFavorite();
                }}
                className={`inline-flex items-center gap-2 rounded-full px-2.5 py-1 text-[12px] font-medium transition ${
                  isFav
                    ? "text-white/80"
                    : "text-white/70 hover:text-violet-300"
                }`}
                title={isFav ? "Убрать из избранного" : "Добавить в избранное"}
              >
                <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor" aria-hidden="true">
                  <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 6 3.99 4 6.5 4c1.54 0 3.04.74 4 1.9C11.46 4.74 12.96 4 14.5 4 17.01 4 19 6 19 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
                </svg>
                {isFav ? "В избранном" : "В избранное"}
              </button>
            </div>
          </div>

          {/* табы */}
          <div className="mt-5">
            <Segmented value={tab} onChange={setTab} />
          </div>
        </div>
      </section>

      {/* ТАБЫ */}
      {tab === "stats" ? (
        <section className="w-full space-y-6 mc-fade">
          {loadingO ? (
            <>
              <div className="h-28 rounded-[20px] border border-white/10 bg-white/5 animate-pulse" />
              <div className="h-40 rounded-[20px] border border-white/10 bg-white/5 animate-pulse" />
            </>
          ) : overview ? (
            <>
              {showLowDataNote && (
                <div className="rounded-[20px] border border-white/10 bg-white/5 p-4 text-sm text-white/60">
                  Недостаточно матчей для устойчивых выводов. Используй данные как ориентир, а не сигнал.
                </div>
              )}
              {/* Верхний ряд KPI */}
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-2 text-[13px] font-medium text-white/85">
                  <span className="inline-block h-3 w-[3px] rounded-full bg-[#8B5CF6]" />
                  Статистика команды
                </div>
                <div className="flex items-center gap-2 pr-1">
                  <span className="text-[12px] text-white/50">Период:</span>
                  <PeriodSwitch value={period} onChange={setPeriod} />
                </div>
              </div>

              <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                <KpiCard
                  title="Матчей"
                  value={periodStats.matches ?? "—"}
                  tooltip={`Сыгранные матчи ${periodLabel}`}
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
                  value={periodStats.points != null ? `${periodStats.points}` : "—"}
                  tooltip={`Очки ${periodLabel} (место по таблице сезона)`}
                  sub={selectedRank != null ? `Ранг: ${selectedRank}` : undefined}
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
                  value={`${periodStats.wins ?? 0}-${periodStats.draws ?? 0}-${periodStats.losses ?? 0}`}
                  tooltip={`Победы/ничьи/поражения ${periodLabel}`}
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
                  value={`${periodStats.goalsFor ?? 0} / ${
                    periodStats.goalsAgainst ?? 0
                  }`}
                  tooltip={`Голы ${periodLabel}`}
                  sub={
                    periodStats.goalsFor != null && periodStats.goalsAgainst != null
                      ? `Разница: ${periodStats.goalsFor - periodStats.goalsAgainst}`
                      : undefined
                  }
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
              <div className="rounded-[20px] border border-white/10 bg-gradient-to-b from-white/[0.04] to-transparent p-6">
                <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                  <KpiCard
                    title="Голы за игру"
                    value={fmtNum(periodStats.goalsPer, 2)}
                    tooltip={`Средние голы за матч ${periodLabel}`}
                  />
                  <KpiCard
                    title="Пропускает за игру"
                    value={fmtNum(periodStats.concededPer, 2)}
                    tooltip={`Средние пропущенные за матч ${periodLabel}`}
                  />
                  <KpiCard
                    title="xG за игру"
                    value={fmtNum(periodStats.xgPer, 2)}
                    tooltip={`Ожидаемые голы за матч ${periodLabel}`}
                  />
                  <KpiCard
                    title="xGA за игру"
                    value={fmtNum(periodStats.xgaPer, 2)}
                    tooltip={`Ожидаемые пропущенные за матч ${periodLabel}`}
                  />
                  <KpiCard
                    title="Удары (сред.)"
                    value={fmtNum(periodStats.shotsAvg, 1)}
                    tooltip={`Средние удары за матч ${periodLabel}`}
                  />
                  <KpiCard
                    title="Владение (сред.)"
                    value={
                      periodStats.possessionAvg != null
                        ? `${fmtNum(periodStats.possessionAvg, 1)}%`
                        : "—"
                    }
                    tooltip={`Среднее владение мячом ${periodLabel}`}
                  />
                  <KpiCard
                    title="Темп (уд./игру)"
                    value={fmtNum(periodStats.tempoAvg, 1)}
                    tooltip={`Темп атак ${periodLabel}`}
                  />
                </div>
                <div className="mt-4 flex items-center justify-between">
                  <div className="flex items-center gap-2 text-[12px] text-white/55">
                    <span className="inline-block h-2 w-2 rounded-full bg-[#8B5CF6]" />
                    Форма за выбранный период
                  </div>
                  <RadarChart
                    key={period}
                    data={{
                      xg: periodStats.xgPer,
                      conceded: periodStats.concededPer,
                      shots: periodStats.shotsAvg,
                      possession: periodStats.possessionAvg,
                      tempo: periodStats.tempoAvg,
                    }}
                  />
                </div>
              </div>
            </>
          ) : (
            <div className="rounded-[20px] border border-white/10 bg-white/5 p-6 text-sm text-white/60">
              Нет данных по сводке.
            </div>
          )}
        </section>
      ) : tab === "results" ? (
        <section className="w-full space-y-6 mc-fade">
          {recentResults.length > 0 && (
            <div className="space-y-4">
              <div className="flex items-center justify-between gap-4">
                <div className="text-[14px] font-semibold text-white">Форма</div>
                <div className="text-[12px] text-white/50">
                  последние 5 матчей
                  {resultFilter === "home" ? " · дома" : resultFilter === "away" ? " · в гостях" : ""}
                </div>
              </div>
              <VenueFilterTabs value={resultFilter} onChange={setResultFilter} />
              <div className="rounded-[20px] border border-white/10 bg-white/5 p-6">
                <div className="mt-4 flex items-center gap-2">
                  {formSummary.results.map((r, i) => (
                    <span
                      key={`form-${i}`}
                      className={clsx(
                        "inline-flex h-7 w-7 items-center justify-center rounded-full text-[12px] font-semibold",
                        r === "W"
                          ? "bg-emerald-500 text-white"
                          : r === "L"
                          ? "bg-rose-500 text-white"
                          : "bg-amber-400/90 text-slate-950"
                      )}
                    >
                      {r === "W" ? "W" : r === "L" ? "L" : "D"}
                    </span>
                  ))}
                </div>
                <div className="mt-4 flex flex-wrap gap-4 text-[13px] text-white/80">
                  <span>xG {formSummary.xg != null ? fmtNum(formSummary.xg, 1) : "—"}</span>
                  <span>Shots {formSummary.shots != null ? fmtNum(formSummary.shots, 1) : "—"}</span>
                  <span>Poss {formSummary.poss != null ? `${fmtNum(formSummary.poss, 0)}%` : "—"}</span>
                  <span>xGA {formSummary.xga != null ? fmtNum(formSummary.xga, 1) : "—"}</span>
                  <span>GD {Number.isFinite(formSummary.gd) ? formSummary.gd : "—"}</span>
                </div>
              </div>
            </div>
          )}
          {loadingR && (
            <div className={`${BG_PANEL} h-28 rounded-3xl border ${BORDER_GLASS} animate-pulse`} />
          )}

          {!loadingR && results.length === 0 && (
            <div className={`${BG_PANEL} rounded-3xl border ${BORDER_GLASS} p-6 text-sm ${TEXT_MUTED}`}>
              Нет сыгранных матчей.
            </div>
          )}

          {!loadingR &&
            filteredResults.map((m, idx) => {
              const isExpanded = expandedResultId === m.fixture_id;
              const sideHome = m.side === "H";
              const leftId = sideHome ? teamId : m.opponent_id;
              const rightId = sideHome ? m.opponent_id : teamId;
              const leftName = sideHome ? titleTeamName : m.opponent_name;
              const rightName = sideHome ? m.opponent_name : titleTeamName;
              const teamIsLeft = leftName === titleTeamName;
              const leftGoals =
                m.team_goals != null && m.opp_goals != null
                  ? sideHome
                    ? m.team_goals
                    : m.opp_goals
                  : null;
              const rightGoals =
                m.team_goals != null && m.opp_goals != null
                  ? sideHome
                    ? m.opp_goals
                    : m.team_goals
                  : null;
              const score =
                leftGoals != null && rightGoals != null
                  ? `${leftGoals}–${rightGoals}`
                  : "—";
              const getPair = (keysLeft, keysRight, source = m) => {
                let a = null;
                let b = null;
                for (var i = 0; i < keysLeft.length; i++) {
                  const v = toNumSafe(source[keysLeft[i]]);
                  if (v != null) {
                    a = v;
                    break;
                  }
                }
                for (var j = 0; j < keysRight.length; j++) {
                  const v = toNumSafe(source[keysRight[j]]);
                  if (v != null) {
                    b = v;
                    break;
                  }
                }
                return a != null && b != null ? [a, b] : null;
              };
              const xgPair = getPair(
                ["xg", "xg_for", "team_xg", "xg_home", "home_xg"],
                ["xg_opp", "xg_against", "opp_xg", "xg_away", "away_xg"]
              );
              const matchStats = expandedResultData[m.fixture_id]?.match || m;
              const possPair = getPair(
                ["possession", "possession_for", "team_possession", "poss_home", "home_possession"],
                ["possession_opp", "possession_against", "opp_possession", "poss_away", "away_possession"],
                matchStats
              );
              const shotsPair = getPair(
                ["shots", "shots_for", "team_shots", "shots_home", "home_shots"],
                ["shots_opp", "shots_against", "opp_shots", "shots_away", "away_shots"],
                matchStats
              );
              const onTargetPair = getPair(
                ["shots_on_goal", "shots_on_target", "shots_on", "sot_home", "home_shots_on_goal"],
                ["shots_on_goal_opp", "shots_on_target_opp", "sot_away", "away_shots_on_goal"],
                matchStats
              );
              const hasKeyStats = xgPair || possPair;

              const res = resultForTeam(
                {
                  home_team_id: sideHome ? teamId : m.opponent_id,
                  away_team_id: sideHome ? m.opponent_id : teamId,
                  home_goals: sideHome ? m.team_goals : m.opp_goals,
                  away_goals: sideHome ? m.opp_goals : m.team_goals,
                },
                teamId
              );

              const matchForOverlay = {
                fixture_id: m.fixture_id,
                date: m.date,
                datetime: m.datetime,
                home_team_id: sideHome ? teamId : m.opponent_id,
                away_team_id: sideHome ? m.opponent_id : teamId,
                home_team: sideHome ? titleTeamName : m.opponent_name,
                away_team: sideHome ? m.opponent_name : titleTeamName,
                home_goals: sideHome ? m.team_goals : m.opp_goals,
                away_goals: sideHome ? m.opp_goals : m.team_goals,
                score,
              };
              const seed = {
                side: sideHome ? "H" : "A",
                team_name: sideHome ? titleTeamName : m.opponent_name,
                team_id: sideHome ? teamId : m.opponent_id,
                opponent_name: sideHome ? m.opponent_name : titleTeamName,
                opponent_id: sideHome ? m.opponent_id : teamId,
                team_goals: sideHome ? m.team_goals : m.opp_goals,
                opp_goals: sideHome ? m.opp_goals : m.team_goals,
                date: m.date,
              };

              return (
                <div
                  key={
                    m.fixture_id ||
                    `${m.home_team_id}-${m.away_team_id}-${idx}`
                  }
                  className={clsx(
                    "relative overflow-hidden rounded-[20px] border border-white/10 bg-white/5 transition-all duration-200",
                    isExpanded && "bg-[rgba(255,255,255,0.06)] shadow-[0_16px_40px_rgba(0,0,0,0.22)]"
                  )}
                >
                  {res && (
                    <span
                      className={clsx(
                        "pointer-events-none absolute left-0 top-2 bottom-2 w-[3px] rounded-full shadow-[0_0_10px_rgba(139,92,246,0.35)]",
                        res === "W"
                          ? "bg-emerald-400/80"
                          : res === "L"
                          ? "bg-rose-400/70"
                          : "bg-amber-400/80"
                      )}
                    />
                  )}
                  <button
                    type="button"
                    onClick={() => {
                      handleToggleResult(matchForOverlay, seed);
                    }}
                    className={clsx(
                      "w-full px-5 py-4 transition-all duration-200 ease-in-out",
                      "bg-transparent hover:bg-[rgba(255,255,255,0.04)]",
                      "grid grid-cols-[1fr_auto_1fr] items-center gap-4"
                    )}
                  >
                    {/* LEFT */}
                    <div className="flex items-center gap-3 min-w-0">
                      <LogoBadge id={leftId} name={leftName} />
                      <div className="min-w-0 text-left">
                        <div className={clsx("text-sm text-white truncate", leftName === titleTeamName ? "font-semibold" : "font-medium")}>
                          {leftName}
                        </div>
                        <div className="text-[11px] text-muted truncate">
                          {toDDMM(m.date)} {m.venue ? `· ${m.venue}` : ""}
                        </div>
                      </div>
                    </div>

                    {/* CENTER */}
                    <div
                      className="text-center flex flex-col items-center justify-center"
                      style={{ width: "110px" }}
                    >
                      <div className="text-[22px] font-semibold tracking-[-0.3px] tabular-nums leading-none">
                        <span className={clsx(leftGoals === rightGoals ? "text-white" : leftGoals > rightGoals ? "text-white" : "text-white/60")}>
                          {leftGoals ?? "—"}
                        </span>
                        <span className="text-white/70 mx-1">–</span>
                        <span className={clsx(leftGoals === rightGoals ? "text-white" : rightGoals > leftGoals ? "text-white" : "text-white/60")}>
                          {rightGoals ?? "—"}
                        </span>
                      </div>
                    </div>

                    {/* RIGHT */}
                    <div className="flex items-center gap-3 min-w-0 justify-end">
                      <div className="text-right min-w-0">
                        <div className={clsx("text-sm text-white truncate", rightName === titleTeamName ? "font-semibold" : "font-medium")}>
                          {rightName}
                        </div>
                        <div className="text-[11px] text-muted truncate">
                          {m.status || ""}
                        </div>
                      </div>
                      <LogoBadge id={rightId} name={rightName} />
                    </div>
                  </button>
                  {expandedResultId === m.fixture_id && (
                    <div className="border-t border-white/10 bg-gradient-to-r from-white/[0.03] to-white/[0.01] px-5 py-5">
                      {expandedResultData[m.fixture_id]?.loading && (
                        <div className="text-sm text-slate-400">Загружаем статистику…</div>
                      )}
                      {expandedResultData[m.fixture_id]?.error && (
                        <div className="text-sm text-rose-400">
                          Ошибка: {expandedResultData[m.fixture_id]?.error}
                        </div>
                      )}
                      {!expandedResultData[m.fixture_id]?.loading &&
                        !expandedResultData[m.fixture_id]?.error && (
                          (() => {
                            const mapPair = (pair) =>
                              pair ? (teamIsLeft ? [pair[0], pair[1]] : [pair[1], pair[0]]) : [null, null];
                            const [posL, posR] = mapPair(possPair);
                            const [xgL, xgR] = mapPair(xgPair);
                            const [shotsL, shotsR] = mapPair(shotsPair);
                            const [sotL, sotR] = mapPair(onTargetPair);
                            const hasAny = posL != null || xgL != null || shotsL != null || sotL != null;
                            return hasAny ? (
                              <div className="w-full space-y-3">
                                <CompactMetricRow label="Владение" left={posL} right={posR} isPercent accentSide={teamIsLeft ? "left" : "right"} />
                                <CompactMetricRow label="xG" left={xgL} right={xgR} accentSide={teamIsLeft ? "left" : "right"} />
                                <CompactMetricRow label="Удары" left={shotsL} right={shotsR} accentSide={teamIsLeft ? "left" : "right"} />
                                <CompactMetricRow label="В створ" left={sotL} right={sotR} accentSide={teamIsLeft ? "left" : "right"} />
                              </div>
                            ) : (
                              <div className="text-sm text-slate-400">Нет данных по метрикам матча.</div>
                            );
                          })()
                        )}
                    </div>
                  )}
                </div>
              );
            })}
        </section>
      ) : tab === "schedule" ? (
        <section className="w-full space-y-6 mc-fade">
          {loadingS && (
            <div className="h-24 rounded-[20px] border border-white/10 bg-white/5 animate-pulse" />
          )}

          {!loadingS && groupedSchedule.length === 0 && (
            <div className="rounded-[20px] border border-white/10 bg-white/5 p-6 text-sm text-white/60">
              Нет будущих матчей.
            </div>
          )}

          {!loadingS &&
            groupedSchedule.map(([week, matches]) => (
              <div key={week} className="space-y-2">
                <div className="text-xs uppercase tracking-[0.24em] text-white/35 mt-2 mb-2">
                  Тур {week}
                </div>
                {matches.map((m, idx) => {
                  const leftId = m.home_team_id;
                  const rightId = m.away_team_id;
                  const leftName = m.home_team;
                  const rightName = m.away_team;
                  const matchDate = parseMatchDate(m);
                  const dateLabel = toDDMM(m.datetime || m.date);
                  const timeLabel = matchDate ? formatHHMM(matchDate) : "";
                  const centerLine = timeLabel ? `${dateLabel} · ${timeLabel}` : dateLabel;
                  const roundLabel =
                    m.round_label != null
                      ? `Round ${String(m.round_label).replace(/\D/g, "")}`
                      : week != null && week !== "—"
                      ? `Round ${String(week).replace(/\D/g, "")}`
                      : null;

                  const isExpanded = expandedScheduleId === m.fixture_id;
                  const pack = expandedScheduleData[m.fixture_id];

                  return (
                    <div
                      key={m.fixture_id || `${m.home_team_id}-${m.away_team_id}-${idx}`}
                      className={clsx(
                        "group relative overflow-hidden rounded-[20px] border border-white/10 bg-white/5 transition-all duration-200",
                        "hover:bg-[rgba(255,255,255,0.05)]",
                        isExpanded && "bg-[rgba(255,255,255,0.06)] shadow-[0_16px_40px_rgba(0,0,0,0.22)]"
                      )}
                    >
                      <span
                        className={clsx(
                          "pointer-events-none absolute left-0 top-3 bottom-3 w-[3px] rounded-full",
                          isExpanded ? "bg-violet-400/80" : "bg-white/10"
                        )}
                      />
                      <button
                        type="button"
                        onClick={() => handleToggleSchedule(m)}
                        className="w-full cursor-pointer px-5 py-4 text-left"
                      >
                        <div className="grid grid-cols-[1fr_auto_1fr_auto] items-center gap-4">
                          {/* HOME */}
                          <div className="flex items-center gap-3 min-w-0 min-h-[56px]">
                            <LogoBadge id={leftId} name={leftName} size={30} imgSize={30} />
                            <span className="text-[15px] font-medium text-white truncate">
                              {leftName}
                            </span>
                          </div>

                          {/* CENTER */}
                          <div className="flex flex-col items-center gap-1 min-w-[160px]">
                            <span className="text-[13px] text-white/80 tabular-nums">
                              {centerLine}
                            </span>
                            {roundLabel && (
                              <span className="text-[11px] text-white/45">{roundLabel}</span>
                            )}
                          </div>

                          {/* AWAY */}
                          <div className="flex items-center gap-3 min-w-0 justify-end min-h-[56px]">
                            <span className="text-[15px] font-medium text-white truncate text-right">
                              {rightName}
                            </span>
                            <LogoBadge id={rightId} name={rightName} size={30} imgSize={30} />
                          </div>

                          {/* CHEVRON */}
                          <div
                            className={clsx(
                              "text-white/40 transition-transform duration-200 group-hover:text-white/70",
                              isExpanded && "rotate-180 text-white/70"
                            )}
                            aria-hidden="true"
                          >
                            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor">
                              <path d="M7 10l5 5 5-5H7z" />
                            </svg>
                          </div>
                        </div>
                      </button>

                      <div
                        className={clsx(
                          "overflow-hidden transition-all duration-200 ease-in-out",
                          isExpanded ? "max-h-[2000px] opacity-100" : "max-h-0 opacity-0"
                        )}
                      >
                        <div className="px-4 pb-4 pt-1 md:px-5">
                          {pack?.loading && (
                            <div className="text-sm text-white/60">Загружаем…</div>
                          )}
                          {pack?.error && (
                            <div className="text-sm text-rose-400">Ошибка: {pack.error}</div>
                          )}
                          {!pack?.loading && !pack?.error && (
                            <div className="space-y-4">
                              {hasSubscription ? (
                                <ForecastHero match={m} />
                              ) : (
                                <ForecastHero
                                  match={m}
                                  locked
                                  blurBody
                                  onUpgrade={openSubscription}
                                />
                              )}

                              <div className="rounded-[18px] border border-white/10 bg-white/[0.03] px-4 py-4">
                                <div className="text-[11px] uppercase tracking-[0.18em] text-white/50">
                                  Средние показатели (посл. 10)
                                </div>
                                <div className="mt-2 flex items-center justify-between text-[11px] text-white/45">
                                  <span>{m.home_team}</span>
                                  <span>{m.away_team}</span>
                                </div>
                                <div className="mt-3 space-y-3">
                                  <AvgCompareRow label="xG" left={pack?.homeAvg?.xg} right={pack?.awayAvg?.xg} />
                                  <AvgCompareRow label="Удары" left={pack?.homeAvg?.shots} right={pack?.awayAvg?.shots} />
                                  <AvgCompareRow label="Владение" left={pack?.homeAvg?.possession} right={pack?.awayAvg?.possession} isPercent />
                                </div>
                              </div>

                              <div className="rounded-[18px] border border-white/10 bg-white/[0.03] px-4 py-4">
                                <MatchInsightsPanelFull
                                  pack={pack}
                                  teamId={teamId}
                                  home={m.home_team}
                                  away={m.away_team}
                                  onOpenMatchModal={(fixtureId) => openMatchInResults(fixtureId)}
                                  variant="flat"
                                  hideAvgs
                                />
                              </div>

                              {!hasSubscription && null}
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            ))}
        </section>
      ) : null}

      </div>
    </div>
  );
}
