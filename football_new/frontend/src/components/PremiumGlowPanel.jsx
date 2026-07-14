// src/components/PremiumGlowPanel.jsx
import React from "react";
import SafeImg from "@/components/SafeImg";
import { teamLogoMap } from "@/constants/teamLogoMap";
import { useLanguage } from "@/context/LanguageContext.jsx";

const logoSafe = (id, name) =>
  id ? `/icons/team_logos/${id}.png` : teamLogoMap[name] || "/icons/team_logos/default.png";

const toPct = (v) =>
  v == null || !Number.isFinite(Number(v)) ? "—" : `${Math.round(v * 100)}%`;

const SOFT_CARD_CLASS =
  "rounded-[24px] border border-white/[0.06] bg-gradient-to-br from-white/[0.045] to-white/[0.02] p-4 ring-1 ring-white/[0.025]";
const CHIP_CLASS =
  "rounded-full border border-white/[0.06] bg-white/[0.05] px-2.5 py-1 text-[11px] text-white/68";

export default function PremiumGlowPanel({ match, pack, onGoTeam, onOpenModal }) {
  const { language } = useLanguage();
  const isRu = language === "ru";

  if (!pack || pack.loading) {
    return (
      <div className="rounded-3xl bg-white/[0.03] px-4 py-4 text-sm text-white/60">
        {isRu ? "Загружаем аналитику…" : "Loading analytics…"}
      </div>
    );
  }

  /* прогноз */
  const outcomeLabel = match?.outcome_label;
  const totalLabel = match?.total_label;

  const p1 = match?.p_home;
  const px = match?.p_draw;
  const p2 = match?.p_away;
  const ov = match?.p_over25;
  const un = match?.p_under25;

  const recDecision = match?.rec_decision;
  const signalPick = match?.signal_pick;
  const signalOdds = match?.signal_odds;
  const signalP = match?.signal_p;
  const signalEV = match?.signal_value;
  const strength = match?.signal_strength;

  const strengthPill = {
    strong: "border-violet-400/35 bg-violet-500/14 text-violet-100",
    medium: "border-amber-400/32 bg-amber-500/12 text-amber-100",
    weak: "border-sky-400/28 bg-sky-500/12 text-sky-100",
    none: "border-white/8 bg-white/[0.04] text-white/45",
  }[strength || "none"];

  return (
    <div className="panel space-y-5 rounded-3xl p-4 sm:p-5">

      {/* HEADER */}
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="text-[10px] uppercase tracking-[0.2em] text-white/38">
            EdgeScore Premium
          </div>
          <div className="pt-1 text-sm text-white/72">{isRu ? "Предматчевая аналитика" : "Pre-match analytics"}</div>
        </div>

        <span className={`rounded-full border px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.12em] ${strengthPill}`}>
          {strength === "strong"
            ? isRu ? "Сильный сигнал" : "Strong signal"
            : strength === "medium"
            ? isRu ? "Средний" : "Medium"
            : strength === "weak"
            ? isRu ? "Слабый" : "Weak"
            : isRu ? "Нет value" : "No value"}
        </span>
      </div>

      {/* ===========================
          1) ПРОГНОЗ
      ============================ */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">

        {/* 1X2 */}
        <div className={SOFT_CARD_CLASS + " space-y-3"}>
          <div className="flex justify-between items-center">
            <div className="text-[11px] uppercase tracking-wide text-white/50">{isRu ? "Исход 1X2" : "1X2 outcome"}</div>
            {outcomeLabel && (
              <span className={CHIP_CLASS}>
                {isRu ? "Базовый" : "Base"}: {outcomeLabel}
              </span>
            )}
          </div>

          <div className="grid grid-cols-3 gap-2">
            {[
              { k: isRu ? "П1" : "1", v: p1 },
              { k: isRu ? "Х" : "X", v: px },
              { k: isRu ? "П2" : "2", v: p2 },
            ].map((o) => {
              const best = outcomeLabel === o.k;
              return (
                <div
                  key={o.k}
                  className={`rounded-xl px-3 py-2 text-center ${
                    best
                      ? "border border-violet-400/18 bg-violet-500/14 shadow-[0_10px_22px_rgba(139,92,246,0.12)]"
                      : "border border-white/[0.05] bg-white/[0.035]"
                  }`}
                >
                  <div className="text-[11px] text-white/70">{o.k}</div>
                  <div className="text-sm font-semibold text-white">
                    {toPct(o.v)}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* TOTAL */}
        <div className={SOFT_CARD_CLASS + " space-y-3"}>
          <div className="flex justify-between items-center">
            <div className="text-[11px] uppercase tracking-wide text-white/50">{isRu ? "Тотал 2.5" : "Total 2.5"}</div>
            {totalLabel && (
              <span className={CHIP_CLASS}>
                {isRu ? "Базовый" : "Base"}: {totalLabel}
              </span>
            )}
          </div>

          <div className="grid grid-cols-2 gap-2">
            {[
              { k: isRu ? "Больше" : "Over", v: ov },
              { k: isRu ? "Меньше" : "Under", v: un },
            ].map((o) => {
              const best =
                (ov === o.v && /over|больше/i.test(totalLabel || "")) ||
                (un === o.v && /under|меньше/i.test(totalLabel || ""));
              return (
                <div
                  key={o.k}
                  className={`rounded-xl px-3 py-2 text-center ${
                    best
                      ? "border border-violet-400/18 bg-violet-500/14 shadow-[0_10px_22px_rgba(139,92,246,0.12)]"
                      : "border border-white/[0.05] bg-white/[0.035]"
                  }`}
                >
                  <div className="text-[11px] text-white/70">{o.k}</div>
                  <div className="text-sm font-semibold text-white">
                    {toPct(o.v)}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* РЕКОМЕНДАЦИЯ */}
      {recDecision === "BET" && signalPick ? (
        <div className="rounded-[24px] border border-emerald-400/18 bg-emerald-500/[0.08] px-4 py-3 ring-1 ring-emerald-400/[0.04]">
          <div className="flex justify-between">
            <div className="text-white">
              <span className="font-semibold">{isRu ? "Рекомендуемая ставка" : "Recommended bet"}: </span>
              {signalPick}
            </div>
            <div className="text-[12px] text-emerald-300">
              EV {(signalEV * 100).toFixed(1)}%, k={Number(signalOdds).toFixed(2)}
            </div>
          </div>
        </div>
      ) : (
        <div className="rounded-[24px] border border-white/[0.06] bg-white/[0.03] px-4 py-3 text-[13px] text-white/60">
          {isRu ? "Нет value по текущим коэффициентам" : "No value at current odds"}
        </div>
      )}

      {/* ===========================
          2) СРЕДНИЕ ПОКОАЗАТЕЛИ
      ============================ */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <TeamAvg avg={pack.homeAvg} name={match.home_team} id={match.home_team_id} onGoTeam={onGoTeam} isRu={isRu} />
        <TeamAvg avg={pack.awayAvg} name={match.away_team} id={match.away_team_id} onGoTeam={onGoTeam} isRu={isRu} />
      </div>

      {/* ===========================
          3) H2H
      ============================ */}
      <H2H list={pack.h2h} onGoTeam={onGoTeam} onOpenModal={onOpenModal} isRu={isRu} />

      {/* ===========================
          4) LAST MATCHES — две колонки
      ============================ */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Last5 list={pack.homeLast} title={match.home_team} teamId={match.home_team_id} onGoTeam={onGoTeam} isRu={isRu} />
        <Last5 list={pack.awayLast} title={match.away_team} teamId={match.away_team_id} onGoTeam={onGoTeam} isRu={isRu} />
      </div>
    </div>
  );
}

/* ======================= */
/* SUBCOMPONENTS */
/* ======================= */

function TeamAvg({ avg, name, id, onGoTeam, isRu }) {
  return (
    <div className={SOFT_CARD_CLASS}>
      <button
        onClick={() => onGoTeam?.(id)}
        className="mb-3 flex items-center gap-2 text-left"
      >
        <img src={logoSafe(id, name)} className="h-6 w-6 rounded-full bg-white/[0.04] p-0.5" />
        <span className="text-white font-medium">{name}</span>
      </button>

      <div className="space-y-2 text-white/80 text-sm">
        <Stat label="xG" v={avg?.xg} />
        <Stat label={isRu ? "Удары" : "Shots"} v={avg?.shots} />
        <Stat label={isRu ? "В створ" : "On target"} v={avg?.shots_on} />
        <Stat label={isRu ? "Владение" : "Possession"} v={avg?.possession} suffix="%" />
        <Stat label={isRu ? "Угловые" : "Corners"} v={avg?.corners} />
      </div>
    </div>
  );
}

function Stat({ label, v, suffix = "" }) {
  return (
    <div className="flex justify-between">
      <span className="text-white/50">{label}</span>
      <span className="text-white">{v != null ? Number(v).toFixed(2) + suffix : "—"}</span>
    </div>
  );
}

function H2H({ list, onGoTeam, onOpenModal, isRu }) {
  return (
    <div className={SOFT_CARD_CLASS + " space-y-3"}>
      <div className="text-white/80 font-medium">{isRu ? "Личные встречи (5)" : "Head-to-head (5)"}</div>
      {!list?.length ? (
        <div className="text-white/40 text-sm">{isRu ? "Нет личных встреч" : "No head-to-head matches"}</div>
      ) : (
        <div className="space-y-2">
          {list.map((m) => (
            <div
              key={m.fixture_id}
              className="grid grid-cols-[70px,1fr,60px,1fr] items-center gap-2 rounded-[18px] border border-white/[0.04] bg-white/[0.03] px-3 py-2 transition hover:bg-white/[0.045]"
              onClick={() => onOpenModal?.(m)}
            >
              <div className="text-white/50 text-[12px]">{m.date.slice(0, 10)}</div>

              <div className="flex items-center gap-2">
                <img src={logoSafe(m.home_team_id, m.home_team)} className="w-4 h-4" />
                <span className="truncate text-white/80 text-sm">{m.home_team}</span>
              </div>

              <div className="text-center text-white font-semibold">{m.score}</div>

              <div className="flex items-center gap-2">
                <img src={logoSafe(m.away_team_id, m.away_team)} className="w-4 h-4" />
                <span className="truncate text-white/80 text-sm">{m.away_team}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function Last5({ list, title, teamId, onGoTeam, isRu }) {
  return (
    <div className={SOFT_CARD_CLASS + " space-y-3"}>
      <button
        className="flex items-center gap-2 text-left"
        onClick={() => onGoTeam?.(teamId)}
      >
        <span className="text-white font-medium">{isRu ? "Последние 5" : "Last 5"} — {title}</span>
      </button>

      {!list?.length ? (
        <div className="text-white/40 text-sm">{isRu ? "Нет матчей" : "No matches"}</div>
      ) : (
        <div className="space-y-2">
          {list.map((m) => (
            <div
              key={m.fixture_id}
              className="grid grid-cols-[70px,1fr,60px,1fr] items-center gap-2 rounded-[18px] border border-white/[0.04] bg-white/[0.03] px-3 py-2 transition hover:bg-white/[0.045]"
            >
              <span className="text-white/50 text-[12px]">{m.date.slice(0, 10)}</span>

              <div className="flex items-center gap-2">
                <img src={logoSafe(m.home_team_id, m.home_team)} className="w-4 h-4" />
                <span className="truncate text-white/80">{m.home_team}</span>
              </div>

              <div className="text-center text-white font-semibold">{m.score}</div>

              <div className="flex items-center gap-2">
                <img src={logoSafe(m.away_team_id, m.away_team)} className="w-4 h-4" />
                <span className="truncate text-white/80">{m.away_team}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
