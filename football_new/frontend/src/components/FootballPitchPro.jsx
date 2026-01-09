// src/components/FootballPitchPro.jsx
import React from "react";
import PlayerPin from "./pitch/PlayerPinPremiumA";

export default function FootballPitchPro({
  homePlayers = [],
  awayPlayers = [],
  homeMeta,
  awayMeta,
  mvpId,
  onOpenCard,
  onPlayer,
}) {
  return (
    <div
      className="relative w-full rounded-3xl overflow-hidden shadow-[0_0_40px_rgba(0,0,0,0.55)]"
      style={{ paddingBottom: "68%" }}
      onMouseDown={(e) => e.stopPropagation()}
    >
      {/* PREMIUM DARK FIELD */}
      <div
        className="absolute inset-0 bg-gradient-to-b from-[#0a1a27] via-[#0d2230] to-[#0a1a27]"
      />

      {/* clean white field lines */}
      <svg className="absolute inset-0 w-full h-full" aria-hidden>
        <rect x="2%" y="2%" width="96%" height="96%" stroke="white" strokeWidth="2.4" fill="none"/>
        <line x1="50%" y1="2%" x2="50%" y2="98%" stroke="white" strokeWidth="2.2" />
        <circle cx="50%" cy="50%" r="10%" stroke="white" fill="none" strokeWidth="2"/>
        <circle cx="50%" cy="50%" r="1%" fill="white" />

        {/* penalty areas */}
        <rect x="2%" y="22%" width="14%" height="56%" stroke="white" fill="none" strokeWidth="2"/>
        <rect x="84%" y="22%" width="14%" height="56%" stroke="white" fill="none" strokeWidth="2"/>

        {/* goalie box */}
        <rect x="2%" y="36%" width="5%" height="28%" stroke="white" fill="none" strokeWidth="2"/>
        <rect x="95%" y="36%" width="3%" height="28%" stroke="white" fill="none" strokeWidth="2"/>
      </svg>

      {/* HOME */}
      {homePlayers.map((p) => (
        <PlayerPin
          key={"h-"+p.player_id}
          player={p}
          side="home"
          meta={homeMeta?.get?.(p.player_id)}
          onClick={(pl) => {
            onPlayer?.(pl);
            onOpenCard?.({ side: "home", player: pl, meta: homeMeta?.get?.(pl.player_id) });
          }}
        />
      ))}

      {/* AWAY */}
      {awayPlayers.map((p) => (
        <PlayerPin
          key={"a-"+p.player_id}
          player={p}
          side="away"
          meta={awayMeta?.get?.(p.player_id)}
          onClick={(pl) => {
            onPlayer?.(pl);
            onOpenCard?.({ side: "away", player: pl, meta: awayMeta?.get?.(pl.player_id) });
          }}
        />
      ))}

    </div>
  );
}
