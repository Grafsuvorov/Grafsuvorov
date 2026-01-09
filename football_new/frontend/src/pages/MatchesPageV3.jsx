// src/pages/MatchesPageV3.jsx
import React, {
  useState,
  useEffect,
  useMemo,
  lazy,
  Suspense,
} from "react";
import { useSearchParams } from "react-router-dom";
import { format } from "date-fns";
import clsx from "clsx";

import SafeImg from "@/components/SafeImg";
import PlayerCard from "@/components/PlayerCard";
import FootballPitchPro from "@/components/FootballPitchPro";
import { teamLogoMap } from "@/constants/teamLogoMap";
import {
  normalizeLineups,
  autoLayout,
  layoutFromGrid,
  buildMetaMaps,
} from "@/lib/lineupsLayout";

const MatchStatsBlockV3 = lazy(() =>
  import("@/components/MatchStatsBlockV3")
);
import "../index.css";

/* ================================
   ROUND PARSE
================================ */
function extractRoundNumber(round) {
  if (!round) return 0;
  const m = String(round).match(/(\d+)/);
  return m ? Number(m[1]) : 0;
}

/* ================================
   PERF HELPERS
================================ */
const lineupsCache = new Map();
const ric =
  typeof window !== "undefined" && window.requestIdleCallback
    ? window.requestIdleCallback
    : (cb) =>
        setTimeout(
          () => cb({ didTimeout: false, timeRemaining: () => 0 }),
          200
        );

function prefetchImage(src) {
  if (!src) return;
  const i = new Image();
  i.decoding = "async";
  i.loading = "eager";
  i.src = src;
}

async function fetchLineupsCached(fixture_id, signal) {
  if (!fixture_id) return null;
  if (lineupsCache.has(fixture_id)) return lineupsCache.get(fixture_id);

  const endpoints = [
    `http://localhost:8001/api/lineups-events?fixture_id=${fixture_id}`,
    `http://localhost:8001/api/match/lineups-events?fixture_id=${fixture_id}`,
  ];

  for (let i = 0; i < endpoints.length; i++) {
    try {
      const r = await fetch(endpoints[i], { signal });
      if (!r.ok) {
        if (i === endpoints.length - 1 || r.status >= 500) break;
        continue;
      }
      const p = await r.json();
      lineupsCache.set(fixture_id, p);
      return p;
    } catch (e) {
      if (i === endpoints.length - 1) console.error("lineups error:", e);
    }
  }
  lineupsCache.set(fixture_id, null);
  return null;
}

function usePrefetchTeamLogos(matches) {
  useEffect(() => {
    if (!Array.isArray(matches)) return;
    matches.slice(0, 20).forEach((m) => {
      const h = m.home_team_id
        ? `/icons/team_logos/${m.home_team_id}.png`
        : teamLogoMap[m.home_team] || "/icons/team_logos/default.png";
      const a = m.away_team_id
        ? `/icons/team_logos/${m.away_team_id}.png`
        : teamLogoMap[m.away_team] || "/icons/team_logos/default.png";
      prefetchImage(h);
      prefetchImage(a);
    });
  }, [matches]);
}

function prefetchLineupsForFixtures(list) {
  const ac = new AbortController();
  list.forEach((m) => {
    if (!m?.fixture_id || lineupsCache.has(m.fixture_id)) return;
    fetchLineupsCached(m.fixture_id, ac.signal).catch(() => {});
  });
  return () => ac.abort();
}

/* ================================
   UTILS
================================ */
const safeDateFormat = (v, fmt = "dd.MM.yyyy") => {
  try {
    if (!v) return "—";
    const d = typeof v === "string" ? new Date(v.replace(" ", "T")) : new Date(v);
    return Number.isNaN(d.getTime()) ? "—" : format(d, fmt);
  } catch {
    return "—";
  }
};

const parseScore = (s) => {
  const m = String(s || "").match(/(\d+)\s*[-:]\s*(\d+)/);
  return m ? [Number(m[1]), Number(m[2])] : [null, null];
};

const pct = (v) =>
  v == null ? "—" : `${(Number(v) * 100).toFixed(1)}%`;

const lower = (v) => (v == null ? "" : String(v).toLowerCase());

const teamLogo = (name, id) =>
  id
    ? `/icons/team_logos/${id}.png`
    : teamLogoMap[name] || "/icons/team_logos/default.png";

/* ================================
   VERDICTS
================================ */
function getOutcomeVerdict(m) {
  const label = (m?.outcome_label || "").trim().toUpperCase();
  const [h, a] = parseScore(m.score);

  if (!label)
    return {
      kind: "no_pick",
      title: "Модель не рекомендовала ставку на исход",
      extra: "Сигнала по исходу не было.",
    };

  if (h == null)
    return {
      kind: "no_result",
      title: "Матч не завершён",
      extra: "Нет результата.",
    };

  const fact = h > a ? "П1" : h < a ? "П2" : "Х";
  const hit = fact === label;

  return hit
    ? {
        kind: "hit",
        title: "Модель была права по исходу",
        extra: `Прогноз (${label}) совпал.`,
      }
    : {
        kind: "miss",
        title: "Модель ошиблась по исходу",
        extra: `Факт ${fact}, прогноз ${label}.`,
      };
}

function getTotalVerdict(m) {
  const lbl = (m?.total_label || "").toLowerCase();
  const [h, a] = parseScore(m.score);

  if (!lbl)
    return {
      kind: "no_pick",
      title: "Модель не рекомендовала тотал",
      extra: "Сигнала по тоталу не было.",
    };

  if (h == null)
    return { kind: "no_result", title: "Матч не завершён", extra: "" };

  const goals = h + a;
  const mLine = lbl.match(/(\d+(?:[.,]\d+)?)/);
  const line = mLine ? parseFloat(mLine[1].replace(",", ".")) : 2.5;
  const isOver = lbl.includes("over") || lbl.includes("больше");
  const isUnder = lbl.includes("under") || lbl.includes("меньше");

  if (goals === line) {
    return {
      kind: "push",
      title: "Возврат по тоталу",
      extra: `Голов ровно ${goals} при линии ${line}.`,
    };
  }

  const hit = isOver ? goals > line : goals < line;

  return hit
    ? { kind: "hit", title: "Модель права по тоталу", extra: "" }
    : { kind: "miss", title: "Модель ошиблась по тоталу", extra: "" };
}

const verdictTone = {
  hit: "bg-emerald-500/10 border-emerald-400/40 text-emerald-200",
  miss: "bg-rose-500/10 border-rose-400/40 text-rose-200",
  no_pick: "bg-surface-2/90 border-glass text-slate-300",
  no_result: "bg-surface-2/90 border-glass text-slate-300",
  push: "bg-amber-500/15 border-amber-400/40 text-amber-100",
};

/* ================================
   Minute pill / avatar
================================ */
function MinutePill({ value }) {
  return (
    <span className="inline-flex h-[22px] w-[52px] items-center justify-center rounded-full border border-glass bg-surface-2 text-[11px] tabular-nums text-slate-100">
      {value}
    </span>
  );
}

function AvatarCircle({ pid, number, ring = "" }) {
  const src = pid ? `/icons/player_photos/${pid}.png` : null;
  return (
    <span
      className={clsx(
        "inline-flex items-center justify-center rounded-full ring-2 bg-surface-2 border border-glass overflow-hidden",
        ring
      )}
      style={{ width: 24, height: 24 }}
    >
      {src ? (
        <img
          src={src}
          alt=""
          className="h-full w-full rounded-full object-cover"
          onError={(e) => {
            e.currentTarget.style.display = "none";
          }}
        />
      ) : (
        <span className="text-[11px] font-semibold text-slate-100">
          {number || "?"}
        </span>
      )}
    </span>
  );
}

/* ================================
   events / subs helpers
================================ */
const ICON = {
  goal: "⚽",
  own_goal: "🥅",
  goal_cancelled: "🚫",
  pen_missed: "⛔",
  yellow: "🟨",
  red: "🟥",
  sub: "🔁",
  var: "🎥",
  other: "•",
};

const DETAIL_RU = {
  "normal goal": "Гол",
  "own goal": "Автогол",
  "goal cancelled": "Гол отменён",
  penalty: "Пенальти",
  "missed penalty": "Нереализованный пенальти",
  "yellow card": "Жёлтая карточка",
  "red card": "Красная карточка",
};

const COMMENTS_RU = {
  foul: "Фол",
  simulation: "Симуляция",
  "time wasting": "Затяжка времени",
};

const translateDetailRu = (d) =>
  DETAIL_RU[lower(d)] || (d == null ? "" : String(d));

const translateCommentRu = (c) =>
  COMMENTS_RU[lower(c)] || (c == null ? "" : String(c));

const getElapsed = (ev) => {
  const cand = [ev?.elapsed, ev?.minute, ev?.elapsed_time, ev?.time?.elapsed];
  const v = cand.find((x) => x != null && x !== "");
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

const getExtra = (ev) => {
  const cand = [ev?.extra, ev?.time?.extra, ev?.extra_time];
  const v = cand.find((x) => x != null && x !== "");
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
};

const minuteStr = (elapsed, extra) => {
  const e = Number(elapsed);
  const x = Number(extra) || 0;
  if (!Number.isFinite(e)) return "—";
  if (e === 45 && x > 0) return `45+${x}'`;
  if (e >= 90 && x > 0) return `${e}+${x}'`;
  return `${e}'`;
};

const inferKind = (ev) => {
  const t = lower(ev?.type);
  const d = lower(ev?.detail);
  if (t.includes("goal") && !d.includes("cancel"))
    return d === "own goal" ? "own_goal" : "goal";
  if (d.includes("cancel")) return "goal_cancelled";
  if (d === "missed penalty") return "pen_missed";
  if (d === "yellow card") return "yellow";
  if (d === "red card") return "red";
  if (t.startsWith("subst")) return "sub";
  if (d.includes("var")) return "var";
  return "other";
};

function computeScoreProgress(events, homeId, awayId) {
  let h = 0;
  let a = 0;

  const sorted = [...(events || [])].sort((A, B) => {
    const ea = getElapsed(A) ?? -1;
    const eb = getElapsed(B) ?? -1;
    const xa = getExtra(A);
    const xb = getExtra(B);

    if (ea !== eb) return ea - eb;
    if (xa !== xb) return xa - xb;
    return (A.player_id || 0) - (B.player_id || 0);
  });

  return sorted.map((e) => {
    const side =
      e.team_id === homeId ? "home" : e.team_id === awayId ? "away" : null;

    const kind = inferKind(e);

    if (kind === "goal") {
      if (side === "home") h++;
      else if (side === "away") a++;
    }
    if (kind === "own_goal") {
      if (side === "home") a++;
      else if (side === "away") h++;
    }

    return {
      ...e,
      team_side: side,
      kind,
      score_after: `${h}-${a}`,
    };
  });
}

const collectSubs = (events = []) =>
  events
    .filter((e) => {
      const t = lower(e?.type);
      const d = lower(e?.detail);
      return t.startsWith("subst") || d.startsWith("substitution");
    })
    .map((e) => ({
      team_id: e.team_id,
      minute: e.minute ?? e.elapsed ?? null,
      in_id: e.player_id,
      in_name: e.player_name,
      out_id: e.assist_id,
      out_name: e.assist_name,
    }));

function groupEventsByPeriod(events) {
  const out = {
    first: { home: [], away: [] },
    second: { home: [], away: [] },
    extra: { home: [], away: [] },
  };

  for (const ev of events) {
    const e = getElapsed(ev) ?? 0;
    const bucket = e <= 45 ? "first" : e <= 90 ? "second" : "extra";
    const side = ev.team_side === "away" ? "away" : "home";
    out[bucket][side].push(ev);
  }

  return out;
}

/* ================================
   Bench list
================================ */
function BenchList({ title, list, ring, teamId, metaMaps, onOpen }) {
  return (
    <div className="panel bg-surface-1/80 p-3 sm:p-4 rounded-2xl">
      <div className="mb-2 text-sm font-medium text-slate-100">
        {title}
      </div>
      <div className="flex flex-wrap gap-2">
        {(list || []).map((p, i) => {
          const pid = p.player_id || i;
          const src = pid ? `/icons/player_photos/${pid}.png` : null;

          const meta = metaMaps.get?.(teamId)?.get?.(pid);

          const name =
            p.name || p.player_name || `#${p.number || "?"}`;

          return (
            <button
              key={pid}
              type="button"
              onClick={() => onOpen(p, meta)}
              className="inline-flex items-center gap-2 rounded-full border border-glass bg-surface-2 px-2 py-1 text-xs text-slate-100 shadow-[0_0_18px_rgba(0,0,0,0.45)] hover:bg-surface-2/80"
            >
              <span
                className={clsx(
                  "inline-flex items-center justify-center rounded-full ring-2 bg-surface-1 overflow-hidden",
                  ring
                )}
                style={{ width: 24, height: 24 }}
              >
                {src ? (
                  <img
                    src={src}
                    className="h-full w-full object-cover"
                  />
                ) : (
                  <span className="text-[11px] font-semibold">
                    {p.number || "?"}
                  </span>
                )}
              </span>
              <span className="truncate max-w-[120px]">{name}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

/* ================================
   LINEUPS SECTION
================================ */
function LineupsSection({
  m,
  lineupsData,
  loadingLineups,
  norm,
  metaMaps,
  setOpenCard,
}) {
  if (!lineupsData) {
    return (
      <div className="mt-4 text-sm text-muted">
        {loadingLineups ? "Загружаем составы…" : "Нет данных по составам."}
      </div>
    );
  }

  const homePins = useMemo(() => {
    const starters = norm?.home?.starters || [];
    if (!starters.length) return [];
    const grid = layoutFromGrid(starters, "home", norm.home.formation);
    return grid.length ? grid : autoLayout(norm.home.formation, starters, "home");
  }, [norm]);

  const awayPins = useMemo(() => {
    const starters = norm?.away?.starters || [];
    if (!starters.length) return [];
    const grid = layoutFromGrid(starters, "away", norm.away.formation);
    return grid.length ? grid : autoLayout(norm.away.formation, starters, "away");
  }, [norm]);

  const homeId = norm?.home?.team_id || m.home_team_id;
  const awayId = norm?.away?.team_id || m.away_team_id;

  const eventsEnriched = useMemo(
    () => computeScoreProgress(norm?.events || [], homeId, awayId),
    [norm, homeId, awayId]
  );

  const groups = useMemo(
    () => groupEventsByPeriod(eventsEnriched),
    [eventsEnriched]
  );

  const subs = useMemo(
    () => collectSubs(norm?.events || []),
    [norm]
  );

  const subsHome = subs.filter((s) => s.team_id === homeId);
  const subsAway = subs.filter((s) => s.team_id === awayId);

  return (
    <div className="mt-4 space-y-4">
      <div className="panel bg-surface-1/90 rounded-2xl p-3 sm:p-4 border border-glass shadow-[0_0_25px_rgba(0,0,0,0.45)]">
        <FootballPitchPro
          homePlayers={homePins}
          awayPlayers={awayPins}
          homeMeta={metaMaps.get?.(homeId)}
          awayMeta={metaMaps.get?.(awayId)}
          mvpId={null}
          onOpenCard={(payload) => setOpenCard(payload)}
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        <BenchList
          title={`Запас • ${m.home_team}`}
          teamId={homeId}
          list={norm?.home?.bench || []}
          ring="ring-emerald-400/80"
          metaMaps={metaMaps}
          onOpen={(p, meta) =>
            setOpenCard({ side: "home", player: p, meta })
          }
        />
        <BenchList
          title={`Запас • ${m.away_team}`}
          teamId={awayId}
          list={norm?.away?.bench || []}
          ring="ring-sky-400/80"
          metaMaps={metaMaps}
          onOpen={(p, meta) =>
            setOpenCard({ side: "away", player: p, meta })
          }
        />
      </div>

      {/* ЗАМЕНЫ */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div className="panel bg-surface-1/80 rounded-2xl p-3 sm:p-4 border border-glass">
          <div className="mb-2 text-sm font-medium text-slate-100">
            Замены • {m.home_team}
          </div>
          {subsHome.length ? (
            subsHome.map((s, i) => (
              <div
                key={`hs-${i}`}
                className="grid grid-cols-[minmax(0,1fr)_60px_minmax(0,1fr)] items-center gap-2 border-b border-glass py-1.5 last:border-0"
              >
                <div className="flex items-center gap-2 min-w-0">
                  <AvatarCircle pid={s.in_id} ring="ring-emerald-400/80" />
                  <span className="truncate text-emerald-200 font-medium">
                    ↗ {s.in_name}
                  </span>
                </div>

                <div className="flex justify-center">
                  <MinutePill value={`${s.minute}'`} />
                </div>

                <div className="flex items-center gap-2 min-w-0 justify-end">
                  <span className="truncate text-rose-200 font-medium text-right">
                    ↘ {s.out_name}
                  </span>
                  <AvatarCircle pid={s.out_id} ring="ring-rose-400/80" />
                </div>
              </div>
            ))
          ) : (
            <div className="text-xs text-muted">—</div>
          )}
        </div>

        <div className="panel bg-surface-1/80 rounded-2xl p-3 sm:p-4 border border-glass">
          <div className="mb-2 text-sm font-medium text-slate-100">
            Замены • {m.away_team}
          </div>
          {subsAway.length ? (
            subsAway.map((s, i) => (
              <div
                key={`as-${i}`}
                className="grid grid-cols-[minmax(0,1fr)_60px_minmax(0,1fr)] items-center gap-2 border-b border-glass py-1.5 last:border-0"
              >
                <div className="flex items-center gap-2 min-w-0">
                  <AvatarCircle pid={s.in_id} ring="ring-sky-400/80" />
                  <span className="truncate text-sky-200 font-medium">
                    ↗ {s.in_name}
                  </span>
                </div>

                <div className="flex justify-center">
                  <MinutePill value={`${s.minute}'`} />
                </div>

                <div className="flex items-center gap-2 min-w-0 justify-end">
                  <span className="truncate text-right text-rose-200 font-medium">
                    ↘ {s.out_name}
                  </span>
                  <AvatarCircle pid={s.out_id} ring="ring-rose-400/80" />
                </div>
              </div>
            ))
          ) : (
            <div className="text-xs text-muted text-right">—</div>
          )}
        </div>
      </div>

      {/* СОБЫТИЯ */}
      <div className="panel bg-surface-1/90 rounded-2xl p-3 sm:p-4 border border-glass">
        <div className="mb-3 text-sm font-medium text-slate-100">
          События матча
        </div>

        {["first", "second", "extra"].map((k) => {
          const title =
            k === "first"
              ? "1-й тайм"
              : k === "second"
              ? "2-й тайм"
              : "Доп. время";

          const homeList = groups[k].home;
          const awayList = groups[k].away;

          if (!homeList.length && !awayList.length) return null;

          return (
            <div key={k} className="mb-4 last:mb-0">
              <div className="mb-1 text-[11px] uppercase tracking-[0.18em] text-muted font-semibold">
                {title}
              </div>

              <div className="grid md:grid-cols-2 gap-3">
                {/* HOME SIDE */}
                <div className="space-y-2">
                  {homeList.length ? (
                    homeList.map((ev, i) => (
                      <div key={`h-${k}-${i}`} className="flex justify-start">
                        <div className="inline-flex items-center gap-2 rounded-full border border-glass bg-surface-2 px-2 py-1 text-[13px] text-slate-100 shadow-[0_0_18px_rgba(0,0,0,0.45)]">
                          <span className="text-base">
                            {ICON[ev.kind] || ICON.other}
                          </span>
                          <MinutePill
                            value={minuteStr(getElapsed(ev), getExtra(ev))}
                          />
                          <span>
                            <span className="font-medium">
                              {ev.player_name}
                            </span>
                            {ev.assist_name &&
                              !/^substitution/i.test(ev.detail || "") && (
                                <span className="text-slate-400">
                                  {" "}
                                  (ассист {ev.assist_name})
                                </span>
                              )}
                            {translateDetailRu(ev.detail) && (
                              <span className="text-slate-300">
                                {" "}
                                — {translateDetailRu(ev.detail)}
                              </span>
                            )}
                            {translateCommentRu(ev.comments) && (
                              <span className="text-slate-400">
                                {" "}
                                ({translateCommentRu(ev.comments)})
                              </span>
                            )}
                            {(ev.kind === "goal" ||
                              ev.kind === "own_goal") &&
                              ev.score_after && (
                                <span className="ml-2 font-semibold">
                                  {ev.score_after}
                                </span>
                              )}
                          </span>
                        </div>
                      </div>
                    ))
                  ) : (
                    <div className="text-muted text-sm">—</div>
                  )}
                </div>

                {/* AWAY SIDE */}
                <div className="space-y-2">
                  {awayList.length ? (
                    awayList.map((ev, i) => (
                      <div key={`a-${k}-${i}`} className="flex justify-end">
                        <div className="inline-flex items-center gap-2 rounded-full border border-glass bg-surface-2 px-2 py-1 text-[13px] text-slate-100 shadow-[0_0_18px_rgba(0,0,0,0.45)]">
                          <span className="text-base">
                            {ICON[ev.kind] || ICON.other}
                          </span>
                          <MinutePill
                            value={minuteStr(getElapsed(ev), getExtra(ev))}
                          />
                          <span className="text-right">
                            <span className="font-medium">
                              {ev.player_name}
                            </span>
                            {ev.assist_name &&
                              !/^substitution/i.test(ev.detail || "") && (
                                <span className="text-slate-400">
                                  {" "}
                                  (ассист {ev.assist_name})
                                </span>
                              )}
                            {translateDetailRu(ev.detail) && (
                              <span className="text-slate-300">
                                {" "}
                                — {translateDetailRu(ev.detail)}
                              </span>
                            )}
                            {translateCommentRu(ev.comments) && (
                              <span className="text-slate-400">
                                {" "}
                                ({translateCommentRu(ev.comments)})
                              </span>
                            )}
                            {(ev.kind === "goal" ||
                              ev.kind === "own_goal") &&
                              ev.score_after && (
                                <span className="ml-2 font-semibold">
                                  {ev.score_after}
                                </span>
                              )}
                          </span>
                        </div>
                      </div>
                    ))
                  ) : (
                    <div className="text-muted text-sm text-right">—</div>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/* ================================
   MATCH ROW COMPACT (как в календаре)
================================ */
function MatchRowCompact({ m, expanded, setExpanded, highlight }) {
  return (
    <button
      type="button"
      onClick={() => setExpanded((v) => !v)}
      className={clsx(
        "w-full px-4 py-4 md:px-6 transition hover:bg-surface-1/70",
        highlight && "bg-accent/10",
        // главное — GRID
        "grid grid-cols-[1fr_auto_1fr] items-center gap-4"
      )}
    >
      {/* LEFT — HOME */}
      <div className="flex items-center gap-3 min-w-0">
        <SafeImg
          src={teamLogo(m.home_team, m.home_team_id)}
          className="h-8 w-8 rounded-lg border border-glass bg-surface-2 object-contain"
        />
        <div className="min-w-0 text-left">
          <div className="text-sm text-white font-semibold truncate">
            {m.home_team}
          </div>
          <div className="text-[11px] text-muted truncate">
            {safeDateFormat(m.date)} {m.venue ? `· ${m.venue}` : ""}
          </div>
        </div>
      </div>

      {/* CENTER — SCORE (fixed width) */}
      <div
        className="rounded-xl bg-surface-2/80 px-4 py-2 border border-glass shadow-inner text-center
                   flex flex-col items-center justify-center"
        style={{ width: "120px" }}   // 🔥 фикс ширина
      >
        <div className="text-[10px] text-muted uppercase tracking-[0.18em]">
          СЧЁТ
        </div>
        <div className="text-xl font-semibold text-white tabular-nums leading-none">
          {m.score || "—"}
        </div>
      </div>

      {/* RIGHT — AWAY */}
      <div className="flex items-center gap-3 min-w-0 justify-end">
        <div className="text-right min-w-0">
          <div className="text-sm font-semibold text-white truncate">
            {m.away_team}
          </div>
          <div className="text-[11px] text-muted truncate">
            {m.status || ""}
          </div>
        </div>
        <SafeImg
          src={teamLogo(m.away_team, m.away_team_id)}
          className="h-8 w-8 rounded-lg border border-glass bg-surface-2 object-contain"
        />
      </div>
    </button>
  );
}


/* ================================
   PREDICTION BLOCK
================================ */
function PredictionBlock({ m }) {
  const o = getOutcomeVerdict(m);
  const t = getTotalVerdict(m);

  return (
    <div className="rounded-2xl bg-surface-1/80 border border-glass p-4 space-y-4 shadow-inner">
      <div>
        <div className="text-[11px] uppercase tracking-[0.18em] text-muted">
          ПРОГНОЗ МОДЕЛИ
        </div>
        <div className="text-sm text-slate-200">
          Исход матча и тотал голов.
        </div>
      </div>

      {/* OUTCOME */}
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <span className="text-xs text-muted uppercase tracking-wide">
            Исход матча (1X2)
          </span>
          <span className="text-[11px] text-slate-400">
            {m.outcome_label || "—"}
          </span>
        </div>

        <div className="flex items-center gap-3">
          {[
            { label: "П1", v: m.outcome_p1 },
            { label: "Х", v: m.outcome_x },
            { label: "П2", v: m.outcome_p2 },
          ].map((o2) => (
            <div
              key={o2.label}
              className={clsx(
                "flex-1 text-center rounded-xl border bg-surface-2/80 p-3 shadow-inner",
                (m.outcome_label || "").toUpperCase() === o2.label
                  ? "ring-2 ring-accent border-accent"
                  : "border-glass"
              )}
            >
              <div className="text-[11px] text-muted">{o2.label}</div>
              <div className="text-lg text-white font-semibold tabular-nums">
                {pct(o2.v)}
              </div>
            </div>
          ))}
        </div>

        {/* verdict */}
        <div
          className={clsx(
            "inline-flex items-start gap-2 rounded-xl border px-3 py-2 text-xs",
            verdictTone[o.kind] || verdictTone.no_pick
          )}
        >
          <span className="text-base leading-none">
            {o.kind === "hit" && "✅"}
            {o.kind === "miss" && "❌"}
            {o.kind === "no_pick" && "ℹ️"}
            {o.kind === "no_result" && "⏳"}
            {o.kind === "push" && "↔"}
          </span>
          <span className="flex flex-col">
            <span className="font-semibold">{o.title}</span>
            <span className="text-[11px] opacity-70">{o.extra}</span>
          </span>
        </div>
      </div>

      {/* TOTAL */}
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <span className="text-xs text-muted uppercase tracking-wide">
            Тотал 2.5
          </span>
          <span className="text-[11px] text-slate-400">
            {m.total_label || "—"}
          </span>
        </div>

        <div className="flex items-center gap-3">
          {[
            { lbl: "Больше 2.5", match: "over", v: m.total_o25 },
            { lbl: "Меньше 2.5", match: "under", v: m.total_u25 },
          ].map((t2) => {
            const active = (m.total_label || "").toLowerCase().includes(t2.match);
            return (
              <div
                key={t2.lbl}
                className={clsx(
                  "flex-1 text-center rounded-xl border bg-surface-2/80 p-3 shadow-inner",
                  active ? "ring-2 ring-accent border-accent" : "border-glass"
                )}
              >
                <div className="text-[11px] text-muted">{t2.lbl}</div>
                <div className="text-lg text-white font-semibold tabular-nums">
                  {pct(t2.v)}
                </div>
              </div>
            );
          })}
        </div>

        <div
          className={clsx(
            "inline-flex items-start gap-2 rounded-xl border px-3 py-2 text-xs",
            verdictTone[t.kind] || verdictTone.no_pick
          )}
        >
          <span className="text-base leading-none">
            {t.kind === "hit" && "✅"}
            {t.kind === "miss" && "❌"}
            {t.kind === "no_pick" && "ℹ️"}
            {t.kind === "no_result" && "⏳"}
            {t.kind === "push" && "↔"}
          </span>
          <span className="flex flex-col">
            <span className="font-semibold">{t.title}</span>
            <span className="text-[11px] opacity-70">{t.extra}</span>
          </span>
        </div>
      </div>
    </div>
  );
}

/* ================================
   MATCH EXPANDED CONTENT
================================ */
function MatchExpanded({ m }) {
  const [tab, setTab] = useState("stats");
  const [lineupsData, setLineupsData] = useState(null);
  const [loadingLineups, setLoadingLineups] = useState(false);
  const [openCard, setOpenCard] = useState(null);

  const norm = useMemo(() => normalizeLineups(lineupsData, m), [lineupsData, m]);
  const metaMaps = useMemo(() => buildMetaMaps(norm), [norm]);

  const openLineups = async () => {
    if (lineupsData || loadingLineups || !m.fixture_id) return;
    setLoadingLineups(true);
    const ac = new AbortController();
    try {
      const j = await fetchLineupsCached(m.fixture_id, ac.signal);
      setLineupsData(j);
    } finally {
      setLoadingLineups(false);
    }
    return () => ac.abort();
  };

  return (
    <div className="px-4 pb-6 md:px-6 space-y-6 bg-surface-1/40 border-t border-glass">
      {/* prediction */}
      <PredictionBlock m={m} />

      {/* tabs */}
      <div className="flex items-center justify-between">
        <div className="text-[11px] uppercase tracking-[0.16em] text-muted">
          детали матча
        </div>
        <div className="inline-flex rounded-xl border border-glass bg-surface-2/90 p-1">
          <button
            className={clsx(
              "px-3 h-7 rounded-lg text-xs font-semibold transition",
              tab === "stats" ? "tab-active" : "text-slate-300 hover:bg-surface-1/80"
            )}
            onClick={() => setTab("stats")}
          >
            Статистика
          </button>
          <button
            className={clsx(
              "px-3 h-7 rounded-lg text-xs font-semibold transition",
              tab === "lineups" ? "tab-active" : "text-slate-300 hover:bg-surface-1/80"
            )}
            onClick={() => {
              setTab("lineups");
              openLineups();
            }}
          >
            Составы
          </button>
        </div>
      </div>

      {tab === "stats" ? (
        <div className="panel bg-surface-1/80 rounded-2xl border border-glass p-4 shadow-inner">
          <Suspense fallback={<div className="text-muted text-sm">Загружаем…</div>}>
            <MatchStatsBlockV3 stats={m} />
          </Suspense>
        </div>
      ) : (
        <LineupsSection
          m={m}
          norm={norm}
          metaMaps={metaMaps}
          loadingLineups={loadingLineups}
          lineupsData={lineupsData}
          setOpenCard={setOpenCard}
        />
      )}

      <PlayerCard
        visible={!!openCard}
        player={openCard?.player}
        meta={openCard?.meta}
        side={openCard?.side}
        onClose={() => setOpenCard(null)}
      />
    </div>
  );
}

/* ================================
   MATCH CARD (ROW + EXPANDED)
================================ */
function MatchCard({ m, highlight }) {
  const [expanded, setExpanded] = useState(false);

  return (
    <div
      id={`fixture-${m.fixture_id}`}
      className={clsx("transition-colors", highlight && "bg-accent/5")}
    >
      <MatchRowCompact
        m={m}
        expanded={expanded}
        setExpanded={setExpanded}
        highlight={highlight}
      />
      {expanded && <MatchExpanded m={m} />}
    </div>
  );
}

/* ================================
   FETCH JSON SAFE
================================ */
async function fetchJsonSafe(url, signal) {
  const r = await fetch(url, { signal });
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  const txt = await r.text();
  try {
    return JSON.parse(txt);
  } catch {
    const fixed = txt
      .replace(/\bNaN\b/g, "null")
      .replace(/\b-?Infinity\b/g, "null");
    return JSON.parse(fixed);
  }
}

/* ================================
   MAIN PAGE
================================ */
export default function MatchesPageV3() {
  const [searchParams, setSearchParams] = useSearchParams();

  const DEFAULT_LEAGUE = "Premier League";
  const DEFAULT_SEASON = "2025";

  const [league, setLeague] = useState(
    searchParams.get("league") || DEFAULT_LEAGUE
  );
  const [season, setSeason] = useState(
    searchParams.get("season") || DEFAULT_SEASON
  );

  const [matches, setMatches] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [highlightId, setHighlightId] = useState(null);

  // Sync url -> state
  useEffect(() => {
    const qLeague = searchParams.get("league") || DEFAULT_LEAGUE;
    const qSeason = searchParams.get("season") || DEFAULT_SEASON;
    if (qLeague !== league) setLeague(qLeague);
    if (qSeason !== season) setSeason(qSeason);
  }, [searchParams]);

  // Keep URL updated
  useEffect(() => {
    const next = new URLSearchParams(searchParams);
    next.set("league", league);
    next.set("season", season);
    if (next.toString() !== searchParams.toString()) {
      setSearchParams(next, { replace: true });
    }
  }, [league, season]);

  const seasonDateRange = (seasonStr) => {
    const y = Number(seasonStr) || Number(DEFAULT_SEASON);
    return { from: `${y}-07-01`, to: `${y + 1}-06-30` };
  };

  // Load matches
  useEffect(() => {
    const ac = new AbortController();
    (async () => {
      try {
        setLoading(true);
        setError("");
        setMatches([]);

        const { from, to } = seasonDateRange(season);
        const q = new URLSearchParams({
          from_date: from,
          to_date: to,
          league,
          season,
        });

        const data = await fetchJsonSafe(
          `http://localhost:8001/api/matches_v3?${q.toString()}`,
          ac.signal
        );

        setMatches(Array.isArray(data) ? data : []);
      } catch (e) {
        if (e.name !== "AbortError") setError(e.message || String(e));
      } finally {
        setLoading(false);
      }
    })();

    return () => ac.abort();
  }, [league, season]);

  // Prefetch
usePrefetchTeamLogos(matches);

useEffect(() => {
  if (!matches.length) return;

  let abortCleanup = null;

  ric(() => {
    abortCleanup = prefetchLineupsForFixtures(matches.slice(0, 2));
  });

  return () => {
    if (typeof abortCleanup === "function") {
      abortCleanup();
    }
  };
}, [matches]);


  // Scroll highlight
  useEffect(() => {
    if (!matches.length) return;
    const fid = searchParams.get("fixture_id");
    if (!fid) return;

    let timer;
    const raf = requestAnimationFrame(() => {
      const el = document.getElementById(`fixture-${fid}`);
      if (el) {
        el.scrollIntoView({ behavior: "smooth", block: "center" });
        setHighlightId(fid);
        timer = setTimeout(() => setHighlightId(null), 2500);
      }
    });

    return () => {
      cancelAnimationFrame(raf);
      if (timer) clearTimeout(timer);
    };
  }, [matches, searchParams]);

  // Group by round
  const grouped = useMemo(() => {
    const map = new Map();
    for (const m of matches) {
      const key = m.round || "Без тура";
      if (!map.has(key)) {
        map.set(key, {
          label: key,
          num: extractRoundNumber(key),
          items: [],
        });
      }
      map.get(key).items.push(m);
    }
    return [...map.values()].sort((a, b) => a.num - b.num);
  }, [matches]);

  return (
    <div className="mx-auto max-w-6xl px-4 py-6 space-y-6">
      {/* HEADER */}
      <div className="panel rounded-3xl px-6 py-5 bg-surface-1/60 border border-glass shadow-[0_18px_40px_rgba(0,0,0,0.35)] backdrop-blur-xl">
        <div className="flex items-start justify-between gap-4">
          <div className="space-y-2">
            <div className="text-[11px] uppercase tracking-[0.18em] text-muted">
              МАТЧИ ТУРНИРА
            </div>

            <div className="text-xl sm:text-2xl font-semibold text-white">
              Матчи · {league}
            </div>

            <p className="text-sm text-slate-400 max-w-[640px] leading-relaxed">
              Просматривайте результаты и аналитику модели EdgeScore.{" "}
              Нажмите на матч, чтобы раскрыть статистику и составы.
            </p>
          </div>

          <div className="flex flex-col items-end">
            <span className="text-[10px] uppercase tracking-[0.18em] text-muted mb-1">
              СЕЗОН
            </span>
            <span className="rounded-xl bg-surface-2/80 border border-glass px-4 py-1.5 text-sm text-white shadow-inner">
              {season}
            </span>
          </div>
        </div>
      </div>

      {/* STATES */}
      {loading && (
        <div className="panel bg-surface-2/70 rounded-2xl p-4 border border-glass text-center text-sm text-muted">
          Загружаем матчи…
        </div>
      )}

      {!loading && error && (
        <div className="panel bg-[rgba(127,29,29,0.25)] rounded-2xl p-4 border border-rose-500/40 text-rose-100 text-center text-sm">
          Ошибка: {error}
        </div>
      )}

      {!loading && !error && matches.length === 0 && (
        <div className="panel bg-surface-2/70 rounded-2xl p-4 border border-glass text-center text-sm text-muted">
          Нет матчей для выбранных фильтров.
        </div>
      )}

      {/* GROUPED BY ROUND */}
{!loading &&
  !error &&
  grouped.map((g) => (
    <section key={g.label} className="space-y-3">
      {/* header */}
      <div className="flex items-center justify-between">
        <div className="inline-flex items-center gap-2">
          <span className="text-[11px] uppercase tracking-[0.18em] text-muted">
            тур
          </span>
          <span className="px-3 py-1 rounded-full border border-glass bg-surface-1/80 text-xs text-white">
            {g.label}
          </span>
        </div>
        <span className="text-[11px] text-slate-500">
          матчей: {g.items.length}
        </span>
      </div>

      {/* unified block — один блок с разделителями */}
      <div className="rounded-3xl overflow-hidden border border-glass bg-surface-1/40 divide-y divide-glass shadow-[0_16px_40px_rgba(0,0,0,0.45)]">
        {g.items.map((m, idx) => (
          <MatchCard
            key={m.fixture_id || idx}
            m={m}
            highlight={String(highlightId) === String(m.fixture_id)}
          />
        ))}
      </div>
        </section>
  ))}

  {/* END grouped */}
</div>
);
}



