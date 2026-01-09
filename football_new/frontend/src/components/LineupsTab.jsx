import React, { useEffect } from "react";
import FootballPitchPro from "@/components/FootballPitchPro";
import {
  normalizeLineups,
  autoLayout,
  layoutFromGrid,
  buildMetaMaps,
} from "@/lib/lineupsLayout";

const ric =
  typeof window !== "undefined" && window.requestIdleCallback
    ? window.requestIdleCallback
    : (cb) => setTimeout(() => cb({ didTimeout: false, timeRemaining: () => 0 }), 200);

function prefetchImage(src) {
  if (!src) return;
  const img = new Image();
  img.decoding = "async";
  img.loading = "eager";
  img.src = src;
}

/* ===============================
   Premium Chip for Player Names
=============================== */
function PlayerChip({ player }) {
  if (!player) return null;
  const src = player.player_id
    ? `/icons/player_photos/${player.player_id}.png`
    : null;

  return (
    <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-surface-2/70 border border-glass shadow-[0_0_20px_rgba(0,0,0,0.35)] hover:bg-surface-2/90 transition">
      <div className="h-7 w-7 rounded-full overflow-hidden ring-2 ring-accent/60">
        {src ? (
          <img src={src} className="h-full w-full object-cover" />
        ) : (
          <div className="h-full w-full bg-slate-700" />
        )}
      </div>
      <span className="text-sm text-white truncate max-w-[160px]">
        {player.name || player.player_name}
      </span>
    </div>
  );
}

/* ===============================
   Premium Substitution Row
=============================== */
function SubRow({ s, home }) {
  const inSrc = s.in_id ? `/icons/player_photos/${s.in_id}.png` : null;
  const outSrc = s.out_id ? `/icons/player_photos/${s.out_id}.png` : null;

  return (
    <div className="grid grid-cols-[1fr_50px_1fr] items-center gap-3 px-3 py-2 rounded-xl bg-surface-1/60 border border-glass shadow-inner">
      <div className="flex items-center gap-2">
        <div className="h-6 w-6 rounded-full overflow-hidden ring-2 ring-emerald-400/70">
          {inSrc ? <img src={inSrc} /> : null}
        </div>
        <span className="text-[13px] text-emerald-300 font-semibold truncate">
          {s.in_name}
        </span>
      </div>

      <div className="flex justify-center text-[11px] text-muted">
        {s.minute}'
      </div>

      <div className="flex items-center gap-2 justify-end">
        <span className="text-[13px] text-rose-300 font-semibold truncate">
          {s.out_name}
        </span>
        <div className="h-6 w-6 rounded-full overflow-hidden ring-2 ring-rose-400/70">
          {outSrc ? <img src={outSrc} /> : null}
        </div>
      </div>
    </div>
  );
}

/* ===============================
   MAIN
=============================== */
export default function LineupsTab({ data, loading, match, onPlayer }) {
  const norm = normalizeLineups(data, match);
  const metaMaps = buildMetaMaps(norm);

  const homePins =
    (norm?.home?.starters?.length &&
      (layoutFromGrid(norm.home.starters, "home", norm.home.formation).length
        ? layoutFromGrid(norm.home.starters, "home", norm.home.formation)
        : autoLayout(norm.home.formation, norm.home.starters, "home"))) || [];

  const awayPins =
    (norm?.away?.starters?.length &&
      (layoutFromGrid(norm.away.starters, "away", norm.away.formation).length
        ? layoutFromGrid(norm.away.starters, "away", norm.away.formation)
        : autoLayout(norm.away.formation, norm.away.starters, "away"))) || [];

  // preload photos
  useEffect(() => {
    const photos = [...(norm?.home?.starters || []), ...(norm?.away?.starters || [])]
      .slice(0, 40)
      .map((p) => p?.player_id && `/icons/player_photos/${p.player_id}.png`)
      .filter(Boolean);

    ric(() => photos.forEach(prefetchImage));
  }, [norm]);

  if (loading) return <div className="py-6 text-muted">Загружаем составы…</div>;

  const homeSubs = norm?.home?.bench || [];
  const awaySubs = norm?.away?.bench || [];

  const homeTeamSubs = norm?.subs?.filter((s) => s.team_id === norm.home.team_id) || [];
  const awayTeamSubs = norm?.subs?.filter((s) => s.team_id === norm.away.team_id) || [];

  return (
    <div className="mt-6 space-y-8 bg-surface-2/40 border border-glass rounded-3xl p-5 shadow-[0_0_35px_rgba(0,0,0,0.35)]">

      {/* Header */}
      <div className="flex justify-between items-center px-2">
        <div className="text-slate-200 text-sm">
          <span className="font-semibold text-white">{norm?.home?.team_name}</span>
          <span className="text-slate-400"> • {norm?.home?.formation}</span>
        </div>

        <div className="text-accent text-[11px] uppercase tracking-[0.15em]">
          Стартовые составы
        </div>

        <div className="text-slate-200 text-sm text-right">
          <span className="font-semibold text-white">{norm?.away?.team_name}</span>
          <span className="text-slate-400"> • {norm?.away?.formation}</span>
        </div>
      </div>

      {/* Pitch */}
      <FootballPitchPro
        homePlayers={homePins}
        awayPlayers={awayPins}
        homeMeta={metaMaps.get?.(norm?.home?.team_id)}
        awayMeta={metaMaps.get?.(norm?.away?.team_id)}
        onPlayer={onPlayer}
      />

      {/* Bench sections */}
      <div className="grid md:grid-cols-2 gap-4">
        <div className="bg-surface-1/70 p-4 rounded-2xl border border-glass shadow-inner space-y-2">
          <div className="text-xs uppercase text-slate-400 mb-2">
            Запас • {norm?.home?.team_name}
          </div>

          <div className="flex flex-wrap gap-2">
            {homeSubs.map((p) => (
              <PlayerChip key={p.player_id} player={p} />
            ))}
          </div>
        </div>

        <div className="bg-surface-1/70 p-4 rounded-2xl border border-glass shadow-inner space-y-2">
          <div className="text-xs uppercase text-slate-400 mb-2">
            Запас • {norm?.away?.team_name}
          </div>

          <div className="flex flex-wrap gap-2">
            {awaySubs.map((p) => (
              <PlayerChip key={p.player_id} player={p} />
            ))}
          </div>
        </div>
      </div>

      {/* Substitutions */}
      <div className="grid md:grid-cols-2 gap-4">
        <div className="space-y-2">
          <div className="text-xs uppercase text-slate-400 mb-1">
            Замены • {norm?.home?.team_name}
          </div>
          {homeTeamSubs.length ? (
            homeTeamSubs.map((s, i) => (
              <SubRow key={i} s={s} home />
            ))
          ) : (
            <div className="text-xs text-muted">—</div>
          )}
        </div>

        <div className="space-y-2">
          <div className="text-xs uppercase text-slate-400 mb-1">
            Замены • {norm?.away?.team_name}
          </div>
          {awayTeamSubs.length ? (
            awayTeamSubs.map((s, i) => <SubRow key={i} s={s} />)
          ) : (
            <div className="text-xs text-muted">—</div>
          )}
        </div>
      </div>
    </div>
  );
}
