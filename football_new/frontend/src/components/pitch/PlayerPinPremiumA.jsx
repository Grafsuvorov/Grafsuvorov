import React from "react";
import clsx from "clsx";

export default function PlayerPinPremiumA({ player, side, meta, onClick }) {
  const rating = meta?.rating || player.rating;
  const events = meta?.events || [];

  return (
    <div
      className="absolute flex flex-col items-center justify-center cursor-pointer select-none"
      style={{
        left: `${player.x}%`,
        top: `${player.y}%`,
        transform: "translate(-50%, -50%)",
      }}
      onClick={() => onClick?.(player)}
    >
      {/* PHOTO + GLOW */}
      <div
        className={clsx(
          "relative w-[48px] h-[48px] rounded-full overflow-hidden shadow-xl",
          side === "home"
            ? "ring-2 ring-teal-400 shadow-[0_0_12px_rgba(34,211,238,0.55)]"
            : "ring-2 ring-purple-400 shadow-[0_0_12px_rgba(168,85,247,0.55)]"
        )}
      >
        <img
          src={`/icons/player_photos/${player.player_id}.png`}
          alt=""
          className="w-full h-full object-cover"
        />
      </div>

      {/* RATING */}
      {rating && (
        <div
          className={clsx(
            "mt-1 px-2 py-[2px] text-[11px] rounded-full font-semibold text-white",
            rating >= 7 ? "bg-emerald-600/80" : rating >= 6 ? "bg-yellow-500/80" : "bg-rose-600/80"
          )}
        >
          {rating}
        </div>
      )}

      {/* EVENTS */}
      <div className="flex gap-1 mt-1">
        {events.includes("goal") && (
          <div className="text-[12px] px-1.5 py-[1px] rounded bg-amber-500/90 shadow-md">⚽</div>
        )}
        {events.includes("yellow") && (
          <div className="text-[12px] px-1 py-[1px] rounded bg-yellow-400/90 shadow-md">🟨</div>
        )}
        {events.includes("red") && (
          <div className="text-[12px] px-1 py-[1px] rounded bg-red-500/90 shadow-md">🟥</div>
        )}
        {events.includes("sub") && (
          <div className="text-[12px] px-1 py-[1px] rounded bg-blue-500/90 shadow-md">↕</div>
        )}
      </div>
    </div>
  );
}
