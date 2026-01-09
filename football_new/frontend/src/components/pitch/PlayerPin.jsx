import React from "react";
import clsx from "clsx";

/* ============================
   NATURAL GLOW TOKENS
============================ */

const baseRing =
  "rounded-full shadow-[0_0_12px_rgba(255,255,255,0.35)] border border-white/20";

const numberBadge =
  "absolute -bottom-1 left-1/2 -translate-x-1/2 px-1.5 py-[1px] rounded-md text-[11px] font-semibold shadow-[0_2px_6px_rgba(0,0,0,0.35)]";

const eventBadge =
  "absolute -top-1 -right-1 w-4 h-4 rounded-full flex items-center justify-center text-[10px] font-bold shadow-[0_2px_5px_rgba(0,0,0,0.45)]";

/* colors */
const glowHome = "shadow-[0_0_18px_rgba(126,255,240,0.55)]";
const glowAway = "shadow-[0_0_18px_rgba(169,126,255,0.55)]";

export default function PlayerPin({
  player,
  side,
  meta,
  isMVP = false,
  onClick,
}) {
  const photo = player.player_photo || `/icons/player_photos/${player.player_id}.png`;

  return (
    <div
      className="absolute flex flex-col items-center cursor-pointer select-none"
      style={{
        left: `${player.x}%`,
        top: `${player.y}%`,
      }}
      onClick={() => onClick?.(player)}
    >
      {/* фото с натуральным glow */}
      <div
        className={clsx(
          "relative w-[44px] h-[44px] rounded-full overflow-hidden bg-black/10",
          baseRing,
          side === "home" ? glowHome : glowAway,
          isMVP && "ring-2 ring-amber-300 shadow-[0_0_18px_rgba(255,219,88,0.7)]"
        )}
      >
        <img
          src={photo}
          alt=""
          className="w-full h-full object-cover"
          onError={(e) => (e.currentTarget.style.display = "none")}
        />
      </div>

      {/* рейтинг */}
      {meta?.rating && (
        <div
          className={clsx(
            numberBadge,
            "bg-slate-900/70 text-white backdrop-blur-sm border border-white/10"
          )}
        >
          {meta.rating}
        </div>
      )}

      {/* события */}
      {meta?.event === "goal" && (
        <div className={clsx(eventBadge, "bg-emerald-400 text-white")}>?</div>
      )}

      {meta?.event === "yellow" && (
        <div className={clsx(eventBadge, "bg-yellow-400")} />
      )}

      {meta?.event === "red" && (
        <div className={clsx(eventBadge, "bg-red-500")} />
      )}

      {meta?.event === "sub" && (
        <div className={clsx(eventBadge, "bg-blue-400 text-white")}>?</div>
      )}
    </div>
  );
}
