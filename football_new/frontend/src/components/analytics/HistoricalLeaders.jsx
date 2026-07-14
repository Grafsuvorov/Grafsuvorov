import SafeImg from "@/components/SafeImg";
import { useState } from "react";
import { useLanguage } from "@/context/LanguageContext.jsx";

const getTeamLogo = (id) =>
  id ? `https://media.api-sports.io/football/teams/${id}.png` : "/icons/default_league.png";

export default function HistoricalLeaders({ leaders = [] }) {
  const [metric, setMetric] = useState("shots");
  const { language } = useLanguage();
  const isRu = language === "ru";
  const metricMap = {
    shots: {
      teamId: "shots_team_id",
      team: "shots_team",
      value: "shots_avg",
      suffix: isRu ? "ударов" : "shots",
      label: isRu ? "Удары" : "Shots",
    },
    xg: {
      teamId: "xg_team_id",
      team: "xg_team",
      value: "xg_avg",
      suffix: "xG",
      label: "xG",
    },
    goals: {
      teamId: "goals_team_id",
      team: "goals_team",
      value: "goals_avg",
      suffix: isRu ? "голов" : "goals",
      label: isRu ? "Голы" : "Goals",
    },
  };
  const m = metricMap[metric];

  return (
    <div className="glass-card p-5">
      <div className="text-sm font-semibold text-white mb-3">{isRu ? "Лидеры лиги по сезонам" : "League leaders by season"}</div>
      <div className="mb-3 flex items-center gap-2 text-xs">
        {Object.keys(metricMap).map((k) => (
          <button
            key={k}
            type="button"
            onClick={() => setMetric(k)}
            className={k === metric ? "rounded-full border border-primary bg-primary/20 px-2 py-1 text-white" : "rounded-full border border-white/10 px-2 py-1 text-white/65"}
          >
            {metricMap[k].label}
          </button>
        ))}
      </div>
      <div className="space-y-2">
        {leaders.map((l, idx) => (
          <div key={`${l.season}-${l[m.teamId]}`} className="flex items-center gap-3 py-1.5">
            <div className="w-12 text-xs text-white/50 tabular-nums">{l.season}</div>
            <div className="relative flex items-center justify-center w-5">
              <span className="h-2.5 w-2.5 rounded-full bg-primary block" />
              {idx < leaders.length - 1 && (
                <span className="absolute top-3 h-5 w-px bg-white/20" />
              )}
            </div>
            <SafeImg src={getTeamLogo(l[m.teamId])} alt={l[m.team]} className="h-[18px] w-[18px] object-contain" />
            <div className="text-sm text-white truncate">{l[m.team]}</div>
            <div className="ml-auto text-xs text-white/70 tabular-nums">
              {l[m.value] != null ? Number(l[m.value]).toFixed(2) : "—"} {m.suffix}
            </div>
          </div>
        ))}
        {leaders.length === 0 && (
          <div className="surface-empty">{isRu ? "Недостаточно данных" : "Not enough data"}</div>
        )}
      </div>
    </div>
  );
}
