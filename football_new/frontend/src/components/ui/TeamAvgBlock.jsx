// src/components/ui/TeamAvgBlock.jsx
import React from "react";
import SafeImg from "@/components/SafeImg";

export default function TeamAvgBlock({ team, logoId, avg }) {
  if (!avg) {
    return (
      <div className="rounded-2xl border border-white/10 bg-slate-900/80 px-4 py-4 text-white/70 text-sm">
        Нет данных по средней статистике.
      </div>
    );
  }

  const metrics = [
    { key: "xg", label: "xG" },
    { key: "shots", label: "Удары" },
    { key: "shots_on", label: "В створ" },
    { key: "possession", label: "Владение (%)" },
    { key: "corners", label: "Угловые" },
  ];

  const logo = logoId ? `/icons/team_logos/${logoId}.png` : null;

  return (
    <div className="
      rounded-3xl border border-violet-400/40
      bg-gradient-to-br from-slate-950/95 via-slate-900/95 to-slate-950/95
      px-5 py-5
      shadow-[0_0_30px_rgba(139,92,246,0.25)]
      backdrop-blur-xl
      space-y-4
      ">

      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="h-10 w-10 rounded-full bg-white/5 border border-white/10 flex items-center justify-center overflow-hidden">
          <SafeImg src={logo} alt={team} className="h-6 w-6 object-contain" />
        </div>
        <div>
          <div className="text-[12px] uppercase tracking-[0.16em] text-white/40">
            Средние показатели
          </div>
          <div className="text-[15px] font-semibold text-white">
            {team}
          </div>
        </div>
      </div>

      {/* Metrics */}
      <div className="grid grid-cols-2 gap-x-6 gap-y-3 mt-2">
        {metrics.map((m) => {
          const val = avg[m.key];
          const shown =
            val != null && Number.isFinite(Number(val))
              ? Number(val).toFixed(m.key === "possession" ? 0 : 2)
              : "—";

          return (
            <div
              key={m.key}
              className="flex items-center justify-between text-white/80"
            >
              <span className="text-[13px] text-white/50">{m.label}</span>
              <span className="text-[15px] font-semibold tabular-nums text-white">
                {shown}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
