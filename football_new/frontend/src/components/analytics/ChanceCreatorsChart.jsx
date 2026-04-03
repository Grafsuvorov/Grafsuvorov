import { useMemo, useState } from "react";
import { ResponsiveContainer, ScatterChart, Scatter, XAxis, YAxis, Tooltip, CartesianGrid } from "recharts";
import { ReferenceLine } from "recharts";

const avatarByPlayerId = (id) =>
  id ? `https://media.api-sports.io/football/players/${id}.png` : "/icons/player_photos/default.png";

function initials(name = "") {
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase() || "")
    .join("");
}

function PlayerDot({ cx, cy, payload }) {
  if (cx == null || cy == null || !payload) return null;
  const size = 24;
  const clipId = `player-dot-${payload.player_id || payload.name}-${Math.round(cx)}-${Math.round(cy)}`;
  return (
    <g>
      <circle cx={cx} cy={cy} r={size / 2 + 1} fill="rgba(124,140,255,0.3)" stroke="#fff" strokeWidth={1} />
      <defs>
        <clipPath id={clipId}>
          <circle cx={cx} cy={cy} r={size / 2 - 1} />
        </clipPath>
      </defs>
      <image
        href={payload.avatar}
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

const fmtAxis = (value) => {
  const n = Number(value);
  if (!Number.isFinite(n)) return "";
  if (Math.abs(n) >= 10) return String(Math.round(n));
  return n.toFixed(1).replace(/\.0$/, "");
};

function CreatorTooltip({ active, payload }) {
  if (!active || !payload?.length) return null;
  const p = payload[0].payload;
  return (
    <div className="rounded-lg border border-white/10 bg-[rgba(10,10,20,0.9)] px-3 py-2 text-xs text-[#e6e9ef] shadow-[0_0_12px_rgba(124,140,255,0.18)]">
      <div className="mb-1 text-sm font-semibold text-white">{p.name}</div>
      <div>Команда: {p.team || "—"}</div>
      <div>Ключевые передачи: {fmtAxis(p.key_passes)}</div>
      <div>Ассисты: {fmtAxis(p.assists)}</div>
      <div>Нереализованные: {fmtAxis(p.key_passes - p.assists)}</div>
    </div>
  );
}

export default function ChanceCreatorsChart({ players = [], teamFilter = "all", onPlayerSelect = null }) {
  const [mode, setMode] = useState("top20");
  const { data, modeLabel } = useMemo(() => {
    const base = players
      .filter((p) => p.key_passes != null && p.assists != null)
      .map((p) => ({
        player_id: p.api_player_id ?? (Number(p.player_id) > 0 ? p.player_id : null),
        name: p.player_name || p.player || "Unknown",
        team: p.team_name || p.team || "—",
        shots: Number(p.shots || 0),
        key_passes: Number(p.key_passes),
        assists: Number(p.assists),
        avatar: avatarByPlayerId(p.api_player_id ?? (Number(p.player_id) > 0 ? p.player_id : null)),
        short: initials(p.player_name || p.player),
      }))
      .filter((p) => {
        if (!teamFilter || teamFilter === "all") return true;
        return String(p.team || "")
          .split(",")
          .map((x) => x.trim().toLowerCase())
          .includes(String(teamFilter).toLowerCase());
      })
      .sort((a, b) => b.key_passes - a.key_passes);

    let filtered = [...base];
    let label = "Все доступные игроки";
    if (filtered.length < 6) {
      filtered = [...base].sort((a, b) => b.shots - a.shots).slice(0, 15);
      label = "Топ игроков по ударам";
    }

    if (mode === "top20") {
      return { data: filtered.slice(0, 20), modeLabel: "ТОП-20 игроков по ключевым передачам" };
    }
    return { data: filtered.slice(0, 25), modeLabel: label };
  }, [players, teamFilter, mode]);
  const maxX = Math.max(1, ...data.map((d) => d.key_passes));
  const ratio = data.length
    ? data.reduce((s, d) => s + (d.key_passes > 0 ? d.assists / d.key_passes : 0), 0) / data.length
    : 0.3;

  return (
    <div className="glass-card p-6">
      <div className="text-sm font-semibold text-white mb-3">Создатели моментов</div>
      <div className="mb-3 flex items-center gap-2">
        <button
          type="button"
          onClick={() => setMode("top20")}
          className={mode === "top20" ? "rounded-full border border-primary bg-primary/20 px-2 py-1 text-xs text-white" : "rounded-full border border-white/10 px-2 py-1 text-xs text-white/65"}
        >
          ТОП-20
        </button>
        <button
          type="button"
          onClick={() => setMode("all")}
          className={mode === "all" ? "rounded-full border border-primary bg-primary/20 px-2 py-1 text-xs text-white" : "rounded-full border border-white/10 px-2 py-1 text-xs text-white/65"}
        >
          Все
        </button>
      </div>
      {data.length < 6 && (
        <div className="mb-3 rounded-lg border border-white/10 bg-white/[0.03] px-3 py-2 text-xs text-white/70">
          Недостаточно данных
        </div>
      )}
      <div className="h-[480px]">
        <ResponsiveContainer width="100%" height="100%">
          <ScatterChart margin={{ top: 22, right: 22, bottom: 12, left: 12 }}>
            <CartesianGrid stroke="rgba(255,255,255,0.06)" />
            <XAxis
              dataKey="key_passes"
              type="number"
              domain={[(min) => Math.max(0, min - 0.5), (max) => max + 0.5]}
              tickFormatter={fmtAxis}
              tick={{ fill: "#9aa3b2", fontSize: 11 }}
            />
            <YAxis
              dataKey="assists"
              type="number"
              domain={[(min) => Math.max(0, min - 0.15), (max) => max + 0.15]}
              tickFormatter={fmtAxis}
              tick={{ fill: "#9aa3b2", fontSize: 11 }}
            />
            <ReferenceLine
              stroke="rgba(124,140,255,0.5)"
              strokeDasharray="4 4"
              segment={[{ x: 0, y: 0 }, { x: maxX, y: maxX * ratio }]}
              label={{ value: "Ожидаемые ассисты", fill: "#9aa3b2", fontSize: 10 }}
            />
            <Tooltip content={<CreatorTooltip />} />
            <Scatter
              data={data}
              shape={<PlayerDot />}
              onClick={(point) => {
                const playerId = point?.player_id ?? point?.payload?.player_id;
                if (playerId) onPlayerSelect?.(playerId);
              }}
            />
          </ScatterChart>
        </ResponsiveContainer>
      </div>
      <div className="mt-2 text-xs text-[#9aa3b2]">{modeLabel}</div>
    </div>
  );
}
