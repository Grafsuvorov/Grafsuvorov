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
      className="relative w-full rounded-xl overflow-hidden border border-white/15 shadow-[inset_0_0_60px_rgba(0,0,0,0.5),0_0_20px_rgba(0,0,0,0.4)]"
      style={{ paddingBottom: "66%", marginTop: 12, marginBottom: 16 }}
      onMouseDown={(e) => e.stopPropagation()}
    >
      {/* PREMIUM DARK FIELD */}
      <div
        className="absolute inset-0 bg-[radial-gradient(circle_at_center,#0e1a2a_0%,#08111f_100%)]"
      />

      {/* clean white field lines */}
      <svg className="absolute inset-0 w-full h-full" aria-hidden>
        <rect x="2%" y="2%" width="96%" height="96%" stroke="rgba(255,255,255,0.15)" strokeWidth="1.2" fill="none"/>
        <line x1="50%" y1="2%" x2="50%" y2="98%" stroke="rgba(255,255,255,0.15)" strokeWidth="1.1" />
        <circle cx="50%" cy="50%" r="10%" stroke="rgba(255,255,255,0.15)" fill="none" strokeWidth="1.1"/>
        <circle cx="50%" cy="50%" r="1%" fill="rgba(255,255,255,0.25)" />

        {/* penalty areas */}
        <rect x="2%" y="22%" width="14%" height="56%" stroke="rgba(255,255,255,0.15)" fill="none" strokeWidth="1.1"/>
        <rect x="84%" y="22%" width="14%" height="56%" stroke="rgba(255,255,255,0.15)" fill="none" strokeWidth="1.1"/>

        {/* goalie box */}
        <rect x="2%" y="36%" width="5%" height="28%" stroke="rgba(255,255,255,0.15)" fill="none" strokeWidth="1.1"/>
        <rect x="93%" y="36%" width="5%" height="28%" stroke="rgba(255,255,255,0.15)" fill="none" strokeWidth="1.1"/>
      </svg>

      {/* HOME */}
      {homePlayers.map((p) => (
        <PlayerPin
          key={"h-"+p.player_id}
          player={{ ...p, mvp: mvpId != null && p.player_id === mvpId }}
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
          player={{ ...p, mvp: mvpId != null && p.player_id === mvpId }}
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
