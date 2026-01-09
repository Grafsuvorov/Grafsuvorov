// src/components/PlayerCard.jsx
import React, { useEffect, useRef, useState } from "react";
import { ratingClasses } from "@/lib/ratingColor";

const pickStat = (obj, keys) => {
  for (const k of keys) if (obj && Object.prototype.hasOwnProperty.call(obj, k)) return obj[k];
  return null;
};
const num0 = (v) => (v == null || v === "" || Number.isNaN(Number(v)) ? 0 : Number(v));
const pct0 = (v) => {
  if (v == null || v === "" || Number.isNaN(Number(v))) return "0%";
  const n = Number(v);
  return `${Math.round(n <= 1 ? n * 100 : n)}%`;
};
const xg0 = (v) => (v == null || v === "" || Number.isNaN(Number(v)) ? "0.00" : Number(v).toFixed(2));

export default function PlayerCard({ visible, player, meta, side, onClose, isMVP }) {
  const scrollRef = useRef(null);
  const [compact, setCompact] = useState(false);

  useEffect(() => {
    const onKey = (e) => e.key === "Escape" && onClose?.();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    const onScroll = () => setCompact(el.scrollTop > 24);
    el.addEventListener("scroll", onScroll, { passive: true });
    return () => el.removeEventListener("scroll", onScroll);
  }, []);

  if (!visible || !player) return null;

  const pid = player?.player_id || player?.id;
  const photo = pid ? `/icons/player_photos/${pid}.png` : "";
  const name = player?.name || player?.player_name || "";
  const ratingNum = Number(player?.rating);
  const rateCls = ratingClasses(ratingNum, isMVP);

  const S = {
    shots_total: num0(pickStat(player, ["shots_total", "shots", "shotsTotal"])),
    shots_on: num0(pickStat(player, ["shots_on", "shots_on_target", "shotsOn"])),
    shots_off: num0(pickStat(player, ["shots_off", "shots_off_target", "shotsOff"])),
    shots_blocked: num0(pickStat(player, ["shots_blocked", "shotsBlocked"])),
    goals: num0(pickStat(player, ["goals", "goal"])) || num0(meta?.goals),
    assists: num0(pickStat(player, ["assists", "assist"])) || num0(meta?.assists),
    xg: xg0(pickStat(player, ["xg", "expected_goals", "expectedGoals"])),

    passes_total: num0(pickStat(player, ["passes_total", "passes", "passesTotal"])),
    passes_accuracy: pct0(pickStat(player, ["passes_accuracy", "pass_accuracy", "passesAccuracy"])),
    key_passes: num0(pickStat(player, ["key_passes", "keyPasses"])),
    crosses_total: num0(pickStat(player, ["crosses_total", "crosses", "crossesTotal"])),
    crosses_accuracy: pct0(pickStat(player, ["crosses_accuracy", "crossesAccuracy"])),
    long_total: num0(pickStat(player, ["long_balls_total", "long_passes_total", "longTotal"])),
    long_accuracy: pct0(pickStat(player, ["long_balls_accuracy", "long_passes_accuracy", "longAccuracy"])),
    through_balls: num0(pickStat(player, ["through_balls", "throughBalls"])),

    drib_attempts: num0(pickStat(player, ["dribbles_attempts", "dribblesAttempts"])),
    drib_success: num0(pickStat(player, ["dribbles_success", "dribblesSuccess"])),
    duels_total: num0(pickStat(player, ["duels_total", "duelsTotal"])),
    duels_won: num0(pickStat(player, ["duels_won", "duelsWon"])),
    aerials_total: num0(pickStat(player, ["aerials_total", "aerialsTotal"])),
    aerials_won: num0(pickStat(player, ["aerials_won", "aerialsWon"])),
    touches: num0(pickStat(player, ["touches"])),

    tackles: num0(pickStat(player, ["tackles"])),
    interceptions: num0(pickStat(player, ["interceptions"])),
    clearances: num0(pickStat(player, ["clearances"])),
    blocks: num0(pickStat(player, ["blocks", "shots_blocked_def", "defBlocks"])),

    fouls_committed: num0(pickStat(player, ["fouls_committed", "foulsCommitted"])),
    fouls_drawn: num0(pickStat(player, ["fouls_drawn", "foulsDrawn"])),
    offsides: num0(pickStat(player, ["offsides"])),
    yellow: num0(pickStat(player, ["cards_yellow", "yellow_cards", "yellow"])) || num0(meta?.yellow),
    red: num0(pickStat(player, ["cards_red", "red_cards", "red"])) || num0(meta?.red),

    saves: num0(pickStat(player, ["saves", "goalkeeper_saves"])),
    conceded: num0(pickStat(player, ["conceded", "goals_conceded"])),

    minutes: num0(pickStat(player, ["minutes", "mins", "time_played"])) || num0(player?.minutes),
    subIn: num0(meta?.subInMin),
    subOut: num0(meta?.subOutMin),
  };

  const Section = ({ title, rows }) => (
    <div className="rounded-xl border bg-white shadow-sm">
      <div className="px-3 py-2 text-xs font-semibold text-gray-700 border-b">{title}</div>
      <div className="p-3 grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
        {rows.map((r, i) => (
          <div key={i} className="flex items-center justify-between">
            <span className="text-gray-600">{r.label}</span>
            <span className="font-semibold tabular-nums">{r.value}</span>
          </div>
        ))}
      </div>
    </div>
  );

  const sections = [
    { title: "Атака", rows: [
      { label: "Удары (всего)", value: S.shots_total },
      { label: "В створ", value: S.shots_on },
      { label: "Мимо", value: S.shots_off },
      { label: "Блокировано", value: S.shots_blocked },
      { label: "Голы", value: S.goals },
      { label: "Ассисты", value: S.assists },
      { label: "xG", value: S.xg },
    ]},
    { title: "Пасы", rows: [
      { label: "Пасы (всего)", value: S.passes_total },
      { label: "Точность пасов", value: S.passes_accuracy },
      { label: "Ключевые пасы", value: S.key_passes },
      { label: "Навесы (всего)", value: S.crosses_total },
      { label: "Точность навесов", value: S.crosses_accuracy },
      { label: "Длинные (всего)", value: S.long_total },
      { label: "Точность длинных", value: S.long_accuracy },
      { label: "Разрезающие", value: S.through_balls },
    ]},
    { title: "Дриблинг и единоборства", rows: [
      { label: "Дриблинг — попытки", value: S.drib_attempts },
      { label: "Дриблинг — успешно", value: S.drib_success },
      { label: "Единоборства (всего)", value: S.duels_total },
      { label: "Единоборства — выиграно", value: S.duels_won },
      { label: "Верховые (всего)", value: S.aerials_total },
      { label: "Верховые — выиграно", value: S.aerials_won },
      { label: "Касания", value: S.touches },
    ]},
    { title: "Оборона", rows: [
      { label: "Отборы", value: S.tackles },
      { label: "Перехваты", value: S.interceptions },
      { label: "Выносы", value: S.clearances },
      { label: "Блоки", value: S.blocks },
    ]},
    { title: "Фолы и дисциплина", rows: [
      { label: "Фолы совершены", value: S.fouls_committed },
      { label: "Фолы на нём", value: S.fouls_drawn },
      { label: "Офсайды", value: S.offsides },
      { label: "ЖК", value: S.yellow },
      { label: "КК", value: S.red },
    ]},
    { title: "Вратарь", rows: [
      { label: "Сэйвы", value: S.saves },
      { label: "Пропущено", value: S.conceded },
    ]},
    { title: "Игровое время", rows: [
      { label: "Минуты", value: S.minutes },
      { label: "Вышел", value: S.subIn ? `${S.subIn}'` : "—" },
      { label: "Ушёл", value: S.subOut ? `${S.subOut}'` : "—" },
    ]},
  ];

  return (
    <div className="fixed inset-0 z-[100]">
      {/* затемнение */}
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      {/* уменьшенное, аккуратно центрированное окно */}
      <div
        className="
          absolute left-1/2 -translate-x-1/2
          top-4
          w-[min(700px,92vw)]
          max-h-[70vh]
          rounded-2xl bg-white shadow-2xl border
          grid grid-rows-[auto,1fr] overflow-hidden
        "
      >
        {/* sticky header */}
        <div className={`sticky top-0 z-10 bg-white/95 backdrop-blur border-b px-4 transition-all ${compact ? "py-2" : "py-3"}`}>
          <div className="flex items-center gap-3">
            <div
              className={`overflow-hidden rounded-full ring-2 ${side === "home" ? "ring-emerald-500/70" : "ring-sky-500/70"} shadow`}
              style={{ width: compact ? 36 : 48, height: compact ? 36 : 48, transition: "width .2s, height .2s" }}
            >
              {photo ? (
                <img src={photo} alt={name} className="h-full w-full object-cover" loading="lazy" decoding="async" />
              ) : (
                <div className="h-full w-full grid place-items-center text-sm font-semibold">
                  {(name || "??").split(" ").map((x) => x[0]).join("").slice(0, 2).toUpperCase()}
                </div>
              )}
            </div>

            <div className="min-w-0 flex-1">
              <div className="text-base font-semibold truncate">{name || "Без имени"}</div>
            </div>

            <div className="ml-auto text-right">
              <div className="text-[11px] text-gray-500">Рейтинг</div>
              <div className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-sm font-semibold ${rateCls}`}>
                {isMVP && <span>⭐</span>}
                <span className="tabular-nums">{Number.isFinite(ratingNum) ? ratingNum.toFixed(1) : "—"}</span>
              </div>
            </div>

            <button
              className="ml-2 text-gray-400 hover:text-gray-600 text-xl leading-none"
              aria-label="close"
              onClick={onClose}
              title="Закрыть"
            >
              ✕
            </button>
          </div>
        </div>

        {/* body */}
        <div ref={scrollRef} className="px-4 py-3 grid gap-3 overflow-auto">
          {sections.map((sec, idx) => (
            <Section key={idx} title={sec.title} rows={sec.rows} />
          ))}
        </div>
      </div>
    </div>
  );
}
