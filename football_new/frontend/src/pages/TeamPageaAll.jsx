// src/pages/TeamPageaAll.jsx
import React, {
  useEffect,
  useMemo,
  useState,
  useCallback,
} from "react";
import { useParams, useSearchParams, useNavigate, useLocation } from "react-router-dom";
import { teamLogoMap } from "@/constants/teamLogoMap";
import { useAuth } from "@/auth/AuthContext.jsx";
import { http } from "@/lib/http.js";
import { hasPilotFullAccess, shouldHideMonetization } from "@/lib/pilotAccess.js";
import {
  fetchLeagueTableForTeam,
  fetchOneMatch,
  fetchTeamOverview,
  fetchTeamResults,
  fetchTeamSchedule,
} from "@/lib/teamApi";
import {
  buildFormSummary,
  buildPeriodStats,
  buildUpcomingTeamSchedule,
  filterResultsByVenue,
  getRecentResults,
  groupScheduleByRound,
  pickLeagueRank,
  resolveTeamLeagueName,
  resultForTeam,
} from "@/lib/teamSelectors.js";

import { loadFavorites, saveFavorites } from "@/lib/favoritesStorage.js";
import { buildMatchPack } from "@/lib/matchInsights";
import SegmentedTabs from "@/components/ui/SegmentedTabs";
import {
  TeamResultsSection,
  TeamScheduleSection,
  TeamStatsSection,
} from "@/components/team/TeamPageSections.jsx";
import { Segmented } from "@/components/team/TeamPageWidgets.jsx";
import { useLanguage } from "@/context/LanguageContext.jsx";

/* ================= helpers & fallbacks ================= */
const FALLBACK_SVG = {
  team:
    "data:image/svg+xml;utf8," +
    encodeURIComponent(
      `<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>
         <rect width='100%' height='100%' fill='#020617'/>
         <path d='M20 4l12 6v8c0 8-6 14-12 18C14 32 8 26 8 18V10l12-6z' fill='#0f172a'/>
       </svg>`
    ),
  league:
    "data:image/svg+xml;utf8," +
    encodeURIComponent(
      `<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>
         <rect width='100%' height='100%' fill='#020617'/>
         <path d='M10 8h20v8c0 6-4 10-10 12C14 26 10 22 10 16V8z' fill='#0f172a'/>
         <rect x='14' y='28' width='12' height='4' rx='2' fill='#1e293b'/>
       </svg>`
    ),
};

const SafeImg = ({ src, alt = "", className = "", fallback = "team", fallbackSrc = "" }) => {
  const onErr = (e) => {
    if (fallbackSrc && e.currentTarget.dataset.fallbackTried !== "1") {
      e.currentTarget.dataset.fallbackTried = "1";
      e.currentTarget.src = fallbackSrc;
      return;
    }
    e.currentTarget.onerror = null;
    e.currentTarget.srcset = "";
    e.currentTarget.src = FALLBACK_SVG[fallback] || FALLBACK_SVG.team;
  };
  return (
    <img
      src={src}
      alt={alt}
      className={className}
      onError={onErr}
      data-fallback-tried="0"
      loading="lazy"
      decoding="async"
      draggable={false}
    />
  );
};

const teamLogo = (id) =>
  id ? `/icons/team_logos/${id}.png` : FALLBACK_SVG.team;
const teamLogoFallback = (id, name = "") =>
  id ? `https://media.api-sports.io/football/teams/${id}.png` : fallbackTeam(name);
const fmtNum = (v, d = 0) => (v == null ? "—" : Number(v).toFixed(d));

/* ===== логотипы как в MatchSchedulePage ===== */
const teamLogoPath = (id) => (id ? `/icons/team_logos/${id}.png` : null);
const fallbackTeam = (name) =>
  teamLogoMap[name] || "/icons/team_logos/default.png";
const logoSafe = (id, name) => teamLogoPath(id) || fallbackTeam(name);

/* форматтер даты DD.MM */
const toDDMM = (val) => {
  if (!val) return "";
  const s = String(val);
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (m) return `${m[3]}.${m[2]}`;
  const m2 = s.match(/^(\d{4})-(\d{2})-(\d{2})T/);
  if (m2) return `${m2[3]}.${m2[2]}`;
  if (/^\d{2}\.\d{2}/.test(s)) return s.slice(0, 5);
  return s;
};

const parseMatchDate = (m) => {
  const src = m?.datetime || m?.date;
  if (!src) return null;
  const d = new Date(src);
  if (!Number.isNaN(d.getTime())) return d;
  if (typeof src === "string") {
    const d2 = new Date(src.replace(" ", "T"));
    if (!Number.isNaN(d2.getTime())) return d2;
  }
  return null;
};

const formatHHMM = (d) => {
  if (!d) return "";
  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  return `${hh}:${mm}`;
};

const INTERNATIONAL_LEAGUES = new Set([
  "World Cup",
  "Euro Championship",
  "Euro Championship - Qualification",
  "World Cup - Qualification Europe",
  "World Cup - Qualification Africa",
  "World Cup - Qualification Asia",
  "World Cup - Qualification CONCACAF",
  "World Cup - Qualification South America",
  "World Cup - Qualification Oceania",
  "World Cup - Qualification Intercontinental Play-offs",
]);

const normalizeLeagueKey = (value) =>
  String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");

/* ================= PAGE ================= */

export default function TeamPageaAll() {
  const { language } = useLanguage();
  const isRu = language === "ru";
  const { id } = useParams();
  const teamId = Number(id || 0);

  const [sp, setSp] = useSearchParams();
  const navigate = useNavigate();
  const location = useLocation();
  const { user, checkAuth } = useAuth();

  const league = sp.get("league") || "Premier League";
  const seasonParam = sp.get("season") || "2026";
  const tabParam = sp.get("tab") || "stats"; // stats | results | schedule
  const isInternationalTeamContext = INTERNATIONAL_LEAGUES.has(league);

  const season = seasonParam;
  const [tab, setTabState] = useState(tabParam);

  const [overview, setOverview] = useState(null);
  const [results, setResults] = useState([]);
  const [schedule, setSchedule] = useState([]);
  const [loadingO, setLoadingO] = useState(false);
  const [loadingR, setLoadingR] = useState(false);
  const [loadingS, setLoadingS] = useState(false);
  const [loadingRank, setLoadingRank] = useState(false);
  const [tableRank, setTableRank] = useState(null);
  const [subscriptionActive, setSubscriptionActive] = useState(null);

  // календарь — один раскрытый матч + pack
  const [expandedScheduleId, setExpandedScheduleId] = useState(null);
  const [expandedScheduleData, setExpandedScheduleData] = useState({});

  const [expandedResultId, setExpandedResultId] = useState(null);
  const [expandedResultData, setExpandedResultData] = useState({});

  const getStoredToken = (key) => {
    try {
      return localStorage.getItem(key) || sessionStorage.getItem(key);
    } catch {
      return null;
    }
  };

  useEffect(() => {
    if (!user && getStoredToken("access_token")) {
      checkAuth();
    }
  }, [user, checkAuth]);


  const statusBasedAccess = (() => {
    const status = String(user?.subscription_status || user?.subscription?.status || "").toLowerCase();
    if (["active", "premium", "pro", "elite", "paid"].includes(status)) return true;
    if (user?.is_premium || user?.is_subscribed) return true;
    if (Array.isArray(user?.active_subscriptions) && user.active_subscriptions.length > 0) return true;
    if (!status) return false;
    return status !== "free";
  })();
  const pilotFullAccess = hasPilotFullAccess(user);
  const hideMonetization = shouldHideMonetization();
  const hasSubscription =
    pilotFullAccess || (subscriptionActive != null ? subscriptionActive : statusBasedAccess);

  useEffect(() => {
    if (pilotFullAccess) {
      setSubscriptionActive(true);
      return;
    }
    let alive = true;
    (async () => {
      if (!user) return;
      try {
        const response = await http.get("/api/subscriptions/me");
        const payload = response?.data || {};
        const subs = Array.isArray(payload?.active_subscriptions)
          ? payload.active_subscriptions
          : [];
        const now = Date.now();
        const active = (() => {
          const topStatus = String(payload?.subscription_status || "").toLowerCase();
          if (["active", "paid", "premium", "pro", "elite"].includes(topStatus)) return true;
          const until = payload?.subscription_until || payload?.subscription_end;
          if (until) {
            const exp = new Date(until).getTime();
            if (Number.isFinite(exp) && exp > now) return true;
          }
          return subs.some((s) => {
            if (!s) return false;
            if (s.is_active === true) return true;
            const status = String(s.status || "").toLowerCase();
            if (["active", "paid", "premium", "pro", "elite"].includes(status)) return true;
            const end = s.end_at || s.expires_at;
            if (!end) return false;
            const exp = new Date(end).getTime();
            return Number.isFinite(exp) ? exp > now : false;
          });
        })();
        if (alive) setSubscriptionActive(active);
      } catch (err) {
        if (String(err?.status) === "401") {
          try {
            await checkAuth();
            const response = await http.get("/api/subscriptions/me");
            const payload = response?.data || {};
            const subs = Array.isArray(payload?.active_subscriptions)
              ? payload.active_subscriptions
              : [];
            const now = Date.now();
            const active = (() => {
              const topStatus = String(payload?.subscription_status || "").toLowerCase();
              if (["active", "paid", "premium", "pro", "elite"].includes(topStatus)) return true;
              const until = payload?.subscription_until || payload?.subscription_end;
              if (until) {
                const exp = new Date(until).getTime();
                if (Number.isFinite(exp) && exp > now) return true;
              }
              return subs.some((s) => {
                if (!s) return false;
                if (s.is_active === true) return true;
                const status = String(s.status || "").toLowerCase();
                if (["active", "paid", "premium", "pro", "elite"].includes(status)) return true;
                const end = s.end_at || s.expires_at;
                if (!end) return false;
                const exp = new Date(end).getTime();
                return Number.isFinite(exp) ? exp > now : false;
              });
            })();
            if (alive) setSubscriptionActive(active);
            return;
          } catch {}
        }
        if (alive) setSubscriptionActive(null);
      }
    })();
    return () => {
      alive = false;
    };
  }, [pilotFullAccess, user, checkAuth]);

  const openSubscription = useCallback(() => {
    if (hideMonetization) return;
    const back = encodeURIComponent(`${location.pathname}${location.search}`);
    navigate(`/subscriptions?redirect_back=${back}#plans`);
  }, [hideMonetization, location.pathname, location.search, navigate]);

  const openMatchInResults = useCallback(
    (fixtureId) => {
      if (!fixtureId) return;
      const params = new URLSearchParams({
        league,
        season,
        fixture_id: String(fixtureId),
      });
      navigate(`/matches-v3?${params.toString()}`);
    },
    [navigate, league, season]
  );

  const setTab = (t) => {
    setTabState(t);
    const next = new URLSearchParams(sp);
    next.set("tab", t);
    setSp(next, { replace: true });
  };

  // overview
  useEffect(() => {
    if (!teamId) return;
    let cancel = false;
    (async () => {
      setLoadingO(true);
      try {
        const qs = new URLSearchParams({
          team_id: String(teamId),
          league,
          season,
        });
        const o = await fetchTeamOverview({
          teamId,
          league,
          season,
        });
        if (!cancel) setOverview(o || null);
      } catch {
        if (!cancel) setOverview(null);
      } finally {
        if (!cancel) setLoadingO(false);
      }
    })();
    return () => {
      cancel = true;
    };
  }, [teamId, league, season]);

  // lock league to team's primary league if user tries to switch
  useEffect(() => {
    if (isInternationalTeamContext) return;
    const teamLeague = resolveTeamLeagueName(overview);
    if (!teamLeague) return;
    const cur = normalizeLeagueKey(league);
    const target = normalizeLeagueKey(teamLeague);
    if (!cur || cur === target) return;
    const next = new URLSearchParams(sp);
    next.set("league", teamLeague);
    setSp(next, { replace: true });
  }, [overview, league, setSp, sp, isInternationalTeamContext]);

  // league table rank (authoritative for selected league)
  useEffect(() => {
    if (!teamId) return;
    let cancel = false;
    (async () => {
      setLoadingRank(true);
      try {
        const list = await fetchLeagueTableForTeam({ league, season });
        const row = list.find(
          (x) => Number(x?.team_id) === Number(teamId)
        );
        const rank =
          row?.rank ??
          row?.position ??
          row?.place ??
          row?.standing ??
          null;
        if (!cancel) {
          const num = Number(rank);
          setTableRank(
            Number.isFinite(num) && num > 0 ? num : null
          );
        }
      } catch {
        if (!cancel) setTableRank(null);
      } finally {
        if (!cancel) setLoadingRank(false);
      }
    })();
    return () => {
      cancel = true;
    };
  }, [teamId, league, season]);

  // results — сыгранные матчи
  useEffect(() => {
    if (!teamId) return;
    let cancel = false;

    (async () => {
      setLoadingR(true);
      try {
        const rows = await fetchTeamResults({
          teamId,
          league,
          season,
          isInternationalTeamContext,
        });

        if (!cancel) {
          setResults(Array.isArray(rows) ? rows : []);
        }
      } catch {
        if (!cancel) setResults([]);
      } finally {
        if (!cancel) setLoadingR(false);
      }
    })();

    return () => {
      cancel = true;
    };
  }, [teamId, league, season, isInternationalTeamContext]);

  // schedule — будущие матчи команды
  useEffect(() => {
    if (!teamId) return;
    let cancel = false;

    (async () => {
      setLoadingS(true);
      try {
        const arr = await fetchTeamSchedule({
          teamId,
          league,
          season,
          isInternationalTeamContext,
        });

        if (!cancel) setSchedule(buildUpcomingTeamSchedule(arr, teamId));
      } catch {
        if (!cancel) setSchedule([]);
      } finally {
        if (!cancel) setLoadingS(false);
      }
    })();

    return () => {
      cancel = true;
    };
  }, [teamId, league, season, isInternationalTeamContext]);

  /* ===== группировка календаря по турам ===== */
  const groupedSchedule = useMemo(() => groupScheduleByRound(schedule), [schedule]);

  useEffect(() => {
    setExpandedScheduleId(null);
    setExpandedScheduleData({});
  }, [teamId, league, season]);

  /* ===== загрузка данных для разворота календаря через buildMatchPack() ===== */
  const loadExpandedPack = useCallback(
    async (m) => {
      if (!m?.fixture_id) return;
      const key = m.fixture_id;

      setExpandedScheduleData((prev) => ({
        ...prev,
        [key]: {
          ...(prev[key] || {}),
          loading: true,
          error: null,
        },
      }));

      try {
        const pack = await buildMatchPack({ match: m, league });
        setExpandedScheduleData((prev) => ({
          ...prev,
          [key]: {
            ...pack,
            loaded: true,
            loading: false,
            error: null,
          },
        }));
      } catch (e) {
        setExpandedScheduleData((prev) => ({
          ...prev,
          [key]: {
            ...(prev[key] || {}),
            loading: false,
            error: e.message || String(e),
          },
        }));
      }
    },
    [league]
  );

  const handleToggleSchedule = useCallback(
    (m) => {
      if (!m?.fixture_id) return;
      setExpandedScheduleId((prev) => {
        const next = prev === m.fixture_id ? null : m.fixture_id;
        if (next === m.fixture_id) {
          loadExpandedPack(m);
        }
        return next;
      });
    },
    [loadExpandedPack]
  );

  const loadResultDetails = useCallback(
    async (m, seed) => {
      if (!m?.fixture_id) return;
      const key = m.fixture_id;
      setExpandedResultData((prev) => ({
        ...prev,
        [key]: { ...(prev[key] || {}), loading: true, error: null },
      }));
      try {
        const match = await fetchOneMatch({
          fixtureId: m.fixture_id,
          league,
          season,
          seed,
        });
        setExpandedResultData((prev) => ({
          ...prev,
          [key]: { match, lineups: null, loading: false, error: null },
        }));
      } catch (e) {
        setExpandedResultData((prev) => ({
          ...prev,
          [key]: { ...(prev[key] || {}), loading: false, error: e.message || String(e) },
        }));
      }
    },
    [league, season]
  );

  const handleToggleResult = useCallback(
    (m, seed) => {
      if (!m?.fixture_id) return;
      setExpandedResultId((prev) => {
        const next = prev === m.fixture_id ? null : m.fixture_id;
        if (next === m.fixture_id) {
          const cached = expandedResultData[m.fixture_id];
          if (!cached || (!cached.loading && !cached.match && !cached.error)) {
            loadResultDetails(m, seed);
          }
        }
        return next;
      });
    },
    [expandedResultData, loadResultDetails]
  );

  const titleTeamName = useMemo(
    () => overview?.team_name || "Команда",
    [overview]
  );
  const [isFav, setIsFav] = useState(false);
  const [resultFilter, setResultFilter] = useState("all");
  const [period, setPeriod] = useState("season");
  const favKey = "favorites_teams";
  const emitFavUpdate = () => {
    try {
      window.dispatchEvent(new CustomEvent("favorites:update"));
    } catch {}
  };

  useEffect(() => {
    try {
      const list = loadFavorites(favKey);
      setIsFav(list.some((x) => Number(x.id) === Number(teamId)));
    } catch {}
  }, [teamId]);

  const toggleFavorite = () => {
    let nextIsFav = !isFav;
    try {
      const list = loadFavorites(favKey);
      const exists = list.some((x) => Number(x.id) === Number(teamId));
      const next = exists
        ? list.filter((x) => Number(x.id) !== Number(teamId))
        : [
            ...list,
            {
              id: Number(teamId),
              name: titleTeamName,
              league,
              season,
            },
          ];
      saveFavorites(favKey, next);
      const refreshed = loadFavorites(favKey);
      nextIsFav = refreshed.some((x) => Number(x.id) === Number(teamId));
    } catch {}
    setIsFav(nextIsFav);
    emitFavUpdate();
  };
  const selectedRank = useMemo(() => {
    if (Number.isFinite(Number(tableRank))) return Number(tableRank);
    return pickLeagueRank(overview, league);
  }, [overview, league, tableRank]);
  const matchesPlayed = Number(overview?.matches_played);
  const showLowDataNote =
    overview && Number.isFinite(matchesPlayed) && matchesPlayed < 5;

  const periodLabel =
    period === "season" ? "за сезон" : `за последние ${period} матчей`;

  const periodStats = useMemo(
    () => buildPeriodStats({ period, overview, results }),
    [period, overview, results]
  );

  const recentResults = useMemo(() => getRecentResults(results), [results]);

  const filteredResults = useMemo(
    () => filterResultsByVenue(results, resultFilter),
    [results, resultFilter]
  );

  const recentResultsFiltered = useMemo(
    () => getRecentResults(filteredResults),
    [filteredResults]
  );

  const formSummary = useMemo(
    () => buildFormSummary({ recentResultsFiltered, teamId }),
    [recentResultsFiltered, teamId]
  );

  return (
    <div className="w-full px-4 py-8">
      <div className="w-full space-y-8">
      {/* HERO / HEADER – в стиле EdgeScore, как таблица/подборки */}
      <section className="surface-hero relative overflow-hidden text-slate-50">
        <div className="relative p-4 sm:p-6 md:p-8">
          <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            <div className="flex min-w-0 items-center gap-3 sm:gap-4">
              <span className="inline-flex h-14 w-14 items-center justify-center overflow-hidden rounded-2xl border border-glass bg-surface-2/80 shadow-[0_18px_70px_rgba(0,0,0,0.9)] sm:h-16 sm:w-16">
                <SafeImg
                  src={teamLogo(teamId)}
                  alt={titleTeamName}
                  className="h-10 w-10 object-contain sm:h-12 sm:w-12"
                  fallbackSrc={teamLogoFallback(teamId, titleTeamName)}
                />
              </span>
              <div className="min-w-0 type-title-block">
                <div className="type-eyebrow">
                  {isRu ? "Команда" : "Team"}
                </div>
                <h1 className="type-page-title whitespace-normal break-words text-[36px] leading-[0.95] sm:text-[52px]">
                  {titleTeamName}
                </h1>
                <div className="type-subtitle text-[14px] sm:text-[16px]">
                  {league} · {isRu ? "Сезон" : "Season"} {season}
                  {selectedRank != null && !loadingRank ? ` · ${isRu ? "Место" : "Rank"}: ${selectedRank}` : ""}
                </div>
              </div>
            </div>

            <div className="relative z-10 flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  toggleFavorite();
                }}
                className={`surface-button h-9 gap-2 px-3 py-1 text-[12px] font-medium ${isFav ? "surface-button-active" : ""}`}
                title={isFav ? (isRu ? "Убрать из избранного" : "Remove from favorites") : (isRu ? "Добавить в избранное" : "Add to favorites")}
              >
                <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor" aria-hidden="true">
                  <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 6 3.99 4 6.5 4c1.54 0 3.04.74 4 1.9C11.46 4.74 12.96 4 14.5 4 17.01 4 19 6 19 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
                </svg>
                {isFav ? (isRu ? "В избранном" : "Saved") : (isRu ? "В избранное" : "Save")}
              </button>
            </div>
          </div>

          {/* табы */}
          <div className="mt-4 sm:mt-5">
            <Segmented value={tab} onChange={setTab} />
          </div>
        </div>
      </section>

      {/* ТАБЫ */}
      {tab === "stats" ? (
        <TeamStatsSection
          loadingO={loadingO}
          overview={overview}
          showLowDataNote={showLowDataNote}
          period={period}
          setPeriod={setPeriod}
          periodStats={periodStats}
          periodLabel={periodLabel}
          selectedRank={selectedRank}
          fmtNumLocal={fmtNum}
        />
      ) : tab === "results" ? (
        <TeamResultsSection
          recentResults={recentResults}
          resultFilter={resultFilter}
          setResultFilter={setResultFilter}
          formSummary={formSummary}
          loadingR={loadingR}
          results={results}
          filteredResults={filteredResults}
          expandedResultId={expandedResultId}
          expandedResultData={expandedResultData}
          teamId={teamId}
          titleTeamName={titleTeamName}
          handleToggleResult={handleToggleResult}
          logoSrc={logoSafe}
          logoFallbackSrc={teamLogoFallback}
          toDDMM={toDDMM}
          resultForTeam={resultForTeam}
        />
      ) : tab === "schedule" ? (
        <TeamScheduleSection
          loadingS={loadingS}
          groupedSchedule={groupedSchedule}
          expandedScheduleId={expandedScheduleId}
          expandedScheduleData={expandedScheduleData}
          handleToggleSchedule={handleToggleSchedule}
          parseMatchDate={parseMatchDate}
          toDDMM={toDDMM}
          formatHHMM={formatHHMM}
          hasSubscription={hasSubscription}
          openSubscription={openSubscription}
          openMatchInResults={openMatchInResults}
          logoSrc={logoSafe}
          logoFallbackSrc={teamLogoFallback}
          teamId={teamId}
        />
      ) : null}

      </div>
    </div>
  );
}
