import React from "react";
import clsx from "clsx";

/* =============================
   PREMIUM TOKENS
============================= */

const PANEL =
  "bg-surface-2/70 backdrop-blur-2xl border border-white/10 rounded-3xl p-6 shadow-[0_0_45px_rgba(0,0,0,0.45)] relative overflow-hidden";

/* мягкая внутренняя подсветка по бокам */
const GLOW_LEFT =
  "absolute inset-y-0 left-0 w-[2px] bg-gradient-to-b from-accent/60 via-accent/20 to-transparent";
const GLOW_RIGHT =
  "absolute inset-y-0 right-0 w-[2px] bg-gradient-to-b from-sky-400/60 via-sky-400/20 to-transparent";

const SECTION_TITLE =
  "text-sm font-semibold text-slate-200 tracking-wide mb-4 mt-8 first:mt-0 flex items-center gap-2";

const ROW =
  "grid grid-cols-[1fr_160px_1fr] items-center gap-6 py-3 rounded-lg transition";

const VALUE =
  "text-[14px] font-semibold text-white tabular-nums text-right drop-shadow-[0_0_4px_rgba(255,255,255,0.35)]";
const VALUE_AWAY =
  "text-[14px] font-semibold text-white tabular-nums text-left drop-shadow-[0_0_4px_rgba(255,255,255,0.35)]";

const LABEL = "text-[12px] text-slate-400 text-center leading-tight";

/* =============================
   PREMIUM BAR w/ GLOW
============================= */

const Bar = ({ home, away }) => {
  const h = Number(home) || 0;
  const a = Number(away) || 0;
  const total = h + a || 1;

  const homePct = (h / total) * 100;
  const awayPct = (a / total) * 100;

  return (
    <div className="mt-1 h-[6px] rounded-full bg-black/20 overflow-hidden flex relative">
      {/* soft glow */}
      <div className="absolute inset-0 pointer-events-none blur-sm opacity-50" />

      {/* HOME */}
      <div
        className="h-full bg-gradient-to-r from-rose-400 via-rose-500 to-rose-500/30 shadow-[0_0_6px_rgba(255,0,80,0.45)]"
        style={{ width: `${homePct}%` }}
      />

      {/* AWAY */}
      <div
        className="h-full bg-gradient-to-r from-sky-400 via-sky-500 to-sky-500/30 shadow-[0_0_6px_rgba(0,180,255,0.45)]"
        style={{ width: `${awayPct}%` }}
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

export default function MatchStatsBlockV3({ stats }) {
  if (!stats) return null;

  const sections = {
    "Главное": [
      { key: "possession", label: "Владение мячом", isPercentage: true },
      { key: "expected_goals", label: "Ожидаемые голы (xG)", decimals: 2 },
      { key: "goals_prevented", label: "Предотвращённые голы", decimals: 2 },
    ],

    "Удары": [
      { key: "total_shots", label: "Всего ударов" },
      { key: "shots_on_goal", label: "Удары в створ" },
      { key: "shots_off_goal", label: "Удары мимо" },
      { key: "blocked_shots", label: "Блокированные удары" },
    ],

    "Зоны ударов": [
      { key: "shots_insidebox", label: "Удары из штрафной" },
      { key: "shots_outsidebox", label: "Удары из-за штрафной" },
    ],

    "Атака": [
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
  };

  return (
    <div className={PANEL}>
      {/* premium side glows */}
      <div className={GLOW_LEFT} />
      <div className={GLOW_RIGHT} />

      {Object.entries(sections).map(([title, fields]) => (
        <div key={title}>
          <div className={SECTION_TITLE}>
            <span className="h-3 w-1 rounded-full bg-gradient-to-b from-accent to-transparent" />
            {title}
          </div>

          <div className="space-y-1">
            {fields.map((m) => {
              const h = stats?.[`home_${m.key}`];
              const a = stats?.[`away_${m.key}`];

              if (h == null && a == null) return null;

              return (
                <div key={m.key} className={ROW}>
                  <div>
                    <div className={VALUE}>{fmt(m, h)}</div>
                    <Bar home={h} away={a} />
                  </div>

                  <div className={LABEL}>{m.label}</div>

                  <div>
                    <div className={VALUE_AWAY}>{fmt(m, a)}</div>
                    <Bar home={a} away={h} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
