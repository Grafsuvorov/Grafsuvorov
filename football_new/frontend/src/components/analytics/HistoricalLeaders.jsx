import SafeImg from "@/components/SafeImg";
import { useState } from "react";

const getTeamLogo = (id) =>
  id ? `https://media.api-sports.io/football/teams/${id}.png` : "/icons/default_league.png";

export default function HistoricalLeaders({ leaders = [] }) {
  const [metric, setMetric] = useState("shots");
  const metricMap = {
    shots: {
      teamId: "shots_team_id",
      team: "shots_team",
      value: "shots_avg",
      suffix: "ударов",
      label: "Удары",
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
      suffix: "голов",
      label: "Голы",
    },
  };
  const m = metricMap[metric];

  return (
    <div className="rounded-[14px] border border-white/10 bg-[#121826] p-5 shadow-[0_0_18px_rgba(124,140,255,0.12)]">
      <div className="text-sm font-semibold text-white mb-3">Лидеры лиги по сезонам</div>
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
          <div className="text-sm text-white/45">Недостаточно данных</div>
        )}
      </div>
    </div>
  );
}
