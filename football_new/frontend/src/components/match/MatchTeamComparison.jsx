import UnderstatShotHeatmap from "@/components/UnderstatShotHeatmap";

export default function MatchTeamComparison({
  title,
  subtitle,
  match,
  labels,
  pack,
  MiniCompareRow,
}) {
  const hasMatchXg =
    Number.isFinite(Number(match?.home_understat_xg)) ||
    Number.isFinite(Number(match?.away_understat_xg));
  const hasPlayerXg =
    (Array.isArray(match?.understat_top_players_home) && match.understat_top_players_home.length > 0) ||
    (Array.isArray(match?.understat_top_players_away) && match.understat_top_players_away.length > 0);
  const hasShots =
    Array.isArray(match?.understat_shots) && match.understat_shots.length > 0;

  return (
    <div className="w-full min-w-0 overflow-hidden space-y-4 rounded-2xl border border-white/5 bg-gradient-to-br from-[#121827] via-[#101624] to-[#0b111e] p-4 shadow-[0_16px_45px_rgba(8,12,22,0.6)] sm:p-5">
      <div className="min-w-0">
        <div className="break-words text-[16px] font-semibold text-white">{title}</div>
        <div className="mt-1 break-words text-[12px] text-white/55">{subtitle}</div>
      </div>

      {hasMatchXg ? (
        <MiniCompareRow
          label={labels.matchXg}
          left={match?.home_understat_xg}
          right={match?.away_understat_xg}
          format={(v) => Number(v).toFixed(2)}
        />
      ) : null}
      <MiniCompareRow label={labels.formXg} left={pack?.homeAvg?.xg} right={pack?.awayAvg?.xg} format={(v) => Number(v).toFixed(2)} />
      <MiniCompareRow label="xGA" left={pack?.homeAvg?.xga} right={pack?.awayAvg?.xga} format={(v) => Number(v).toFixed(2)} />
      <MiniCompareRow label="ΔxG" left={pack?.homeAvg?.xg_diff} right={pack?.awayAvg?.xg_diff} format={(v) => Number(v).toFixed(2)} />
      <MiniCompareRow label={labels.shots} left={pack?.homeAvg?.shots} right={pack?.awayAvg?.shots} format={(v) => Number(v).toFixed(1)} />
      <MiniCompareRow label={labels.shotsOn} left={pack?.homeAvg?.shots_on} right={pack?.awayAvg?.shots_on} format={(v) => Number(v).toFixed(1)} />
      <MiniCompareRow label={labels.possession} left={pack?.homeAvg?.possession} right={pack?.awayAvg?.possession} format={(v) => `${Number(v).toFixed(0)}%`} />
      <MiniCompareRow label={labels.corners} left={pack?.homeAvg?.corners} right={pack?.awayAvg?.corners} format={(v) => Number(v).toFixed(1)} />

      {hasPlayerXg ? (
        <div className="border-t border-white/10 pt-2">
          <div className="mb-2 text-[12px] text-white/55">{labels.playerXg}</div>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <div className="mb-1 text-[12px] text-white/75">{match?.home_team || labels.homeFallback}</div>
              <div className="space-y-1">
                {(match?.understat_top_players_home || []).slice(0, 4).map((p) => (
                  <div key={`uh-${p.player_id}-${p.player_name}`} className="flex items-center justify-between text-[12px] text-white/80">
                    <span className="truncate pr-2">{p.player_name}</span>
                    <span className="tabular-nums text-violet-300">{Number(p.xg || 0).toFixed(2)} xG</span>
                  </div>
                ))}
              </div>
            </div>
            <div>
              <div className="mb-1 text-[12px] text-white/75">{match?.away_team || labels.awayFallback}</div>
              <div className="space-y-1">
                {(match?.understat_top_players_away || []).slice(0, 4).map((p) => (
                  <div key={`ua-${p.player_id}-${p.player_name}`} className="flex items-center justify-between text-[12px] text-white/80">
                    <span className="truncate pr-2">{p.player_name}</span>
                    <span className="tabular-nums text-sky-300">{Number(p.xg || 0).toFixed(2)} xG</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      ) : null}

      {hasShots ? (
        <div className="border-t border-white/10 pt-2">
          <UnderstatShotHeatmap
            shots={match.understat_shots}
            homeTeam={match?.home_team || labels.homeFallback}
            awayTeam={match?.away_team || labels.awayFallback}
          />
        </div>
      ) : null}
    </div>
  );
}
