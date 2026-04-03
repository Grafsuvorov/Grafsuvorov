import React from "react";
import clsx from "clsx";

function CountBadge({ icon, count, className = "" }) {
  if (!count || count <= 0) return null;
  return (
    <span className={clsx("relative inline-flex h-[12px] min-w-[12px] items-center justify-center rounded-[3px] text-[8px] leading-none", className)}>
      {icon}
      {count > 1 && (
        <span className="absolute -right-[5px] -top-[5px] inline-flex h-[9px] min-w-[9px] items-center justify-center rounded-full bg-slate-950 text-[7px] font-semibold text-white border border-white/20 px-[2px]">
          {count}
        </span>
      )}
    </span>
  );
}

export default function PlayerPinPremiumA({ player, side, meta, onClick }) {
  const rating = meta?.rating || player.rating;
  const isMvp = Boolean(meta?.is_mvp || player?.is_mvp || player?.mvp);
  const ratingNum = Number(rating);
  const goals = Number(meta?.goals || 0);
  const assists = Number(meta?.assists || 0);
  const yellow = Number(meta?.yellow || 0);
  const red = Number(meta?.red || 0);
  const hasSub = meta?.subInMin != null || meta?.subOutMin != null;
  const fullName = player?.name || player?.player_name || "Игрок";
  const shortName = (() => {
    const base = fullName.trim();
    if (!base) return "Игрок";
    const last = base.split(" ").slice(-1)[0] || base;
    return last.length > 12 ? `${last.slice(0, 11)}…` : last;
  })();
  const number = player?.number ?? "?";
  const fallbackPhoto = player?.player_id
    ? `https://media.api-sports.io/football/players/${player.player_id}.png`
    : "/icons/player_photos/default.png";

  const ratingBadge = (() => {
    if (!Number.isFinite(ratingNum)) return null;
    if (isMvp) return "bg-sky-500 text-white";
    if (ratingNum >= 7.5) return "bg-emerald-500 text-white";
    if (ratingNum >= 7.0) return "bg-lime-500 text-slate-950";
    if (ratingNum >= 6.5) return "bg-amber-500 text-slate-950";
    return "bg-rose-500 text-white";
  })();

  return (
    <div
      className="absolute flex flex-col items-center justify-center cursor-pointer select-none"
      style={{
        left: `${player.x}%`,
        top: `${player.y}%`,
        transform: `translate(-50%, -50%) translate(${player._dx || 0}px, ${player._dy || 0}px) translate(${side === "away" ? 4 : 0}px, 0px)`,
      }}
      onClick={() => onClick?.(player)}
    >
      <div className="relative w-[38px] h-[38px] rounded-full overflow-visible">
        <div className="w-full h-full rounded-full overflow-hidden bg-[#0a1a27] transition-shadow duration-200 hover:shadow-[0_0_12px_rgba(168,85,247,0.25)]">
          <img
            src={`/icons/player_photos/${player.player_id}.png`}
            alt=""
            className="w-full h-full object-cover scale-[1.06]"
            onError={(e) => {
              if (e.currentTarget.src !== fallbackPhoto) {
                e.currentTarget.src = fallbackPhoto;
                return;
              }
              e.currentTarget.onerror = null;
              e.currentTarget.src = "/icons/player_photos/default.png";
            }}
          />
        </div>

        <div
          className={clsx(
            "absolute top-[6px] flex flex-col gap-1",
            side === "away" ? "-left-[16px]" : "-right-[16px]"
          )}
        >
          {goals > 0 && (
            <span className="inline-flex h-4 w-4 items-center justify-center rounded-[3px] bg-amber-500 text-[9px] font-semibold text-slate-950">
              ⚽
            </span>
          )}
          {assists > 0 && (
            <span className="inline-flex h-4 w-4 items-center justify-center rounded-[3px] bg-emerald-500 text-[9px] font-semibold text-white">
              A
            </span>
          )}
          {yellow > 0 && (
            <span className="inline-flex h-4 w-4 items-center justify-center rounded-[3px] bg-yellow-400 text-transparent">
              •
            </span>
          )}
          {red > 0 && (
            <span className="inline-flex h-4 w-4 items-center justify-center rounded-[3px] bg-red-500 text-transparent">
              •
            </span>
          )}
          {hasSub && (
            <span className="inline-flex h-4 w-4 items-center justify-center rounded-[3px] bg-sky-500 text-[9px] leading-none text-white">
              ↕
            </span>
          )}
        </div>

        {rating && ratingBadge && (
          <div
            className={clsx(
              "absolute left-0 top-0 -translate-x-[35%] -translate-y-[35%] min-w-[22px] h-[12px] px-1 rounded text-[8px] font-bold leading-[12px] text-center shadow-sm z-30",
              ratingBadge
            )}
          >
            {rating}
          </div>
        )}

        {isMvp && (
          <div className="absolute -right-1 -top-1 h-[12px] w-[12px] rounded-full bg-sky-500 text-white text-[9px] leading-[12px] text-center">
            ★
          </div>
        )}
      </div>

      <div
        className="mt-1 w-[100px] max-w-[100px] rounded-lg bg-[#0a1223]/70 backdrop-blur-sm px-2 py-1 text-center text-[13px] font-medium text-white/90 border border-white/10 whitespace-nowrap overflow-hidden text-ellipsis tracking-[0.2px]"
        title={fullName}
      >
        <span className="inline-flex items-center justify-center h-[14px] min-w-[16px] px-1 rounded-md bg-white/5 text-[11px] text-white/50 align-middle">
          {number}
        </span>{" "}
        <span>{shortName}</span>
      </div>
    </div>
  );
}
