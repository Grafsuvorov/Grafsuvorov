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
      <div className="relative h-[26px] w-[26px] overflow-visible rounded-full sm:h-[38px] sm:w-[38px]">
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
            "absolute top-[3px] flex flex-col gap-0.5 sm:top-[6px] sm:gap-1",
            side === "away" ? "-left-[11px] sm:-left-[16px]" : "-right-[11px] sm:-right-[16px]"
          )}
        >
          {goals > 0 && (
            <span className="inline-flex h-3 w-3 items-center justify-center rounded-[3px] bg-amber-500 text-[7px] font-semibold text-slate-950 sm:h-4 sm:w-4 sm:text-[9px]">
              ⚽
            </span>
          )}
          {assists > 0 && (
            <span className="inline-flex h-3 w-3 items-center justify-center rounded-[3px] bg-emerald-500 text-[7px] font-semibold text-white sm:h-4 sm:w-4 sm:text-[9px]">
              A
            </span>
          )}
          {yellow > 0 && (
            <span className="inline-flex h-3 w-3 items-center justify-center rounded-[3px] bg-yellow-400 text-transparent sm:h-4 sm:w-4">
              •
            </span>
          )}
          {red > 0 && (
            <span className="inline-flex h-3 w-3 items-center justify-center rounded-[3px] bg-red-500 text-transparent sm:h-4 sm:w-4">
              •
            </span>
          )}
          {hasSub && (
            <span className="inline-flex h-3 w-3 items-center justify-center rounded-[3px] bg-sky-500 text-[7px] leading-none text-white sm:h-4 sm:w-4 sm:text-[9px]">
              ↕
            </span>
          )}
        </div>

        {rating && ratingBadge && (
          <div
            className={clsx(
              "absolute left-0 top-0 z-30 h-[10px] min-w-[18px] -translate-x-[35%] -translate-y-[35%] rounded px-0.5 text-center text-[7px] font-bold leading-[10px] shadow-sm sm:h-[12px] sm:min-w-[22px] sm:px-1 sm:text-[8px] sm:leading-[12px]",
              ratingBadge
            )}
          >
            {rating}
          </div>
        )}

        {isMvp && (
          <div className="absolute -right-1 -top-1 h-[10px] w-[10px] rounded-full bg-sky-500 text-center text-[7px] leading-[10px] text-white sm:h-[12px] sm:w-[12px] sm:text-[9px] sm:leading-[12px]">
            ★
          </div>
        )}
      </div>

      <div
        className="mt-0.5 w-[58px] max-w-[58px] overflow-hidden text-ellipsis whitespace-nowrap rounded-md border border-white/10 bg-[#0a1223]/70 px-1 py-0.5 text-center text-[9px] font-medium tracking-[0.1px] text-white/90 backdrop-blur-sm sm:mt-1 sm:w-[100px] sm:max-w-[100px] sm:rounded-lg sm:px-2 sm:py-1 sm:text-[13px] sm:tracking-[0.2px]"
        title={fullName}
      >
        <span className="inline-flex h-[11px] min-w-[12px] items-center justify-center rounded bg-white/5 px-0.5 align-middle text-[8px] text-white/50 sm:h-[14px] sm:min-w-[16px] sm:rounded-md sm:px-1 sm:text-[11px]">
          {number}
        </span>{" "}
        <span>{shortName}</span>
      </div>
    </div>
  );
}
