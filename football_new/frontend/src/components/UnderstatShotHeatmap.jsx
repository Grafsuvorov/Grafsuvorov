import { useMemo, useState } from "react";

const clamp01 = (v) => Math.max(0, Math.min(1, Number(v || 0)));

const parseNum = (v, fallback = 0) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
};

function ShotTooltip({ shot }) {
  if (!shot) return null;
  const minute = parseNum(shot.minute, null);
  return (
    <div className="pointer-events-none absolute -translate-x-1/2 -translate-y-full rounded-lg border border-white/10 bg-[rgba(15,23,42,0.96)] px-2 py-1 text-[11px] text-white shadow-[0_10px_30px_rgba(0,0,0,0.5)]">
      <div className="font-semibold">{shot.player_name || "Игрок"}</div>
      <div className="text-white/80">
        {minute != null ? `${minute}'` : "—"} · xG {parseNum(shot.xg).toFixed(2)}
      </div>
      <div className="text-white/65">{shot.result || "Shot"}</div>
    </div>
  );
}

export default function UnderstatShotHeatmap({
  shots = [],
  homeTeam = "Хозяева",
  awayTeam = "Гости",
}) {
  const [teamView, setTeamView] = useState("all");
  const [mode, setMode] = useState("heat");
  const [hoveredShotId, setHoveredShotId] = useState(null);

  const filteredShots = useMemo(() => {
    const src = Array.isArray(shots) ? shots : [];
    return src
      .filter((s) => s?.x != null && s?.y != null && s?.side)
      .filter((s) => {
        if (teamView === "all") return true;
        return s.side === teamView;
      })
      .map((s) => {
        const xRaw = clamp01(s.x);
        const yRaw = clamp01(s.y);
        const side = s.side === "a" ? "a" : "h";
        // home shots -> attack right, away shots mirrored to attack left
        const x = side === "h" ? xRaw : 1 - xRaw;
        return {
          ...s,
          x,
          y: yRaw,
          xg: parseNum(s.xg),
          isGoal: String(s.result || "").toLowerCase() === "goal",
        };
      });
  }, [shots, teamView]);

  const heatCells = useMemo(() => {
    const cols = 18;
    const rows = 12;
    const cells = Array.from({ length: rows * cols }, () => 0);
    for (const s of filteredShots) {
      const c = Math.max(0, Math.min(cols - 1, Math.floor(s.x * cols)));
      const r = Math.max(0, Math.min(rows - 1, Math.floor(s.y * rows)));
      cells[r * cols + c] += Math.max(0.03, s.xg);
    }
    const max = Math.max(0, ...cells);
    return { cells, cols, rows, max };
  }, [filteredShots]);

  const hoveredShot = filteredShots.find((s) => s.shot_id === hoveredShotId);

  const homeCount = filteredShots.filter((s) => s.side === "h").length;
  const awayCount = filteredShots.filter((s) => s.side === "a").length;

  return (
    <div className="rounded-[14px] border border-white/10 bg-[#121826] p-4 shadow-[0_0_18px_rgba(124,140,255,0.12)]">
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <div>
          <div className="text-sm font-semibold text-white">Карта ударов</div>
          <div className="text-[12px] text-white/55">Тепловая карта на футбольном поле</div>
        </div>
        <div className="flex items-center gap-2">
          <div className="flex rounded-full border border-white/10 bg-white/5 p-0.5">
            <button
              type="button"
              onClick={() => setMode("heat")}
              className={mode === "heat" ? "rounded-full bg-primary/25 px-2 py-1 text-[11px] text-white" : "rounded-full px-2 py-1 text-[11px] text-white/65"}
            >
              Тепловая
            </button>
            <button
              type="button"
              onClick={() => setMode("dots")}
              className={mode === "dots" ? "rounded-full bg-primary/25 px-2 py-1 text-[11px] text-white" : "rounded-full px-2 py-1 text-[11px] text-white/65"}
            >
              Точки
            </button>
          </div>
          <div className="flex rounded-full border border-white/10 bg-white/5 p-0.5">
            <button
              type="button"
              onClick={() => setTeamView("all")}
              className={teamView === "all" ? "rounded-full bg-primary/25 px-2 py-1 text-[11px] text-white" : "rounded-full px-2 py-1 text-[11px] text-white/65"}
            >
              Все
            </button>
            <button
              type="button"
              onClick={() => setTeamView("h")}
              className={teamView === "h" ? "rounded-full bg-primary/25 px-2 py-1 text-[11px] text-white" : "rounded-full px-2 py-1 text-[11px] text-white/65"}
            >
              {homeTeam}
            </button>
            <button
              type="button"
              onClick={() => setTeamView("a")}
              className={teamView === "a" ? "rounded-full bg-primary/25 px-2 py-1 text-[11px] text-white" : "rounded-full px-2 py-1 text-[11px] text-white/65"}
            >
              {awayTeam}
            </button>
          </div>
        </div>
      </div>

      {filteredShots.length === 0 ? (
        <div className="rounded-xl border border-white/10 bg-white/[0.02] p-4 text-sm text-white/65">
          Нет данных по ударам для выбранного фильтра.
        </div>
      ) : (
        <>
          <div className="relative w-full overflow-hidden rounded-2xl border border-white/10" style={{ aspectRatio: "1.55 / 1" }}>
            <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,#0f1d2d_0%,#0a1320_100%)]" />

            <svg className="absolute inset-0 h-full w-full">
              <rect x="2%" y="2%" width="96%" height="96%" fill="none" stroke="rgba(255,255,255,0.16)" strokeWidth="1.1" />
              <line x1="50%" y1="2%" x2="50%" y2="98%" stroke="rgba(255,255,255,0.16)" strokeWidth="1.1" />
              <circle cx="50%" cy="50%" r="10%" fill="none" stroke="rgba(255,255,255,0.16)" strokeWidth="1.1" />
              <rect x="2%" y="22%" width="14%" height="56%" fill="none" stroke="rgba(255,255,255,0.16)" strokeWidth="1.1" />
              <rect x="84%" y="22%" width="14%" height="56%" fill="none" stroke="rgba(255,255,255,0.16)" strokeWidth="1.1" />
            </svg>

            {mode === "heat" && (
              <svg className="absolute inset-0 h-full w-full">
                {heatCells.cells.map((v, idx) => {
                  if (v <= 0) return null;
                  const { cols, rows, max } = heatCells;
                  const c = idx % cols;
                  const r = Math.floor(idx / cols);
                  const w = 100 / cols;
                  const h = 100 / rows;
                  const alpha = max > 0 ? Math.min(0.75, (v / max) * 0.8) : 0;
                  return (
                    <rect
                      key={`cell-${idx}`}
                      x={`${c * w}%`}
                      y={`${r * h}%`}
                      width={`${w}%`}
                      height={`${h}%`}
                      fill={`rgba(124,92,255,${alpha})`}
                    />
                  );
                })}
              </svg>
            )}

            <div className="absolute inset-0">
              {filteredShots.map((s) => {
                const left = `${s.x * 100}%`;
                const top = `${s.y * 100}%`;
                const size = 7 + Math.min(12, s.xg * 60) + (s.isGoal ? 4 : 0);
                const color = s.isGoal ? "rgba(46, 204, 113, 0.95)" : s.side === "h" ? "rgba(157,139,255,0.9)" : "rgba(99,179,237,0.9)";
                return (
                  <div
                    key={`shot-${s.shot_id}`}
                    className="absolute -translate-x-1/2 -translate-y-1/2 rounded-full border border-white/50 flex items-center justify-center"
                    style={{
                      left,
                      top,
                      width: `${size}px`,
                      height: `${size}px`,
                      background: color,
                      boxShadow: mode === "dots" || s.isGoal ? "0 0 12px rgba(0,0,0,0.45)" : "none",
                      opacity: s.isGoal ? 0.98 : mode === "dots" ? 0.95 : 0.55,
                      zIndex: hoveredShotId === s.shot_id ? 20 : 10,
                    }}
                    onMouseEnter={() => setHoveredShotId(s.shot_id)}
                    onMouseLeave={() => setHoveredShotId(null)}
                  >
                    {s.isGoal ? (
                      <span
                        style={{
                          fontSize: `${Math.max(9, Math.min(14, size - 2))}px`,
                          lineHeight: 1,
                          filter: "drop-shadow(0 1px 2px rgba(0,0,0,0.6))",
                        }}
                      >
                        ⚽
                      </span>
                    ) : null}
                  </div>
                );
              })}
              {hoveredShot ? (
                <div
                  className="absolute"
                  style={{
                    left: `${hoveredShot.x * 100}%`,
                    top: `${hoveredShot.y * 100}%`,
                    zIndex: 30,
                  }}
                >
                  <ShotTooltip shot={hoveredShot} />
                </div>
              ) : null}
            </div>
          </div>

          <div className="mt-3 flex flex-wrap items-center justify-between gap-2 text-[12px] text-white/65">
            <div>
              Удары: {filteredShots.length} · Хозяева: {homeCount} · Гости: {awayCount}
            </div>
            <div className="flex items-center gap-3">
              <span className="inline-flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-[rgba(46,204,113,0.95)]" /> Гол</span>
              <span className="inline-flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-[rgba(157,139,255,0.9)]" /> Хозяева</span>
              <span className="inline-flex items-center gap-1"><span className="h-2 w-2 rounded-full bg-[rgba(99,179,237,0.9)]" /> Гости</span>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
