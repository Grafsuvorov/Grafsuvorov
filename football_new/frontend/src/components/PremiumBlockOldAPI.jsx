// src/components/PremiumBlockOldAPI.jsx
import React from "react";

export default function PremiumBlockOldAPI({ match }) {
  if (!match) return null;

  const p1 = match.p1 || match.p_home;
  const px = match.x || match.p_draw;
  const p2 = match.p2 || match.p_away;

  const pov = match.p_over25;
  const pun = match.p_under25;

  const baselineOutcome = match.outcome_label;
  const baselineTotal = match.total_label;

  const rec = match.rec_decision === "BET" ? "BET" : "SKIP";
  const reason = match.rec_reason;

  const toPct = (v) =>
    v == null ? "—" : `${Math.round(Number(v) * 100)}%`;

  return (
    <div className="rounded-3xl border border-white/10 bg-[#0f0f17]/80 backdrop-blur-xl shadow-[0_18px_55px_rgba(0,0,0,0.75)] p-6 space-y-5">

      {/* HEADER */}
      <div className="flex items-center justify-between">
        <div>
          <div className="text-[11px] uppercase tracking-[0.18em] text-white/50">
            Прогноз модели EdgeScore
          </div>
          <div className="text-sm text-white/80">
            Вероятности исходов и сигнал value по рынку.
          </div>
        </div>

        <div className="flex gap-2">
          <span
            className={`px-3 h-7 flex items-center rounded-full text-[11px] font-semibold ${
              rec === "BET"
                ? "bg-emerald-500 text-white"
                : "bg-slate-700 text-slate-100"
            }`}
          >
            {rec === "BET" ? "Value bet" : "Пропуск"}
          </span>

          <span className="px-3 h-7 flex items-center rounded-full text-[11px] bg-white/5 text-white/60 border border-white/10">
            {match.signal_strength || "Сигнала нет"}
          </span>
        </div>
      </div>

      {/* TWO BLOCKS */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">

        {/* 1X2 */}
        <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
          <div className="flex justify-between items-center mb-2">
            <span className="text-[11px] uppercase tracking-[0.16em] text-white/50">
              Исход 1X2
            </span>

            {baselineOutcome && (
              <span className="text-[11px] px-2 py-1 rounded-full bg-white/10 text-white/70">
                Базовый исход: {baselineOutcome}
              </span>
            )}
          </div>

          <div className="grid grid-cols-3 gap-3">
            {[
              { label: "П1", value: toPct(p1), active: baselineOutcome === "П1" },
              { label: "Х", value: toPct(px), active: baselineOutcome === "Х" },
              { label: "П2", value: toPct(p2), active: baselineOutcome === "П2" },
            ].map((opt) => (
              <div
                key={opt.label}
                className={`rounded-xl px-2 py-2 flex flex-col items-center border ${
                  opt.active
                    ? "border-violet-400/80 bg-violet-500/20 shadow-[0_0_24px_rgba(139,92,246,0.4)]"
                    : "border-white/10 bg-white/[0.05]"
                }`}
              >
                <div className="text-[11px] text-white/70">{opt.label}</div>
                <div className="text-sm font-semibold text-white">
                  {opt.value}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* TOTAL 2.5 */}
        <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
          <div className="flex justify-between items-center mb-2">
            <span className="text-[11px] uppercase tracking-[0.16em] text-white/50">
              Тотал 2.5
            </span>

            {baselineTotal && (
              <span className="text-[11px] px-2 py-1 rounded-full bg-white/10 text-white/70">
                Базовый тотал: {baselineTotal}
              </span>
            )}
          </div>

          <div className="grid grid-cols-2 gap-3">
            {[
              {
                label: "Больше",
                value: toPct(pov),
                active: baselineTotal?.includes("Больше"),
              },
              {
                label: "Меньше",
                value: toPct(pun),
                active: baselineTotal?.includes("Меньше"),
              },
            ].map((opt) => (
              <div
                key={opt.label}
                className={`rounded-xl px-2 py-2 flex flex-col items-center border ${
                  opt.active
                    ? "border-violet-400/80 bg-violet-500/20 shadow-[0_0_24px_rgba(139,92,246,0.4)]"
                    : "border-white/10 bg-white/[0.05]"
                }`}
              >
                <div className="text-[11px] text-white/70">{opt.label}</div>
                <div className="text-sm font-semibold text-white">
                  {opt.value}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* RECOMMENDATION */}
      <div className="rounded-xl border border-white/10 bg-white/[0.03] px-4 py-3 text-[13px] text-white/70">
        Рекомендация модели:{" "}
        <span className="text-white font-semibold">
          {rec === "BET"
            ? match.signal_pick || "ставка найдена"
            : "пропуск матча (нет value по текущим коэффициентам)."}
        </span>
      </div>

      {/* REASON */}
      {reason && (
        <div className="rounded-xl border border-white/10 bg-white/[0.03] px-4 py-3 text-[12px] text-white/70">
          <div className="text-[11px] uppercase tracking-[0.16em] text-white/45 mb-1">
            Обоснование
          </div>
          {reason}
        </div>
      )}
    </div>
  );
}
