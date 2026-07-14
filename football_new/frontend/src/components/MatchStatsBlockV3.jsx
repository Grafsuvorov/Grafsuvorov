import React from "react";
import clsx from "clsx";
import { useLanguage } from "@/context/LanguageContext.jsx";

/* =============================
   PREMIUM TOKENS
============================= */

const PANEL =
  "px-1 py-1";

const SECTION_TITLE =
  "text-[11px] font-semibold uppercase tracking-[0.18em] text-white/60 mb-3 mt-12 first:mt-0 text-left";
const ROW = "py-2.5";
const GRID =
  "grid grid-cols-[58px_minmax(0,1fr)_58px] items-center gap-2 sm:grid-cols-[120px_minmax(0,1fr)_120px] sm:gap-4 lg:grid-cols-[140px_minmax(0,1fr)_140px]";
const VALUE = "text-[13px] font-medium text-white tabular-nums text-center sm:text-[16px]";
const VALUE_AWAY = "text-[13px] font-medium text-white tabular-nums text-center sm:text-[16px]";
const LABEL = "min-w-0 text-[11px] text-white/72 text-center leading-[1.15] sm:text-[13px]";

const toNum = (v) => {
  if (v == null || v === "") return 0;
  if (typeof v === "number") return Number.isFinite(v) ? v : 0;
  const s = String(v).replace("%", "").replace(",", ".").trim();
  const n = Number(s);
  return Number.isFinite(n) ? n : 0;
};

const DuelBar = ({ home, away, emphasis = "normal", accentSide = null }) => {
  const h = toNum(home);
  const a = toNum(away);
  const max = Math.max(Math.abs(h), Math.abs(a), 0);
  const cap = 44;
  let homeWidth = max > 0 ? (Math.abs(h) / max) * cap : 0;
  let awayWidth = max > 0 ? (Math.abs(a) / max) * cap : 0;
  if (Math.abs(h) > 0) homeWidth = Math.max(homeWidth, 10);
  if (Math.abs(a) > 0) awayWidth = Math.max(awayWidth, 10);
  const nearEqual = max > 0 ? Math.abs(h - a) <= 0.0001 : true;
  const homeLeads = h >= a;
  const forceHome = accentSide === "home";
  const forceAway = accentSide === "away";
  const accentHome = forceHome || (!forceAway && homeLeads);
  const accentAway = forceAway || (!forceHome && !homeLeads);

  const heightClass = "h-1.5";

  return (
    <div className={clsx("relative mt-1 rounded-full bg-white/[0.1] overflow-hidden", heightClass)}>
      <div className="absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-white/12" />
      <div
        className={clsx(
          "absolute right-1/2 top-0 h-full",
          "bg-gradient-to-r from-[#8b5cf6]/90 to-[#6d28d9]/85 shadow-[inset_0_1px_0_rgba(255,255,255,0.25)]"
        )}
        style={{ width: `${homeWidth}%` }}
      />
        <div
          className={clsx(
            "absolute left-1/2 top-0 h-full",
            "bg-gradient-to-l from-[#38bdf8]/90 to-[#14b8a6]/80 shadow-[inset_0_1px_0_rgba(255,255,255,0.22)]"
        )}
        style={{ width: `${awayWidth}%` }}
      />
    </div>
  );
};

/* =============================
   FORMATTER
============================= */

const fmt = (metric, v) => {
  if (metric.isPercentage) {
    const n = Number(v ?? 0);
    return `${n <= 1 ? Math.round(n * 100) : Math.round(n)}%`;
  }
  if (v == null) return "—";
  const n = Number(v);
  if (Number.isNaN(n)) return "—";
  return metric.decimals ? n.toFixed(metric.decimals) : n;
};

/* =============================
   EDGE SCORE PREMIUM — COMPONENT
============================= */

export default function MatchStatsBlockV3({ stats, accentSide = null }) {
  const { language } = useLanguage();
  if (!stats) return null;

  const sections = language === "ru" ? {
    "Главное": [
      { key: "possession", label: "Владение мячом", isPercentage: true, emphasis: "main" },
      { key: "expected_goals", label: "Ожидаемые голы (xG)", decimals: 2, emphasis: "main" },
      { key: "goals_prevented", label: "Предотвращённые голы", decimals: 2, emphasis: "main" },
    ],
    "Атака": [
      { key: "total_shots", label: "Всего ударов" },
      { key: "shots_on_goal", label: "Удары в створ" },
      { key: "shots_off_goal", label: "Удары мимо" },
      { key: "blocked_shots", label: "Блокированные удары" },
    ],

    "Зоны ударов": [
      { key: "shots_insidebox", label: "Удары из штрафной" },
      { key: "shots_outsidebox", label: "Удары из-за штрафной" },
    ],

    "Давление": [
      { key: "attacks", label: "Атаки" },
      { key: "dangerous_attacks", label: "Опасные атаки" },
    ],

    "Передачи": [
      { key: "passes", label: "Всего передач" },
      { key: "passes_accurate", label: "Точные передачи" },
      { key: "passes_percentage", label: "Точность передач", isPercentage: true },
    ],

    "Оборона / Вратарь": [
      { key: "tackles", label: "Отборы" },
      { key: "saves", label: "Сейвы" },
    ],

    "Стандарты и дисциплина": [
      { key: "corners", label: "Угловые" },
      { key: "offsides", label: "Офсайды" },
      { key: "fouls", label: "Фолы" },
      { key: "yellow_cards", label: "Жёлтые карточки" },
      { key: "red_cards", label: "Красные карточки" },
    ],
  } : {
    "Core": [
      { key: "possession", label: "Possession", isPercentage: true, emphasis: "main" },
      { key: "expected_goals", label: "Expected goals (xG)", decimals: 2, emphasis: "main" },
      { key: "goals_prevented", label: "Goals prevented", decimals: 2, emphasis: "main" },
    ],
    "Attack": [
      { key: "total_shots", label: "Total shots" },
      { key: "shots_on_goal", label: "Shots on target" },
      { key: "shots_off_goal", label: "Shots off target" },
      { key: "blocked_shots", label: "Blocked shots" },
    ],
    "Shot zones": [
      { key: "shots_insidebox", label: "Shots inside the box" },
      { key: "shots_outsidebox", label: "Shots outside the box" },
    ],
    "Pressure": [
      { key: "attacks", label: "Attacks" },
      { key: "dangerous_attacks", label: "Dangerous attacks" },
    ],
    "Passing": [
      { key: "passes", label: "Total passes" },
      { key: "passes_accurate", label: "Accurate passes" },
      { key: "passes_percentage", label: "Pass accuracy", isPercentage: true },
    ],
    "Defence / Goalkeeper": [
      { key: "tackles", label: "Tackles" },
      { key: "saves", label: "Saves" },
    ],
    "Set pieces and discipline": [
      { key: "corners", label: "Corners" },
      { key: "offsides", label: "Offsides" },
      { key: "fouls", label: "Fouls" },
      { key: "yellow_cards", label: "Yellow cards" },
      { key: "red_cards", label: "Red cards" },
    ],
  };

  return (
    <div className={PANEL}>
      {Object.entries(sections).map(([title, fields]) => (
        (() => {
          const visible = fields.filter((m) => {
            const h = stats?.[`home_${m.key}`];
            const a = stats?.[`away_${m.key}`];
            return !(h == null && a == null);
          });
          if (!visible.length) return null;
          return (
        <section key={title} className="mt-6 first:mt-0">
          <div className="px-1">
            <div className="flex items-center gap-2.5">
              <span className="inline-block h-4 w-[3px] rounded-full bg-[linear-gradient(180deg,rgba(192,132,252,0.95),rgba(103,232,249,0.75))]" />
              <div className={SECTION_TITLE + " mt-0 mb-0"}>
                {title}
              </div>
            </div>
          </div>

            <div className="space-y-1 pt-3">
            {visible.map((m) => {
              const h = stats?.[`home_${m.key}`];
              const a = stats?.[`away_${m.key}`];

              if (h == null && a == null) return null;

              return (
                <div key={m.key} className={ROW}>
                  <div className={GRID}>
                    <div className={VALUE}>{fmt(m, h)}</div>
                    <div className={LABEL}>{m.label}</div>
                    <div className={VALUE_AWAY}>{fmt(m, a)}</div>
                  </div>
                  <div className="px-1">
                    <DuelBar home={h} away={a} emphasis={m.emphasis || "normal"} accentSide={accentSide} />
                  </div>
                </div>
              );
            })}
          </div>
        </section>
          );
        })()
      ))}
    </div>
  );
}
