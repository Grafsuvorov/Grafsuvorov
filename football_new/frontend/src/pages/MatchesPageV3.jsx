// src/pages/MatchesPageV3.jsx
import React, {
  useState,
  useEffect,
  useMemo,
  lazy,
  Suspense,
} from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import { authFetch } from "@/lib/authFetch";
import TeamLogoLink from "@/components/TeamLogoLink";
import { format } from "date-fns";
import clsx from "clsx";

import SafeImg from "@/components/SafeImg";
import PlayerCard from "@/components/PlayerCard";
import FootballPitchPro from "@/components/FootballPitchPro";
import { teamLogoMap } from "@/constants/teamLogoMap";
import SegmentedTabs from "@/components/ui/SegmentedTabs";
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

function humanRoundLabel(round) {
  const n = extractRoundNumber(round);
  return n ? `Тур ${n}` : String(round || "Тур");
}

/* ================================
   PERF HELPERS
================================ */
const lineupsCache = new Map();
const API_BASE = import.meta.env.VITE_API_BASE_URL || "";
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
    `${API_BASE}/api/lineups-events?fixture_id=${fixture_id}`,
    `${API_BASE}/api/match/lineups-events?fixture_id=${fixture_id}`,
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

const FINISHED_STATUSES = new Set([
  "FT",
  "AET",
  "PEN",
  "FT_PEN",
  "AET_PEN",
  "CANC",
  "ABD",
  "AWD",
  "WO",
  "FINISHED",
  "MATCH FINISHED",
]);

const LIVE_STATUS_HINTS = [
  "1H",
  "2H",
  "ET",
  "P",
  "LIVE",
  "FIRST HALF",
  "SECOND HALF",
  "EXTRA TIME",
  "HALF TIME",
  "HALFTIME",
  "BREAK TIME",
  "PEN",
  "PENALTY",
];

const POSTPONED_STATUS_HINTS = [
  "MATCH POSTPONED",
  "POSTPONED",
  "PST",
];

const CANCELLED_STATUS_HINTS = [
  "CANCELED",
  "CANCELLED",
  "MATCH CANCELLED",
  "MATCH CANCELED",
];

function isStaleLiveStatus(m) {
  const kickoffRaw = m?.kickoff_at;
  if (!kickoffRaw) return false;
  const kickoff = new Date(String(kickoffRaw).replace(" ", "T"));
  if (Number.isNaN(kickoff.getTime())) return false;

  const status = String(m?.status_short || m?.status || "").trim().toUpperCase();
  const elapsed = Number(m?.elapsed);
  const diffMinutes = Math.floor((Date.now() - kickoff.getTime()) / 60000);
  if (!Number.isFinite(diffMinutes) || diffMinutes <= 0) return false;

  if (status === "1H" || status.includes("FIRST HALF")) {
    return diffMinutes > 65 || (Number.isFinite(elapsed) && elapsed <= 45 && diffMinutes > 60);
  }
  if (status === "HT" || status === "HALF TIME" || status === "HALFTIME" || status.includes("BREAK TIME")) {
    return diffMinutes > 80;
  }
  if (status === "2H" || status.includes("SECOND HALF")) {
    return diffMinutes > 125;
  }
  if (status === "ET" || status.includes("EXTRA TIME") || status === "PEN" || status.includes("PENALTY")) {
    return diffMinutes > 170;
  }
  return diffMinutes > 140;
}

function isLiveMatch(m) {
  const statusRaw = m?.status_short || m?.status || "";
  const status = String(statusRaw).trim().toUpperCase();
  if (!status || FINISHED_STATUSES.has(status) || isStaleLiveStatus(m)) return false;
  return LIVE_STATUS_HINTS.some((hint) =>
    hint.length <= 3 ? status === hint : status.includes(hint)
  );
}

function liveMinuteLabel(m) {
  const elapsed = Number(m?.elapsed);
  const extra = Number(m?.extra);
  const statusRaw = String(m?.status_short || m?.status || "").trim().toUpperCase();
  const isHalfTime =
    statusRaw === "HT" ||
    statusRaw === "HALF TIME" ||
    statusRaw === "HALFTIME" ||
    statusRaw.includes("BREAK TIME");
  const estimatedElapsed = estimateLiveElapsed(m);
  const effectiveElapsed =
    Number.isFinite(elapsed) && elapsed > 0
      ? elapsed
      : estimatedElapsed;

  if (Number.isFinite(effectiveElapsed) && effectiveElapsed > 0) {
    const minute = Number.isFinite(extra) && extra > 0 ? `${effectiveElapsed}+${extra}'` : `${effectiveElapsed}'`;
    if (isHalfTime) return `${minute} · перерыв`;
    return minute;
  }
  if (isHalfTime) return "Перерыв";
  if (statusRaw.includes("PEN")) return "PEN";
  return "";
}

function estimateLiveElapsed(m) {
  const kickoffRaw = m?.kickoff_at;
  if (!kickoffRaw) return null;
  const kickoff = new Date(String(kickoffRaw).replace(" ", "T"));
  if (Number.isNaN(kickoff.getTime())) return null;

  const now = new Date();
  const diffMinutes = Math.floor((now.getTime() - kickoff.getTime()) / 60000);
  if (!Number.isFinite(diffMinutes) || diffMinutes <= 0) return null;

  const statusRaw = String(m?.status_short || m?.status || "").trim().toUpperCase();
  if (statusRaw === "1H" || statusRaw.includes("FIRST HALF")) {
    return Math.min(diffMinutes, 45);
  }
  if (statusRaw === "HT" || statusRaw === "HALF TIME" || statusRaw === "HALFTIME" || statusRaw.includes("BREAK TIME")) {
    return 45;
  }
  if (statusRaw === "2H" || statusRaw.includes("SECOND HALF")) {
    return Math.min(Math.max(diffMinutes - 15, 46), 90);
  }
  if (statusRaw === "ET" || statusRaw.includes("EXTRA TIME")) {
    return Math.min(Math.max(diffMinutes - 15, 91), 120);
  }
  return null;
}

function getMatchStateBadge(m) {
  if (isLiveMatch(m)) {
    return {
      kind: "live",
      label: "Live",
      sublabel: liveMinuteLabel(m) || "В игре",
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
    const minute = liveMinuteLabel(m);
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
   MATCH ROW COMPACT (как в календаре)
================================ */
function MatchRowCompact({ m, highlight, onOpen }) {
  const { home, away } = extractGoals(m);
  const semanticScoreClass = scoreStyleBySemantics(home, away);
  const homeWin = home != null && away != null && home > away;
  const awayWin = home != null && away != null && away > home;
  const badge = getMatchStateBadge(m);

  return (
    <button
      type="button"
      onClick={() => {
        onOpen?.();
      }}
      className={clsx(
        "w-full px-4 py-2.5 transition-all duration-200 ease-in-out relative rounded-xl cursor-pointer",
        "bg-transparent",
        "hover:bg-white/5",
        "grid grid-cols-[1fr_auto_1fr] items-center gap-4"
      )}
    >
      {highlight && (
        <span className="pointer-events-none absolute left-0 top-2 bottom-2 w-[3px] rounded-full bg-[linear-gradient(180deg,#8b5cf6,#6d28d9)] shadow-[0_0_10px_rgba(123,92,255,0.35)]" />
      )}
      {/* LEFT — HOME */}
      <div className="flex items-center gap-3 min-w-0">
        <TeamLogoLink teamId={m.home_team_id} stopPropagation className="block">
          <SafeImg
            src={teamLogo(m.home_team, m.home_team_id)}
            className="h-8 w-8 rounded-lg border border-glass bg-surface-2 object-contain"
            fallbackSrc={teamLogoFallback(m.home_team_id)}
          />
        </TeamLogoLink>
        <div className="min-w-0 text-left">
          <div className={clsx("text-sm text-white truncate", homeWin ? "font-semibold" : "font-medium")}>
            {m.home_team}
          </div>
          <div className="text-[11px] text-muted truncate">
            {badge ? (
              <span className="inline-flex items-center gap-2">
                <span className={`inline-flex h-5 items-center rounded-full border px-2 text-[9px] font-semibold uppercase tracking-[0.12em] ${badge.pillClass}`}>
                  {badge.label}
                </span>
                {badge.sublabel ? (
                  <span className={`tabular-nums ${badge.sublabelClass}`}>{badge.sublabel}</span>
                ) : null}
              </span>
            ) : (
              <>
                {safeDateFormat(m.date)} {m.venue ? `· ${m.venue}` : ""}
              </>
            )}
          </div>
        </div>
      </div>

      {/* CENTER — SCORE (fixed width) */}
      <div
        className="text-center flex flex-col items-center justify-center"
        style={{ width: "110px" }}
      >
        <div
          className={clsx(
            "text-[22px] font-semibold tracking-[0.02em] text-white tabular-nums leading-none",
            semanticScoreClass
          )}
        >
          {home == null || away == null ? (
            "—"
          ) : (
            <>
              <span className={homeWin ? "text-white" : awayWin ? "text-white/40" : "text-white"}>
                {home}
              </span>
              <span className="px-1 text-white/80">–</span>
              <span className={awayWin ? "text-white" : homeWin ? "text-white/40" : "text-white"}>
                {away}
              </span>
            </>
          )}
        </div>
      </div>

      {/* RIGHT — AWAY */}
      <div className="flex items-center gap-3 min-w-0 justify-end">
        <div className="text-right min-w-0">
          <div className={clsx("text-sm text-white truncate", awayWin ? "font-semibold" : "font-medium")}>
            {m.away_team}
          </div>
        </div>
        <TeamLogoLink teamId={m.away_team_id} stopPropagation className="block">
          <SafeImg
            src={teamLogo(m.away_team, m.away_team_id)}
            className="h-8 w-8 rounded-lg border border-glass bg-surface-2 object-contain"
            fallbackSrc={teamLogoFallback(m.away_team_id)}
          />
        </TeamLogoLink>
      </div>
    </button>
  );
}


/* ================================
   PREDICTION BLOCK
================================ */
function PredictionBlock() {
  return null;
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
      const j = await fetchLineupsCached(m.fixture_id, ac.signal);
      setLineupsData(j);
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
      <MatchRowCompact m={m} highlight={highlight} onOpen={onOpen} />
    </div>
  );
}

/* ================================
   FETCH JSON SAFE
================================ */
async function fetchJsonSafe(url, signal) {
  const r = await authFetch(url, { signal });
  if (r.status === 401 || r.status === 403) return null;
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
  const navigate = useNavigate();

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
  }, [league, season]);

  const seasonDateRange = (seasonStr) => {
    const y = Number(seasonStr) || Number(DEFAULT_SEASON);
    return { from: `${y}-07-01`, to: `${y + 1}-06-30` };
  };

  const isInternationalLongCycleLeague = (leagueName) => {
    const value = String(leagueName || "").toLowerCase();
    return (
      value.includes("world cup") ||
      value.includes("euro championship") ||
      value.includes("nations league") ||
      value.includes("copa america") ||
      value.includes("gold cup")
    );
  };

  // Load matches
  useEffect(() => {
    const ac = new AbortController();
    (async () => {
      try {
        setLoading(true);
        setError("");
        setMatches([]);

        const q = new URLSearchParams({
          league,
          season,
        });
        if (!isInternationalLongCycleLeague(league)) {
          const { from, to } = seasonDateRange(season);
          q.set("from_date", from);
          q.set("to_date", to);
        }

        const data = await fetchJsonSafe(
          `/api/matches_v3?${q.toString()}`,
          ac.signal
        );

        const list = Array.isArray(data) ? data : [];
        const played = list.filter((m) => isPlayedMatch(m));
        const sorted = [...played].sort(
          (a, b) => matchTimestamp(b) - matchTimestamp(a)
        );
        setMatches(sorted);
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

  return (
    <div className="w-full px-4 py-8 space-y-8">
      {/* HEADER */}
      <div>
        <div className="panel rounded-3xl p-6 md:p-8">
          <div className="flex items-start justify-between gap-4">
            <div className="space-y-1.5">
              <div className="text-[11px] uppercase tracking-[0.18em] text-muted">
                МАТЧИ ТУРНИРА
              </div>

              <div className="text-xl sm:text-2xl font-semibold text-white">
                Результаты · {league}
              </div>

              <p className="text-sm text-slate-400 max-w-[640px] leading-relaxed">
                Результаты сыгранных матчей. Нажмите на матч, чтобы открыть
                Match Center.
              </p>
            </div>

            <div className="flex flex-col items-end">
              <span className="text-[10px] uppercase tracking-[0.18em] text-muted mb-1">
                СЕЗОН
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

      {!loading && !error && matches.length > 0 && showHint && (
        <div className="text-xs text-slate-400">
          Нажми на матч, чтобы открыть Match Center.
        </div>
      )}

      {/* GROUPED BY ROUND */}
      {!loading &&
        !error &&
        grouped.map((g, idx) => (
          <section key={g.label} className={clsx("space-y-3", idx > 0 && "mt-8")}>
            {/* header */}
            <div className="px-4 md:px-6 pt-5 border-t border-white/5">
              <div className="flex items-center justify-between">
                <div className="text-[13px] uppercase tracking-[0.15em] text-white/60 whitespace-nowrap">
                  {humanRoundLabel(g.label)}
                </div>
                <span className="text-[11px] text-white/60 bg-white/5 px-3 py-1 rounded-full">
                  {g.items.length} матчей
                </span>
              </div>
            </div>

            {/* unified block — один блок с разделителями */}
            <div className="bg-transparent space-y-3">
              {g.items.map((m, idx) => (
                <MatchCard
                  key={m.fixture_id || idx}
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
              ))}
            </div>
          </section>
        ))}

      {/* END grouped */}
</div>
);
}
