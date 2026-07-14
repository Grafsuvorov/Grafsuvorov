// src/pages/MatchSchedulePage.jsx
import React, { useEffect, useState, useCallback } from "react";
import { useSearchParams, useNavigate, useLocation } from "react-router-dom";
import { authFetch } from "@/lib/authFetch";
import SafeImg from "@/components/SafeImg";

import { useAuth } from "@/auth/AuthContext";
import { http } from "@/lib/http";
import { hasPilotFullAccess, shouldHideMonetization } from "@/lib/pilotAccess.js";
import {
  LEAGUE_ID_BY_NAME,
  decideOutcomeTier,
  decideTotalsTierByValues,
} from "@/lib/policyDecision";
import { fetchMatchesV3, isInternationalLongCycleLeague, seasonDateRange } from "@/lib/matchesApi";
import {
  CANCELLED_STATUS_HINTS,
  FINISHED_STATUSES,
  POSTPONED_STATUS_HINTS,
  estimateLiveElapsed,
  isLiveMatch,
  isStaleLiveStatus,
  liveMinuteLabel,
} from "@/lib/matchStatus";
import { teamLogoMap } from "@/constants/teamLogoMap";
import { useLanguage } from "@/context/LanguageContext.jsx";

/* ===========================
   CONFIG / HELPERS
=========================== */

const API_BASE = "";
const SCHEDULE_LOOKBACK_DAYS = 10;
const SCHEDULE_LOOKAHEAD_DAYS = 35;
const SCHEDULE_CACHE_TTL = 2 * 60 * 1000;

// кэш расписаний по ключу league|season
const scheduleCache = new Map();
// кэш разворотов по fixture_id
const detailsCache = new Map();

/** Безопасный fetch JSON с заменой NaN/Infinity */
async function fetchJsonSafe(url, signal) {
  const rsp = await authFetch(url, { signal });
  if (rsp.status === 401 || rsp.status === 403) return null;
  if (!rsp.ok) {
    const txt = await rsp.text().catch(() => "");
    throw new Error(`HTTP ${rsp.status}${txt ? `: ${txt}` : ""}`);
  }
  const txt = await rsp.text();
  try {
    return JSON.parse(txt);
  } catch {
    const fixed = txt
      .replace(/\bNaN\b/g, "null")
      .replace(/\b-?Infinity\b/g, "null");
    return JSON.parse(fixed);
  }
}

// разбор "15.08 20:00" с привязкой к сезону
function parseDatetimeDDMM(raw, seasonYear) {
  try {
    if (!raw) return { kickoff_local: "", isoDate: "", time: "" };

    const [dd, rest] = raw.trim().split(".");
    const [mm, time] = (rest || "").trim().split(" ");
    const day = String(dd || "").padStart(2, "0");
    const month = String(mm || "").padStart(2, "0");
    const m = Number(month) || 1;

    const season = Number(seasonYear) || new Date().getFullYear();
    const year = m >= 7 ? season : season + 1;

    const isoDate = `${year}-${month}-${day}`;
    const kickoff_local = `${day}.${month}` + (time ? ` ${time}` : "");

    return { kickoff_local, isoDate, time: time || "" };
  } catch {
    return { kickoff_local: raw || "", isoDate: "", time: "" };
  }
}

function logoSrc(teamId, name) {
  if (teamId) return `/icons/team_logos/${teamId}.png`;
  return teamLogoMap[name] || "/icons/team_logos/default.png";
}

function logoFallbackSrc(teamId) {
  if (teamId) return `https://media.api-sports.io/football/teams/${teamId}.png`;
  return "/icons/team_logos/default.png";
}

function scoreLabel(match) {
  const gh = Number(match.home_goals ?? match.home_score);
  const ga = Number(match.away_goals ?? match.away_score);

  if (Number.isFinite(gh) && Number.isFinite(ga)) {
    return `${gh}:${ga}`;
  }

  if (typeof match.score === "string" && match.score) {
    const m = match.score.match(/(\d+)\s*[-:]\s*(\d+)/);
    if (m) return `${m[1]}:${m[2]}`;
  }

  return "—";
}

function getMatchStateBadge(match, language = "ru") {
  if (isLiveMatch(match)) {
    return {
      kind: "live",
      label: "Live",
      sublabel: liveMinuteLabel(match, language) || (language === "ru" ? "В игре" : "Live"),
      pillClass:
        "border-rose-400/30 bg-gradient-to-r from-rose-500/20 to-orange-400/15 text-rose-100 shadow-[0_0_14px_rgba(244,63,94,0.18)]",
      sublabelClass: "text-white/90",
    };
  }

  const statusRaw = String(match?.status_short || match?.status || "").trim().toUpperCase();
  if (!statusRaw) return null;

  if (POSTPONED_STATUS_HINTS.some((hint) => statusRaw === hint || statusRaw.includes(hint))) {
    return {
      kind: "postponed",
      label: language === "ru" ? "Перенесён" : "Postponed",
      sublabel: "",
      pillClass:
        "border-amber-400/35 bg-amber-500/15 text-amber-200",
      sublabelClass: "text-white/70",
    };
  }

  if (CANCELLED_STATUS_HINTS.some((hint) => statusRaw === hint || statusRaw.includes(hint))) {
    return {
      kind: "cancelled",
      label: language === "ru" ? "Отменён" : "Cancelled",
      sublabel: "",
      pillClass:
        "border-white/15 bg-white/8 text-white/70",
      sublabelClass: "text-white/60",
    };
  }

  return null;
}

function isUnplayedMatch(match) {
  const hasScore = scoreLabel(match) !== "—";
  if (hasScore) return false;
  if (isLiveMatch(match)) return false;
  const statusRaw = match.status_short || match.status || "";
  const status = String(statusRaw).trim().toUpperCase();
  if (status && FINISHED_STATUSES.has(status)) return false;
  const kickoffRaw = match?.kickoff_at || match?.date;
  if (kickoffRaw) {
    const kickoff = new Date(String(kickoffRaw).replace(" ", "T"));
    const diffMinutes = Math.floor((Date.now() - kickoff.getTime()) / 60000);
    if (Number.isFinite(diffMinutes) && diffMinutes > 240) return false;
  }
  return true;
}

function formatDateTime(match, season) {
  if (match.kickoff_local) {
    const [d, t] = match.kickoff_local.split(" ");
    return { date: d || "", time: t || "" };
  }

  if (match.datetime) {
    const { kickoff_local } = parseDatetimeDDMM(match.datetime, season);
    const [d, t] = kickoff_local.split(" ");
    return { date: d || "", time: t || "" };
  }

  if (match.date) {
    const s = String(match.date);
    const iso = s.slice(0, 10);
    const [, m, d] = iso.split("-");
    const date = d && m ? `${d}.${m}` : s;
    const time = s.includes("T") ? s.slice(11, 16) : "";
    return { date, time };
  }

  return { date: "", time: "" };
}

function scheduleCardAccentClass(tier) {
  if (tier === "A") return "bg-violet-400/90 shadow-[0_0_14px_rgba(139,92,246,0.35)]";
  if (tier === "B") return "bg-violet-300/70 shadow-[0_0_12px_rgba(139,92,246,0.22)]";
  return "bg-white/18";
}

function roundTitle(matches, language = "ru") {
  const sample = matches[0] || {};
  const week = sample.week;
  if (week != null) return `${language === "ru" ? "Тур" : "Round"} ${week}`;
  return language === "ru" ? "Тур" : "Round";
}

const day = (s) => String(s || "").slice(0, 10);

/* ===== ХЕЛПЕРЫ v3-версии для H2H / last ===== */

const idOf = (x, side /* 'home' | 'away' */) => {
  const legacySide = side === "home" ? "localteam" : "visitorteam";
  const candidates = [
    x?.[`${side}_team_id`],
    x?.[`${side}_id`],
    x?.[`${legacySide}_id`],
    x?.teams?.[side]?.id,
    x?.[side]?.id,
  ];
  const v = candidates.find((vv) => Number.isFinite(Number(vv)));
  return Number.isFinite(Number(v)) ? Number(v) : NaN;
};

const normName = (s = "") =>
  String(s)
    .toLowerCase()
    .replace(/\s+fc$|^fc\s+/g, "")
    .replace(/[^\p{L}\p{N}]+/gu, "");

const nameOf = (x, side) => {
  const candidates = [
    x?.[`${side}_team`],
    x?.[`${side}_name`],
    x?.teams?.[side]?.name,
    x?.[side]?.name,
  ];
  const v = candidates.find((vv) => vv && String(vv).trim());
  return normName(v || "");
};

/* Нормализованный ряд для H2H/last – полностью совместим
   с тем, что ждут H2HBlock / LastMatchesBlock */
const normalizeRow = (x) => {
  const fixtureId =
    x.fixture_id ||
    x.id ||
    `${x.date || ""}-${x.home_team || ""}-${x.away_team || ""}`;

  const date = x.date || x.datetime || x?.fixture?.date || "";

  const rawHomeId =
    x.home_team_id ??
    x.home_id ??
    x.localteam_id ??
    x?.teams?.home?.id ??
    x?.home?.id;
  const rawAwayId =
    x.away_team_id ??
    x.away_id ??
    x.visitorteam_id ??
    x?.teams?.away?.id ??
    x?.away?.id;

  const home_team_id = Number.isFinite(Number(rawHomeId))
    ? Number(rawHomeId)
    : undefined;
  const away_team_id = Number.isFinite(Number(rawAwayId))
    ? Number(rawAwayId)
    : undefined;

  const home_team =
    x.home_team ||
    x.home_name ||
    x.localteam_name ||
    x?.teams?.home?.name ||
    x?.home?.name ||
    "";
  const away_team =
    x.away_team ||
    x.away_name ||
    x.visitorteam_name ||
    x?.teams?.away?.name ||
    x?.away?.name ||
    "";

  const gHomeRaw =
    x.home_goals ??
    x.home_score ??
    x?.goals?.home ??
    x?.score?.home ??
    x?.score?.fulltime?.home;
  const gAwayRaw =
    x.away_goals ??
    x.away_score ??
    x?.goals?.away ??
    x?.score?.away ??
    x?.score?.fulltime?.away;

  let hg = Number.isFinite(Number(gHomeRaw)) ? Number(gHomeRaw) : null;
  let ag = Number.isFinite(Number(gAwayRaw)) ? Number(gAwayRaw) : null;

  const strScoreCandidate =
    typeof x.score === "string"
      ? x.score
      : typeof x?.score?.fulltime === "string"
      ? x.score.fulltime
      : typeof x?.ft_score === "string"
      ? x.ft_score
      : "";

  if (hg == null || ag == null) {
    const s = strScoreCandidate || "";
    const m = s.match(/(\d+)\s*[-:]\s*(\d+)/);
    if (m) {
      hg = parseInt(m[1], 10);
      ag = parseInt(m[2], 10);
    }
  }

  const score =
    hg != null && ag != null ? `${hg}:${ag}` : strScoreCandidate || "";

  return {
    fixture_id: fixtureId,
    date,
    home_team_id,
    away_team_id,
    home_team,
    away_team,
    home_goals: hg != null ? hg : undefined,
    away_goals: ag != null ? ag : undefined,
    // дублируем как score-поля, которые могли использоваться в старых компонентах
    home_score: hg != null ? hg : undefined,
    away_score: ag != null ? ag : undefined,
    score,
  };
};

/* ===========================
   SMALL UI PARTS
=========================== */

function LogoBadge({ id, name, onClick }) {
  return (
    <span
      role="button"
      tabIndex={0}
      onClick={(e) => {
        e.stopPropagation();
        onClick?.();
      }}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          e.stopPropagation();
          onClick?.();
        }
      }}
      className="inline-flex items-center justify-center"
      aria-label={name || "team"}
    >
      <span className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-white/[0.04] border border-white/10 overflow-hidden sm:h-8 sm:w-8">
        <SafeImg
          src={logoSrc(id, name)}
          alt={name || "team"}
          className="h-5 w-5 object-contain sm:h-6 sm:w-6"
          fallbackSrc={logoFallbackSrc(id)}
        />
      </span>
    </span>
  );
}

function TeamLine({ name, teamId, onGoTeam, align = "left" }) {
  return (
    <div
      className={[
        "flex items-center gap-2 min-w-0 sm:gap-3",
        align === "right" ? "justify-end" : "justify-start",
      ].join(" ")}
    >
      {align === "right" ? (
        <>
          <span className="truncate text-xs text-white/90 text-right sm:text-[14px]">{name}</span>
          <LogoBadge id={teamId} name={name} onClick={() => onGoTeam?.(teamId)} />
        </>
      ) : (
        <>
          <LogoBadge id={teamId} name={name} onClick={() => onGoTeam?.(teamId)} />
          <span className="truncate text-xs text-white/90 sm:text-[14px]">{name}</span>
        </>
      )}
    </div>
  );
}

const AVG_METRICS = [
  { key: "xg", label: "xG" },
  { key: "shots", label: "Удары" },
  { key: "shots_on", label: "В створ" },
  { key: "possession", label: "Владение (%)" },
  { key: "corners", label: "Угловые" },
];

function StatsColumn({ team, teamId, avg, align = "left" }) {
  if (!avg) {
    return (
      <div className="text-[12px] text-white/55">
        Нет данных по средней статистике.
      </div>
    );
  }

  return (
    <div
      className={[
        "flex min-w-0 flex-1 items-center gap-2 text-xs font-semibold text-white/88 sm:gap-3 sm:text-[14px]",
        align === "right" ? "justify-end text-right" : "justify-start text-left",
      ].join(" ")}
    >
      {align === "right" ? (
        <>
          <span className="truncate">{team}</span>
          <span
            className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-white/10 bg-white/[0.04] sm:h-10 sm:w-10"
            aria-hidden="true"
          >
            <SafeImg
              src={logoSrc(teamId, team)}
              alt={team || "team"}
              className="h-5 w-5 object-contain opacity-95 sm:h-6 sm:w-6"
              fallbackSrc={logoFallbackSrc(teamId)}
            />
          </span>
        </>
      ) : null}
      {align !== "right" ? (
        <>
          <span
            className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-white/10 bg-white/[0.04] sm:h-10 sm:w-10"
            aria-hidden="true"
          >
            <SafeImg
              src={logoSrc(teamId, team)}
              alt={team || "team"}
              className="h-5 w-5 object-contain opacity-95 sm:h-6 sm:w-6"
              fallbackSrc={logoFallbackSrc(teamId)}
            />
          </span>
          <span className="truncate">{team}</span>
        </>
      ) : null}
    </div>
  );
}

function ComparisonRow({ label, leftVal, rightVal, format, emphasis = "normal" }) {
  const l = Number.isFinite(Number(leftVal)) ? Number(leftVal) : null;
  const r = Number.isFinite(Number(rightVal)) ? Number(rightVal) : null;
  const max = Math.max(l ?? 0, r ?? 0);
  const min = Math.min(l ?? 0, r ?? 0);
  const isNearEqual =
    l != null &&
    r != null &&
    Math.abs(Number(l) - Number(r)) <= 0.001;
  const cap = min > 0 ? 46 : 50;
  const minVisible = min > 0 ? 12 : 0;
  let lPct = max > 0 ? (l / max) * cap : 0;
  let rPct = max > 0 ? (r / max) * cap : 0;
  if (l != null && l > 0) lPct = Math.max(lPct, minVisible);
  if (r != null && r > 0) rPct = Math.max(rPct, minVisible);
  if (isNearEqual) {
    lPct = 50;
    rPct = 50;
  }
  const lHigher = l != null && r != null ? l >= r : l != null;
  const relGap = max > 0 ? Math.abs((l ?? 0) - (r ?? 0)) / max : 0;
  const neutralDuel = relGap < 0.05;
  const show = (v) => (v == null ? "—" : format(v));

  const barHeight = "h-2";

  return (
    <div className="space-y-3">
      <div className="grid grid-cols-[56px_minmax(0,1fr)_56px] items-center sm:grid-cols-[1fr_auto_1fr]">
        <div className="text-left text-[13px] font-semibold text-white/85 tabular-nums sm:text-[15px]">
          {show(l)}
        </div>
        <div className="min-w-0 px-1 text-center text-[9px] font-medium text-white/84 sm:px-3 sm:text-[10px]">
          {label}
        </div>
        <div className="text-right text-[13px] font-semibold text-white/85 tabular-nums sm:text-[15px]">
          {show(r)}
        </div>
      </div>
      <div className={`relative ${barHeight} rounded-full bg-white/10 overflow-hidden`}>
        <div className="pointer-events-none absolute left-0 top-0 h-full w-1/2 bg-white/[0.04]" />
        <div className="pointer-events-none absolute right-0 top-0 h-full w-1/2 bg-white/[0.04]" />
        <div className="pointer-events-none absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-white/8" />
        <div
          className="absolute right-1/2 top-0 h-full bg-violet-500/85"
          style={{ width: `${lPct}%` }}
        />
        <div
          className="absolute left-1/2 top-0 h-full bg-gradient-to-l from-sky-400/80 to-teal-400/70"
          style={{ width: `${rPct}%` }}
        />
      </div>
    </div>
  );
}

function AdvantageIndex({ home, away }) {
  const metrics = [
    { key: "xg", weight: 1 },
    { key: "shots", weight: 1 },
    { key: "possession", weight: 1 },
    { key: "corners", weight: 1 },
  ];
  let score = 0;
  let total = 0;
  metrics.forEach((m) => {
    const l = Number(home?.[m.key]);
    const r = Number(away?.[m.key]);
    if (!Number.isFinite(l) || !Number.isFinite(r)) return;
    const max = Math.max(l, r) || 1;
    score += ((l - r) / max) * m.weight;
    total += m.weight;
  });
  if (!total) return null;
  const value = score / total;
  const side = value >= 0 ? "home" : "away";
  const abs = Math.abs(value);
  return { side, value: abs };
}

function MatchRow({ match, season, onClick, onGoTeam, expanded, language = "ru" }) {
  const { date, time } = formatDateTime(match, season);
  const badge = getMatchStateBadge(match, language);
  const centerLine = badge ? "" : time ? `${date} · ${time}` : date;

  return (
    <button
      type="button"
      onClick={() => onClick?.(match)}
      className={[
        "w-full px-3 py-3 text-left transition-all duration-200 rounded-xl cursor-pointer sm:px-5 sm:py-4",
        "grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center gap-2 sm:gap-4",
        expanded ? "bg-white/[0.03]" : "hover:bg-white/5",
      ].join(" ")}
    >
      {/* LEFT */}
      <div className="min-w-0">
        <TeamLine name={match.home_team} teamId={match.home_team_id} onGoTeam={onGoTeam} />
      </div>

      {/* CENTER */}
      <div className="w-[82px] text-center text-[12px] text-white/70 tabular-nums sm:w-auto sm:min-w-[118px] sm:text-[14px]">
        {badge ? (
          <div className="flex flex-col items-center gap-1">
            <span className={`inline-flex h-6 items-center rounded-full border px-2.5 text-[10px] font-semibold uppercase tracking-[0.12em] ${badge.pillClass}`}>
              {badge.label}
            </span>
            {badge.sublabel ? (
              <span className={`text-[13px] font-semibold ${badge.sublabelClass}`}>
                {badge.sublabel}
              </span>
            ) : null}
          </div>
        ) : (
          centerLine || "—"
        )}
      </div>

      {/* RIGHT */}
      <div className="min-w-0">
        <TeamLine
          name={match.away_team}
          teamId={match.away_team_id}
          onGoTeam={onGoTeam}
          align="right"
        />
      </div>
    </button>
  );
}

/* ===========================
   HUMAN-REASON BUILDER
=========================== */

function buildHumanReason(match) {
  const recDecision = match?.rec_decision;
  const signalPick = match?.signal_pick;
  const signalP = Number(match?.signal_p);
  const signalOdds = Number(match?.signal_odds);
  const signalEV = Number(match?.signal_value);
  const signalEdge = Number(match?.signal_edge);
  const signalType = match?.signal_type; // align / contrarian
  const books = match?.books;

  const isFiniteNum = (v) => Number.isFinite(v);

  const parts = [];

  if (recDecision === "BET") {
    if (signalPick) {
      parts.push(`Базовая ставка модели — ${signalPick}.`);
    }
    if (isFiniteNum(signalP) && isFiniteNum(signalOdds)) {
      parts.push(
        `Модель оценивает вероятность исхода примерно в ${(signalP * 100).toFixed(
          1
        )}% при коэффициенте около ${signalOdds.toFixed(2)}.`
      );
    }
    if (isFiniteNum(signalEV)) {
      parts.push(
        `Ожидаемое значение ставки — около ${(signalEV * 100).toFixed(
          1
        )}%.`
      );
    }
    if (isFiniteNum(signalEdge)) {
      parts.push(
        `Преимущество над линией букмекеров — порядка ${(signalEdge * 100).toFixed(
          1
        )} п.п.`
      );
    }
    if (signalType === "contrarian") {
      parts.push(
        "Сигнал контр-рыночный: модель идёт против основного движения коэффициентов."
      );
    } else if (signalType === "align") {
      parts.push(
        "Сигнал по тренду рынка: модель совпадает с направлением движения коэффициентов."
      );
    }
    if (books) {
      parts.push(`Расчёт выполнен по данным примерно ${books} букмекеров.`);
    }
  } else {
    parts.push(
      "Модель не видит достаточного преимущества над линией и предлагает пропустить матч."
    );
    if (isFiniteNum(signalEdge)) {
      parts.push(
        `Преимущество оценивается всего в ${(signalEdge * 100).toFixed(
          1
        )} п.п., что ниже порога для value-ставки.`
      );
    }
    if (isFiniteNum(signalEV)) {
      parts.push(
        `Ожидаемое значение близко к нулю — около ${(signalEV * 100).toFixed(
          1
        )}%.`
      );
    }
  }

  return parts.join(" ");
}

function generateEdgeScoreText({ match, stats, locked, insight, language = "ru" }) {
  const home = match?.home_team || (language === "ru" ? "Хозяева" : "Home");
  const away = match?.away_team || (language === "ru" ? "Гости" : "Away");
  const leagueId =
    Number.isFinite(Number(match?.league_id))
      ? Number(match?.league_id)
      : LEAGUE_ID_BY_NAME[match?.league] || null;
  const recOutcome = insight?.recommendations?.outcome || null;
  const recTotal = insight?.recommendations?.total || null;
  const recSelectedMarket = insight?.recommendations?.selected_market || null;
  const recSelectedTier = insight?.recommendations?.selected_tier || null;
  const probs = {
    H: Number(insight?.probs_1x2?.home ?? match?.p_home),
    D: Number(insight?.probs_1x2?.draw ?? match?.p_draw),
    A: Number(insight?.probs_1x2?.away ?? match?.p_away),
    O: Number(match?.p_over25),
    U: Number(match?.p_under25),
  };
  const odds = {
    H: Number(insight?.odds_1x2?.home ?? match?.avg_odds_home),
    D: Number(insight?.odds_1x2?.draw ?? match?.avg_odds_draw),
    A: Number(insight?.odds_1x2?.away ?? match?.avg_odds_away),
    O: Number(match?.avg_odds_over25),
    U: Number(match?.avg_odds_under25),
  };
  const isNum = (v) => Number.isFinite(v);
  const fmtPct = (v) => {
    if (!isNum(v)) return "—";
    if (v === 0) return "≈0%";
    const pct = Math.round(v * 100);
    if (v > 0 && pct === 0) return "<1%";
    return `${pct}%`;
  };
  const valuePct = (prob, k) => {
    if (!isNum(prob) || !isNum(k) || k <= 0) return null;
    return (prob - 1 / k) * 100;
  };
  const topPick = (items) =>
    items.reduce((a, b) => (a.prob >= b.prob ? a : b));
  const hashKey = (str) =>
    String(str || "")
      .split("")
      .reduce((acc, ch) => acc + ch.charCodeAt(0), 0);
  const pickPhrase = (list, seed) => list[seed % list.length];
  const leaderName = (diff) => (diff >= 0 ? home : away);

  const items1x2 = [
    { code: "H", label: "П1", prob: probs.H, odds: odds.H },
    { code: "D", label: "Х", prob: probs.D, odds: odds.D },
    { code: "A", label: "П2", prob: probs.A, odds: odds.A },
  ].filter((i) => isNum(i.prob));
  const itemsO25 = [
    { code: "O", label: "ТБ 2.5", prob: probs.O, odds: odds.O },
    { code: "U", label: "ТМ 2.5", prob: probs.U, odds: odds.U },
  ].filter((i) => isNum(i.prob));

  const pick1x2 =
    recOutcome && isNum(recOutcome.p)
      ? {
          code:
            recOutcome.outcome === "home"
              ? "H"
              : recOutcome.outcome === "away"
                ? "A"
                : "D",
          label: recOutcome.label || (recOutcome.outcome === "draw" ? "Х" : recOutcome.outcome === "away" ? "П2" : "П1"),
          prob: Number(recOutcome.p),
          odds: Number(recOutcome.odds),
        }
      : items1x2.length
        ? topPick(items1x2)
        : null;
  const pickO25 =
    recTotal && isNum(recTotal.p)
      ? {
          code: recTotal.outcome === "over" ? "O" : "U",
          label: recTotal.label || (recTotal.outcome === "over" ? "ТБ 2.5" : "ТМ 2.5"),
          prob: Number(recTotal.p),
          odds: Number(recTotal.odds),
        }
      : itemsO25.length
        ? topPick(itemsO25)
        : null;
  const val1 = pick1x2 ? valuePct(pick1x2.prob, pick1x2.odds) : null; // in pct points
  const val2 = pickO25 ? valuePct(pickO25.prob, pickO25.odds) : null; // in pct points
  const outcomeTier =
    recOutcome?.saved && recOutcome?.tier
      ? recOutcome.tier
      : leagueId == null || !pick1x2
      ? "NO BET"
      : decideOutcomeTier((pick1x2.prob || 0) * (pick1x2.odds || 0) - 1, pick1x2.odds, leagueId, pick1x2.code === "H" ? "home" : pick1x2.code === "D" ? "draw" : "away");
  const totalsTier =
    recTotal?.saved && recTotal?.tier
      ? recTotal.tier
      : leagueId == null
      ? "NO BET"
      : decideTotalsTierByValues({
          pOver25: probs.O,
          avgOddsOver25: odds.O,
          avgOddsUnder25: odds.U,
          leagueId,
        });
  const tierScore = { A: 2, B: 1, "NO BET": 0 };
  const dominantTier =
    recSelectedTier ||
    (recSelectedMarket === "1X2"
      ? outcomeTier
      : recSelectedMarket === "OU25"
        ? totalsTier
        : tierScore[outcomeTier] >= tierScore[totalsTier]
          ? outcomeTier
          : totalsTier);

  const outcomeTeam =
    pick1x2?.code === "H" ? home : pick1x2?.code === "A" ? away : language === "ru" ? "ничья" : "draw";
  const hero = locked
    ? language === "ru"
      ? "Модель EdgeScore оценивает матч через форму, xG и рыночную линию. Ниже — ключевые факторы и финальная оценка сценариев."
      : "The EdgeScore model evaluates the match through form, xG and the market line. Below are the key factors and the final scenario view."
    : (() => {
        const h = stats?.home || {};
        const a = stats?.away || {};
        const metricWinners = [];
        const metric = (name, hv, av) => {
          if (!isNum(hv) || !isNum(av)) return;
          if (Math.abs(hv - av) < 1e-6) return;
          metricWinners.push({ name, winner: hv > av ? home : away });
        };
        metric("xG", Number(h.xg), Number(a.xg));
        metric("shots", Number(h.shots), Number(a.shots));
        metric("possession", Number(h.possession), Number(a.possession));
        metric("corners", Number(h.corners), Number(a.corners));

        const wins = metricWinners.reduce(
          (acc, m) => {
            acc[m.winner] = (acc[m.winner] || 0) + 1;
            return acc;
          },
          {}
        );
        const statLeader =
          (wins[home] || 0) === (wins[away] || 0)
            ? null
            : (wins[home] || 0) > (wins[away] || 0)
              ? home
              : away;

        if (!statLeader) {
          return language === "ru"
            ? "Силы команд выглядят сопоставимыми по ключевым метрикам. Основной сценарий формируется за счёт нюансов формы и рыночной оценки."
            : "The teams look close on the key metrics. The main scenario is shaped by form details and market pricing.";
        }
        if (pick1x2 && outcomeTeam !== (language === "ru" ? "ничья" : "draw") && statLeader !== outcomeTeam) {
          return language === "ru"
            ? `${statLeader} выглядит активнее по статистике, но модель склоняется к сценарию в пользу ${outcomeTeam}. Ключевой фактор здесь — рыночное расхождение, а не чистое доминирование по цифрам.`
            : `${statLeader} looks stronger on the raw stats, but the model leans toward ${outcomeTeam}. The key factor is market mispricing rather than pure statistical dominance.`;
        }
        return language === "ru"
          ? `Общая картина: по качеству игры и контролю темпа ${statLeader} выглядит предпочтительнее. Дальше важно понять, даёт ли текущая линия рынка рабочий запас.`
          : `Overall, ${statLeader} looks better in game quality and tempo control. The next question is whether the current market line still leaves a workable edge.`;
      })();

  const factors = [];
  if (!locked && stats?.home && stats?.away) {
    const mk = (a, b, rel, abs, fmt) => {
      if (!isNum(a) || !isNum(b)) return null;
      const diff = a - b;
      const absDiff = Math.abs(diff);
      const relDiff = absDiff / Math.max(Math.abs(b), 1e-6);
      if (absDiff < (abs ?? 0) && relDiff < rel) return null;
      const homeBetter = diff > 0;
      return {
        leader: homeBetter ? home : away,
        leadVal: fmt(homeBetter ? a : b),
        trailVal: fmt(homeBetter ? b : a),
      };
    };

    const xg = mk(
      Number(stats.home.xg),
      Number(stats.away.xg),
      0.15,
      0,
      (v) => v.toFixed(2)
    );
    if (xg) {
      factors.push(language === "ru" ? `По xG перевес у ${xg.leader}: ${xg.leadVal} против ${xg.trailVal}.` : `xG edge for ${xg.leader}: ${xg.leadVal} vs ${xg.trailVal}.`);
    }

    const shots = mk(
      Number(stats.home.shots),
      Number(stats.away.shots),
      0.15,
      0,
      (v) => v.toFixed(1)
    );
    if (shots) {
      factors.push(language === "ru" ? `По ударам впереди ${shots.leader}: ${shots.leadVal} против ${shots.trailVal}.` : `Shot edge for ${shots.leader}: ${shots.leadVal} vs ${shots.trailVal}.`);
    }

    const poss = mk(
      Number(stats.home.possession),
      Number(stats.away.possession),
      0.12,
      6,
      (v) => `${v.toFixed(0)}%`
    );
    if (poss) {
      factors.push(language === "ru" ? `По владению устойчивее ${poss.leader}: ${poss.leadVal} против ${poss.trailVal}.` : `Possession edge for ${poss.leader}: ${poss.leadVal} vs ${poss.trailVal}.`);
    }

    const corners = mk(
      Number(stats.home.corners),
      Number(stats.away.corners),
      0.2,
      1.2,
      (v) => v.toFixed(1)
    );
    if (corners) {
      factors.push(language === "ru" ? `По угловым небольшой перевес у ${corners.leader}: ${corners.leadVal} против ${corners.trailVal}.` : `Small corners edge for ${corners.leader}: ${corners.leadVal} vs ${corners.trailVal}.`);
    }
  }
  if (!factors.length) {
    factors.push(
      locked
        ? (language === "ru" ? "Форма и качество моментов команд сопоставимы — модель не видит явного перекоса." : "Form and chance quality are close, so the model does not see a clear skew.")
        : (language === "ru" ? "Статистика команд близка по ключевым метрикам — ярко выраженного перевеса по базе не видно." : "The teams are close on the main metrics, so the base numbers do not show a strong edge.")
    );
  }
  const prediction = [];
  prediction.push(language === "ru" ? "Вероятности 1X2 и тотала — это оценка нашей модели EdgeScore." : "1X2 and total probabilities are estimated by the EdgeScore model.");
  prediction.push(
    dominantTier === "A"
      ? language === "ru"
        ? "Рынок сейчас: есть заметное расхождение между моделью и линией."
        : "Market read: there is a meaningful gap between the model and the line."
      : dominantTier === "B"
        ? language === "ru"
          ? "Рынок сейчас: перевес есть, но запас ограничен."
          : "Market read: there is an edge, but the margin is limited."
        : language === "ru"
          ? "Рынок сейчас: линия близка к справедливой, явного перекоса нет."
          : "Market read: the line looks close to fair with no obvious skew."
  );
  const explainByTier = (tier, value) => {
    if (tier === "A") return language === "ru" ? "запас по value рабочий" : "the value margin is actionable";
    if (tier === "B") return language === "ru" ? "плюс есть, но без запаса" : "there is an edge, but without enough margin";
    if (isNum(value) && value > 0) return language === "ru" ? "плюс ниже рабочего порога" : "the edge is below the working threshold";
    if (!isNum(value)) return language === "ru" ? "коэффициенты недоступны, value не оценивается" : "odds are unavailable, so value cannot be assessed";
    return language === "ru" ? "входа нет" : "no entry";
  };
  if (!locked && pick1x2) {
    const pHome = items1x2.find((x) => x.code === "H");
    const pDraw = items1x2.find((x) => x.code === "D");
    const pAway = items1x2.find((x) => x.code === "A");
    const valueText = isNum(val1) ? `${val1 >= 0 ? "+" : ""}${val1.toFixed(1)}%` : "—";
    prediction.push(
      language === "ru"
        ? `1X2: П1 ${fmtPct(pHome?.prob)} · Х ${fmtPct(pDraw?.prob)} · П2 ${fmtPct(pAway?.prob)}.`
        : `1X2: 1 ${fmtPct(pHome?.prob)} · X ${fmtPct(pDraw?.prob)} · 2 ${fmtPct(pAway?.prob)}.`
    );
    prediction.push(
      language === "ru"
        ? `По исходу: базовый сценарий ${pick1x2.label}. Value ${valueText} — ${explainByTier(outcomeTier, val1)}.`
        : `Outcome: base scenario ${pick1x2.label}. Value ${valueText} — ${explainByTier(outcomeTier, val1)}.`
    );
  }
  if (!locked && pickO25) {
    const pOver = itemsO25.find((x) => x.code === "O");
    const pUnder = itemsO25.find((x) => x.code === "U");
    const valueText = isNum(val2) ? `${val2 >= 0 ? "+" : ""}${val2.toFixed(1)}%` : "—";
    prediction.push(
      language === "ru"
        ? `Тотал 2.5: ТБ ${fmtPct(pOver?.prob)} · ТМ ${fmtPct(pUnder?.prob)}.`
        : `Total 2.5: Over ${fmtPct(pOver?.prob)} · Under ${fmtPct(pUnder?.prob)}.`
    );
    prediction.push(
      language === "ru"
        ? `По тоталу: базовый сценарий ${pickO25.label}. Value ${valueText} — ${explainByTier(totalsTier, val2)}.`
        : `Total: base scenario ${pickO25.label}. Value ${valueText} — ${explainByTier(totalsTier, val2)}.`
    );
  }
  if (!prediction.length) {
    prediction.push(
      language === "ru"
        ? "Прогноз построен на модели xG и форме команд, детали доступны по подписке."
        : "The forecast is based on xG and team form; full details are available with a subscription."
    );
  }

  const final =
    dominantTier === "A"
      ? language === "ru"
        ? `Рабочий сценарий — ${pick1x2 ? pick1x2.label : "по модели"}. Есть устойчивый перевес относительно линии.`
        : `The working scenario is ${pick1x2 ? pick1x2.label : "the model lean"}. There is a stable edge versus the line.`
      : dominantTier === "B"
        ? language === "ru"
          ? `${pick1x2 ? pick1x2.label : "Основной сценарий"} выглядит разумно, но без запаса. Оптимально играть аккуратно.`
          : `${pick1x2 ? pick1x2.label : "The main scenario"} looks reasonable, but without enough margin. A cautious approach fits better.`
        : language === "ru"
          ? "Заметного преимущества над линией нет. Лучшее решение — наблюдать и ждать движения рынка."
          : "There is no notable edge over the line. The best move is to watch and wait for the market to shift.";

  const confidence =
    isNum(probs.H) || isNum(probs.D) || isNum(probs.A)
      ? Math.max(Number(probs.H || 0), Number(probs.D || 0), Number(probs.A || 0)) * 100
      : null;

  return {
    hero,
    factors,
    prediction,
    final,
    cta: language === "ru" ? "Открыть аналитику EdgeScore" : "Open EdgeScore analytics",
    probs: { p1: probs.H, px: probs.D, p2: probs.A },
    confidence,
  };
}

/* ===========================
   PREMIUM ANALYTICS BLOCK
   (фиолетовая карточка прогноза)
=========================== */

function PremiumAnalyticsBlock({ match, locked = false }) {
  // поля из /api/matches_v3
  const p1 = match?.p_home;
  const px = match?.p_draw;
  const p2 = match?.p_away;
  const pov = match?.p_over25;
  const pun = match?.p_under25;

  const outcomeLabel = match?.outcome_label; // "П1", "Х", "П2"
  const totalLabel = match?.total_label; // "Больше 2.5" / "Меньше 2.5"

  const oddsHome = match?.avg_odds_home;
  const oddsDraw = match?.avg_odds_draw;
  const oddsAway = match?.avg_odds_away;
  const oddsOver = match?.avg_odds_over25;
  const oddsUnder = match?.avg_odds_under25;
  const leagueId =
    Number.isFinite(Number(match?.league_id))
      ? Number(match?.league_id)
      : LEAGUE_ID_BY_NAME[match?.league] || null;

  const hasOutcome = [p1, px, p2].some(
    (v) => v != null && Number.isFinite(Number(v))
  );
  const hasTotal = [pov, pun].some(
    (v) => v != null && Number.isFinite(Number(v))
  );
  const hasAnyProb = hasOutcome || hasTotal;

  const toPctLabel = (v) => {
    if (v == null || !Number.isFinite(Number(v))) return "—";
    const num = Number(v);
    if (num === 0) return "≈0%";
    const pct = Math.round(num * 100);
    if (num > 0 && pct === 0) return "<1%";
    return `${pct}%`;
  };
  const toFixed = (v) =>
    v == null || !Number.isFinite(Number(v)) ? null : Number(v).toFixed(2);
  const impliedProb = (odds) =>
    odds == null || !Number.isFinite(Number(odds)) || Number(odds) <= 0
      ? null
      : 1 / Number(odds);
  const valueEdge = (prob, odds) => {
    if (!Number.isFinite(Number(prob))) return null;
    const implied = impliedProb(odds);
    if (implied == null) return null;
    return Number(prob) - implied;
  };
  const fmtValue = (value) => {
    if (value == null || !Number.isFinite(Number(value))) return "value нет";
    const pct = Number(value) * 100;
    if (Math.abs(pct) < 0.5) return "value нет";
    return `value ${pct >= 0 ? "+" : ""}${pct.toFixed(1)}%`;
  };
  const statusBadge = () => {
    if (locked) {
      return { text: "Доступ", hint: "по подписке" };
    }
    if (outcomePolicyTier === "A" || totalsPolicyTier === "A") {
      return { text: "Сильный сигнал", hint: "перевес над линией устойчивый" };
    }
    if (outcomePolicyTier === "B" || totalsPolicyTier === "B") {
      return { text: "Рабочий сигнал", hint: "перевес есть, но умеренный" };
    }
    return { text: "Наблюдать", hint: "ниже порога для входа" };
  };

  const outcomePolicyTier = (() => {
    if (!hasOutcome || leagueId == null) return "NO BET";
    const candidates = [
      { key: "home", p: Number(p1), odds: Number(oddsHome), outcome: "home" },
      { key: "draw", p: Number(px), odds: Number(oddsDraw), outcome: "draw" },
      { key: "away", p: Number(p2), odds: Number(oddsAway), outcome: "away" },
    ].filter((x) => Number.isFinite(x.p) && Number.isFinite(x.odds));
    if (!candidates.length) return "NO BET";
    const top = candidates.sort((a, b) => b.p - a.p)[0];
    const ev = top.p * top.odds - 1;
    return decideOutcomeTier(ev, top.odds, leagueId, top.outcome);
  })();

  const totalsPolicyTier =
    leagueId == null
      ? "NO BET"
      : decideTotalsTierByValues({
          pOver25: pov,
          avgOddsOver25: oddsOver,
          avgOddsUnder25: oddsUnder,
          leagueId,
        });

  const humanReason = match?.rec_reason_human || buildHumanReason(match || {});

  const tierPillClass = (tier) => {
    if (tier === "A") return "bg-violet-500/15 text-violet-200 border-violet-400/40";
    if (tier === "B") return "bg-violet-400/10 text-violet-200 border-violet-300/30";
    return "bg-white/[0.03] text-white/45 border-white/10";
  };
  const barAccentClass = (tier, highlighted) => {
    if (!highlighted || tier === "NO BET") {
      return "bg-white/20 shadow-[0_0_10px_rgba(255,255,255,0.08)]";
    }
    if (tier === "A") {
      return "bg-gradient-to-r from-violet-500/90 to-violet-400/65 shadow-[0_0_12px_rgba(139,92,246,0.35)]";
    }
    return "bg-gradient-to-r from-violet-500/70 to-violet-400/45 shadow-[0_0_10px_rgba(139,92,246,0.25)]";
  };
  const renderProbOption = (opt, { highlighted = false, tier = "NO BET" } = {}) => {
    const probValue = Number.isFinite(Number(opt?.prob)) ? Math.max(0, Math.min(100, Number(opt.prob) * 100)) : 0;
    const odds = toFixed(opt?.odds);
    const val = fmtValue(valueEdge(opt?.prob, opt?.odds));
    return (
      <div
        key={opt.key}
        className={highlighted ? "rounded-xl bg-white/[0.06] px-4 py-3 border border-white/10" : "rounded-xl bg-white/[0.03] px-3 py-3 border border-white/8"}
      >
        <div className="flex items-center justify-between gap-3 text-[12px]">
          <span className={highlighted ? "text-white/85" : "text-white/65"}>{highlighted ? "Выбор модели" : opt.label}</span>
          <span className={highlighted ? "text-white/55" : "text-white/45"}>{highlighted ? opt.label : (locked ? "— · k=— · value —" : `${toPctLabel(opt.prob)} · ${odds ? `k=${odds}` : "k=—"} · ${val}`)}</span>
        </div>
        <div className="mt-2 flex items-end justify-between gap-3">
          <div className={highlighted ? "text-[22px] font-semibold text-white/90 tabular-nums" : "text-[14px] font-medium text-white/80 tabular-nums"}>
            {locked ? "—" : toPctLabel(opt.prob)}
          </div>
          {highlighted && (
            <div className="text-[12px] text-white/60">
              {locked ? "k=— · value —" : `${odds ? `k=${odds}` : "k=—"} · ${val}`}
            </div>
          )}
        </div>
        <div className="mt-2 h-[6px] rounded-full bg-white/8 overflow-hidden">
          <div
            className={`h-full rounded-full ${barAccentClass(tier, highlighted)}`}
            style={{ width: `${locked ? 0 : probValue}%` }}
          />
        </div>
      </div>
    );
  };

  const outcomeLabelView = outcomeLabel;
  const totalLabelView = totalLabel;
  if (!hasAnyProb && !humanReason && !locked) {
    return (
      <div className="rounded-[24px] bg-white/[0.03] px-5 py-4 border border-white/10">
        <div className="text-[13px] text-white/60">
          Для этого матча прогноз модели пока недоступен.
        </div>
      </div>
    );
  }

  return (
    <div className="rounded-[24px] bg-slate-900/85 px-6 py-6 space-y-5">
      {/* HEADER */}
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="text-[18px] font-semibold text-white">Прогноз и value</div>
          <div className="mt-1 text-[13px] leading-relaxed text-white/65">
            Вероятности и расхождения с рынком
          </div>
        </div>
        <div className="mt-1 flex flex-col items-end gap-1 text-right">
          {(() => {
            const status = statusBadge();
            return (
              <>
                <span className="surface-chip h-7 px-3 py-0 text-[11px]">
                  {status.text}
                </span>
                <span className="text-[11px] text-white/50">{status.hint}</span>
              </>
            );
          })()}
        </div>
      </div>

      <div className="space-y-4">
        {/* MARKETS */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* 1X2 */}
          <div className="relative overflow-hidden rounded-2xl bg-white/[0.02] px-4 py-4 space-y-3 border border-white/5">
            <div className={`absolute left-0 top-3 bottom-3 w-[3px] rounded-full ${scheduleCardAccentClass(outcomePolicyTier)}`} />
            <div className="flex items-center justify-between gap-2">
              <div className="pl-2 text-[9px] uppercase tracking-[0.12em] text-white/45">
                Исход 1X2
              </div>
              <span
                className={`inline-flex h-6 items-center rounded-full border px-2.5 text-[10px] ${tierPillClass(
                  outcomePolicyTier
                )}`}
              >
                {outcomePolicyTier === "A"
                  ? "Сильный"
                  : outcomePolicyTier === "B"
                    ? "Рабочий"
                    : "Наблюдать"}
              </span>
            </div>
            {hasOutcome ? (
              (() => {
                const options = [
                  {
                    key: "П1",
                    label: "П1",
                    prob: p1,
                    odds: oddsHome,
                  },
                  {
                    key: "Х",
                    label: "Х",
                    prob: px,
                    odds: oddsDraw,
                  },
                  {
                    key: "П2",
                    label: "П2",
                    prob: p2,
                    odds: oddsAway,
                  },
                ];
                const heroKey = !locked && outcomePolicyTier !== "NO BET" ? outcomeLabelView : null;
                const hero =
                  options.find((opt) => opt.key === heroKey) || null;
                const secondary = hero
                  ? options.filter((opt) => opt.key !== hero.key)
                  : options;
                return (
                  <div className="space-y-3">
                    {hero ? renderProbOption(hero, { highlighted: true, tier: outcomePolicyTier }) : null}
                    <div className="space-y-2">
                      {secondary.map((opt) =>
                        renderProbOption(opt, {
                          highlighted: false,
                          tier: hero ? "NO BET" : outcomePolicyTier,
                        })
                      )}
                    </div>
                  </div>
                );
              })()
            ) : (
              <div className="text-[13px] text-white/50 mt-1">
                Для этого матча нет оценок вероятностей 1X2.
              </div>
            )}
          </div>

          {/* TOTAL 2.5 */}
          <div className="relative overflow-hidden rounded-2xl bg-white/[0.02] px-4 py-4 space-y-3 border border-white/5">
            <div className={`absolute left-0 top-3 bottom-3 w-[3px] rounded-full ${scheduleCardAccentClass(totalsPolicyTier)}`} />
            <div className="flex items-center justify-between gap-2">
              <div className="pl-2 text-[9px] uppercase tracking-[0.12em] text-white/45">
                Тотал 2.5
              </div>
              <span
                className={`inline-flex h-6 items-center rounded-full border px-2.5 text-[10px] ${tierPillClass(
                  totalsPolicyTier
                )}`}
              >
                {totalsPolicyTier === "A"
                  ? "Сильный"
                  : totalsPolicyTier === "B"
                    ? "Рабочий"
                    : "Наблюдать"}
              </span>
            </div>
            {hasTotal ? (
              (() => {
                const options = [
                  {
                    key: "Больше 2.5",
                    label: "Больше",
                    prob: pov,
                    odds: oddsOver,
                  },
                  {
                    key: "Меньше 2.5",
                    label: "Меньше",
                    prob: pun,
                    odds: oddsUnder,
                  },
                ];
                const heroKey = !locked && totalsPolicyTier !== "NO BET" ? totalLabelView : null;
                const hero =
                  options.find((opt) => opt.key === heroKey) || null;
                const secondary = hero
                  ? options.filter((opt) => opt.key !== hero.key)
                  : options;
                return (
                  <div className="space-y-3">
                    {hero ? renderProbOption(hero, { highlighted: true, tier: totalsPolicyTier }) : null}
                    <div className="space-y-2">
                      {secondary.map((opt) =>
                        renderProbOption(opt, {
                          highlighted: false,
                          tier: hero ? "NO BET" : totalsPolicyTier,
                        })
                      )}
                    </div>
                  </div>
                );
              })()
            ) : (
              <div className="text-[13px] text-white/50 mt-1">
                Для тотала 2.5 нет оценок вероятностей.
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

/* ===========================
   INLINE MATCH INSIGHTS
   (раскрытие под строкой)
=========================== */

function MatchInlineInsights({
  match,
  pack,
  season,
  onOpenMatch,
  onGoTeam,
  locked,
  onUnlock,
}) {
  const { language } = useLanguage();
  const [insight, setInsight] = useState(null);
  const homeId = match?.home_team_id;
  const awayId = match?.away_team_id;
  const analytics = generateEdgeScoreText({
    match,
    stats: { home: pack?.homeAvg, away: pack?.awayAvg },
    locked,
    insight,
    language,
  });
  const renderEmphasizedText = (value) => {
    const text = String(value || "");
    const tokenRegex = /([+\-−]?\d+(?:[.,]\d+)?%?|П1|П2|Х|ТБ|ТМ|1X2|2\.5|xG)/gi;
    const parts = text.split(tokenRegex);
    return parts.map((part, idx) => {
      const isToken = tokenRegex.test(part);
      tokenRegex.lastIndex = 0;
      if (!part) return null;
      const isPct = /^[+\-−]?\d+(?:[.,]\d+)?%$/.test(part);
      if (!isToken) {
        return (
          <span key={`txt-${idx}`} className="font-normal text-white/55">
            {part}
          </span>
        );
      }
      if (isPct) {
        const cleaned = part.replace("−", "-").replace("%", "");
        const num = Number(cleaned.replace(",", "."));
        const abs = Math.abs(num);
        const cls =
          Number.isFinite(num) && abs >= 1
            ? num > 0
              ? "text-emerald-300"
              : "text-rose-300"
            : "text-white/80";
        return (
          <span key={`tok-${idx}`} className={`font-semibold ${cls}`}>
            {part}
          </span>
        );
      }
      return (
        <span key={`tok-${idx}`} className="font-semibold text-white/88">
          {part}
        </span>
      );
    });
  };
  const renderRichLine = (line) => {
    const text = String(line || "");
    const idx = text.indexOf(":");
    if (idx <= 0) return <span>{renderEmphasizedText(text)}</span>;
    const head = text.slice(0, idx + 1);
    const tail = text.slice(idx + 1).trim();
    return (
      <span>
        <span className="font-semibold text-white">{head}</span>{" "}
        <span>{renderEmphasizedText(tail)}</span>
      </span>
    );
  };

  useEffect(() => {
    if (!match?.fixture_id) return;
    const ac = new AbortController();
    setInsight(null);
    fetchJsonSafe(
      `/api/match-insight?fixture_id=${match.fixture_id}`,
      ac.signal
    )
      .then((data) => setInsight(data || null))
      .catch(() => setInsight(null))
    return () => ac.abort();
  }, [match?.fixture_id]);

  if (!pack) return null;

  if (pack.error) {
    return (
      <div className="px-3 pb-6 text-sm text-rose-400 sm:px-6">
        {language === "ru" ? "Ошибка загрузки" : "Loading error"}: {pack.error}
      </div>
    );
  }

  return (
    <div className="px-0 pb-8 sm:px-6">
      <div className="glass-card mx-auto mt-3 w-full max-w-[920px] p-3 sm:p-6">
        {/* Средние показатели */}
        <section className="mt-1">
          <div className="mb-4 flex items-start justify-between gap-4">
            <div>
              <div className="text-left text-base font-semibold text-white sm:text-[20px]">
                {language === "ru" ? "Сравнение команд" : "Team comparison"}
              </div>
              <div className="mt-1 text-left text-xs text-white/62 sm:text-[14px]">
                {language === "ru" ? "Средние показатели за последние 10 матчей" : "Average metrics over the last 10 matches"}
              </div>
            </div>
          </div>

          <div className="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)] items-center gap-3 sm:gap-8">
            <StatsColumn team={match.home_team} teamId={homeId} avg={pack.homeAvg} />
            <StatsColumn
              team={match.away_team}
              teamId={awayId}
              avg={pack.awayAvg}
              align="right"
            />
          </div>

          <div className="mt-4 space-y-4">
            <ComparisonRow
              label="xG"
              leftVal={pack.homeAvg?.xg}
              rightVal={pack.awayAvg?.xg}
              format={(v) => Number(v).toFixed(2)}
              emphasis="xg"
            />
            <ComparisonRow
              label={language === "ru" ? "Удары" : "Shots"}
              leftVal={pack.homeAvg?.shots}
              rightVal={pack.awayAvg?.shots}
              format={(v) => Number(v).toFixed(1)}
              emphasis="shots"
            />
            <ComparisonRow
              label={language === "ru" ? "Владение" : "Possession"}
              leftVal={pack.homeAvg?.possession}
              rightVal={pack.awayAvg?.possession}
              format={(v) => `${Number(v).toFixed(0)}%`}
              emphasis="possession"
            />
            <ComparisonRow
              label={language === "ru" ? "Угловые" : "Corners"}
              leftVal={pack.homeAvg?.corners}
              rightVal={pack.awayAvg?.corners}
              format={(v) => Number(v).toFixed(1)}
              emphasis="corners"
            />
          </div>

          {(() => {
            const adv = AdvantageIndex(pack.homeAvg, pack.awayAvg);
            if (!adv) return null;
            const leader =
              adv.side === "home" ? match.home_team : match.away_team;
            return (
            <div className="mt-4 flex items-center justify-between gap-3 text-xs text-white/62 sm:text-[13px]">
              <span>{language === "ru" ? "Преимущество по средним показателям:" : "Edge in average metrics:"}</span>
              <span className="text-white/80">
                {leader} +{adv.value.toFixed(2)}
                </span>
              </div>
            );
          })()}
        </section>

        {/* SUMMARY / VERDICT */}
        <section className="mt-5">
          <div className="h-px w-full bg-white/10 mb-5" />
          {(() => {
            const raw =
              analytics?.final ||
              analytics?.hero ||
              (language === "ru"
                ? "Рынок не даёт достаточного преимущества по линии."
                : "The market does not offer enough edge at the current line.");
            const normalizedRaw =
              language === "ru"
                ? raw
                : String(raw).trim() === "Рынок не даёт достаточного преимущества по линии."
                  ? "The market does not offer enough edge at the current line."
                  : raw;
            const parts = String(normalizedRaw).split(".");
            const headline = (parts.shift() || normalizedRaw).trim();
            const rest = parts.join(".").trim();
            const toPctLabel = (v) => {
              if (v == null || !Number.isFinite(Number(v))) return "—";
              const num = Number(v);
              const pct = Math.round(num * 100);
              return `${pct}%`;
            };
            const p1 = analytics?.probs?.p1 ?? match?.p_home;
            const px = analytics?.probs?.px ?? match?.p_draw;
            const p2 = analytics?.probs?.p2 ?? match?.p_away;
            const confidence =
              analytics?.confidence != null
                ? Math.round(Number(analytics.confidence))
                : p1 != null || px != null || p2 != null
                  ? Math.round(Math.max(Number(p1 || 0), Number(px || 0), Number(p2 || 0)) * 100)
                  : null;
            return (
              <div className="glass-card relative w-full overflow-hidden px-6 py-5 transition hover:bg-white/[0.05]">
                <div className={`absolute left-0 top-4 bottom-4 w-[3px] rounded-full ${scheduleCardAccentClass(
                  confidence != null && confidence >= 60 ? "B" : "NO BET"
                )}`} />
                <div className="pl-2 text-[11px] uppercase tracking-[0.18em] text-white/55 mb-1">
                  {language === "ru" ? "Вывод модели" : "Model conclusion"}
                </div>
                <div className="pl-2 text-[15px] font-semibold text-white">
                  {headline}
                </div>
                {rest ? (
                  <div className="mt-1 pl-2 text-[13px] leading-relaxed text-white/75">
                    {rest}
                  </div>
                ) : null}
                <div className="mt-3 pl-2 text-[12px] text-white/70">
                  {language === "ru"
                    ? `П1 ${toPctLabel(p1)} · Х ${toPctLabel(px)} · П2 ${toPctLabel(p2)}`
                    : `1 ${toPctLabel(p1)} · X ${toPctLabel(px)} · 2 ${toPctLabel(p2)}`}
                </div>
                <div className="mt-1 pl-2 text-[12px] text-white/60">
                  {language === "ru" ? "Уверенность модели" : "Model confidence"}: {confidence != null ? `${confidence}%` : "—"}
                </div>
                <div className="mt-3 pl-2">
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      onOpenMatch?.(match);
                    }}
                    className="inline-flex items-center text-[13px] font-medium text-white/90 underline decoration-white/30 underline-offset-4 hover:decoration-white transition"
                  >
                    {language === "ru" ? "Расширенный анализ" : "Extended analysis"} →
                  </button>
                </div>
              </div>
            );
          })()}
        </section>
      </div>
    </div>
  );
}

/* ===========================
   MAIN PAGE: MATCH SCHEDULE
=========================== */

export default function MatchSchedulePage() {
  const { t, language } = useLanguage();
  const { user } = useAuth();
  const [search] = useSearchParams();
  const navigate = useNavigate();
  const location = useLocation();

  const league = search.get("league") || "Premier League";
  const season = search.get("season") || "2025";
  const seasonNum = Number(season) || new Date().getFullYear();
  const seasonOptions = [
    seasonNum - 1,
    seasonNum,
    seasonNum + 1,
  ].map((s) => String(s));

  const [groups, setGroups] = useState({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const [expandedId, setExpandedId] = useState(null);
  const [detailsById, setDetailsById] = useState({});
  const [showPaywall, setShowPaywall] = useState(false);
  const [subscriptionActive, setSubscriptionActive] = useState(null);
  const pilotFullAccess = hasPilotFullAccess(user);
  const hideMonetization = shouldHideMonetization();

  // переход к команде
  const goToTeam = useCallback(
    (teamId) => {
      if (!teamId) return;
      navigate(
        `/team/${teamId}?league=${encodeURIComponent(
          league
        )}&season=${encodeURIComponent(season)}`
      );
    },
    [navigate, league, season]
  );

  const openMatchDetails = useCallback(
    (m) => {
      if (!m?.fixture_id) return;
      const params = new URLSearchParams({
        league,
        season,
        fixture_id: String(m.fixture_id),
      });
      navigate(`/match/${m.fixture_id}?${params.toString()}`);
    },
    [navigate, league, season]
  );

  const statusBasedAccess = (() => {
    const status = String(user?.subscription_status || "").toLowerCase();
    if (!status) return false;
    if (["active", "premium", "pro", "elite", "paid"].includes(status)) return true;
    return status !== "free";
  })();
  const hasSubscription =
    pilotFullAccess || (subscriptionActive != null ? subscriptionActive : statusBasedAccess);

  const handleOpenPaywall = () => setShowPaywall(true);
  const handleClosePaywall = () => setShowPaywall(false);
  const handleChoosePlan = () => {
    if (hideMonetization) {
      handleClosePaywall();
      return;
    }
    const back = encodeURIComponent(`${location.pathname}${location.search}`);
    navigate(`/subscriptions?redirect_back=${back}#plans`);
  };

  useEffect(() => {
    if (!showPaywall) return;
    const onKey = (event) => {
      if (event.key === "Escape") handleClosePaywall();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [showPaywall]);

  const handleSeasonChange = (event) => {
    const next = event.target.value;
    const params = new URLSearchParams(search);
    params.set("season", next);
    if (!params.get("league")) params.set("league", league);
    navigate(`/schedule?${params.toString()}`);
  };

  useEffect(() => {
    if (pilotFullAccess) {
      setSubscriptionActive(true);
      return;
    }
    let cancelled = false;
    if (!user) {
      setSubscriptionActive(false);
      return;
    }
    (async () => {
      try {
        const response = await http.get("/api/subscriptions/me");
        const payload = response?.data || response;
        const subs = Array.isArray(payload?.active_subscriptions)
          ? payload.active_subscriptions
          : [];
        const isActive = subs.some(
          (s) =>
            s?.is_active === true ||
            String(s?.status || "").toLowerCase() === "active"
        );
        if (!cancelled) setSubscriptionActive(isActive || statusBasedAccess);
      } catch {
        if (!cancelled) setSubscriptionActive(statusBasedAccess);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [pilotFullAccess, user, statusBasedAccess]);

  // загрузка расписания
  useEffect(() => {
    let cancelled = false;
    const key = `${league}|${season}`;
    const cached = scheduleCache.get(key);
    const freshCached =
      cached && Date.now() - cached.t < SCHEDULE_CACHE_TTL ? cached.v : null;

    if (freshCached) {
      setGroups(freshCached);
      setLoading(false);
    }

    async function load() {
      try {
        setLoading(!freshCached);
        setError("");
        if (!freshCached) setGroups({});

        const arr = await fetchMatchesV3({
          league,
          season,
          includeUpcoming: true,
          limit: 96,
          lookbackDays: isInternationalLongCycleLeague(league) ? 0 : SCHEDULE_LOOKBACK_DAYS,
          lookaheadDays: isInternationalLongCycleLeague(league) ? 0 : SCHEDULE_LOOKAHEAD_DAYS,
        });
        const upcoming = arr.filter(isUnplayedMatch);

        const grouped = upcoming.reduce((acc, m) => {
          const parsed = parseDatetimeDDMM(m.datetime, season);
          const match = {
            ...m,
            kickoff_local: parsed.kickoff_local || m.kickoff_local,
            date: parsed.isoDate || m.date,
          };

          const week =
            m.week != null
              ? m.week
              : m.round_number != null
              ? m.round_number
              : 0;
          const key = String(week || "—");

          if (!acc[key]) acc[key] = [];
          acc[key].push(match);
          return acc;
        }, {});

        // сортировка матчей внутри тура по дате
        Object.values(grouped).forEach((list) => {
          list.sort((a, b) => {
            const da = day(a.date || "");
            const db = day(b.date || "");
            return da.localeCompare(db);
          });
        });

        if (!cancelled) {
          scheduleCache.set(key, { t: Date.now(), v: grouped });
          setGroups(grouped);
        }
      } catch (e) {
        if (!cancelled) setError(e.message || String(e));
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [league, season]);

  // ПОЛНЫЙ РАБОЧИЙ BLOCK для расчёта H2H и LAST
  const loadDetails = useCallback(
    async (match) => {
      if (!match?.fixture_id) return;
      const fid = match.fixture_id;

      if (detailsCache.has(fid)) {
        const cached = detailsCache.get(fid);
        setDetailsById((s) => ({ ...s, [fid]: cached }));
        return;
      }

      setDetailsById((s) => ({
        ...s,
        [fid]: { ...(s[fid] || {}), loading: true, error: null },
      }));

      try {
        const ourHomeId = Number(match.home_team_id);
        const ourAwayId = Number(match.away_team_id);
        const ourHomeName = normName(match.home_team || "");
        const ourAwayName = normName(match.away_team || "");
        const resultsUrl = (teamId) =>
          `${API_BASE}/api/team/results?team_id=${encodeURIComponent(teamId)}&league=${encodeURIComponent(
            league
          )}&season=${encodeURIComponent(season)}&limit=20`;

        const [homeResp, awayResp] = await Promise.all([
          fetchJsonSafe(resultsUrl(ourHomeId)),
          fetchJsonSafe(resultsUrl(ourAwayId)),
        ]);

        const homeResultsRaw = Array.isArray(homeResp) ? homeResp : [];
        const awayResultsRaw = Array.isArray(awayResp) ? awayResp : [];

        const resultRowToMatch = (row, teamId, teamName) => {
          const isHome = String(row?.side || "").toUpperCase() === "H";
          return normalizeRow({
            fixture_id: row.fixture_id,
            date: row.date,
            home_team_id: isHome ? teamId : row.opponent_id,
            away_team_id: isHome ? row.opponent_id : teamId,
            home_team: isHome ? teamName : row.opponent_name,
            away_team: isHome ? row.opponent_name : teamName,
            home_goals: isHome ? row.team_goals : row.opp_goals,
            away_goals: isHome ? row.opp_goals : row.team_goals,
            score: row.score_str,
          });
        };

        const byDateDesc = (a, b) =>
          day(b.date || "").localeCompare(day(a.date || ""));

        const homeResults = homeResultsRaw
          .map((row) => resultRowToMatch(row, ourHomeId, match.home_team))
          .sort(byDateDesc);
        const awayResults = awayResultsRaw
          .map((row) => resultRowToMatch(row, ourAwayId, match.away_team))
          .sort(byDateDesc);

        const h2hFlat = homeResults
          .filter((row) => {
            const h = Number(row.home_team_id);
            const a = Number(row.away_team_id);
            const byId =
              (h === ourHomeId && a === ourAwayId) ||
              (h === ourAwayId && a === ourHomeId);
            if (byId) return true;
            const hn = normName(row.home_team || "");
            const an = normName(row.away_team || "");
            return (
              (hn === ourHomeName && an === ourAwayName) ||
              (hn === ourAwayName && an === ourHomeName)
            );
          })
          .slice(0, 5);

        const homeLast = homeResults.slice(0, 5);
        const awayLast = awayResults.slice(0, 5);

        const computeAvgFromTeamResults = (rows) => {
          const acc = {
            xg: [],
            shots: [],
            shots_on: [],
            possession: [],
          };
          const pushNum = (arr, v) => {
            const n = Number(v);
            if (Number.isFinite(n)) arr.push(n);
          };
          rows.slice(0, 10).forEach((row) => {
            pushNum(acc.xg, row.xg);
            pushNum(acc.shots, row.shots);
            pushNum(acc.shots_on, row.shots_on_goal);
            pushNum(acc.possession, row.possession);
          });
          const avg = (arr) =>
            arr.length ? arr.reduce((a, b) => a + b, 0) / arr.length : 0;
          return {
            xg: avg(acc.xg),
            shots: avg(acc.shots),
            shots_on: avg(acc.shots_on),
            possession: avg(acc.possession),
            corners: 0,
          };
        };

        const homeAvg = computeAvgFromTeamResults(homeResultsRaw);
        const awayAvg = computeAvgFromTeamResults(awayResultsRaw);

        const pack = {
          loading: false,
          error: null,
          homeAvg,
          awayAvg,
          h2h: h2hFlat,
          homeLast,
          awayLast,
        };

        detailsCache.set(fid, pack);
        setDetailsById((s) => ({ ...s, [fid]: pack }));
      } catch (e) {
        setDetailsById((s) => ({
          ...s,
          [fid]: {
            loading: false,
            error: e.message || "Ошибка загрузки данных",
          },
        }));
      }
    },
    [league, season]
  );

  const handleRowClick = (match) => {
    setExpandedId((prev) => {
      const next = prev === match.fixture_id ? null : match.fixture_id;
      if (next === match.fixture_id) {
        // открываем — подгружаем разворот
        loadDetails(match);
      }
      return next;
    });
  };

  const hasData = Object.keys(groups).length > 0;

  return (
    <>
      <div className="w-full min-w-0 overflow-x-hidden px-1 py-5 space-y-6 sm:px-4 sm:py-8 sm:space-y-8">
      {/* HEADER */}
      <div>
        <div className="surface-hero p-4 sm:p-6 md:p-8">
          <div className="flex flex-col items-start justify-between gap-4 sm:flex-row sm:items-center">
            <div className="min-w-0 space-y-1.5">
              <div className="type-eyebrow">
                {t("calendarEyebrow")}
              </div>
              <div className="type-page-title break-words text-xl sm:text-2xl">
                {t("scheduleTitle")} · {league}
              </div>
              <p className="type-subtitle max-w-xl">
                {t("scheduleLead")}
              </p>
            </div>

            <div className="flex w-full min-w-0 items-center gap-3 self-start sm:w-auto sm:self-auto">
              <label
                htmlFor="season-select"
                className="type-eyebrow"
              >
                {t("season")}
              </label>
              <select
                id="season-select"
                value={season}
                onChange={handleSeasonChange}
                className="surface-select h-8 tabular-nums text-[13px] text-white/80"
              >
                {seasonOptions.map((s) => (
                  <option key={s} value={s} className="bg-slate-900">
                    {s}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>
      </div>

      {/* STATE */}
      {loading && (
        <div className="text-center text-sm text-white/60 mt-6">
          {t("loadingSchedule")}
        </div>
      )}

      {!loading && error && (
        <div className="text-center text-sm text-rose-400 mt-6">
          {t("scheduleErrorPrefix")}: {error}
        </div>
      )}

      {!loading && !error && !hasData && (
        <div className="text-center text-sm text-white/60 mt-6">
          {t("noScheduledMatches")}
        </div>
      )}

      {/* ROUNDS */}
      {!loading &&
        !error &&
        hasData &&
        Object.entries(groups)
          .sort(([a], [b]) => {
            const an = Number(a);
            const bn = Number(b);
            if (!Number.isNaN(an) && !Number.isNaN(bn)) return an - bn;
            return String(a).localeCompare(String(b));
          })
          .map(([weekKey, matches]) => {
            const title = roundTitle(matches, language);
            const total = matches.length;

            return (
              <section key={weekKey} className="space-y-3 mt-8">
                <div className="flex items-center justify-between px-1 pt-5 border-t border-white/5">
                  <div className="text-[13px] uppercase tracking-[0.15em] text-white/60">
                    {title}
                  </div>
                  <div className="bg-white/5 text-white/60 text-xs px-3 py-1 rounded-full">
                    {total} {t("matchesCount")}
                  </div>
                </div>

                <div className="space-y-3">
                  {matches.map((m, idx) => {
                    const key =
                      m.fixture_id ||
                      m.id ||
                      `${m.date || ""}-${m.home_team}-${m.away_team}-${idx}`;
                    const isExpanded = expandedId === m.fixture_id;
                    const details = detailsById[m.fixture_id];

                    return (
                      <div key={key}>
                        <MatchRow
                          match={m}
                          season={season}
                          onClick={handleRowClick}
                          onGoTeam={goToTeam}
                          expanded={isExpanded}
                          language={language}
                        />
                        {isExpanded && (
                          <>
                            {details?.loading && (
                              <div className="px-6 pb-6 text-sm text-white/60">
                                {t("loadingMatchAnalytics")}
                              </div>
                            )}
                            {!details?.loading && (
                              <MatchInlineInsights
                                match={m}
                                pack={details}
                                season={season}
                                onOpenMatch={openMatchDetails}
                                onGoTeam={goToTeam}
                                locked={!hasSubscription}
                                onUnlock={handleOpenPaywall}
                              />
                            )}
                          </>
                        )}
                      </div>
                    );
                  })}
                </div>
              </section>
            );
          })}
      </div>

      {showPaywall && (
        <div
          className="fixed inset-0 z-[1000] flex items-center justify-center bg-[rgba(8,12,22,0.8)] backdrop-blur-[3px] p-6"
          onClick={handleClosePaywall}
        >
          <div
            className="w-full max-w-sm rounded-2xl bg-slate-900/95 border border-white/10 px-5 py-5 text-white"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="text-sm uppercase tracking-[0.18em] text-white/60">
              {t("lockedAnalyticsTitle")}
            </div>
            <div className="mt-2 text-[13px] text-white/80">
              {t("lockedAnalyticsBody")}
            </div>
            <div className="mt-4 flex items-center justify-center gap-4">
              <button
                type="button"
                onClick={handleChoosePlan}
                className="h-10 px-5 rounded-xl bg-gradient-to-r from-emerald-400/90 via-emerald-300/90 to-teal-300/90 text-slate-900 text-[13px] font-semibold shadow-[0_8px_18px_rgba(16,185,129,0.25)]"
              >
                {t("goToPlans")}
              </button>
              <button
                type="button"
                onClick={handleClosePaywall}
                className="text-[13px] text-white/60 hover:text-white/80 transition"
              >
                {t("close")}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
