// src/components/PremiumGlowPanel.jsx
import React from "react";
import SafeImg from "@/components/SafeImg";
import { teamLogoMap } from "@/constants/teamLogoMap";

const logoSafe = (id, name) =>
  id ? `/icons/team_logos/${id}.png` : teamLogoMap[name] || "/icons/team_logos/default.png";

const toPct = (v) =>
  v == null || !Number.isFinite(Number(v)) ? "—" : `${Math.round(v * 100)}%`;

export default function PremiumGlowPanel({ match, pack, onGoTeam, onOpenModal }) {
  if (!pack || pack.loading) {
    return (
      <div className="px-4 py-4 text-sm text-white/60 bg-slate-950/90 rounded-3xl">
        Загружаем аналитику…
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
    strong: "bg-violet-500/20 text-violet-200 border-violet-400/60",
    medium: "bg-amber-500/20 text-amber-200 border-amber-400/60",
    weak: "bg-sky-500/20 text-sky-200 border-sky-400/60",
    none: "bg-white/5 text-white/40 border-white/10",
  }[strength || "none"];

  return (
    <div className="rounded-3xl bg-slate-950/95 border border-violet-500/30 shadow-[0_0_60px_rgba(139,92,246,0.45)] p-5 space-y-6">

      {/* HEADER */}
      <div className="flex items-center justify-between">
        <div>
          <div className="text-[11px] uppercase tracking-[0.18em] text-white/40">
            EdgeScore Premium
          </div>
          <div className="text-sm text-white/70">Предматчевая аналитика</div>
        </div>

        <span className={`px-3 py-1 rounded-full border text-[11px] font-semibold ${strengthPill}`}>
          {strength === "strong" ? "Сильный сигнал" :
           strength === "medium" ? "Средний" :
           strength === "weak" ? "Слабый" :
           "Нет value"}
        </span>
      </div>

      {/* ===========================
          1) ПРОГНОЗ
      ============================ */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">

        {/* 1X2 */}
        <div className="rounded-2xl bg-white/[0.03] border border-white/10 p-4 space-y-3">
          <div className="flex justify-between items-center">
            <div className="text-[11px] uppercase tracking-wide text-white/50">Исход 1X2</div>
            {outcomeLabel && (
              <span className="px-2 py-1 rounded-full bg-white/10 text-[11px] text-white/70">
                Базовый: {outcomeLabel}
              </span>
            )}
          </div>

          <div className="grid grid-cols-3 gap-2">
            {[
              { k: "П1", v: p1 },
              { k: "Х", v: px },
              { k: "П2", v: p2 },
            ].map((o) => {
              const best = outcomeLabel === o.k;
              return (
                <div
                  key={o.k}
                  className={`px-3 py-2 rounded-xl text-center border backdrop-blur-sm ${
                    best
                      ? "border-violet-400/80 bg-violet-500/20 shadow-[0_0_20px_rgba(139,92,246,0.4)]"
                      : "border-white/10 bg-white/5"
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
        <div className="rounded-2xl bg-white/[0.03] border border-white/10 p-4 space-y-3">
          <div className="flex justify-between items-center">
            <div className="text-[11px] uppercase tracking-wide text-white/50">Тотал 2.5</div>
            {totalLabel && (
              <span className="px-2 py-1 rounded-full bg-white/10 text-[11px] text-white/70">
                Базовый: {totalLabel}
              </span>
            )}
          </div>

          <div className="grid grid-cols-2 gap-2">
            {[
              { k: "Больше", v: ov },
              { k: "Меньше", v: un },
            ].map((o) => {
              const best =
                (o.k === "Больше" && totalLabel?.includes("Больше")) ||
                (o.k === "Меньше" && totalLabel?.includes("Меньше"));
              return (
                <div
                  key={o.k}
                  className={`px-3 py-2 rounded-xl text-center border backdrop-blur-sm ${
                    best
                      ? "border-violet-400/80 bg-violet-500/20 shadow-[0_0_20px_rgba(139,92,246,0.4)]"
                      : "border-white/10 bg-white/5"
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
        <div className="rounded-2xl px-4 py-3 bg-emerald-500/10 border border-emerald-500/40">
          <div className="flex justify-between">
            <div className="text-white">
              <span className="font-semibold">Рекомендуемая ставка: </span>
              {signalPick}
            </div>
            <div className="text-[12px] text-emerald-300">
              EV {(signalEV * 100).toFixed(1)}%, k={Number(signalOdds).toFixed(2)}
            </div>
          </div>
        </div>
      ) : (
        <div className="rounded-2xl px-4 py-3 bg-white/5 border border-white/10 text-white/60 text-[13px]">
          Нет value по текущим коэффициентам
        </div>
      )}

      {/* ===========================
          2) СРЕДНИЕ ПОКОАЗАТЕЛИ
      ============================ */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <TeamAvg avg={pack.homeAvg} name={match.home_team} id={match.home_team_id} onGoTeam={onGoTeam} />
        <TeamAvg avg={pack.awayAvg} name={match.away_team} id={match.away_team_id} onGoTeam={onGoTeam} />
      </div>

      {/* ===========================
          3) H2H
      ============================ */}
      <H2H list={pack.h2h} onGoTeam={onGoTeam} onOpenModal={onOpenModal} />

      {/* ===========================
          4) LAST MATCHES — две колонки
      ============================ */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Last5 list={pack.homeLast} title={match.home_team} teamId={match.home_team_id} onGoTeam={onGoTeam} />
        <Last5 list={pack.awayLast} title={match.away_team} teamId={match.away_team_id} onGoTeam={onGoTeam} />
      </div>
    </div>
  );
}

/* ======================= */
/* SUBCOMPONENTS */
/* ======================= */

function TeamAvg({ avg, name, id, onGoTeam }) {
  return (
    <div className="rounded-2xl bg-white/[0.03] border border-white/10 p-4">
      <button
        onClick={() => onGoTeam?.(id)}
        className="flex items-center gap-2 mb-3"
      >
        <img src={logoSafe(id, name)} className="w-6 h-6" />
        <span className="text-white font-medium">{name}</span>
      </button>

      <div className="space-y-2 text-white/80 text-sm">
        <Stat label="xG" v={avg?.xg} />
        <Stat label="Удары" v={avg?.shots} />
        <Stat label="В створ" v={avg?.shots_on} />
        <Stat label="Владение" v={avg?.possession} suffix="%" />
        <Stat label="Угловые" v={avg?.corners} />
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

function H2H({ list, onGoTeam, onOpenModal }) {
  return (
    <div className="rounded-2xl bg-white/[0.03] border border-white/10 p-4 space-y-3">
      <div className="text-white/80 font-medium">Личные встречи (5)</div>
      {!list?.length ? (
        <div className="text-white/40 text-sm">Нет личных встреч</div>
      ) : (
        <div className="space-y-2">
          {list.map((m) => (
            <div
              key={m.fixture_id}
              className="grid grid-cols-[70px,1fr,60px,1fr] gap-2 items-center bg-white/[0.02] border border-white/5 rounded-xl px-3 py-2 hover:bg-white/[0.05] transition"
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

function Last5({ list, title, teamId, onGoTeam }) {
  return (
    <div className="rounded-2xl bg-white/[0.03] border border-white/10 p-4 space-y-3">
      <button
        className="flex items-center gap-2"
        onClick={() => onGoTeam?.(teamId)}
      >
        <span className="text-white font-medium">Последние 5 — {title}</span>
      </button>

      {!list?.length ? (
        <div className="text-white/40 text-sm">Нет матчей</div>
      ) : (
        <div className="space-y-2">
          {list.map((m) => (
            <div
              key={m.fixture_id}
              className="grid grid-cols-[70px,1fr,60px,1fr] gap-2 items-center bg-white/[0.02] border border-white/5 rounded-xl px-3 py-2 hover:bg-white/[0.05] transition"
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
