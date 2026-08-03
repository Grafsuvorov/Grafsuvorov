// src/pages/MatchesPageV3.jsx
import React, {
  useState,
  useEffect,
  useMemo,
  useRef,
  lazy,
  Suspense,
} from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import { format } from "date-fns";
import clsx from "clsx";
import { Radio, Sparkles } from "lucide-react";

import PlayerCard from "@/components/PlayerCard";
import FootballPitchPro from "@/components/FootballPitchPro";
import MatchRowCompact from "@/components/match/MatchRowCompact";
import MatchRoundSection from "@/components/match/MatchRoundSection";
import { teamLogoMap } from "@/constants/teamLogoMap";
import SegmentedTabs from "@/components/ui/SegmentedTabs";
import { useLanguage } from "@/context/LanguageContext.jsx";
import { loadLineupsCached, prefetchLineupsForFixtures } from "@/lib/lineupsApi";
import { fetchMatchesV3, isInternationalLongCycleLeague } from "@/lib/matchesApi";
import {
  CANCELLED_STATUS_HINTS,
  FINISHED_STATUSES,
  POSTPONED_STATUS_HINTS,
  isLiveMatch,
  liveMinuteLabel,
} from "@/lib/matchStatus";
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

function humanRoundLabel(round, language = "ru") {
  const n = extractRoundNumber(round);
  return n ? `${language === "ru" ? "Тур" : "Round"} ${n}` : String(round || (language === "ru" ? "Тур" : "Round"));
}

/* ================================
   PERF HELPERS
================================ */
const ric =
  typeof window !== "undefined" && window.requestIdleCallback
    ? window.requestIdleCallback
    : (cb) =>
        setTimeout(
          () => cb({ didTimeout: false, timeRemaining: () => 0 }),
          200
        );
const RESULTS_INITIAL_ROUNDS = 4;
const RESULTS_ROUND_STEP = 3;
const RESULTS_LOOKBACK_DAYS = 75;
const RESULTS_CACHE_TTL = 2 * 60 * 1000;
const RESULTS_REFRESH_INTERVAL = 60 * 1000;
const resultsCache = new Map();

function prefetchImage(src) {
  if (!src) return;
  const i = new Image();
  i.decoding = "async";
  i.loading = "eager";
  i.src = src;
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

const matchTimestamp = (m) => {
  const raw = m?.date || m?.datetime || "";
  if (!raw) return 0;
  const normalized =
    typeof raw === "string" ? raw.replace(" ", "T") : raw;
  const d = new Date(normalized);
  const t = d.getTime();
  return Number.isNaN(t) ? 0 : t;
};

const parseScore = (s) => {
  const m = String(s || "").match(/(\d+)\s*[-:]\s*(\d+)/);
  return m ? [Number(m[1]), Number(m[2])] : [null, null];
};

const pct = (v) =>
  v == null ? "—" : `${(Number(v) * 100).toFixed(1)}%`;

const lower = (v) => (v == null ? "" : String(v).toLowerCase());

function getMatchStateBadge(m) {
  if (isLiveMatch(m)) {
    return {
      kind: "live",
      label: "Live",
      sublabel: liveMinuteLabel(m, "ru") || "В игре",
      pillClass:
        "border-rose-400/30 bg-gradient-to-r from-rose-500/20 to-orange-400/15 text-rose-100 shadow-[0_0_14px_rgba(244,63,94,0.18)]",
      sublabelClass: "text-white/80",
    };
  }

  const statusRaw = String(m?.status_short || m?.status || "").trim().toUpperCase();
  if (!statusRaw) return null;

  if (POSTPONED_STATUS_HINTS.some((hint) => statusRaw === hint || statusRaw.includes(hint))) {
    return {
      kind: "postponed",
      label: "Перенесён",
      sublabel: "",
      pillClass:
        "border-amber-400/35 bg-amber-500/15 text-amber-200",
      sublabelClass: "text-white/70",
    };
  }

  if (CANCELLED_STATUS_HINTS.some((hint) => statusRaw === hint || statusRaw.includes(hint))) {
    return {
      kind: "cancelled",
      label: "Отменён",
      sublabel: "",
      pillClass:
        "border-white/15 bg-white/8 text-white/70",
      sublabelClass: "text-white/60",
    };
  }

  return null;
}

function isPlayedMatch(m) {
  if (isLiveMatch(m)) return true;
  const [h, a] = parseScore(m?.score);
  if (h != null && a != null) return true;
  const gh = Number(m?.home_goals ?? m?.home_score);
  const ga = Number(m?.away_goals ?? m?.away_score);
  if (Number.isFinite(gh) && Number.isFinite(ga)) return true;
  const statusRaw = m?.status_short || m?.status || "";
  const status = String(statusRaw).trim().toUpperCase();
  if (status && FINISHED_STATUSES.has(status)) return true;
  return false;
}

const teamLogo = (name, id) =>
  id
    ? `/icons/team_logos/${id}.png`
    : teamLogoMap[name] || "/icons/team_logos/default.png";

const teamLogoFallback = (id) =>
  id
    ? `https://media.api-sports.io/football/teams/${id}.png`
    : "/icons/team_logos/default.png";

function extractGoals(m) {
  const [sh, sa] = parseScore(m?.score);
  if (sh != null && sa != null) return { home: sh, away: sa };
  const gh = Number(m?.home_goals ?? m?.home_score);
  const ga = Number(m?.away_goals ?? m?.away_score);
  if (Number.isFinite(gh) && Number.isFinite(ga)) return { home: gh, away: ga };
  return { home: null, away: null };
}

function scoreStyleBySemantics(homeGoals, awayGoals) {
  if (homeGoals == null || awayGoals == null) {
    return "text-white/90 font-semibold";
  }
  const diff = Math.abs(homeGoals - awayGoals);
  const maxGoals = Math.max(homeGoals, awayGoals);
  if (homeGoals === awayGoals) return "text-white/75 font-medium";
  if (diff >= 3 || (diff >= 2 && maxGoals >= 3)) return "text-white font-semibold";
  if (diff === 1) return "text-white/90 font-medium";
  return "text-white/85 font-medium";
}

function resultContextTag(homeGoals, awayGoals) {
  if (homeGoals == null || awayGoals == null) return "Match Finished";
  const total = homeGoals + awayGoals;
  if (homeGoals === awayGoals) return "Draw";
  if ((homeGoals === 0 && awayGoals > 0) || (awayGoals === 0 && homeGoals > 0)) return "Clean Sheet";
  if (total >= 5) return "High Scoring";
  if (Math.abs(homeGoals - awayGoals) >= 3) return "Dominant Win";
  return "Narrow Win";
}

function buildMatchSummary(m) {
  if (isLiveMatch(m)) {
    const minute = liveMinuteLabel(m, "ru");
    return minute
      ? `Матч в лайве: ${minute}. Детали и статистика обновляются по ходу игры.`
      : "Матч в лайве. Детали и статистика обновляются по ходу игры.";
  }
  const { home, away } = extractGoals(m);
  if (home == null || away == null) return "Матч завершён. Откройте детали для полного разбора.";
  const total = home + away;
  const diff = Math.abs(home - away);
  const winner = home > away ? m?.home_team : away > home ? m?.away_team : null;

  if (home === away && total <= 2) return "Равная игра без большого количества моментов.";
  if (home === away) return "Результативная ничья: матч держал темп до финального свистка.";
  if (total >= 5) return "Открытая игра с высоким темпом и большим числом опасных атак.";
  if (diff >= 3 && winner) return `${winner} уверенно контролировал ход матча.`;
  if (diff === 1) return "Матч решили отдельные эпизоды и реализация в ключевых моментах.";
  return "Команды долго шли рядом, но победитель оказался точнее в завершающей фазе.";
}

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

function eventToneClass(kind) {
  if (kind === "goal") return "text-emerald-200";
  if (kind === "own_goal") return "text-amber-200";
  if (kind === "yellow" || kind === "red") return "text-white/85";
  if (kind === "sub") return "text-sky-200";
  return "text-white/80";
}

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
    <div>
      <div className="mb-2 text-xs font-medium text-white/60 tracking-wide">
        {title}
      </div>
      <div className="grid grid-cols-2 md:grid-cols-3 gap-x-5 gap-y-2">
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
              className="inline-flex items-center gap-2 text-xs text-white/80 hover:text-white/95"
            >
              <span
                className={clsx(
                  "inline-flex items-center justify-center rounded-full ring-1 ring-white/10 overflow-hidden bg-white/[0.02]",
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
              <span className="truncate max-w-[140px]">{name}</span>
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

  const groupSubsByMinute = (list) => {
    const map = new Map();
    for (const s of list) {
      const key = Number(s.minute) || 0;
      if (!map.has(key)) map.set(key, []);
      map.get(key).push(s);
    }
    return [...map.entries()]
      .sort((a, b) => a[0] - b[0])
      .map(([minute, items]) => ({ minute, items }));
  };

  const subsHomeGrouped = groupSubsByMinute(subsHome);
  const subsAwayGrouped = groupSubsByMinute(subsAway);

  const mvpId = useMemo(() => {
    const candidates = [...homePins, ...awayPins]
      .map((p) => {
        const hm = metaMaps.get?.(homeId)?.get?.(p.player_id);
        const am = metaMaps.get?.(awayId)?.get?.(p.player_id);
        const rating = Number(hm?.rating ?? am?.rating ?? p?.rating);
        return { id: p.player_id, rating };
      })
      .filter((x) => Number.isFinite(x.rating));
    if (!candidates.length) return null;
    candidates.sort((a, b) => b.rating - a.rating);
    return candidates[0].id;
  }, [homePins, awayPins, metaMaps, homeId, awayId]);

  if (!lineupsData) {
    return (
      <div className="mt-4 text-sm text-muted">
        {loadingLineups ? "Загружаем составы…" : "Нет данных по составам."}
      </div>
    );
  }

  return (
    <div className="mt-4 space-y-4">
      <div className="origin-top scale-[0.9]">
        <FootballPitchPro
          homePlayers={homePins}
          awayPlayers={awayPins}
          homeMeta={metaMaps.get?.(homeId)}
          awayMeta={metaMaps.get?.(awayId)}
          mvpId={mvpId}
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
        <div>
          <div className="mb-2 text-xs font-medium text-white/60 tracking-wide">
            Замены • {m.home_team}
          </div>
          {subsHomeGrouped.length ? (
            subsHomeGrouped.map((g, i) => (
              <div
                key={`hs-${i}`}
                className="grid grid-cols-[48px_minmax(0,1fr)] gap-3 py-2 hover:bg-white/[0.03] rounded-md"
              >
                <div className="flex items-start justify-center pt-0.5">
                  <span className="rounded-full bg-white/[0.08] px-2 py-0.5 text-[11px] text-white/85">
                    {g.minute}'
                  </span>
                </div>
                <div className="space-y-1">
                  {g.items.map((s, idx) => (
                    <div key={`hso-${i}-${idx}`}>
                      <div className="flex items-center gap-2 text-[12px] text-rose-300">
                        <span>⬇</span>
                        <AvatarCircle pid={s.out_id} ring="ring-white/10" />
                        <span className="truncate">{s.out_name}</span>
                      </div>
                      <div className="flex items-center gap-2 text-[12px] text-emerald-300 mt-0.5">
                        <span>⬆</span>
                        <AvatarCircle pid={s.in_id} ring="ring-white/10" />
                        <span className="truncate">{s.in_name}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ))
          ) : (
            <div className="text-xs text-white/45">—</div>
          )}
        </div>

        <div>
          <div className="mb-2 text-xs font-medium text-white/60 tracking-wide text-right">
            Замены • {m.away_team}
          </div>
          {subsAwayGrouped.length ? (
            subsAwayGrouped.map((g, i) => (
              <div
                key={`as-${i}`}
                className="grid grid-cols-[minmax(0,1fr)_48px] gap-3 py-2 hover:bg-white/[0.03] rounded-md"
              >
                <div className="space-y-1 text-right">
                  {g.items.map((s, idx) => (
                    <div key={`aso-${i}-${idx}`}>
                      <div className="flex items-center gap-2 text-[12px] text-rose-300 justify-end">
                        <span className="truncate">{s.out_name}</span>
                        <AvatarCircle pid={s.out_id} ring="ring-white/10" />
                        <span>⬇</span>
                      </div>
                      <div className="flex items-center gap-2 text-[12px] text-emerald-300 mt-0.5 justify-end">
                        <span className="truncate">{s.in_name}</span>
                        <AvatarCircle pid={s.in_id} ring="ring-white/10" />
                        <span>⬆</span>
                      </div>
                    </div>
                  ))}
                </div>
                <div className="flex items-start justify-center pt-0.5">
                  <span className="rounded-full bg-white/[0.08] px-2 py-0.5 text-[11px] text-white/85">
                    {g.minute}'
                  </span>
                </div>
              </div>
            ))
          ) : (
            <div className="text-xs text-white/45 text-right">—</div>
          )}
        </div>
      </div>

      {/* СОБЫТИЯ */}
      <div>
        <div className="mb-3 text-xs font-medium text-white/60 tracking-wide">
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
              <div className="mb-1 text-[11px] uppercase tracking-[0.18em] text-white/45 font-semibold">
                {title}
              </div>

              <div className="grid md:grid-cols-2 gap-3">
                {/* HOME SIDE */}
                <div className="space-y-2">
                  {homeList.length ? (
                    homeList.map((ev, i) => (
                      <div key={`h-${k}-${i}`} className="flex justify-start">
                        <div className={clsx("inline-flex items-center gap-2 text-[13px]", eventToneClass(ev.kind))}>
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
                    <div className="text-white/45 text-sm">—</div>
                  )}
                </div>

                {/* AWAY SIDE */}
                <div className="space-y-2">
                  {awayList.length ? (
                    awayList.map((ev, i) => (
                      <div key={`a-${k}-${i}`} className="flex justify-end">
                        <div className={clsx("inline-flex items-center gap-2 text-[13px]", eventToneClass(ev.kind))}>
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
                    <div className="text-white/45 text-sm text-right">—</div>
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
   MATCH EXPANDED CONTENT
================================ */
function MatchExpanded({ m }) {
  const [tab, setTab] = useState("stats");
  const [lineupsData, setLineupsData] = useState(null);
  const [loadingLineups, setLoadingLineups] = useState(false);
  const [openCard, setOpenCard] = useState(null);

  const norm = useMemo(() => normalizeLineups(lineupsData, m), [lineupsData, m]);
  const metaMaps = useMemo(() => buildMetaMaps(norm?.events || []), [norm]);

  const openLineups = async () => {
    if (lineupsData || loadingLineups || !m.fixture_id) return;
    setLoadingLineups(true);
    const ac = new AbortController();
    try {
      const res = await loadLineupsCached(m.fixture_id, ac.signal);
      setLineupsData(res?.data || null);
    } finally {
      setLoadingLineups(false);
    }
    return () => ac.abort();
  };

  return (
    <div className="w-full px-2 pt-2 pb-6 md:px-4 md:pt-3 space-y-6 bg-transparent">
      {/* tabs */}
      <div className="flex items-center justify-between">
        <div className="text-[10px] uppercase tracking-[0.16em] text-white/75">
          детали матча
        </div>
        <SegmentedTabs
          size="xs"
          items={[
            { key: "stats", label: "Статистика" },
            { key: "lineups", label: "Составы" },
          ]}
          value={tab}
          onChange={setTab}
          listClassName="gap-4"
          onItemClick={(key) => {
            if (key === "lineups") openLineups();
          }}
        />
      </div>

      {tab === "stats" ? (
        <Suspense fallback={<div className="text-muted text-sm">Загружаем…</div>}>
          <MatchStatsBlockV3 stats={m} />
        </Suspense>
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
function MatchCard({ m, highlight, onOpen }) {
  return (
    <div
      id={`fixture-${m.fixture_id}`}
      className="transition-colors"
    >
      <MatchRowCompact
        match={m}
        highlight={highlight}
        onOpen={onOpen}
        extractGoals={extractGoals}
        scoreStyleBySemantics={scoreStyleBySemantics}
        getMatchStateBadge={getMatchStateBadge}
        safeDateFormat={safeDateFormat}
        teamLogo={teamLogo}
        teamLogoFallback={teamLogoFallback}
      />
    </div>
  );
}

/* ================================
   FETCH JSON SAFE
================================ */
function seasonDateRangeGlobal(seasonStr) {
  const y = Number(seasonStr) || 2025;
  return { from: `${y}-07-01`, to: `${y + 1}-06-30` };
}

/* ================================
   MAIN PAGE
================================ */
export default function MatchesPageV3() {
  const { t, language } = useLanguage();
  const [searchParams, setSearchParams] = useSearchParams();
  const navigate = useNavigate();

  const DEFAULT_LEAGUE = "Premier League";
  const DEFAULT_SEASON = "2026";

  const [league, setLeague] = useState(
    searchParams.get("league") || DEFAULT_LEAGUE
  );
  const [season, setSeason] = useState(
    searchParams.get("season") || DEFAULT_SEASON
  );

  const [matches, setMatches] = useState([]);
  const [visibleRoundCount, setVisibleRoundCount] = useState(RESULTS_INITIAL_ROUNDS);
  const loadMoreRoundsRef = useRef(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [highlightId, setHighlightId] = useState(null);
  const [refreshTick, setRefreshTick] = useState(0);
  const [showHint, setShowHint] = useState(() => {
    try {
      return localStorage.getItem("results_hint_seen") !== "1";
    } catch {
      return true;
    }
  });

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
  }, [league, season, refreshTick]);

  useEffect(() => {
    const timer = window.setInterval(() => {
      setRefreshTick((tick) => tick + 1);
    }, RESULTS_REFRESH_INTERVAL);

    return () => window.clearInterval(timer);
  }, []);

  const seasonDateRange = (seasonStr) => {
    return seasonDateRangeGlobal(seasonStr || DEFAULT_SEASON);
  };

  // Load matches
  useEffect(() => {
    const ac = new AbortController();
    const key = `${league}|${season}`;
    const cached = resultsCache.get(key);
    const freshCached =
      cached && Date.now() - cached.t < RESULTS_CACHE_TTL ? cached.v : null;

    if (freshCached) {
      setMatches(freshCached);
      setLoading(false);
    }

    (async () => {
      try {
        setLoading(!freshCached);
        setError("");
        if (!freshCached) setMatches([]);

        const list = await fetchMatchesV3({
          league,
          season,
          limit: 240,
          lookbackDays: isInternationalLongCycleLeague(league) ? 0 : RESULTS_LOOKBACK_DAYS,
        }, ac.signal);
        const played = list.filter((m) => isPlayedMatch(m));
        const sorted = [...played].sort(
          (a, b) => matchTimestamp(b) - matchTimestamp(a)
        );
        resultsCache.set(key, { t: Date.now(), v: sorted });
        setMatches(sorted);
      } catch (e) {
        if (e.name !== "AbortError") setError(e.message || String(e));
      } finally {
        setLoading(false);
      }
    })();

    return () => ac.abort();
  }, [league, season]);

  useEffect(() => {
    setVisibleRoundCount(RESULTS_INITIAL_ROUNDS);
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

    const groups = [...map.values()];
    for (const g of groups) {
      g.items.sort((a, b) => matchTimestamp(b) - matchTimestamp(a));
      g.latestTs = g.items.length ? matchTimestamp(g.items[0]) : 0;
    }

    return groups.sort((a, b) => {
      if (b.latestTs !== a.latestTs) return b.latestTs - a.latestTs;
      return b.num - a.num;
    });
  }, [matches]);

  const visibleGroups = useMemo(
    () => grouped.slice(0, visibleRoundCount),
    [grouped, visibleRoundCount]
  );

  useEffect(() => {
    const el = loadMoreRoundsRef.current;
    if (!el || visibleRoundCount >= grouped.length) return;
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setVisibleRoundCount((count) =>
              Math.min(count + RESULTS_ROUND_STEP, grouped.length)
            );
          }
        });
      },
      { rootMargin: "700px 0px" }
    );
    io.observe(el);
    return () => io.disconnect();
  }, [grouped.length, visibleRoundCount]);

  return (
    <div className="type-page w-full min-w-0 overflow-x-hidden px-1 py-5 sm:px-4 sm:py-8">
      {/* HEADER */}
      <div>
        <div className="surface-hero p-4 sm:p-6 md:p-8">
          <div className="mb-5 flex flex-wrap items-center gap-2">
            <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] px-2.5 py-1.5 text-[10px] font-medium uppercase tracking-[0.16em] text-white/65 sm:px-3 sm:text-[11px] sm:tracking-[0.18em]">
              <Sparkles className="h-3.5 w-3.5 text-violet-200" />
              Match archive
            </div>
            <div className="inline-flex items-center gap-2 rounded-full border border-emerald-400/16 bg-emerald-400/8 px-2.5 py-1.5 text-[10px] uppercase tracking-[0.16em] text-emerald-100/76 sm:px-3 sm:text-[11px] sm:tracking-[0.18em]">
              <Radio className="h-3.5 w-3.5" />
              {grouped.length} rounds indexed
            </div>
          </div>
          <div className="flex flex-col items-start justify-between gap-4 sm:flex-row">
            <div className="min-w-0 space-y-1.5">
              <div className="type-eyebrow">
                {t("tournamentMatches")}
              </div>

              <div className="type-page-title break-words text-xl sm:text-2xl">
                {t("resultsTitle")} · {league}
              </div>

              <p className="type-subtitle max-w-[640px]">
                {t("resultsLead")}
              </p>
            </div>

            <div className="flex w-full min-w-0 flex-row items-end justify-between gap-3 sm:w-auto sm:flex-col sm:items-end sm:justify-start">
              <span className="text-[10px] uppercase tracking-[0.18em] text-muted mb-1">
                {t("seasonUpper")}
              </span>
              <span className="text-sm text-white/85">
                {season}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* STATES */}
      {loading && (
        <div className="surface-loading">
          {t("loadingMatches")}
        </div>
      )}

      {!loading && error && (
        <div className="surface-error">
          {t("errorPrefix")}: {error}
        </div>
      )}

      {!loading && !error && matches.length === 0 && (
        <div className="surface-empty">
          {t("noMatches")}
        </div>
      )}

      {!loading && !error && matches.length > 0 && showHint && (
        <div className="surface-note text-xs sm:text-sm">
          {t("openMatchHint")}
        </div>
      )}

      {/* GROUPED BY ROUND */}
      {!loading &&
        !error &&
        visibleGroups.map((g, idx) => (
          <MatchRoundSection
            key={g.label}
            group={g}
            index={idx}
            language={language}
            humanRoundLabel={humanRoundLabel}
            matchesCountLabel={t("matchesCount")}
            renderMatchCard={(m, matchIdx) => (
              <MatchCard
                key={m.fixture_id || matchIdx}
                m={m}
                highlight={String(highlightId) === String(m.fixture_id)}
                onOpen={() => {
                  if (showHint) {
                    setShowHint(false);
                    try {
                      localStorage.setItem("results_hint_seen", "1");
                    } catch {}
                  }
                  const q = new URLSearchParams({
                    league,
                    season,
                  });
                  navigate(`/match/${m.fixture_id}?${q.toString()}`);
                }}
              />
            )}
          />
        ))}

      {!loading && !error && visibleRoundCount < grouped.length && (
        <div ref={loadMoreRoundsRef} className="py-6 text-center text-xs text-slate-500">
          {t("loadingMoreRounds")}
        </div>
      )}

      {/* END grouped */}
</div>
);
}
