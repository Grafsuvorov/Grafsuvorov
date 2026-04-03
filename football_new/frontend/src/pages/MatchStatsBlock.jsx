import React from "react";

export default function MatchStatsBlock({ stats }) {
  if (!stats) return null;

  const renderStat = (label, homeValue, awayValue) => {
    const home = Number(homeValue) || 0;
    const away = Number(awayValue) || 0;
    const total = home + away;
    const homePct = total > 0 ? (home / total) * 100 : 50;
    const awayPct = 100 - homePct;

    return (
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm text-slate-300 w-16 text-right">{home}</span>
        <div className="flex-1 mx-3">
          <div className="text-xs text-slate-400 mb-1">{label}</div>
          <div className="w-full h-2 rounded overflow-hidden bg-white/10 flex">
            <div className="bg-violet-500/80 h-full" style={{ width: `${homePct}%` }} />
            <div className="bg-gradient-to-r from-sky-400/80 to-teal-400/70 h-full" style={{ width: `${awayPct}%` }} />
          </div>
        </div>
        <span className="text-sm text-slate-300 w-16 text-left">{away}</span>
      </div>
    );
  };

  return (
    <div className="match-stats-block mt-4 text-sm rounded-lg border border-glass bg-surface-2/80 p-4 text-slate-100">
      <h4 className="text-center text-md font-bold text-slate-100 mb-3">Статистика матча</h4>
      
      {renderStat("Владение", stats.home_possession, stats.away_possession)}
      {renderStat("Удары", stats.home_total_shots, stats.away_total_shots)}
      {renderStat("Удары в створ", stats.home_shots_on_goal, stats.away_shots_on_goal)}
      {renderStat("Передачи", stats.home_passes, stats.away_passes)}
      {renderStat("Точность передач", stats.home_passes_percentage, stats.away_passes_percentage)}
      {renderStat("Угловые", stats.home_corners, stats.away_corners)}
      {renderStat("Фолы", stats.home_fouls, stats.away_fouls)}
      {renderStat("Желтые карточки", stats.home_yellow_cards, stats.away_yellow_cards)}
      {renderStat("Красные карточки", stats.home_red_cards, stats.away_red_cards)}
    </div>
  );
}
