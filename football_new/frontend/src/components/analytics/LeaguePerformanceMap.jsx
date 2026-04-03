import {
  ResponsiveContainer,
  ScatterChart,
  Scatter,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
  ReferenceArea,
  ReferenceLine,
} from "recharts";

const logoByTeamId = (id) =>
  id ? `https://media.api-sports.io/football/teams/${id}.png` : "/icons/default_league.png";

const hashColor = (name = "") => {
  let hash = 0;
  for (let i = 0; i < name.length; i += 1) hash = name.charCodeAt(i) + ((hash << 5) - hash);
  const hue = Math.abs(hash) % 360;
  return `hsl(${hue}, 70%, 60%)`;
};

function DotShape({ cx, cy, payload, highlightedTeam, onTeamHover }) {
  if (cx == null || cy == null || !payload) return null;
  const isActive = highlightedTeam && payload.name === highlightedTeam;
  const box = isActive ? 30 : 26;
  const logo = isActive ? 26 : 24;
  return (
    <g
      onMouseEnter={() => onTeamHover?.(payload.name)}
      onMouseLeave={() => onTeamHover?.(null)}
    >
      <circle cx={cx} cy={cy} r={box / 2 + 1} fill="#0f172a" stroke="rgba(255,255,255,0.16)" strokeWidth={1} />
      <image
        href={payload.logo}
        x={cx - logo / 2}
        y={cy - logo / 2}
        width={logo}
        height={logo}
        preserveAspectRatio="xMidYMid meet"
      />
    </g>
  );
}

function MapTooltip({ active, payload }) {
  if (!active || !payload?.length) return null;
  const p = payload[0].payload;
  return (
    <div className="rounded-lg border border-white/10 bg-[rgba(10,10,20,0.9)] px-3 py-2 text-xs text-[#e6e9ef] shadow-[0_0_12px_rgba(124,140,255,0.18)]">
      <div className="mb-1 text-sm font-semibold text-white">{p.name}</div>
      <div>xG: {p.xg.toFixed(2)}</div>
      <div>xGA: {p.xga.toFixed(2)}</div>
      <div>Голы: {p.goals != null ? Number(p.goals).toFixed(2) : "—"}</div>
      <div>Пропущено: {p.conceded != null ? Number(p.conceded).toFixed(2) : "—"}</div>
    </div>
  );
}

export default function LeaguePerformanceMap({ teams = [], height = 320, highlightedTeam = null, onTeamHover = null }) {
  const data = teams
    .filter((t) => t.xg != null && t.xga != null)
    .map((t) => ({
      name: t.team,
      team_id: t.team_id,
      xg: Number(t.xg),
      xga: Number(t.xga),
      goals: t.goals,
      conceded: t.goals_conceded,
      color: hashColor(t.team),
      logo: logoByTeamId(t.team_id),
    }));
  const xVals = data.map((d) => d.xg);
  const yVals = data.map((d) => d.xga);
  const xMin = xVals.length ? Math.min(...xVals) : 0;
  const xMax = xVals.length ? Math.max(...xVals) : 3;
  const yMin = yVals.length ? Math.min(...yVals) : 0;
  const yMax = yVals.length ? Math.max(...yVals) : 3;
  const xMid = xVals.length ? xVals.reduce((a, b) => a + b, 0) / xVals.length : 1.5;
  const yMid = yVals.length ? yVals.reduce((a, b) => a + b, 0) / yVals.length : 1.5;

  return (
    <div className="rounded-[14px] border border-white/10 bg-[#121826] p-5 shadow-[0_0_18px_rgba(124,140,255,0.12)]">
      <div className="text-sm font-semibold text-white mb-3">Карта силы команд</div>
      <div style={{ height }}>
        <ResponsiveContainer width="100%" height="100%">
          <ScatterChart>
            <ReferenceArea x1={xMin} x2={xMid} y1={yMid} y2={yMax} fill="rgba(16,185,129,0.09)" />
            <ReferenceArea x1={xMid} x2={xMax} y1={yMid} y2={yMax} fill="rgba(245,158,11,0.08)" />
            <ReferenceArea x1={xMin} x2={xMid} y1={yMin} y2={yMid} fill="rgba(56,189,248,0.08)" />
            <ReferenceArea x1={xMid} x2={xMax} y1={yMin} y2={yMid} fill="rgba(244,63,94,0.08)" />
            <CartesianGrid stroke="rgba(255,255,255,0.06)" />
            <ReferenceLine x={xMid} stroke="rgba(255,255,255,0.25)" strokeDasharray="4 4" />
            <ReferenceLine y={yMid} stroke="rgba(255,255,255,0.25)" strokeDasharray="4 4" />
            <XAxis
              dataKey="xg"
              type="number"
              tick={{ fill: "rgba(230,233,239,0.7)", fontSize: 12 }}
              name="Атака (xG)"
              label={{ value: "Атака (xG за матч)", position: "insideBottom", offset: -4, fill: "rgba(230,233,239,0.7)", fontSize: 12 }}
            />
            <YAxis
              dataKey="xga"
              type="number"
              tick={{ fill: "rgba(230,233,239,0.7)", fontSize: 12 }}
              name="Защита (xGA)"
              label={{ value: "Защита (xGA за матч)", angle: -90, position: "insideLeft", fill: "rgba(230,233,239,0.7)", fontSize: 12 }}
            />
            <Tooltip cursor={{ stroke: "rgba(124,140,255,0.35)", strokeWidth: 1 }} content={<MapTooltip />} />
            <Scatter data={data} shape={(props) => <DotShape {...props} highlightedTeam={highlightedTeam} onTeamHover={onTeamHover} />} />
          </ScatterChart>
        </ResponsiveContainer>
      </div>
      <div className="mt-2 grid grid-cols-2 gap-x-4 gap-y-1 text-[11px] text-[#9aa3b2]">
        <div>Верх-лево: сильная команда</div>
        <div>Верх-право: атакующая команда</div>
        <div>Низ-лево: оборонительная команда</div>
        <div>Низ-право: слабая команда</div>
      </div>
    </div>
  );
}
