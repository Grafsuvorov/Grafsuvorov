import { useMemo, useState } from "react";
import { ResponsiveContainer, ScatterChart, Scatter, XAxis, YAxis, Tooltip, CartesianGrid, ReferenceLine } from "recharts";

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
  const size = payload.isElite ? 28 : 24;
  const clipId = `player-dot-${payload.player_id || payload.name}-${Math.round(cx)}-${Math.round(cy)}`;
  return (
    <g>
      <circle
        cx={cx}
        cy={cy}
        r={size / 2 + 1}
        fill="rgba(124,140,255,0.3)"
        stroke={payload.isElite ? "#facc15" : "#fff"}
        strokeWidth={payload.isElite ? 2 : 1}
      />
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

function PlayerTooltip({ active, payload }) {
  if (!active || !payload?.length) return null;
  const p = payload[0].payload;
  return (
    <div className="rounded-lg border border-white/10 bg-[rgba(10,10,20,0.9)] px-3 py-2 text-xs text-[#e6e9ef] shadow-[0_0_12px_rgba(124,140,255,0.18)]">
      <div className="mb-1 text-sm font-semibold text-white">{p.name}</div>
      <div>Команда: {p.team || "—"}</div>
      <div>Голы: {fmtAxis(p.goals)}</div>
      <div>xG: {fmtAxis(p.xg)}</div>
      <div>Удары: {p.shots}</div>
      <div>Реализация: {(p.goals - p.xg >= 0 ? "+" : "") + fmtAxis(p.goals - p.xg)}</div>
    </div>
  );
}

const ELITE_PLAYERS = new Set(["haaland", "salah", "kane", "son"]);

const toNum = (v) => {
  if (v == null) return null;
  if (typeof v === "string") {
    const s = v.trim().replace(",", ".");
    if (!s) return null;
    const n = Number(s);
    return Number.isFinite(n) ? n : null;
  }
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

export default function PlayerFinishingChart({
  players = [],
  minMinutes = 900,
  minShots = 20,
  teamFilter = "all",
  onPlayerSelect = null,
}) {
  const [mode, setMode] = useState("top20");

  const { data, modeLabel } = useMemo(() => {
    const base = players
      .map((p) => {
        const shots = toNum(p.shots);
        const xg = toNum(p.xg);
        const goals = toNum(p.goals);
        const minutes = toNum(p.minutes) ?? 0;
        if (shots == null || xg == null || goals == null) return null;
        const resolvedPlayerId =
          p.api_player_id ?? (Number(p.player_id) > 0 ? p.player_id : null);
        return {
        player_id: resolvedPlayerId,
        name: p.player_name || p.player || "Unknown",
        team: p.team_name || p.team || "—",
        minutes,
        shots,
        xg,
        goals,
        conversion: xg > 0 ? goals / xg : 0,
        avatar: avatarByPlayerId(resolvedPlayerId),
        short: initials(p.player_name),
        isElite: ELITE_PLAYERS.has(String(p.player_name || "").toLowerCase()),
      };
      })
      .filter(Boolean)
      .filter((p) => {
        if (!teamFilter || teamFilter === "all") return true;
        return String(p.team || "")
          .split(",")
          .map((x) => x.trim().toLowerCase())
          .includes(String(teamFilter).toLowerCase());
      });

    const minuteCandidates = [Number(minMinutes), 720, 360, 90, 0]
      .filter((v, i, arr) => Number.isFinite(v) && arr.indexOf(v) === i);
    const shotCandidates = [Number(minShots), 10, 5]
      .filter((v, i, arr) => Number.isFinite(v) && arr.indexOf(v) === i);

    let filtered = [];
    for (const mm of minuteCandidates) {
      for (const sh of shotCandidates) {
        const cur = base
          .filter((p) => p.minutes >= mm && (p.shots >= sh || p.xg >= 5))
          .sort((a, b) => b.xg - a.xg);
        if (cur.length >= 8) {
          filtered = cur;
          break;
        }
        if (!filtered.length && cur.length) filtered = cur;
      }
      if (filtered.length >= 8) break;
    }

    if (mode === "top20") {
      return { data: filtered.slice(0, 20), modeLabel: "ТОП-20 игроков по xG" };
    }
    return { data: filtered.slice(0, 25), modeLabel: "Все игроки (до 25)" };
  }, [players, mode, teamFilter, minMinutes, minShots]);

  const maxAxis = Math.max(1, ...data.map((d) => Math.max(d.xg, d.goals)));

  return (
    <div className="glass-card p-6">
      <div className="text-sm font-semibold text-white mb-3">Карта реализации игроков</div>
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
              dataKey="xg"
              type="number"
              domain={[(min) => Math.max(0, min - 0.15), (max) => max + 0.15]}
              tickFormatter={fmtAxis}
              tick={{ fill: "#9aa3b2", fontSize: 11 }}
            />
            <YAxis
              dataKey="goals"
              type="number"
              domain={[(min) => Math.max(0, min - 0.15), (max) => max + 0.15]}
              tickFormatter={fmtAxis}
              tick={{ fill: "#9aa3b2", fontSize: 11 }}
            />
            <ReferenceLine
              stroke="rgba(255,255,255,0.25)"
              strokeDasharray="4 4"
              segment={[{ x: 0, y: 0 }, { x: maxAxis, y: maxAxis }]}
            />
            <Tooltip content={<PlayerTooltip />} />
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
      <div className="mt-1 text-xs text-[#9aa3b2]">Выше линии: реализует лучше ожидаемого, ниже: хуже ожидаемого</div>
    </div>
  );
}
