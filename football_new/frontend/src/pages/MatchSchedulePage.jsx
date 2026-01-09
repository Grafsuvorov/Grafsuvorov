// src/pages/MatchSchedulePage.jsx
import React, { useEffect, useState, useCallback } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";

import { Card, CardContent } from "@/components/ui/card";
import TeamAvgBlock from "@/components/ui/TeamAvgBlock";
import H2HBlock from "@/components/ui/H2HBlock";
import LastMatchesBlock from "@/components/ui/LastMatchesBlock";
import { teamLogoMap } from "@/constants/teamLogoMap";

/* ===========================
   CONFIG / HELPERS
=========================== */

const API_BASE = "http://localhost:8001";

// кэш расписаний по ключу league|season
const scheduleCache = new Map();
// кэш разворотов по fixture_id
const detailsCache = new Map();

/** Безопасный fetch JSON с заменой NaN/Infinity */
async function fetchJsonSafe(url) {
  const rsp = await fetch(url);
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

function seasonDateRange(seasonStr) {
  const y = Number(seasonStr) || 2025;
  return { from: `${y}-07-01`, to: `${y + 1}-06-30` };
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
    const [y, m, d] = iso.split("-");
    const date = d && m ? `${d}.${m}` : s;
    const time = s.includes("T") ? s.slice(11, 16) : "";
    return { date, time };
  }

  return { date: "", time: "" };
}

function roundTitle(matches) {
  const sample = matches[0] || {};
  const week = sample.week;
  const label = sample.round_label || sample.stage_name;

  if (label && week != null) return `${label} — ${week}`;
  if (label) return label;
  if (week != null) return `Тур ${week}`;
  return "Тур";
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
    <button
      type="button"
      onClick={(e) => {
        e.stopPropagation();
        onClick?.();
      }}
      className="inline-flex items-center justify-center"
    >
      <span className="inline-flex h-8 w-8 items-center justify-center rounded-full bg-white/5 border border-white/10 shadow-sm overflow-hidden">
        <img
          src={logoSrc(id, name)}
          alt={name || "team"}
          className="h-5 w-5 object-contain"
        />
      </span>
    </button>
  );
}

function TeamLine({ name, teamId, onGoTeam }) {
  return (
    <div className="flex items-center gap-2 min-w-0">
      <LogoBadge id={teamId} name={name} onClick={() => onGoTeam?.(teamId)} />
      <span className="truncate text-[13px] text-white/90">{name}</span>
    </div>
  );
}

function MatchRow({ match, season, onClick, onGoTeam, expanded }) {
  const { date, time } = formatDateTime(match, season);
  const sLabel = scoreLabel(match);
  const isFinished = sLabel !== "—";

  return (
    <button
      type="button"
      onClick={() => onClick?.(match)}
      className={[
        "w-full px-4 py-3 flex items-center gap-4 text-left transition",
        expanded ? "bg-white/[0.03]" : "hover:bg-white/[0.02]",
      ].join(" ")}
    >
      {/* DATE / TIME */}
      <div className="w-[70px] text-[11px] text-white/60">
        {date && <div className="tabular-nums">{date}</div>}
        {time && (
          <div className="mt-0.5 tabular-nums text-white/40">{time}</div>
        )}
      </div>

      {/* TEAMS */}
      <div className="flex-1 flex flex-col gap-1 min-w-0">
        <TeamLine
          name={match.home_team}
          teamId={match.home_team_id}
          onGoTeam={onGoTeam}
        />
        <TeamLine
          name={match.away_team}
          teamId={match.away_team_id}
          onGoTeam={onGoTeam}
        />
      </div>

      {/* SCORE + STATUS */}
      <div className="w-[86px] flex flex-col items-end gap-1">
        <span
          className={[
            "inline-flex min-w-[64px] justify-center px-2 py-1 rounded-full text-[14px] font-semibold tabular-nums",
            isFinished
              ? "bg-white/10 text-white"
              : "bg-white/5 text-white/80 border border-white/10",
          ].join(" ")}
        >
          {sLabel}
        </span>
        {match.status_short && (
          <span className="text-[10px] uppercase tracking-wide text-white/40">
            {match.status_short}
          </span>
        )}
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

/* ===========================
   PREMIUM ANALYTICS BLOCK
   (фиолетовая карточка прогноза)
=========================== */

function PremiumAnalyticsBlock({ match }) {
  // поля из /api/matches_v3
  const p1 = match?.p_home;
  const px = match?.p_draw;
  const p2 = match?.p_away;
  const pov = match?.p_over25;
  const pun = match?.p_under25;

  const outcomeLabel = match?.outcome_label; // "П1", "Х", "П2"
  const totalLabel = match?.total_label; // "Больше 2.5" / "Меньше 2.5"

  const recDecision = match?.rec_decision; // "BET" / "SKIP"
  const strength = match?.signal_strength || "none"; // weak/medium/strong/none
  const signalPick = match?.signal_pick; // "П1", "ТБ2.5" и т.п.
  const signalP = match?.signal_p;
  const signalOdds = match?.signal_odds;
  const signalEV = match?.signal_value;
  const signalEdge = match?.signal_edge;
  const kelly = match?.kelly_frac;
  const signalType = match?.signal_type; // "align"/"contrarian"

  // human-обоснование
  const humanReason =
    match?.rec_reason_human || buildHumanReason(match || {});

  const hasOutcome = [p1, px, p2].some(
    (v) => v != null && Number.isFinite(Number(v))
  );
  const hasTotal = [pov, pun].some(
    (v) => v != null && Number.isFinite(Number(v))
  );
  const hasAnyProb = hasOutcome || hasTotal;

  const toPct = (v) =>
    v == null || !Number.isFinite(Number(v))
      ? null
      : Math.round(Number(v) * 100);

  const strengthPill = (() => {
    if (strength === "strong")
      return {
        label: "Сильный сигнал",
        className: "bg-emerald-500/20 text-emerald-200 border-emerald-400/60",
      };
    if (strength === "medium")
      return {
        label: "Средний сигнал",
        className: "bg-amber-500/20 text-amber-200 border-amber-400/60",
      };
    if (strength === "weak")
      return {
        label: "Слабый сигнал",
        className: "bg-sky-500/20 text-sky-200 border-sky-400/60",
      };
    return {
      label: "Сигнала нет",
      className: "bg-white/5 text-white/60 border-white/10",
    };
  })();

  const decisionPill =
    recDecision === "BET"
      ? { label: "Value bet", className: "bg-emerald-500 text-emerald-50" }
      : { label: "Пропуск", className: "bg-slate-700 text-slate-100" };

  const signalTypeLabel =
    signalType === "contrarian"
      ? "Против рынка"
      : signalType === "align"
      ? "По тренду рынка"
      : null;

  if (!hasAnyProb && !humanReason) {
    return (
      <div className="rounded-2xl border border-white/10 bg-slate-950/80 px-4 py-3 shadow-[0_18px_55px_rgba(0,0,0,0.8)]">
        <div className="text-[13px] text-white/60">
          Для этого матча прогноз модели пока недоступен.
        </div>
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-violet-500/35 bg-gradient-to-r from-slate-950/95 via-slate-900/95 to-slate-950/95 px-4 py-4 shadow-[0_18px_55px_rgba(0,0,0,0.9)] space-y-4">
      {/* HEADER */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="min-w-0">
          <div className="text-[10px] uppercase tracking-[0.2em] text-white/40">
            Прогноз модели EdgeScore
          </div>
          <div className="text-sm text-white/80">
            Вероятности исходов и сигнал value по рынку.
          </div>
        </div>
        <div className="flex items-center gap-2">
          <span
            className={`inline-flex items-center rounded-full px-3 h-7 text-[11px] font-semibold ${decisionPill.className}`}
          >
            {decisionPill.label}
          </span>
          <span
            className={
              "inline-flex items-center rounded-full px-3 h-7 text-[11px] border " +
              strengthPill.className
            }
          >
            {strengthPill.label}
          </span>
        </div>
      </div>

      {/* PROBABILITY CARDS */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        {/* 1X2 */}
        <div className="rounded-2xl border border-white/10 bg-slate-900/80 px-3 py-3 space-y-2">
          <div className="flex items-center justify-between gap-2">
            <span className="text-[10px] uppercase tracking-[0.2em] text-white/55">
              Исход 1X2
            </span>
            {outcomeLabel && (
              <span className="text-[11px] px-2 py-1 rounded-full bg-white/10 text-white/80">
                Базовый исход: {outcomeLabel}
              </span>
            )}
          </div>
          {hasOutcome ? (
            <div className="grid grid-cols-3 gap-2 mt-1">
              {[
                { key: "П1", label: `П1`, value: toPct(p1) },
                { key: "Х", label: `Х`, value: toPct(px) },
                { key: "П2", label: `П2`, value: toPct(p2) },
              ].map((opt) => {
                const isBest = outcomeLabel === opt.key;
                return (
                  <div
                    key={opt.key}
                    className={[
                      "rounded-xl px-2 py-2.5 flex flex-col items-center justify-center border backdrop-blur-sm",
                      isBest
                        ? "border-violet-400/80 bg-violet-500/20 shadow-[0_0_24px_rgba(139,92,246,0.5)]"
                        : "border-white/10 bg-white/5",
                    ].join(" ")}
                  >
                    <div className="text-[11px] text-white/70 mb-0.5">
                      {opt.label}
                    </div>
                    <div className="text-[18px] leading-tight font-semibold text-white tabular-nums">
                      {opt.value != null ? `${opt.value}%` : "—"}
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="text-[13px] text-white/50 mt-1">
              Для этого матча нет оценок вероятностей 1X2.
            </div>
          )}
        </div>

        {/* TOTAL 2.5 */}
        <div className="rounded-2xl border border-white/10 bg-slate-900/80 px-3 py-3 space-y-2">
          <div className="flex items-center justify-between gap-2">
            <span className="text-[10px] uppercase tracking-[0.2em] text-white/55">
              Тотал 2.5
            </span>
            {totalLabel && (
              <span className="text-[11px] px-2 py-1 rounded-full bg-white/10 text-white/80">
                Базовый тотал: {totalLabel}
              </span>
            )}
          </div>
          {hasTotal ? (
            <div className="grid grid-cols-2 gap-2 mt-1">
              {[
                {
                  key: "Больше 2.5",
                  label: "Больше",
                  value: toPct(pov),
                },
                {
                  key: "Меньше 2.5",
                  label: "Меньше",
                  value: toPct(pun),
                },
              ].map((opt) => {
                const isBest = totalLabel === opt.key;
                return (
                  <div
                    key={opt.key}
                    className={[
                      "rounded-xl px-2 py-2.5 flex flex-col items-center justify-center border backdrop-blur-sm",
                      isBest
                        ? "border-violet-400/80 bg-violet-500/20 shadow-[0_0_24px_rgba(139,92,246,0.5)]"
                        : "border-white/10 bg-white/5",
                    ].join(" ")}
                  >
                    <div className="text-[11px] text-white/70 mb-0.5">
                      {opt.label}
                    </div>
                    <div className="text-[18px] leading-tight font-semibold text-white tabular-nums">
                      {opt.value != null ? `${opt.value}%` : "—"}
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="text-[13px] text-white/50 mt-1">
              Для тотала 2.5 нет оценок вероятностей.
            </div>
          )}
        </div>
      </div>

      {/* VALUE / РЕКОМЕНДАЦИЯ */}
      <div className="space-y-2">
        {recDecision === "BET" && signalPick ? (
          <div className="rounded-2xl border border-emerald-500/40 bg-emerald-500/10 px-3 py-2.5 flex flex-col gap-1">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="text-[13px] text-emerald-100">
                <span className="font-semibold">Рекомендуемая ставка:</span>{" "}
                {signalPick}
              </div>
              {signalTypeLabel && (
                <span className="text-[11px] px-2 py-1 rounded-full bg-emerald-500/20 text-emerald-100 border border-emerald-400/70">
                  {signalTypeLabel}
                </span>
              )}
            </div>
            <div className="flex flex-wrap items-center gap-2 text-[12px] text-emerald-100/90 tabular-nums">
              {signalP != null && (
                <span>p ≈ {(signalP * 100).toFixed(1)}%</span>
              )}
              {signalOdds != null && (
                <span>коэфф. {Number(signalOdds).toFixed(2)}</span>
              )}
              {signalEV != null && (
                <span>EV {(signalEV * 100).toFixed(1)}%</span>
              )}
              {signalEdge != null && (
                <span>
                  edge {(signalEdge * 100).toFixed(1)}
                  {" п.п."}
                </span>
              )}
              {kelly != null && (
                <span>Kelly f ≈ {(kelly * 100).toFixed(1)}%</span>
              )}
            </div>
          </div>
        ) : (
          <div className="rounded-2xl border border-white/10 bg-slate-900/80 px-3 py-2.5 text-[13px] text-white/70">
            Рекомендация модели:{" "}
            <span className="font-semibold text-white">
              пропуск матча (нет value по текущим коэффициентам).
            </span>
          </div>
        )}

        {humanReason && (
          <div className="rounded-2xl border border-white/10 bg-slate-900/70 px-3 py-2 text-[12px] text-white/70">
            <div className="text-[10px] uppercase tracking-[0.2em] text-white/45 mb-0.5">
              Обоснование
            </div>
            <div className="whitespace-pre-line">{humanReason}</div>
          </div>
        )}
      </div>
    </div>
  );
}

/* ===========================
   INLINE MATCH INSIGHTS
   (раскрытие под строкой)
=========================== */

function MatchInlineInsights({ match, pack }) {
  const homeId = match?.home_team_id;
  const awayId = match?.away_team_id;

  if (!pack) return null;

  if (pack.error) {
    return (
      <div className="px-4 pb-4 bg-slate-950/90 text-sm text-rose-400">
        Ошибка загрузки: {pack.error}
      </div>
    );
  }

  return (
    <div className="px-4 pb-4 bg-slate-950/90">
      <div className="mt-0 rounded-3xl border border-white/12 bg-slate-950/95 px-4 py-4 space-y-5 shadow-[0_18px_55px_rgba(0,0,0,0.85)]">
        {/* Средние показатели */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <TeamAvgBlock
            team={match.home_team}
            logoId={homeId}
            avg={pack.homeAvg}
          />
          <TeamAvgBlock
            team={match.away_team}
            logoId={awayId}
            avg={pack.awayAvg}
          />
        </div>

        {/* Прогноз модели */}
        <PremiumAnalyticsBlock match={match} />

        {/* H2H */}
        <H2HBlock h2h={pack.h2h} onGoTeam={() => {}} />

        {/* Последние матчи */}
        <LastMatchesBlock
          title={`Последние матчи — ${match.home_team}`}
          matches={pack.homeLast}
        />
        <LastMatchesBlock
          title={`Последние матчи — ${match.away_team}`}
          matches={pack.awayLast}
        />
      </div>
    </div>
  );
}

/* ===========================
   MAIN PAGE: MATCH SCHEDULE
=========================== */

export default function MatchSchedulePage() {
  const [search] = useSearchParams();
  const navigate = useNavigate();

  const league = search.get("league") || "Premier League";
  const season = search.get("season") || "2025";

  const [groups, setGroups] = useState({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const [expandedId, setExpandedId] = useState(null);
  const [detailsById, setDetailsById] = useState({});

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

  // загрузка расписания
  useEffect(() => {
    let cancelled = false;
    const key = `${league}|${season}`;
    const cached = scheduleCache.get(key);

    if (cached) {
      setGroups(cached);
    }

    async function load() {
      try {
        setLoading(!cached);
        setError("");
        if (!cached) setGroups({});

        const { from, to } = seasonDateRange(season);
        const qs = new URLSearchParams({
          league,
          season,
          from_date: from,
          to_date: to,
          include_upcoming: "true",
        }).toString();

        const rsp = await fetch(`${API_BASE}/api/matches_v3?${qs}`);
        if (!rsp.ok) {
          const txt = await rsp.text().catch(() => "");
          throw new Error(`HTTP ${rsp.status}${txt ? `: ${txt}` : ""}`);
        }

        const raw = await rsp.json();
        const arr = Array.isArray(raw) ? raw : [];

        const grouped = arr.reduce((acc, m) => {
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
          scheduleCache.set(key, grouped);
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
        const untilRaw =
          match.date || parseDatetimeDDMM(match.datetime, season).isoDate || "";
        if (!untilRaw) throw new Error("Неизвестна дата матча");

        const until = day(untilRaw);
        const fromAllTime = "1900-01-01";

        const ourHomeId = Number(match.home_team_id);
        const ourAwayId = Number(match.away_team_id);
        const ourHomeName = normName(match.home_team || "");
        const ourAwayName = normName(match.away_team || "");

        // точная проверка пары команд
        const samePair = (x) => {
          const h = idOf(x, "home");
          const a = idOf(x, "away");
          const byId =
            Number.isFinite(h) &&
            Number.isFinite(a) &&
            ((h === ourHomeId && a === ourAwayId) ||
              (h === ourAwayId && a === ourHomeId));

          if (byId) return true;

          const hn = nameOf(x, "home");
          const an = nameOf(x, "away");
          const byName =
            (hn === ourHomeName && an === ourAwayName) ||
            (hn === ourAwayName && an === ourHomeName);

          return byName;
        };

        // грузим все игры лиги
        const oneUrl = `${API_BASE}/api/matches_v3?league=${encodeURIComponent(
          league
        )}&from_date=${encodeURIComponent(
          fromAllTime
        )}&to_date=${encodeURIComponent(until)}`;

        const rowsAllResp = await fetchJsonSafe(oneUrl);
        const rowsAll = Array.isArray(rowsAllResp) ? rowsAllResp : [];

        // H2H
        let h2hRows = rowsAll.filter(
          (x) => samePair(x) && day(x.date) <= until
        );

        // fallback: без ограничения по лиге
        if (!h2hRows.length) {
          const anyUrl = `${API_BASE}/api/matches_v3?from_date=${encodeURIComponent(
            fromAllTime
          )}&to_date=${encodeURIComponent(until)}`;
          const anyResp = await fetchJsonSafe(anyUrl);
          const anyRows = Array.isArray(anyResp) ? anyResp : [];
          h2hRows = anyRows.filter(
            (x) => samePair(x) && day(x.date) <= until
          );
        }

        const byDateDesc = (a, b) =>
          day(b.date || "").localeCompare(day(a.date || ""));

        const h2hFlat = h2hRows
          .sort(byDateDesc)
          .slice(0, 5)
          .map(normalizeRow);

        // последние матчи
        const lastNFor = (teamId, n = 5) =>
          rowsAll
            .filter((x) => {
              const h = idOf(x, "home");
              const a = idOf(x, "away");
              return (
                (Number(h) === Number(teamId) ||
                  Number(a) === Number(teamId)) &&
                day(x.date) <= until
              );
            })
            .sort(byDateDesc)
            .slice(0, n)
            .map(normalizeRow);

        const homeLast = lastNFor(ourHomeId, 5);
        const awayLast = lastNFor(ourAwayId, 5);

        // AVERAGES last 10
        const last10For = (teamId) =>
          rowsAll
            .filter((x) => {
              const h = idOf(x, "home");
              const a = idOf(x, "away");
              return (
                (Number(h) === Number(teamId) ||
                  Number(a) === Number(teamId)) &&
                day(x.date) <= until
              );
            })
            .sort(byDateDesc)
            .slice(0, 10);

        const computeAvgForTeam = (teamId, rows) => {
          const acc = {
            xg: [],
            shots: [],
            shots_on: [],
            possession: [],
            corners: [],
          };
          const pushNum = (arr, v) => {
            const n = Number(v);
            if (Number.isFinite(n)) arr.push(n);
          };

          for (const r of rows) {
            const isHome = Number(idOf(r, "home")) === Number(teamId);
            const isAway = Number(idOf(r, "away")) === Number(teamId);
            const side = isHome ? "home" : isAway ? "away" : null;
            if (!side) continue;

            pushNum(acc.xg, r[`${side}_xg`] ?? r[`${side}_expected_goals`]);
            pushNum(
              acc.shots,
              r[`${side}_shots`] ?? r[`${side}_total_shots`]
            );
            pushNum(
              acc.shots_on,
              r[`${side}_shots_on_target`] ?? r[`${side}_shots_on_goal`]
            );
            pushNum(acc.possession, r[`${side}_possession`]);
            pushNum(
              acc.corners,
              r[`${side}_corners`] ?? r[`${side}_corner_kicks`]
            );
          }

          const avg = (arr) =>
            arr.length
              ? arr.reduce((a, b) => a + b, 0) / arr.length
              : 0; // <- чтобы в UI не было пустых дыр

          return {
            xg: avg(acc.xg),
            shots: avg(acc.shots),
            shots_on: avg(acc.shots_on),
            possession: avg(acc.possession),
            corners: avg(acc.corners),
          };
        };

        const homeAvg = computeAvgForTeam(ourHomeId, last10For(ourHomeId));
        const awayAvg = computeAvgForTeam(ourAwayId, last10For(ourAwayId));

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
    <div className="max-w-5xl mx-auto px-2 sm:px-0 py-4 space-y-5">
      {/* HEADER CARD */}
      <Card className="border border-white/10 bg-slate-950/80 backdrop-blur-xl shadow-[0_18px_55px_rgba(0,0,0,0.75)] rounded-3xl">

        <CardContent className="p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div className="space-y-1">
            <div className="text-[11px] uppercase tracking-[0.18em] text-white/40">
              Календарь турнира
            </div>
            <div className="text-lg sm:text-xl font-semibold text-white">
              Расписание матчей · {league}
            </div>
            <p className="text-[13px] text-white/55 max-w-xl">
              Следите за турами, статусом матчей и результатами для выбранного
              сезона. Нажмите на матч, чтобы открыть подробную аналитику
              EdgeScore прямо под строкой.
            </p>
          </div>

          <div className="flex items-center gap-3 self-start sm:self-auto">
            <span className="text-[11px] uppercase tracking-[0.18em] text-white/40">
              Сезон
            </span>
            <span className="inline-flex items-center rounded-full border border-white/15 bg-white/5 px-3 h-8 text-[13px] text-white/85 tabular-nums shadow-sm">
              {season}
            </span>
          </div>
        </CardContent>
      </Card>

      {/* STATE */}
      {loading && (
        <div className="text-center text-sm text-white/60 mt-4">
          Загружаем расписание…
        </div>
      )}

      {!loading && error && (
        <div className="text-center text-sm text-rose-400 mt-4">
          Ошибка загрузки: {error}
        </div>
      )}

      {!loading && !error && !hasData && (
        <div className="text-center text-sm text-white/60 mt-4">
          Нет запланированных матчей для выбранного сезона.
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
            const title = roundTitle(matches);
            const total = matches.length;

            return (
              <Card
                key={weekKey}
                className="border border-white/10 bg-slate-950/75 rounded-3xl overflow-hidden"
              >
                <CardContent className="p-0">
                  <div className="flex items-center justify-between px-4 py-2.5 bg-white/[0.03] border-b border-white/10">
                    <div className="text-[13px] font-semibold text-white/90">
                      {title}
                    </div>
                    <div className="text-[11px] text-white/45">
                      {total} матч
                      {total === 1 ? "" : total < 5 ? "а" : "ей"}
                    </div>
                  </div>

                  <div className="divide-y divide-white/[0.06]">
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
                          />
                          {isExpanded && (
                            <>
                              {details?.loading && (
                                <div className="px-4 pb-4 bg-slate-950/90 text-sm text-white/60">
                                  Загружаем аналитику по матчу…
                                </div>
                              )}
                              {!details?.loading && (
                                <MatchInlineInsights
                                  match={m}
                                  pack={details}
                                />
                              )}
                            </>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </CardContent>
              </Card>
            );
          })}
    </div>
  );
}
