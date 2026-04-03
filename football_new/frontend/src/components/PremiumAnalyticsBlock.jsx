import React from "react";

function buildHumanReason(match) {
  const signalPick = match?.signal_pick;
  const signalP = Number(match?.signal_p);
  const signalOdds = Number(match?.signal_odds);
  const signalEV = Number(match?.signal_value);
  const signalEdge = Number(match?.signal_edge);
  const signalType = match?.signal_type; // align / contrarian

  const isFiniteNum = (v) => Number.isFinite(v);
  const parts = [];

  if (match?.rec_decision === "BET") {
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
        `Ожидаемое значение ставки — около ${(signalEV * 100).toFixed(1)}%.`
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
      parts.push("Сигнал против рынка.");
    } else if (signalType === "align") {
      parts.push("Сигнал совпадает с рынком.");
    }
    const books = Number(match?.n_bookmakers || 0);
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

export default function PremiumAnalyticsBlock({ match }) {
  const p1 = match?.p_home;
  const px = match?.p_draw;
  const p2 = match?.p_away;
  const pov = match?.p_over25;
  const pun = match?.p_under25;

  const outcomeLabel = match?.outcome_label;
  const totalLabel = match?.total_label;

  const recDecision = match?.rec_decision;
  const strength = match?.signal_strength || "none";
  const signalPick = match?.signal_pick;
  const signalP = match?.signal_p;
  const signalOdds = match?.signal_odds;
  const signalEV = match?.signal_value;
  const signalEdge = match?.signal_edge;
  const kelly = match?.kelly_frac;
  const signalType = match?.signal_type;

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
      ? "В унисон с рынком"
      : null;

  if (!hasAnyProb && !signalPick && !recDecision) return null;

  return (
    <div className="rounded-3xl border border-violet-500/20 bg-slate-950/90 px-4 py-4 space-y-4 shadow-[0_18px_55px_rgba(0,0,0,0.5)]">
      <div className="flex flex-wrap items-center gap-2">
        <span className="inline-flex items-center gap-2 rounded-full border border-violet-400/40 bg-violet-500/20 px-3 py-1 text-[11px] text-violet-100">
          Прогноз модели
        </span>
        <span
          className={`inline-flex items-center rounded-full border px-3 py-1 text-[11px] ${strengthPill.className}`}
        >
          {strengthPill.label}
        </span>
        <span
          className={`inline-flex items-center rounded-full px-3 py-1 text-[11px] ${decisionPill.className}`}
        >
          {decisionPill.label}
        </span>
      </div>

      {hasOutcome && (
        <div>
          <div className="text-[11px] uppercase tracking-[0.2em] text-white/50">
            Исход
          </div>
          <div className="mt-2 grid grid-cols-3 gap-2 text-sm text-white/90">
            <div>П1: {toPct(p1) != null ? `${toPct(p1)}%` : "—"}</div>
            <div>Х: {toPct(px) != null ? `${toPct(px)}%` : "—"}</div>
            <div>П2: {toPct(p2) != null ? `${toPct(p2)}%` : "—"}</div>
          </div>
          {outcomeLabel && (
            <div className="mt-2 text-sm text-violet-100">
              Прогноз: <span className="text-white">{outcomeLabel}</span>
            </div>
          )}
        </div>
      )}

      {hasTotal && (
        <div>
          <div className="text-[11px] uppercase tracking-[0.2em] text-white/50">
            Тотал 2.5
          </div>
          <div className="mt-2 grid grid-cols-2 gap-2 text-sm text-white/90">
            <div>Меньше: {toPct(pun) != null ? `${toPct(pun)}%` : "—"}</div>
            <div>Больше: {toPct(pov) != null ? `${toPct(pov)}%` : "—"}</div>
          </div>
          {totalLabel && (
            <div className="mt-2 text-sm text-sky-100">
              Прогноз: <span className="text-white">{totalLabel}</span>
            </div>
          )}
        </div>
      )}

      {recDecision === "BET" && signalPick && (
        <div className="rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-[12px] text-white/85">
          <div className="font-semibold text-white/90">
            Рекомендуется: {signalPick}
          </div>
          <div className="mt-1 flex flex-wrap gap-3 text-[11px] text-white/70">
            {signalTypeLabel && <span>{signalTypeLabel}</span>}
            {signalP != null && (
              <span>p ≈ {(Number(signalP) * 100).toFixed(1)}%</span>
            )}
            {signalOdds != null && (
              <span>коэфф. {Number(signalOdds).toFixed(2)}</span>
            )}
            {signalEV != null && (
              <span>EV {(Number(signalEV) * 100).toFixed(1)}%</span>
            )}
            {signalEdge != null && (
              <span>edge {(Number(signalEdge) * 100).toFixed(1)} п.п.</span>
            )}
            {kelly != null && (
              <span>Kelly {Math.round(Number(kelly) * 100)}%</span>
            )}
          </div>
        </div>
      )}

      {humanReason && (
        <div className="text-[12px] text-white/70 leading-relaxed">
          {humanReason}
        </div>
      )}
    </div>
  );
}
