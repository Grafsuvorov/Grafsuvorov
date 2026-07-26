import { useEffect, useMemo, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { ArrowRight, Sparkles } from "lucide-react";
import { useLanguage } from "@/context/LanguageContext.jsx";
import { authFetch } from "@/lib/authFetch";
import SafeImg from "@/components/SafeImg";
import { loadFavorites } from "@/lib/favoritesStorage.js";
import {
  isFavoriteLeague,
  loadFavoriteLeagues,
  toggleFavoriteLeague,
} from "@/lib/favoriteLeaguesStorage.js";
import { loadRecentMatches } from "@/lib/recentMatches.js";
import { isLiveMatch } from "@/lib/matchStatus";

const TOP_LEAGUES = [
  "Premier League",
  "La Liga",
  "Bundesliga",
  "Serie A",
  "Ligue 1",
];

function teamLogo(teamId) {
  return teamId ? `/icons/team_logos/${teamId}.png` : "/icons/team_logos/default.png";
}

function leagueLogo(name) {
  return `/icons/${String(name).replace(/\s/g, "_")}.png`;
}

function formatKickoff(value) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(+date)) return String(value);
  return new Intl.DateTimeFormat("en-GB", {
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function parseMatchTime(match) {
  const raw = match?.kickoff_at || match?.kickoff_local || match?.datetime || match?.date;
  if (!raw) return null;

  const normalized = String(raw).trim();
  let parsed = new Date(normalized);
  if (Number.isFinite(parsed.getTime())) return parsed;

  const localDateTime = normalized.match(/^(\d{2})\.(\d{2})(?:\.(\d{4}))?\s+(\d{2}):(\d{2})$/);
  if (localDateTime) {
    const now = new Date();
    const [, dd, mm, yyyy, hh, min] = localDateTime;
    parsed = new Date(
      Number(yyyy || now.getFullYear()),
      Number(mm) - 1,
      Number(dd),
      Number(hh),
      Number(min)
    );
    return Number.isFinite(parsed.getTime()) ? parsed : null;
  }

  const localDate = normalized.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (localDate) {
    const [, yyyy, mm, dd] = localDate;
    parsed = new Date(Number(yyyy), Number(mm) - 1, Number(dd), 12, 0, 0);
    return Number.isFinite(parsed.getTime()) ? parsed : null;
  }

  return null;
}

function isExpiredLiveStatus(match) {
  const statusRaw = match?.status_short || match?.short_status || match?.status_text || match?.status || "";
  const status = String(statusRaw).trim().toUpperCase();
  if (!status) return false;

  const kickoff = parseMatchTime(match);
  if (!kickoff) return false;

  const diffMinutes = Math.floor((Date.now() - kickoff.getTime()) / 60000);
  if (!Number.isFinite(diffMinutes) || diffMinutes <= 0) return false;

  if (status === "1H" || status.includes("FIRST HALF")) return diffMinutes > 80;
  if (status === "HT" || status === "HALF TIME" || status === "HALFTIME" || status.includes("BREAK TIME")) return diffMinutes > 100;
  if (status === "2H" || status.includes("SECOND HALF")) return diffMinutes > 150;
  if (status === "ET" || status.includes("EXTRA TIME")) return diffMinutes > 185;
  if (status === "PEN" || status.includes("PENALTY")) return diffMinutes > 200;
  if (status === "LIVE" || status === "P") return diffMinutes > 150;

  return false;
}

function isLive(match) {
  if (isExpiredLiveStatus(match)) return false;
  return isLiveMatch(match);
}

function bestPickLabel(pick) {
  if (!pick) return "";
  const type = String(pick.best_bet_type || "").toUpperCase();
  const outcome = String(pick.best_bet_outcome || "").toUpperCase();
  if (type === "1X2") {
    if (outcome === "HOME") return "1";
    if (outcome === "DRAW") return "X";
    if (outcome === "AWAY") return "2";
  }
  if (type === "OU25") {
    if (outcome === "OVER") return "Over 2.5";
    if (outcome === "UNDER") return "Under 2.5";
  }
  return pick.best_bet_outcome || pick.best_bet_type || "";
}

function bestPickTone(pick, t) {
  if (!pick) return "";
  if (Number.isFinite(Number(pick.best_bet_ev))) return `${t("bestSignalToday")} · ${((Number(pick.best_bet_ev) || 0) * 100).toFixed(1)}% EV`;
  return t("bestSignalToday");
}

function buildPath(path, league, season, extra = {}) {
  const params = new URLSearchParams();
  if (league) params.set("league", league);
  if (season) params.set("season", season);
  Object.entries(extra).forEach(([key, value]) => {
    if (value == null || value === "") return;
    params.set(key, String(value));
  });
  return `${path}?${params.toString()}`;
}

async function fetchJsonSafe(url, signal) {
  const response = await authFetch(url, { signal });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return response.json();
}

function MatchChip({ match, league, season, t }) {
  const target = buildPath(
    `/match/${match.fixture_id}`,
    match.league || league,
    match.season || season
  );

  return (
    <Link
      to={target}
      className="grid min-w-0 grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center gap-2 rounded-2xl bg-white/[0.035] px-3 py-3 ring-1 ring-white/[0.04] transition hover:bg-white/[0.055]"
    >
      <div className="flex min-w-0 items-center gap-2">
        <SafeImg
          src={teamLogo(match.home_team_id)}
          fallbackSrc="/icons/team_logos/default.png"
          className="h-6 w-6 shrink-0 object-contain"
        />
        <span className="truncate text-sm text-white/90">{match.home_team}</span>
      </div>

      <div className="min-w-[72px] text-center">
        {isLive(match) ? (
          <div className="space-y-1">
            <div className="text-[11px] font-semibold uppercase tracking-[0.12em] text-rose-300">
              LIVE
            </div>
            <div className="text-sm font-semibold text-white">
              {match.home_goals ?? 0} - {match.away_goals ?? 0}
            </div>
          </div>
        ) : (
          <div className="space-y-1">
            <div className="text-xs text-white/50">{formatKickoff(match.kickoff_local || match.datetime || match.date)}</div>
            <div className="text-[11px] uppercase tracking-[0.12em] text-white/35">
              {t("matchCenter")}
            </div>
          </div>
        )}
      </div>

      <div className="flex min-w-0 items-center justify-end gap-2">
        <span className="truncate text-right text-sm text-white/90">{match.away_team}</span>
        <SafeImg
          src={teamLogo(match.away_team_id)}
          fallbackSrc="/icons/team_logos/default.png"
          className="h-6 w-6 shrink-0 object-contain"
        />
      </div>
    </Link>
  );
}

export default function DashboardPage() {
  const { t } = useLanguage();
  const [search] = useSearchParams();
  const league = search.get("league") || "Premier League";
  const season = search.get("season") || "2025";
  const [loading, setLoading] = useState(true);
  const [liveMatches, setLiveMatches] = useState([]);
  const [upcomingMatches, setUpcomingMatches] = useState([]);
  const [bestPicks, setBestPicks] = useState([]);
  const [favoriteTeams, setFavoriteTeams] = useState(() =>
    loadFavorites("favorites_teams").slice(0, 5)
  );
  const [favoriteLeagues, setFavoriteLeagues] = useState(() =>
    loadFavoriteLeagues().slice(0, 5)
  );
  const [favoriteMatches, setFavoriteMatches] = useState(() =>
    loadFavorites("favorites_matches").slice(0, 4)
  );
  const [recentMatches, setRecentMatches] = useState(() =>
    loadRecentMatches().slice(0, 4)
  );
  const [recentLeagues, setRecentLeagues] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem("recent_leagues") || "[]").slice(0, 5);
    } catch {
      return [];
    }
  });
  const [leagueSaved, setLeagueSaved] = useState(() => isFavoriteLeague(league));

  useEffect(() => {
    const controller = new AbortController();
    (async () => {
      try {
        setLoading(true);
        const now = new Date();
        const from = new Date(now);
        from.setDate(from.getDate() - 1);
        const to = new Date(now);
        to.setDate(to.getDate() + 3);
        const fmt = (d) => d.toISOString().slice(0, 10);
        const params = new URLSearchParams({
          league,
          season,
          include_upcoming: "true",
          from_date: fmt(from),
          to_date: fmt(to),
          limit: "40",
        });
        const picksParams = new URLSearchParams({
          league,
          season,
          from_date: fmt(from),
          to_date: fmt(to),
          top_n: "6",
          return_fixtures: "true",
        });
        const liveLeagueRequests = TOP_LEAGUES.map((liveLeague) => {
          const liveParams = new URLSearchParams({
            league: liveLeague,
            season,
            include_upcoming: "true",
            from_date: fmt(from),
            to_date: fmt(to),
            limit: "20",
          });
          return fetchJsonSafe(`/api/matches_v3?${liveParams.toString()}`, controller.signal).catch(() => []);
        });

        const [data, picksData, ...liveLeagueData] = await Promise.all([
          fetchJsonSafe(`/api/matches_v3?${params.toString()}`, controller.signal),
          fetchJsonSafe(`/api/best-picks?${picksParams.toString()}`, controller.signal).catch(() => null),
          ...liveLeagueRequests,
        ]);
        const rows = Array.isArray(data) ? data : [];
        const liveRows = liveLeagueData
          .flatMap((chunk) => (Array.isArray(chunk) ? chunk : []))
          .filter(isLive)
          .sort((a, b) => {
            const aTime = new Date(a?.kickoff_at || a?.date || 0).getTime();
            const bTime = new Date(b?.kickoff_at || b?.date || 0).getTime();
            return (bTime || 0) - (aTime || 0);
          });
        const uniqueLiveRows = Array.from(
          new Map(liveRows.map((match) => [String(match.fixture_id), match])).values()
        ).slice(0, 6);

        setLiveMatches(uniqueLiveRows);
        setUpcomingMatches(rows.filter((m) => !isLive(m)).slice(0, 6));
        setBestPicks(Array.isArray(picksData?.fixtures) ? picksData.fixtures.slice(0, 4) : []);
      } catch {
        setLiveMatches([]);
        setUpcomingMatches([]);
        setBestPicks([]);
      } finally {
        setLoading(false);
      }
    })();
    return () => controller.abort();
  }, [league, season]);

  useEffect(() => {
    setLeagueSaved(isFavoriteLeague(league));
  }, [league]);

  useEffect(() => {
    const sync = () => {
      setFavoriteTeams(loadFavorites("favorites_teams").slice(0, 5));
      setFavoriteLeagues(loadFavoriteLeagues().slice(0, 5));
      setFavoriteMatches(loadFavorites("favorites_matches").slice(0, 4));
      setRecentMatches(loadRecentMatches().slice(0, 4));
      setLeagueSaved(isFavoriteLeague(league));
      try {
        setRecentLeagues(JSON.parse(localStorage.getItem("recent_leagues") || "[]").slice(0, 5));
      } catch {
        setRecentLeagues([]);
      }
    };

    sync();
    window.addEventListener("favorites:update", sync);
    window.addEventListener("recent-matches:update", sync);
    window.addEventListener("storage", sync);
    return () => {
      window.removeEventListener("favorites:update", sync);
      window.removeEventListener("recent-matches:update", sync);
      window.removeEventListener("storage", sync);
    };
  }, [league]);

  const quickActions = useMemo(
    () => [
      { title: t("openResults"), to: buildPath("/matches-v3", league, season), accent: "Live and recent" },
      { title: t("openSchedule"), to: buildPath("/schedule", league, season), accent: "Next fixtures" },
      { title: t("openPicks"), to: buildPath("/best-picks", league, season), accent: "Model signals" },
      { title: t("openTable"), to: buildPath("/table", league, season), accent: "Standings view" },
    ],
    [league, season, t]
  );

  const heroMatch = useMemo(() => {
    if (bestPicks.length) {
      const pick = bestPicks[0];
      return {
        kind: "pick",
        fixtureId: pick.fixture_id,
        homeTeam: pick.home_team,
        awayTeam: pick.away_team,
        league: pick.league || league,
        season: pick.season || season,
        label: t("matchOfTheDay"),
        sublabel: bestPickTone(pick, t),
        badge: bestPickLabel(pick),
      };
    }
    if (liveMatches.length) {
      const match = liveMatches[0];
      return {
        kind: "live",
        fixtureId: match.fixture_id,
        homeTeam: match.home_team,
        awayTeam: match.away_team,
        league: match.league || league,
        season: match.season || season,
        label: t("matchOfTheDay"),
        sublabel: t("livePriority"),
        badge: "LIVE",
      };
    }
    if (upcomingMatches.length) {
      const match = upcomingMatches[0];
      return {
        kind: "upcoming",
        fixtureId: match.fixture_id,
        homeTeam: match.home_team,
        awayTeam: match.away_team,
        league: match.league || league,
        season: match.season || season,
        label: t("matchOfTheDay"),
        sublabel: t("upcomingPriority"),
        badge: formatKickoff(match.kickoff_local || match.datetime || match.date),
      };
    }
    return null;
  }, [bestPicks, liveMatches, upcomingMatches, league, season, t]);

  return (
    <div className="type-page w-full min-w-0 overflow-x-hidden px-1 py-5 sm:px-4 sm:py-8">
      <div>
        <div className="surface-hero p-4 sm:p-6 md:p-8">
          <div className="mb-5 flex flex-wrap items-center gap-2">
            <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] px-2.5 py-1.5 text-[10px] font-medium uppercase tracking-[0.16em] text-white/65 sm:px-3 sm:text-[11px] sm:tracking-[0.18em]">
              <Sparkles className="h-3.5 w-3.5 text-violet-200" />
              Matchday control room
            </div>
            <div className="inline-flex max-w-full items-center rounded-full border border-emerald-400/14 bg-emerald-400/8 px-2.5 py-1.5 text-[10px] uppercase tracking-[0.16em] text-emerald-100/75 sm:px-3 sm:text-[11px] sm:tracking-[0.18em]">
              {league}
            </div>
          </div>

          <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_360px] xl:items-start">
            <div className="flex flex-col items-start justify-between gap-4 sm:flex-row">
              <div className="min-w-0 space-y-1.5">
                <div className="type-eyebrow">
                  {t("todayEyebrow")}
                </div>

                <div className="type-page-title text-xl sm:text-2xl">
                  {t("todayTitle")} · {league}
                </div>

                <p className="type-subtitle max-w-[640px]">
                  {t("todayLead")}
                </p>
              </div>

              <div className="flex w-full min-w-0 flex-row items-end justify-between gap-3 sm:w-auto sm:flex-col sm:items-end sm:justify-start">
                <span className="mb-1 text-[10px] uppercase tracking-[0.18em] text-muted">
                  {t("seasonUpper")}
                </span>
                <span className="text-sm text-white/85 sm:text-base">{season}</span>
                <button
                  type="button"
                  onClick={() => setLeagueSaved(toggleFavoriteLeague(league, season))}
                  className="surface-button h-9 px-3 py-1.5 text-[11px] font-medium sm:h-10 sm:text-xs"
                >
                  <span aria-hidden="true">{leagueSaved ? "★" : "☆"}</span>
                  {leagueSaved ? t("removeLeague") : t("saveLeague")}
                </button>
              </div>
            </div>

            <section className="grid gap-3 sm:grid-cols-3 xl:grid-cols-1">
              <StatTile
                label={t("liveNow")}
                value={loading ? "…" : String(liveMatches.length)}
                tone="rose"
                compact
              />
              <StatTile
                label={t("upcomingSoon")}
                value={loading ? "…" : String(upcomingMatches.length)}
                tone="cyan"
                compact
              />
              <StatTile
                label={t("topLeaguesShort")}
                value={String(TOP_LEAGUES.length)}
                tone="violet"
                compact
              />
            </section>
          </div>
        </div>
      </div>

      {heroMatch ? (
        <Link
          to={buildPath(`/match/${heroMatch.fixtureId}`, heroMatch.league, heroMatch.season)}
          className="block rounded-[26px] bg-[linear-gradient(135deg,rgba(124,58,237,0.22),rgba(14,165,233,0.12),rgba(255,255,255,0.03))] p-4 shadow-[0_18px_46px_rgba(0,0,0,0.28)] ring-1 ring-white/[0.06] transition hover:bg-[linear-gradient(135deg,rgba(124,58,237,0.28),rgba(14,165,233,0.16),rgba(255,255,255,0.04))] sm:p-6"
        >
          <div className="grid gap-3 lg:grid-cols-[minmax(0,1fr)_auto] lg:items-center">
            <div className="space-y-2">
              <div className="text-[11px] uppercase tracking-[0.18em] text-white/45">
                {heroMatch.label}
              </div>
              <div className="text-lg font-semibold leading-tight text-white sm:text-2xl">
                {heroMatch.homeTeam} vs {heroMatch.awayTeam}
              </div>
              <div className="text-sm text-white/65">
                {heroMatch.league} · {heroMatch.sublabel}
              </div>
            </div>
            <div className="flex flex-row items-center justify-between gap-3 lg:flex-col lg:items-end">
              <div className="rounded-full border border-white/10 bg-white/[0.06] px-3 py-1.5 text-[11px] font-semibold text-white/85 sm:text-xs">
                {heroMatch.badge}
              </div>
              <div className="text-[13px] font-medium text-violet-200 sm:text-sm">
                {t("openMatchCenter")} →
              </div>
            </div>
          </div>
        </Link>
      ) : null}

      <section className="space-y-3">
        <div className="text-[11px] uppercase tracking-[0.18em] text-white/45">
          {t("quickActions")}
        </div>
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          {quickActions.map((item) => (
            <Link
              key={item.to}
              to={item.to}
              className="group rounded-[24px] border border-white/[0.06] bg-[linear-gradient(180deg,rgba(255,255,255,0.045),rgba(255,255,255,0.016))] px-4 py-4 text-white shadow-[0_14px_34px_rgba(0,0,0,0.28)] transition hover:border-white/[0.1] hover:bg-white/[0.06]"
            >
              <div className="flex items-start justify-between gap-3">
                <div>
                  <div className="text-sm font-semibold text-white">{item.title}</div>
                  <div className="mt-1 text-xs text-white/48">{item.accent}</div>
                </div>
                <ArrowRight className="mt-0.5 h-4 w-4 text-white/42 transition group-hover:translate-x-0.5 group-hover:text-white/78" />
              </div>
              <div className="mt-4 text-[11px] uppercase tracking-[0.16em] text-white/34">
                {league} · {season}
              </div>
            </Link>
          ))}
        </div>
      </section>

      <section className="grid gap-4 xl:grid-cols-[minmax(0,1.25fr)_minmax(320px,0.75fr)]">
        <Panel title={t("liveNow")} actionTo={buildPath("/matches-v3", league, season)} actionLabel={t("viewAll")}>
          <div className="space-y-2">
            {!loading && liveMatches.length === 0 ? (
              <EmptyState text={t("noLiveMatches")} />
            ) : (
              liveMatches.map((match) => (
                <MatchChip key={match.fixture_id} match={match} league={league} season={season} t={t} />
              ))
            )}
          </div>
        </Panel>

        <div className="space-y-4">
          <Panel title={t("topLeaguesShort")}>
            <div className="grid gap-2">
              {TOP_LEAGUES.map((item) => (
                <LeagueJumpCard key={item} item={item} season={season} subtitle={t("jumpIn")} />
              ))}
            </div>
          </Panel>

          <Panel title={t("recentLeagues")}>
            <div className="grid gap-2">
              {recentLeagues.length ? (
                recentLeagues.map((item) => (
                  <LeagueJumpCard key={item} item={item} season={season} subtitle={t("openLeague")} compact />
                ))
              ) : (
                <EmptyState text={t("noRecentLeagues")} />
              )}
            </div>
          </Panel>
        </div>
      </section>

      <Panel title={t("upcomingSoon")} actionTo={buildPath("/schedule", league, season)} actionLabel={t("viewAll")}>
        <div className="grid gap-2 lg:grid-cols-2">
          {!loading && upcomingMatches.length === 0 ? (
            <EmptyState text={t("noUpcomingMatches")} />
          ) : (
            upcomingMatches.map((match) => (
              <MatchChip key={match.fixture_id} match={match} league={league} season={season} t={t} />
            ))
          )}
        </div>
      </Panel>

      <Panel title={t("favoriteTeams")}>
        <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
          {favoriteTeams.length ? (
            favoriteTeams.map((team) => (
              <Link
                key={`${team.id}-${team.name}`}
                to={`/team/${team.id}?league=${encodeURIComponent(team.league || league)}&season=${team.season || season}`}
                className="flex min-w-0 items-center gap-3 rounded-2xl bg-white/[0.035] px-4 py-3 ring-1 ring-white/[0.04] transition hover:bg-white/[0.06]"
              >
                <SafeImg
                  src={teamLogo(team.id)}
                  fallbackSrc="/icons/team_logos/default.png"
                  className="h-8 w-8 shrink-0 object-contain"
                />
                <div className="min-w-0">
                  <div className="truncate text-sm font-medium text-white">{team.name}</div>
                  <div className="truncate text-xs text-white/45">{team.league || league}</div>
                </div>
              </Link>
            ))
          ) : (
            <EmptyState text={t("noFavoriteTeams")} />
          )}
        </div>
      </Panel>

      <Panel title={t("favoriteLeagues")}>
        <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
          {favoriteLeagues.length ? (
            favoriteLeagues.map((item) => (
              <LeagueJumpCard
                key={`${item.name}-${item.season || season}`}
                item={item.name}
                season={item.season || season}
                subtitle={t("openLeague")}
              />
            ))
          ) : (
            <EmptyState text={t("noFavoriteLeagues")} />
          )}
        </div>
      </Panel>

      <Panel title={t("favoriteMatches")}>
        <div className="grid gap-2 lg:grid-cols-2">
          {favoriteMatches.length ? (
            favoriteMatches.map((match) => (
              <MatchChip
                key={`fav-match-${match.fixture_id}`}
                match={match}
                league={match.league || league}
                season={match.season || season}
                t={t}
              />
            ))
          ) : (
            <EmptyState text={t("noFavoriteMatches")} />
          )}
        </div>
      </Panel>

      <Panel title={t("bestPicksToday")} actionTo={buildPath("/best-picks", league, season)} actionLabel={t("viewAll")}>
        <div className="grid gap-2 lg:grid-cols-2">
          {bestPicks.length ? (
            bestPicks.map((pick) => (
              <Link
                key={`pick-${pick.fixture_id}`}
                to={buildPath(`/match/${pick.fixture_id}`, pick.league || league, pick.season || season)}
                className="rounded-2xl bg-white/[0.035] px-4 py-4 ring-1 ring-white/[0.04] transition hover:bg-white/[0.055]"
              >
                <div className="flex items-center justify-between gap-3">
                  <div className="min-w-0">
                    <div className="truncate text-sm font-semibold text-white">
                      {pick.home_team} vs {pick.away_team}
                    </div>
                    <div className="mt-1 text-xs text-white/45">
                      {pick.league || league}
                    </div>
                  </div>
                  <div className="rounded-xl bg-violet-500/12 px-3 py-1 text-xs font-semibold text-violet-100 ring-1 ring-violet-400/25">
                    {bestPickLabel(pick)}
                  </div>
                </div>
                <div className="mt-3 flex items-center gap-4 text-xs text-white/60">
                  <span>{t("evShort")}: {Number.isFinite(Number(pick.best_bet_ev)) ? `${(Number(pick.best_bet_ev) * 100).toFixed(1)}%` : "—"}</span>
                  <span>{t("oddsShort")}: {Number.isFinite(Number(pick.best_bet_odds)) ? Number(pick.best_bet_odds).toFixed(2) : "—"}</span>
                </div>
              </Link>
            ))
          ) : (
            <EmptyState text={t("noBestPicksToday")} />
          )}
        </div>
      </Panel>

      <Panel title={t("recentMatches")}>
        <div className="grid gap-2 lg:grid-cols-2">
          {recentMatches.length ? (
            recentMatches.map((match) => (
              <MatchChip
                key={`recent-${match.fixture_id}`}
                match={match}
                league={match.league || league}
                season={match.season || season}
                t={t}
              />
            ))
          ) : (
            <EmptyState text={t("noRecentMatches")} />
          )}
        </div>
      </Panel>

      <section className="glass-card px-5 py-5">
        <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] px-3 py-1.5 text-[11px] uppercase tracking-[0.18em] text-white/58">
          <Sparkles className="h-3.5 w-3.5 text-violet-200" />
          EdgeScore
        </div>
        <div className="mt-2 max-w-2xl text-sm leading-6 text-white/70">
          {t("productShortAbout")}
        </div>
      </section>
    </div>
  );
}

function LeagueJumpCard({ item, season, subtitle, compact = false }) {
  return (
    <Link
      to={buildPath("/table", item, season)}
      className={`flex items-center gap-3 rounded-2xl border border-white/[0.06] bg-white/[0.03] px-3 shadow-[0_10px_24px_rgba(0,0,0,0.2)] transition hover:border-white/[0.1] hover:bg-white/[0.06] ${compact ? "py-2.5" : "py-3"}`}
    >
      <SafeImg
        src={leagueLogo(item)}
        fallbackSrc="/icons/Premier_League.png"
        className="h-7 w-7 shrink-0 object-contain"
        loading="eager"
        decoding="sync"
        fetchPriority="high"
      />
      <div className="min-w-0">
        <div className="truncate text-sm font-medium text-white">{item}</div>
        <div className="text-xs text-white/45">{subtitle}</div>
      </div>
    </Link>
  );
}

function StatTile({ label, value, tone, compact = false }) {
  const toneClass =
    tone === "rose"
      ? "from-rose-500/22 to-rose-400/6"
      : tone === "cyan"
      ? "from-cyan-500/22 to-cyan-400/6"
      : "from-violet-500/22 to-violet-400/6";

  return (
    <div
      className={`rounded-[24px] border border-white/[0.06] bg-gradient-to-br ${toneClass} shadow-[0_14px_34px_rgba(0,0,0,0.24)] ring-1 ring-white/[0.04] ${
        compact ? "px-4 py-3.5 xl:min-h-[88px]" : "px-4 py-4"
      }`}
    >
      <div className="text-[11px] uppercase tracking-[0.16em] text-white/45">{label}</div>
      <div className={`${compact ? "mt-1.5 text-xl xl:text-2xl" : "mt-2 text-2xl"} font-semibold text-white`}>
        {value}
      </div>
    </div>
  );
}

function Panel({ title, actionTo, actionLabel, children }) {
  return (
    <section className="glass-card p-4 sm:p-5">
      <div className="mb-4 flex items-center justify-between gap-3">
        <div>
          <div className="text-[10px] uppercase tracking-[0.18em] text-white/42">Section</div>
          <div className="mt-1 text-sm font-semibold text-white">{title}</div>
        </div>
        {actionTo ? (
          <Link to={actionTo} className="inline-flex items-center gap-1 text-xs font-medium text-white/55 transition hover:text-white">
            {actionLabel}
            <ArrowRight className="h-3.5 w-3.5" />
          </Link>
        ) : null}
      </div>
      {children}
    </section>
  );
}

function EmptyState({ text }) {
  return (
    <div className="glass-card px-4 py-6 text-center">
      <div className="mx-auto grid h-10 w-10 place-items-center rounded-2xl border border-white/[0.06] bg-white/[0.03] text-white/55">
        <svg className="h-4 w-4" viewBox="0 0 20 20" fill="none" aria-hidden="true">
          <path d="M10 4.25v6m0 4.25h.01" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
          <circle cx="10" cy="10" r="7.25" stroke="currentColor" strokeOpacity="0.55" />
        </svg>
      </div>
      <div className="mt-3 text-sm text-white/50">{text}</div>
    </div>
  );
}
