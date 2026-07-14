import React from "react";
import { useLanguage } from "@/context/LanguageContext.jsx";

function buildHumanReason(match, language = "ru") {
  const isRu = language === "ru";
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
      parts.push(
        isRu
          ? `Базовая ставка модели — ${signalPick}.`
          : `The model's base pick is ${signalPick}.`
      );
    }
    if (isFiniteNum(signalP) && isFiniteNum(signalOdds)) {
      parts.push(
        isRu
          ? `Модель оценивает вероятность исхода примерно в ${(signalP * 100).toFixed(
              1
            )}% при коэффициенте около ${signalOdds.toFixed(2)}.`
          : `The model estimates the outcome probability at about ${(signalP * 100).toFixed(
              1
            )}% with odds around ${signalOdds.toFixed(2)}.`
      );
    }
    if (isFiniteNum(signalEV)) {
      parts.push(
        isRu
          ? `Ожидаемое значение ставки — около ${(signalEV * 100).toFixed(1)}%.`
          : `The expected value of the pick is about ${(signalEV * 100).toFixed(1)}%.`
      );
    }
    if (isFiniteNum(signalEdge)) {
      parts.push(
        isRu
          ? `Преимущество над линией букмекеров — порядка ${(signalEdge * 100).toFixed(
              1
            )} п.п.`
          : `The edge over the bookmaker line is about ${(signalEdge * 100).toFixed(
              1
            )} pts.`
      );
    }
    if (signalType === "contrarian") {
      parts.push(isRu ? "Сигнал против рынка." : "This is a contrarian market signal.");
    } else if (signalType === "align") {
      parts.push(isRu ? "Сигнал совпадает с рынком." : "This signal aligns with the market.");
    }
    const books = Number(match?.n_bookmakers || 0);
    if (books) {
      parts.push(
        isRu
          ? `Расчёт выполнен по данным примерно ${books} букмекеров.`
          : `The estimate is based on data from roughly ${books} bookmakers.`
      );
    }
  } else {
    parts.push(
      isRu
        ? "Модель не видит достаточного преимущества над линией и предлагает пропустить матч."
        : "The model does not see enough edge over the line and suggests skipping the match."
    );
    if (isFiniteNum(signalEdge)) {
      parts.push(
        isRu
          ? `Преимущество оценивается всего в ${(signalEdge * 100).toFixed(
              1
            )} п.п., что ниже порога для value-ставки.`
          : `The edge is only about ${(signalEdge * 100).toFixed(
              1
            )} pts, which is below the threshold for a value bet.`
      );
    }
    if (isFiniteNum(signalEV)) {
      parts.push(
        isRu
          ? `Ожидаемое значение близко к нулю — около ${(signalEV * 100).toFixed(
              1
            )}%.`
          : `The expected value is close to zero, around ${(signalEV * 100).toFixed(
              1
            )}%.`
      );
    }
  }

  return parts.join(" ");
}

export default function PremiumAnalyticsBlock({ match }) {
  const { language } = useLanguage();
  const isRu = language === "ru";
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
    match?.rec_reason_human || buildHumanReason(match || {}, language);

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
        label: isRu ? "Сильный сигнал" : "Strong signal",
        className: "bg-emerald-500/20 text-emerald-200 border-emerald-400/60",
      };
    if (strength === "medium")
      return {
        label: isRu ? "Средний сигнал" : "Medium signal",
        className: "bg-amber-500/20 text-amber-200 border-amber-400/60",
      };
    if (strength === "weak")
      return {
        label: isRu ? "Слабый сигнал" : "Weak signal",
        className: "bg-sky-500/20 text-sky-200 border-sky-400/60",
      };
    return {
      label: isRu ? "Сигнала нет" : "No signal",
      className: "bg-white/5 text-white/60 border-white/10",
    };
  })();

  const decisionPill =
    recDecision === "BET"
      ? { label: isRu ? "Value-ставка" : "Value bet", className: "bg-emerald-500 text-emerald-50" }
      : { label: isRu ? "Пропуск" : "Skip", className: "bg-slate-700 text-slate-100" };

  const signalTypeLabel =
    signalType === "contrarian"
      ? isRu ? "Против рынка" : "Against market"
      : signalType === "align"
      ? isRu ? "В унисон с рынком" : "Aligned with market"
      : null;

  if (!hasAnyProb && !signalPick && !recDecision) return null;

  return (
    <div className="rounded-3xl border border-violet-500/20 bg-slate-950/90 px-4 py-4 space-y-4 shadow-[0_18px_55px_rgba(0,0,0,0.5)]">
      <div className="flex flex-wrap items-center gap-2">
        <span className="inline-flex items-center gap-2 rounded-full border border-violet-400/40 bg-violet-500/20 px-3 py-1 text-[11px] text-violet-100">
          {isRu ? "Прогноз модели" : "Model forecast"}
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
            {isRu ? "Исход" : "Outcome"}
          </div>
          <div className="mt-2 grid grid-cols-3 gap-2 text-sm text-white/90">
            <div>{isRu ? "П1" : "1"}: {toPct(p1) != null ? `${toPct(p1)}%` : "—"}</div>
            <div>{isRu ? "Х" : "X"}: {toPct(px) != null ? `${toPct(px)}%` : "—"}</div>
            <div>{isRu ? "П2" : "2"}: {toPct(p2) != null ? `${toPct(p2)}%` : "—"}</div>
          </div>
          {outcomeLabel && (
            <div className="mt-2 text-sm text-violet-100">
              {isRu ? "Прогноз" : "Forecast"}: <span className="text-white">{outcomeLabel}</span>
            </div>
          )}
        </div>
      )}

      {hasTotal && (
        <div>
          <div className="text-[11px] uppercase tracking-[0.2em] text-white/50">
            {isRu ? "Тотал 2.5" : "Total 2.5"}
          </div>
          <div className="mt-2 grid grid-cols-2 gap-2 text-sm text-white/90">
            <div>{isRu ? "Меньше" : "Under"}: {toPct(pun) != null ? `${toPct(pun)}%` : "—"}</div>
            <div>{isRu ? "Больше" : "Over"}: {toPct(pov) != null ? `${toPct(pov)}%` : "—"}</div>
          </div>
          {totalLabel && (
            <div className="mt-2 text-sm text-sky-100">
              {isRu ? "Прогноз" : "Forecast"}: <span className="text-white">{totalLabel}</span>
            </div>
          )}
        </div>
      )}

      {recDecision === "BET" && signalPick && (
        <div className="rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-[12px] text-white/85">
          <div className="font-semibold text-white/90">
            {isRu ? "Рекомендуется" : "Recommended"}: {signalPick}
          </div>
          <div className="mt-1 flex flex-wrap gap-3 text-[11px] text-white/70">
            {signalTypeLabel && <span>{signalTypeLabel}</span>}
            {signalP != null && (
              <span>p ≈ {(Number(signalP) * 100).toFixed(1)}%</span>
            )}
            {signalOdds != null && (
              <span>{isRu ? "коэфф." : "odds"} {Number(signalOdds).toFixed(2)}</span>
            )}
            {signalEV != null && (
              <span>EV {(Number(signalEV) * 100).toFixed(1)}%</span>
            )}
            {signalEdge != null && (
              <span>{isRu ? "edge" : "edge"} {(Number(signalEdge) * 100).toFixed(1)} {isRu ? "п.п." : "pts"}</span>
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
