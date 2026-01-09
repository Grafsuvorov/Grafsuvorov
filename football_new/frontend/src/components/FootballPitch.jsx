import React, { useMemo, useState } from "react";

/* ----- helpers ----- */
const initials = (name = "") =>
  name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join("") || "??";

/** grid like "4:3" or "row:col" / "col:row" → {x,y} in % */
function gridToXY(grid, side = "home", domain = { rows: 5, cols: 5 }) {
  if (!grid) return null;
  const [a, b] = String(grid).split(":").map((n) => Number(n));
  if (!Number.isFinite(a) || !Number.isFinite(b)) return null;

  // поддерживаем и row:col, и col:row — выбираем более «узкую» ось за rows
  const rows = domain.rows || 5;
  const cols = domain.cols || 5;
  const asRowCol = { row: a, col: b };
  const asColRow = { row: b, col: a };
  const rc = Math.max(a, b) > rows ? asColRow : asRowCol;

  const padX = 6; // отступы от краёв
  const padY = 8;
  const stepX = (100 - padX * 2) / Math.max(1, (cols - 1));
  const stepY = (100 - padY * 2) / Math.max(1, (rows - 1));

  const xRaw = padX + (rc.col - 1) * stepX;
  const y = padY + (rc.row - 1) * stepY;
  const x = side === "home" ? xRaw : 100 - xRaw;
  return { x, y };
}

function PlayerPin({ p, side = "home" }) {
  const [err, setErr] = useState(false);
  const size = 40;
  const ring = side === "home" ? "ring-emerald-500/80 bg-emerald-50" : "ring-sky-500/80 bg-sky-50";

  const pid = p.player_id ?? p.id ?? p.photo_id;
  const imgSrc = pid ? `/icons/player_photos/${pid}.png` : "";
  const xy = p.x != null && p.y != null ? { x: p.x, y: p.y } : gridToXY(p.grid, side);

  if (!xy) return null;

  return (
    <div
      className="absolute"
      style={{ left: `${xy.x}%`, top: `${xy.y}%`, transform: "translate(-50%, -50%)" }}
      title={`${p.number ? "#" + p.number + " " : ""}${p.player_name || p.name || ""}${p.position ? " • " + p.position : ""}`}
    >
      <div className={`relative flex items-center justify-center rounded-full ring-2 ${ring}`} style={{ width: size, height: size }}>
        {!!imgSrc && !err ? (
          <img
            src={imgSrc}
            alt={p.player_name || p.name}
            className="w-full h-full rounded-full object-cover"
            onError={() => setErr(true)}
          />
        ) : (
          <div className="w-full h-full rounded-full flex items-center justify-center text-xs font-semibold text-gray-700">
            {p.number ? `#${p.number}` : initials(p.player_name || p.name)}
          </div>
        )}
      </div>
      {(p.player_name || p.name) && (
        <div className="mt-1 w-max px-2 py-0.5 rounded-full bg-white/80 backdrop-blur text-[10px] leading-none text-gray-700 shadow">
          {p.player_name || p.name}
        </div>
      )}
    </div>
  );
}

/** Красивое поле. homePlayers/awayPlayers: игроки с x/y или grid */
export default function FootballPitch({ homePlayers = [], awayPlayers = [], className = "", showGrid = false }) {
  return (
    <div className={`relative ${className}`}>
      <div className="relative w-full rounded-3xl overflow-hidden shadow" style={{ paddingBottom: "65%" }}>
        {/* фон со «стрижкой» */}
        <div
          className="absolute inset-0"
          style={{ background: "repeating-linear-gradient(90deg, #eef8ee 0 8%, #e6f3e6 8% 16%)" }}
        />

        {/* вспомогательная сетка (опция) */}
        {showGrid && (
          <svg className="absolute inset-0 w-full h-full">
            {[...Array(10)].map((_, i) => (
              <line key={`v${i}`} x1={`${(i + 1) * 10}%`} y1="0%" x2={`${(i + 1) * 10}%`} y2="100%" stroke="rgba(0,0,0,0.05)" strokeWidth="1" />
            ))}
            {[...Array(6)].map((_, i) => (
              <line key={`h${i}`} x1="0%" y1={`${(i + 1) * 14.285}%`} x2="100%" y2={`${(i + 1) * 14.285}%`} stroke="rgba(0,0,0,0.05)" strokeWidth="1" />
            ))}
          </svg>
        )}

        {/* разметка поля */}
        <svg className="absolute inset-0 w-full h-full">
          <rect x="2%" y="2%" width="96%" height="96%" fill="none" stroke="white" strokeWidth="3" />
          <line x1="50%" y1="2%" x2="50%" y2="98%" stroke="white" strokeWidth="2" />
          <circle cx="50%" cy="50%" r="9%" fill="none" stroke="white" strokeWidth="2" />
          <circle cx="50%" cy="50%" r="0.8%" fill="white" />
          {/* левая сторона */}
          <rect x="2%" y="20.355%" width="15.7%" height="59.29%" fill="none" stroke="white" strokeWidth="2" />
          <rect x="2%" y="36.53%" width="5.24%" height="26.94%" fill="none" stroke="white" strokeWidth="2" />
          <circle cx="12.5%" cy="50%" r="0.8%" fill="white" />
          <path d="M 20% 50% m 8.7% 0 a 8.7% 8.7% 0 1 0 0 -0.01" fill="none" stroke="white" strokeWidth="2" />
          {/* правая сторона */}
          <rect x="82.3%" y="20.355%" width="15.7%" height="59.29%" fill="none" stroke="white" strokeWidth="2" />
          <rect x="92.76%" y="36.53%" width="5.24%" height="26.94%" fill="none" stroke="white" strokeWidth="2" />
          <circle cx="87.5%" cy="50%" r="0.8%" fill="white" />
          <path d="M 80% 50% m -8.7% 0 a 8.7% 8.7% 0 1 1 0 -0.01" fill="none" stroke="white" strokeWidth="2" />
          {/* угловые дуги */}
          <path d="M2% 4.2% A 2.2% 2.2% 0 0 1 4.2% 2%" stroke="white" strokeWidth="2" fill="none" />
          <path d="M98% 4.2% A 2.2% 2.2% 0 0 0 95.8% 2%" stroke="white" strokeWidth="2" fill="none" />
          <path d="M2% 95.8% A 2.2% 2.2% 0 0 0 4.2% 98%" stroke="white" strokeWidth="2" fill="none" />
          <path d="M98% 95.8% A 2.2% 2.2% 0 0 1 95.8% 98%" stroke="white" strokeWidth="2" fill="none" />
        </svg>

        {/* игроки */}
        <div className="absolute inset-0">
          {homePlayers.map((p, i) => <PlayerPin key={`h-${p.player_id || p.id || i}`} p={p} side="home" />)}
          {awayPlayers.map((p, i) => <PlayerPin key={`a-${p.player_id || p.id || i}`} p={p} side="away" />)}
        </div>
      </div>
    </div>
  );
}
