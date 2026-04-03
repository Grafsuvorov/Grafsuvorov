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

const lower = (v) => (v == null ? "" : String(v).toLowerCase());

function eventKind(ev) {
  const t = lower(ev?.type);
  const d = lower(ev?.detail);
  if (t.includes("goal") && !d.includes("cancel")) return d === "own goal" ? "own_goal" : "goal";
  if (d.includes("cancel")) return "goal_cancelled";
  if (d === "missed penalty") return "pen_missed";
  if (d === "yellow card") return "yellow";
  if (d === "red card") return "red";
  if (t.startsWith("subst")) return "sub";
  if (d.includes("var")) return "var";
  return "other";
}

function minuteStr(ev) {
  const m = Number(ev?.minute ?? ev?.elapsed ?? null);
  const x = Number(ev?.extra ?? 0);
  if (!Number.isFinite(m)) return "—";
  if (x > 0) return `${m}+${x}'`;
  return `${m}'`;
}

function EventIcon({ kind }) {
  switch (kind) {
    case "goal":
      return "⚽";
    case "own_goal":
      return "🆚";
    case "goal_cancelled":
      return "🚫";
    case "pen_missed":
      return "⛔";
    case "yellow":
      return "🟨";
    case "red":
      return "🟥";
    case "sub":
      return "🔁";
    case "var":
      return "🎥";
    default:
      return "•";
  }
}

function PlayerBadges({ meta }) {
  if (!meta) return null;
  const left = [];
  const right = [];
  if (meta.goals) left.push({ k: "g", v: meta.goals, icon: "⚽" });
  if (meta.assists) left.push({ k: "a", v: meta.assists, icon: "🅰" });
  if (meta.yellow) right.push({ k: "y", v: meta.yellow, icon: "🟨" });
  if (meta.red) right.push({ k: "r", v: meta.red, icon: "🟥" });
  if (meta.subInMin != null) right.push({ k: "in", v: `${meta.subInMin}'`, icon: "↗" });
  if (meta.subOutMin != null) right.push({ k: "out", v: `${meta.subOutMin}'`, icon: "↘" });

  if (!left.length && !right.length) return null;
  return (
    <div className="flex items-center gap-2 text-[11px] text-white/70">
      {left.length ? (
        <div className="flex items-center gap-2">
          {left.map((b) => (
            <span key={b.k} className="inline-flex items-center gap-1">
              <span>{b.icon}</span>
              <span className="tabular-nums">{b.v}</span>
            </span>
          ))}
        </div>
      ) : null}
      {right.length ? (
        <div className="flex items-center gap-2 ml-auto">
          {right.map((b) => (
            <span key={b.k} className="inline-flex items-center gap-1">
              <span>{b.icon}</span>
              <span className="tabular-nums">{b.v}</span>
            </span>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function playerLabel(player) {
  return player?.name || player?.player_name || "—";
}

function EventPlayerName({ playerId, label, onPlayer, player }) {
  if (!label || label === "—") return <span>{label}</span>;
  if (!playerId || !onPlayer) return <span>{label}</span>;
  return (
    <button
      type="button"
      onClick={() =>
        onPlayer(player || { player_id: playerId, player_name: label, name: label })
      }
      className="truncate text-inherit transition hover:text-cyan-300"
    >
      {label}
    </button>
  );
}

function PlayerListRow({ player, onPlayer, align = "left" }) {
  if (!player) return null;
  const meta = player._meta || null;
  const label = playerLabel(player);
  const isRight = align === "right";

  return (
    <button
      type="button"
      onClick={() => onPlayer?.(player)}
      className={`flex w-full items-start justify-between gap-3 rounded-xl px-1 py-1 transition hover:bg-white/5 ${
        isRight ? "text-right" : "text-left"
      }`}
    >
      <div className={`min-w-0 text-sm text-white/88 ${isRight ? "order-2" : ""}`}>
        <span className="block truncate">{label}</span>
      </div>
      <div className={`shrink-0 ${isRight ? "order-1" : ""}`}>
        <PlayerBadges meta={meta} />
      </div>
    </button>
  );
}

/* ===============================
   MAIN
=============================== */
export default function LineupsTab({ data, loading, match, onPlayer }) {
  const norm = normalizeLineups(data, match);
  const metaMaps = buildMetaMaps(norm?.events || []);

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

  const homeSubs = (norm?.home?.bench || []).map((p) => ({
    ...p,
    _meta: metaMaps.get?.(norm?.home?.team_id)?.get?.(p.player_id),
  }));
  const awaySubs = (norm?.away?.bench || []).map((p) => ({
    ...p,
    _meta: metaMaps.get?.(norm?.away?.team_id)?.get?.(p.player_id),
  }));

  const events = Array.isArray(norm?.events) ? norm.events : [];
  const mergedEvents = [...events].sort(
    (a, b) =>
      Number(a.minute ?? a.elapsed ?? 0) - Number(b.minute ?? b.elapsed ?? 0)
  );

  return (
    <div className="w-full space-y-8 bg-surface-2/40 border border-glass rounded-3xl p-5 shadow-[0_0_35px_rgba(0,0,0,0.35)]">

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
      <div className="grid md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <div className="text-xs uppercase text-slate-400 mb-2">
            Запас • {norm?.home?.team_name}
          </div>

          <div className="space-y-1">
            {homeSubs.length ? homeSubs.map((p) => (
              <PlayerListRow key={p.player_id} player={p} onPlayer={onPlayer} />
            )) : (
              <div className="text-sm text-white/45">—</div>
            )}
          </div>
        </div>

        <div className="space-y-2">
          <div className="text-xs uppercase text-slate-400 mb-2 text-right pr-1">
            Запас • {norm?.away?.team_name}
          </div>

          <div className="space-y-1">
            {awaySubs.length ? awaySubs.map((p) => (
              <PlayerListRow key={p.player_id} player={p} onPlayer={onPlayer} align="right" />
            )) : (
              <div className="text-sm text-white/45">—</div>
            )}
          </div>
        </div>
      </div>

      {/* Shared events */}
      <div className="space-y-2">
        <div className="text-xs uppercase text-slate-400 mb-1">
          События матча
        </div>
        {mergedEvents.length ? (
          <div className="space-y-2">
            {mergedEvents.map((e, i) => {
              const kind = eventKind(e);
              const teamSide =
                e.team_id === norm?.home?.team_id
                  ? "Дома"
                  : e.team_id === norm?.away?.team_id
                    ? "Гости"
                    : "";
              const isHomeEvent = e.team_id === norm?.home?.team_id;
              return (
                <div
                  key={`ev-${i}`}
                  className={`grid items-start gap-3 rounded-2xl px-3 py-3 text-sm transition hover:bg-white/[0.04] ${
                    isHomeEvent
                      ? "grid-cols-[56px_28px_minmax(0,1fr)]"
                      : "grid-cols-[minmax(0,1fr)_28px_56px]"
                  }`}
                >
                  {isHomeEvent ? (
                    <div className="pt-0.5 text-white/50 tabular-nums">
                      {minuteStr(e)}
                    </div>
                  ) : (
                    <div className="min-w-0 text-right text-white/85">
                      <div className="min-w-0">
                        {teamSide ? (
                          <div className="mb-0.5 text-[10px] uppercase tracking-[0.14em] text-white/35">
                            {teamSide}
                          </div>
                        ) : null}
                        <div className="font-medium">
                          <EventPlayerName
                            playerId={e.player_id}
                            label={e.player_name || "—"}
                            onPlayer={onPlayer}
                            player={e}
                          />
                          {e.assist_name ? (
                            <span className="text-white/50"> (ассист {e.assist_name})</span>
                          ) : null}
                        </div>
                      </div>
                      <div className="mt-1 text-white/60">
                        {e.detail || e.type || ""}
                      </div>
                    </div>
                  )}
                  <div className="pt-0.5 text-center text-white/70">
                    <EventIcon kind={kind} />
                  </div>
                  {isHomeEvent ? (
                    <div className="min-w-0 text-white/85">
                      <div className="min-w-0">
                        {teamSide ? (
                          <div className="mb-0.5 text-[10px] uppercase tracking-[0.14em] text-white/35">
                            {teamSide}
                          </div>
                        ) : null}
                        <div className="font-medium">
                          <EventPlayerName
                            playerId={e.player_id}
                            label={e.player_name || "—"}
                            onPlayer={onPlayer}
                            player={e}
                          />
                          {e.assist_name ? (
                            <span className="text-white/50"> (ассист {e.assist_name})</span>
                          ) : null}
                        </div>
                      </div>
                      <div className="mt-1 text-white/60">
                        {e.detail || e.type || ""}
                      </div>
                    </div>
                  ) : (
                    <div className="pt-0.5 text-right text-white/50 tabular-nums">
                      {minuteStr(e)}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        ) : (
          <div className="text-xs text-muted">—</div>
        )}
      </div>
    </div>
  );
}
