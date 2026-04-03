import { ResponsiveContainer, ScatterChart, Scatter, XAxis, YAxis, Tooltip, CartesianGrid } from "recharts";
import { ReferenceLine } from "recharts";

const logoByTeamId = (id) =>
  id ? `https://media.api-sports.io/football/teams/${id}.png` : "/icons/default_league.png";

const fmtAxis = (value) => {
  const n = Number(value);
  if (!Number.isFinite(n)) return "";
  if (Math.abs(n) >= 10) return String(Math.round(n));
  return n.toFixed(1).replace(/\.0$/, "");
};

function TeamLogoDot({ cx, cy, payload }) {
  if (cx == null || cy == null || !payload) return null;
  const isActive = payload.isActive;
  const size = isActive ? 30 : 26;
  const clipId = `team-dot-${payload.team_id || payload.name}-${Math.round(cx)}-${Math.round(cy)}`;
  return (
    <g>
      <circle
        cx={cx}
        cy={cy}
        r={size / 2 + 1}
        fill="#0f172a"
        stroke="rgba(255,255,255,0.16)"
        strokeWidth={1}
      />
      <defs>
        <clipPath id={clipId}>
          <circle cx={cx} cy={cy} r={size / 2 - 1} />
        </clipPath>
      </defs>
      <image
        href={payload.logo}
        x={cx - size / 2}
        y={cy - size / 2}
        width={size}
        height={size}
        preserveAspectRatio="xMidYMid slice"
        clipPath={`url(#${clipId})`}
      />
    </g>
  );
}

function ShotTooltip({ active, payload }) {
  if (!active || !payload?.length) return null;
  const p = payload[0].payload;
  return (
    <div className="rounded-lg border border-white/10 bg-[rgba(10,10,20,0.9)] px-3 py-2 text-xs text-[#e6e9ef] shadow-[0_0_12px_rgba(124,140,255,0.18)]">
      <div className="mb-1 text-sm font-semibold text-white">{p.name}</div>
      <div>Удары: {fmtAxis(p.shots)}</div>
      <div>Голы: {fmtAxis(p.goals)}</div>
      <div>Конверсия: {(p.conversion * 100).toFixed(1)}%</div>
    </div>
  );
}

export default function ShotEfficiencyChart({ teams = [], highlightedTeam = null, onTeamHover = null }) {
  const data = teams
    .filter((t) => t.shots != null && t.goals != null)
    .map((t) => ({
      name: t.team,
      team_id: t.team_id,
      shots: Number(t.shots),
      goals: Number(t.goals),
      conversion: Number(t.shots) > 0 ? Number(t.goals) / Number(t.shots) : 0,
      logo: logoByTeamId(t.team_id),
      isActive: highlightedTeam && highlightedTeam === t.team,
    }));
  const avgX = data.length ? data.reduce((s, d) => s + d.shots, 0) / data.length : 0;
  const avgY = data.length ? data.reduce((s, d) => s + d.goals, 0) / data.length : 0;

  return (
    <div className="glass-card p-6">
      <div className="text-sm font-semibold text-white mb-3">Эффективность ударов</div>
      <div className="h-[480px]">
        <ResponsiveContainer width="100%" height="100%">
          <ScatterChart margin={{ top: 22, right: 22, bottom: 12, left: 12 }}>
            <CartesianGrid stroke="rgba(255,255,255,0.06)" />
            <XAxis
              dataKey="shots"
              type="number"
              domain={[(min) => Math.max(0, min - 0.5), (max) => max + 0.5]}
              tickFormatter={fmtAxis}
              tick={{ fill: "rgba(230,233,239,0.7)", fontSize: 12 }}
            />
            <YAxis
              dataKey="goals"
              type="number"
              domain={[(min) => Math.max(0, min - 0.2), (max) => max + 0.2]}
              tickFormatter={fmtAxis}
              tick={{ fill: "rgba(230,233,239,0.7)", fontSize: 12 }}
            />
            <ReferenceLine x={avgX} stroke="rgba(255,255,255,0.2)" strokeDasharray="3 3" />
            <ReferenceLine y={avgY} stroke="rgba(255,255,255,0.2)" strokeDasharray="3 3" />
            <Tooltip content={<ShotTooltip />} />
            <Scatter
              data={data}
              shape={<TeamLogoDot />}
              onMouseMove={(e) => {
                const team = e?.payload?.name;
                if (team) onTeamHover?.(team);
              }}
              onMouseLeave={() => onTeamHover?.(null)}
            />
          </ScatterChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
