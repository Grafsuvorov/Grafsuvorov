import { lazy, Suspense, useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import clsx from "clsx";
import SafeImg from "@/components/SafeImg";
import SegmentedTabs from "@/components/ui/SegmentedTabs";
import { useLanguage } from "@/context/LanguageContext.jsx";

const LeaguePerformanceMap = lazy(() => import("@/components/analytics/LeaguePerformanceMap"));
const OverperformanceChart = lazy(() => import("@/components/analytics/OverperformanceChart"));
const ShotEfficiencyChart = lazy(() => import("@/components/analytics/ShotEfficiencyChart"));
const PlayerFinishingChart = lazy(() => import("@/components/analytics/PlayerFinishingChart"));
const ChanceCreatorsChart = lazy(() => import("@/components/analytics/ChanceCreatorsChart"));
const TeamFormGrid = lazy(() => import("@/components/analytics/TeamFormGrid"));
const HistoricalLeaders = lazy(() => import("@/components/analytics/HistoricalLeaders"));
const InsightsPanel = lazy(() => import("@/components/analytics/InsightsPanel"));

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

const makeSeasonList = (startYear = 2010) => {
  const now = new Date();
  const current = now.getFullYear();
  const list = [];
  for (let y = current; y >= startYear; y -= 1) {
    list.push(String(y));
  }
  return list;
};

const SEASONS = makeSeasonList(2010);
const pageDataCache = new Map();

const TAB_OPTIONS = [
  { key: "attack", label: "Attack" },
  { key: "defense", label: "Defense" },
  { key: "possession", label: "Possession" },
  { key: "advanced", label: "Advanced" },
];

const TAB_COLUMNS = {
  attack: [
    { key: "shots", label: "Shots" },
    { key: "shots_on_target", label: "Shots OT" },
    { key: "shots_inside_box", label: "Big Chances" },
    { key: "goals", label: "Goals" },
  ],
  defense: [
    { key: "shots_conceded", label: "Shots Conceded" },
    { key: "xga", label: "xGA" },
    { key: "goals_conceded", label: "Goals Con." },
    { key: "tackles", label: "Tackles" },
  ],
  possession: [
    { key: "possession", label: "Possession %" },
    { key: "attacks", label: "Attacks" },
    { key: "dangerous_attacks", label: "Dangerous" },
    { key: "corners", label: "Corners" },
    { key: "deep_avg", label: "Deep Prog." },
    { key: "tempo_shots_per_game", label: "Shot Tempo" },
  ],
  advanced: [
    { key: "xg", label: "xG" },
    { key: "xga", label: "xGA" },
    { key: "xg_diff", label: "xG Diff" },
    { key: "goal_diff", label: "Goal Diff" },
    { key: "shots_diff", label: "Shots Diff" },
    { key: "ppda_avg", label: "PPDA" },
  ],
};

const fmt = (v) => {
  if (v == null || Number.isNaN(Number(v))) return "—";
  return Number(v).toFixed(2).replace(/\.00$/, "");
};

const periodLabel = (windowValue, language = "ru") => {
  if (!windowValue || windowValue === "season") return language === "ru" ? "Сезон" : "Season";
  const n = Number(windowValue);
  if (!Number.isFinite(n)) return language === "ru" ? "Сезон" : "Season";
  if (n === 1) return language === "ru" ? "1 матч" : "1 match";
  return language === "ru" ? `${n} матчей` : `${n} matches`;
};

const cardMetricLabel = (field) => {
  switch (field) {
    case "shots":
      return "shots / match";
    case "goals_conceded":
      return "goals conceded / match";
    case "xg":
      return "xG / match";
    case "shots_conceded":
      return "shots conceded / match";
    case "clean_sheets":
      return "clean sheets";
    case "ppda_avg":
      return "ppda";
    case "deep_avg":
      return "deep progressions";
    case "tempo_shots_per_game":
      return "shots tempo";
    default:
      return "per match";
  }
};

const TEAM_BADGE_FALLBACK =
  "data:image/svg+xml;utf8," +
  encodeURIComponent(
    `<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>
       <rect width='40' height='40' rx='12' fill='#10182a'/>
       <path d='M20 6 31 11v8c0 7.6-4.9 13.8-11 16-6.1-2.2-11-8.4-11-16v-8l11-5z' fill='#cbd5e1'/>
     </svg>`
  );
const PLAYER_BADGE_FALLBACK =
  "data:image/svg+xml;utf8," +
  encodeURIComponent(
    `<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>
       <rect width='40' height='40' rx='20' fill='#10182a'/>
       <circle cx='20' cy='15' r='6' fill='#cbd5e1'/>
       <path d='M10 33c1.8-5.7 6-8.5 10-8.5S28.2 27.3 30 33' fill='#cbd5e1'/>
     </svg>`
  );

const resolveTeamId = (...candidates) => {
  for (const value of candidates) {
    if (value == null || value === "") continue;
    const normalized = Number(value);
    if (Number.isFinite(normalized) && normalized > 0) return normalized;
  }
  return null;
};

const resolvePlayerId = (...candidates) => {
  for (const value of candidates) {
    if (value == null || value === "") continue;
    const normalized = Number(value);
    if (Number.isFinite(normalized) && normalized > 0) return normalized;
  }
  return null;
};

const getTeamLogo = (id) =>
  id ? `/icons/team_logos/${id}.png` : TEAM_BADGE_FALLBACK;
const getTeamLogoFallback = (id) =>
  id ? `https://media.api-sports.io/football/teams/${id}.png` : TEAM_BADGE_FALLBACK;
const getPlayerPhoto = (id) =>
  id ? `/icons/player_photos/${id}.png` : PLAYER_BADGE_FALLBACK;
const getPlayerPhotoFallback = (id) =>
  id ? `https://media.api-sports.io/football/players/${id}.png` : PLAYER_BADGE_FALLBACK;

const COL_WIDTHS = {
  shots: 120,
  shots_on_target: 120,
  shots_inside_box: 140,
  xg: 100,
  goals: 100,
  shots_conceded: 120,
  xga: 100,
  goals_conceded: 100,
  possession: 120,
  attacks: 120,
  dangerous_attacks: 140,
  corners: 100,
  tackles: 100,
  deep_avg: 120,
  tempo_shots_per_game: 120,
  ppda_avg: 100,
  xg_diff: 100,
  goal_diff: 100,
  shots_diff: 120,
};

const buildGridTemplate = (cols) => {
  const base = ["50px", "220px", "80px"];
  const extra = cols.map((c) => `${COL_WIDTHS[c.key] || 140}px`);
  return [...base, ...extra].join(" ");
};

const renderAnalyticsFallback = (language = "ru") => (
  <div className="surface-loading p-6">
    {language === "ru" ? "Загрузка аналитики..." : "Loading analytics..."}
  </div>
);

async function fetchJsonCached(url, { force = false } = {}) {
  if (!force && pageDataCache.has(url)) return pageDataCache.get(url);
  const response = await fetch(url);
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  const data = await response.json();
  pageDataCache.set(url, data);
  return data;
}

export default function LeagueInsightsPage() {
  const { language } = useLanguage();
  const [searchParams, setSearchParams] = useSearchParams();
  const navigate = useNavigate();
  const leagueSlug = searchParams.get("league") || "Premier-League";
  const leagueParam = leagueSlug.replace(/-/g, " ");
  const seasonParam = searchParams.get("season") || "2025";
  const isUcl = leagueParam === "UEFA Champions League";
  const isInternationalLeague = INTERNATIONAL_LEAGUES.has(leagueParam);
  const defaultTrendWindow = isInternationalLeague ? 5 : 10;
  const defaultMinMinutes = isInternationalLeague ? 180 : 900;
  const defaultMinShots = isInternationalLeague ? 3 : 20;

  const [season, setSeason] = useState(seasonParam);
  const [window, setWindow] = useState(searchParams.get("window") || "season");
  const [uclStage, setUclStage] = useState(searchParams.get("uclStage") || "league");
  const [tab, setTab] = useState("attack");
  const [view, setView] = useState("teams");
  const [insightsSection, setInsightsSection] = useState("teams");
  const [trendWindow, setTrendWindow] = useState(Number(searchParams.get("trendWindow") || defaultTrendWindow));
  const [minMinutes, setMinMinutes] = useState(Number(searchParams.get("minMinutes") || defaultMinMinutes));
  const [minShots, setMinShots] = useState(Number(searchParams.get("minShots") || defaultMinShots));
  const [teamFilter, setTeamFilter] = useState(searchParams.get("team") || "all");

  const [loading, setLoading] = useState(false);
  const [rows, setRows] = useState([]);
  const [cards, setCards] = useState({});
  const [playersLoading, setPlayersLoading] = useState(false);
  const [topScorers, setTopScorers] = useState([]);
  const [topAssists, setTopAssists] = useState([]);
  const [topRated, setTopRated] = useState([]);
  const [topShots, setTopShots] = useState([]);
  const [topKeyPasses, setTopKeyPasses] = useState([]);
  const [topTackles, setTopTackles] = useState([]);
  const [topDribbles, setTopDribbles] = useState([]);
  const [topDuelsWon, setTopDuelsWon] = useState([]);
  const [topInterceptions, setTopInterceptions] = useState([]);
  const [topMinutes, setTopMinutes] = useState([]);
  const [analyticsLoading, setAnalyticsLoading] = useState(false);
  const [analytics, setAnalytics] = useState({
    teams: [],
    players: [],
    trends: [],
    leaders: [],
    has_understat: false,
    fallback_mode: false,
  });
  const [highlightedTeam, setHighlightedTeam] = useState(null);

  const [sort, setSort] = useState({ key: "shots", dir: "desc" });
  const [page, setPage] = useState(1);
  const pageSize = 50;
  const openPlayerCard = (playerId) => {
    if (!playerId) return;
    navigate(`/player/${playerId}?league=${encodeURIComponent(leagueParam)}&season=${season}`);
  };

  useEffect(() => {
    if (!searchParams.get("trendWindow")) setTrendWindow(defaultTrendWindow);
    if (!searchParams.get("minMinutes")) setMinMinutes(defaultMinMinutes);
    if (!searchParams.get("minShots")) setMinShots(defaultMinShots);
  }, [defaultTrendWindow, defaultMinMinutes, defaultMinShots, searchParams]);

  useEffect(() => {
    const next = {
      league: leagueSlug,
      season,
    };
    if (window && window !== "season") next.window = window;
    if (isUcl && uclStage !== "league") next.uclStage = uclStage;
    if (trendWindow !== defaultTrendWindow) next.trendWindow = String(trendWindow);
    if (minMinutes !== defaultMinMinutes) next.minMinutes = String(minMinutes);
    if (minShots !== defaultMinShots) next.minShots = String(minShots);
    if (teamFilter && teamFilter !== "all") next.team = teamFilter;
    setSearchParams(next);
  }, [leagueSlug, season, window, uclStage, trendWindow, minMinutes, minShots, teamFilter, setSearchParams, isUcl, defaultTrendWindow, defaultMinMinutes, defaultMinShots]);

  useEffect(() => {
    setLoading(true);
    const params = new URLSearchParams({
      league: leagueParam,
      season,
    });
    if (window && window !== "season") params.set("window", window);
    if (isUcl) params.set("ucl_stage", uclStage);
    fetchJsonCached(`/api/insights?${params.toString()}`)
      .then((data) => {
        setRows(Array.isArray(data?.teams) ? data.teams : []);
        setCards(data?.cards || {});
      })
      .catch(() => {
        setRows([]);
        setCards({});
      })
      .finally(() => setLoading(false));
  }, [leagueParam, season, window, uclStage, isUcl]);

  useEffect(() => {
    if (view !== "insights") return;
    setAnalyticsLoading(true);
    const qs = new URLSearchParams({
      league: leagueParam,
      season,
    });
    if (window && window !== "season") qs.set("window", window);
    if (isUcl) qs.set("ucl_stage", uclStage);
    qs.set("trend_window", String(trendWindow));
    qs.set("min_minutes", String(minMinutes));
    qs.set("min_shots", String(minShots));
    fetchJsonCached(`/api/league-analytics?${qs.toString()}`)
      .then((data) => {
        setAnalytics({
          teams: Array.isArray(data?.teams) ? data.teams : [],
          players: Array.isArray(data?.players) ? data.players : [],
          trends: Array.isArray(data?.trends) ? data.trends : [],
          leaders: Array.isArray(data?.leaders) ? data.leaders : [],
          has_understat: Boolean(data?.has_understat),
          fallback_mode: Boolean(data?.fallback_mode),
        });
      })
      .catch(() =>
        setAnalytics({
          teams: [],
          players: [],
          trends: [],
          leaders: [],
          has_understat: false,
          fallback_mode: false,
        })
      )
      .finally(() => setAnalyticsLoading(false));
  }, [leagueParam, season, window, uclStage, trendWindow, minMinutes, minShots, isUcl, view]);

  useEffect(() => {
    if (view !== "players") return;
    setPlayersLoading(true);
    const qs = new URLSearchParams({
      league: leagueParam,
      season,
    });
    if (window && window !== "season") qs.set("window", window);
    if (isUcl) qs.set("ucl_stage", uclStage);
    Promise.all([
      fetchJsonCached(`/api/top-scorers?${qs.toString()}`),
      fetchJsonCached(`/api/top-assists?${qs.toString()}`),
      fetchJsonCached(`/api/players/mvp?${qs.toString()}&limit=5`),
      fetchJsonCached(`/api/players/shots?${qs.toString()}&limit=5`),
      fetchJsonCached(`/api/players/key-passes?${qs.toString()}&limit=5`),
      fetchJsonCached(`/api/players/tackles?${qs.toString()}&limit=5`),
      fetchJsonCached(`/api/players/dribbles?${qs.toString()}&limit=5`),
      fetchJsonCached(`/api/players/duels-won?${qs.toString()}&limit=5`),
      fetchJsonCached(`/api/players/interceptions?${qs.toString()}&limit=5`),
      fetchJsonCached(`/api/players/minutes?${qs.toString()}&limit=5`),
    ])
      .then(([sc, as, mv, sh, kp, tk, dr, dw, it, mn]) => {
        setTopScorers(Array.isArray(sc) ? sc.slice(0, 5) : []);
        setTopAssists(Array.isArray(as) ? as.slice(0, 5) : []);
        setTopRated(Array.isArray(mv) ? mv.slice(0, 5) : []);
        setTopShots(Array.isArray(sh) ? sh.slice(0, 5) : []);
        setTopKeyPasses(Array.isArray(kp) ? kp.slice(0, 5) : []);
        setTopTackles(Array.isArray(tk) ? tk.slice(0, 5) : []);
        setTopDribbles(Array.isArray(dr) ? dr.slice(0, 5) : []);
        setTopDuelsWon(Array.isArray(dw) ? dw.slice(0, 5) : []);
        setTopInterceptions(Array.isArray(it) ? it.slice(0, 5) : []);
        setTopMinutes(Array.isArray(mn) ? mn.slice(0, 5) : []);
      })
      .catch(() => {
        setTopScorers([]);
        setTopAssists([]);
        setTopRated([]);
        setTopShots([]);
        setTopKeyPasses([]);
        setTopTackles([]);
        setTopDribbles([]);
        setTopDuelsWon([]);
        setTopInterceptions([]);
        setTopMinutes([]);
      })
      .finally(() => setPlayersLoading(false));
  }, [leagueParam, season, window, uclStage, isUcl, view]);

  const enriched = useMemo(() => {
    return rows.map((r) => ({
      ...r,
      xg_diff:
        r.xg != null && r.xga != null ? Number(r.xg) - Number(r.xga) : null,
      goal_diff:
        r.goals != null && r.goals_conceded != null
          ? Number(r.goals) - Number(r.goals_conceded)
          : null,
      shots_diff:
        r.shots != null && r.shots_conceded != null
          ? Number(r.shots) - Number(r.shots_conceded)
          : null,
    }));
  }, [rows]);

  const allColumns = useMemo(() => {
    return TAB_COLUMNS[tab] || TAB_COLUMNS.attack;
  }, [tab]);

  const maxByKey = useMemo(() => {
    const out = {};
    allColumns.forEach((c) => {
      const vals = enriched
        .map((r) => Number(r[c.key]))
        .filter((v) => Number.isFinite(v));
      out[c.key] = vals.length ? Math.max(...vals) : 0;
    });
    return out;
  }, [allColumns, enriched]);

  const sortedRows = useMemo(() => {
    const dir = sort.dir === "asc" ? 1 : -1;
    const key = sort.key;
    return [...enriched].sort((a, b) => {
      const av = Number(a[key]);
      const bv = Number(b[key]);
      if (Number.isNaN(av) && Number.isNaN(bv)) return 0;
      if (Number.isNaN(av)) return 1;
      if (Number.isNaN(bv)) return -1;
      if (av === bv) return 0;
      return (av - bv) * dir;
    });
  }, [enriched, sort]);

  const topXgPlayers = useMemo(() => {
    const base = [...(analytics.players || [])].filter((p) => {
      if (!teamFilter || teamFilter === "all") return true;
      return String(p.team_name || p.team || "")
        .split(",")
        .map((x) => x.trim().toLowerCase())
        .includes(String(teamFilter).toLowerCase());
    });
    return base
      .filter((p) => p?.xg != null && Number.isFinite(Number(p.xg)))
      .sort((a, b) => Number(b.xg || 0) - Number(a.xg || 0))
      .slice(0, 5);
  }, [analytics.players, teamFilter]);

  const teamFilterOptions = useMemo(() => {
    return [...new Set((analytics.teams || []).map((t) => t?.team).filter(Boolean))].sort((a, b) => String(a).localeCompare(String(b)));
  }, [analytics.teams]);

  const filteredTeamsForInsights = useMemo(() => {
    if (!teamFilter || teamFilter === "all") return analytics.teams || [];
    return (analytics.teams || []).filter((t) => String(t.team || "").toLowerCase() === String(teamFilter).toLowerCase());
  }, [analytics.teams, teamFilter]);

  const filteredPlayersForInsights = useMemo(() => {
    const src = analytics.players || [];
    if (!teamFilter || teamFilter === "all") return src;
    return src.filter((p) =>
      String(p.team_name || p.team || "")
        .split(",")
        .map((x) => x.trim().toLowerCase())
        .includes(String(teamFilter).toLowerCase())
    );
  }, [analytics.players, teamFilter]);

  const hasTeamMap = (analytics.teams || []).some((t) => t.xg != null && t.xga != null);
  const hasOverperformance = (analytics.teams || []).some((t) => t.xg != null && t.goals != null);
  const hasShotEfficiency = (analytics.teams || []).some((t) => t.shots != null && t.goals != null);
  const hasPlayerFinishing = (analytics.players || []).some((p) => p.xg != null && p.goals != null);
  const hasChanceCreators = (analytics.players || []).some((p) => p.key_passes != null && p.assists != null);
  const hasTrends = (analytics.trends || []).length > 0;
  const hasLeaders = (analytics.leaders || []).length > 0;

  const extraTeamStats = useMemo(() => {
    const src = filteredTeamsForInsights;
    const topCleanSheets = [...src].sort((a, b) => Number(b.clean_sheets || 0) - Number(a.clean_sheets || 0))[0];
    const topDeep = [...src]
      .filter((t) => t.deep_avg != null && Number.isFinite(Number(t.deep_avg)))
      .sort((a, b) => Number(b.deep_avg || 0) - Number(a.deep_avg || 0))[0];
    const topTempo = [...src]
      .filter((t) => t.tempo_shots_per_game != null && Number.isFinite(Number(t.tempo_shots_per_game)))
      .sort((a, b) => Number(b.tempo_shots_per_game || 0) - Number(a.tempo_shots_per_game || 0))[0];
    const bestPress = [...src]
      .filter((t) => t.ppda_avg != null && Number.isFinite(Number(t.ppda_avg)))
      .sort((a, b) => Number(a.ppda_avg || 0) - Number(b.ppda_avg || 0))[0];
    return { topCleanSheets, topDeep, topTempo, bestPress };
  }, [filteredTeamsForInsights]);

  const extraPlayerStats = useMemo(() => {
    const src = filteredPlayersForInsights;
    const topXa = [...src]
      .filter((p) => p.xa != null && Number.isFinite(Number(p.xa)))
      .sort((a, b) => Number(b.xa || 0) - Number(a.xa || 0))[0];
    const topNpxg = [...src]
      .filter((p) => p.npxg != null && Number.isFinite(Number(p.npxg)))
      .sort((a, b) => Number(b.npxg || 0) - Number(a.npxg || 0))[0];
    const topXgChain = [...src]
      .filter((p) => p.xg_chain != null && Number.isFinite(Number(p.xg_chain)))
      .sort((a, b) => Number(b.xg_chain || 0) - Number(a.xg_chain || 0))[0];
    const topXgBuildup = [...src]
      .filter((p) => p.xg_buildup != null && Number.isFinite(Number(p.xg_buildup)))
      .sort((a, b) => Number(b.xg_buildup || 0) - Number(a.xg_buildup || 0))[0];
    return { topXa, topNpxg, topXgChain, topXgBuildup };
  }, [filteredPlayersForInsights]);

  const advancedPlayerLeaders = useMemo(() => {
    return [
      { key: "xa", label: "xA", item: extraPlayerStats.topXa, value: extraPlayerStats.topXa?.xa },
      { key: "npxg", label: "npxG", item: extraPlayerStats.topNpxg, value: extraPlayerStats.topNpxg?.npxg },
      { key: "xg_chain", label: "xG Chain", item: extraPlayerStats.topXgChain, value: extraPlayerStats.topXgChain?.xg_chain },
      { key: "xg_buildup", label: "xG Buildup", item: extraPlayerStats.topXgBuildup, value: extraPlayerStats.topXgBuildup?.xg_buildup },
    ].filter((x) => x.item);
  }, [extraPlayerStats]);

  const summaryCards = useMemo(
    () =>
      [
        {
          title: "Most attacking team",
          data: cards?.most_attacking,
          field: "shots",
        },
        {
          title: "Weakest defence",
          data: cards?.weakest_defense,
          field: "goals_conceded",
        },
        {
          title: "Highest xG team",
          data: cards?.highest_xg,
          field: "xg",
        },
        {
          title: "Most shots conceded",
          data: cards?.most_shots_conceded,
          field: "shots_conceded",
        },
        {
          title: "Most clean sheets",
          data: extraTeamStats.topCleanSheets,
          field: "clean_sheets",
        },
        {
          title: "Best pressing (PPDA)",
          data: extraTeamStats.bestPress,
          field: "ppda_avg",
        },
        {
          title: "Deep progressions leader",
          data: extraTeamStats.topDeep,
          field: "deep_avg",
        },
        {
          title: "Highest shot tempo",
          data: extraTeamStats.topTempo,
          field: "tempo_shots_per_game",
        },
      ].filter((item) => item?.data?.team && item?.data?.[item.field] != null),
    [cards, extraTeamStats]
  );

  const selectedPeriodLabel = useMemo(() => periodLabel(window, language), [window, language]);

  const totalPages = Math.max(1, Math.ceil(sortedRows.length / pageSize));
  const pageRows = sortedRows.slice((page - 1) * pageSize, page * pageSize);

  useEffect(() => {
    if (page > totalPages) setPage(1);
  }, [page, totalPages]);

  const toggleSort = (key) => {
    setSort((prev) => {
      if (prev.key === key) {
        return { key, dir: prev.dir === "asc" ? "desc" : "asc" };
      }
      return { key, dir: "desc" };
    });
  };

  const renderBar = (value, key) => {
    if (value == null || Number.isNaN(Number(value))) return "—";
    const max = maxByKey[key] || 1;
    const pct = Math.max(2, Math.round((Number(value) / max) * 100));
    return (
      <div className="flex items-center gap-1.5">
        <div className="h-[6px] w-20 rounded-full bg-white/5 overflow-hidden">
          <div
            className="h-full bg-primary/40 rounded-full transition-all duration-200 group-hover:bg-primary"
            style={{ width: `${pct}%` }}
          />
        </div>
        <span className="tabular-nums text-xs text-white/80">{fmt(value)}</span>
      </div>
    );
  };

  const buildTopList = (key, dir = "desc") => {
    const list = enriched
      .filter((r) => r[key] != null && !Number.isNaN(Number(r[key])))
      .sort((a, b) => {
        const av = Number(a[key]);
        const bv = Number(b[key]);
        return dir === "asc" ? av - bv : bv - av;
      });
    const top = list.slice(0, 3);
    const max = list.length ? Math.max(...list.map((r) => Number(r[key]))) : 1;
    return { top, max };
  };

  const metricCards = {
    attack: [
      { key: "shots", label: language === "ru" ? "Удары" : "Shots" },
      { key: "shots_on_target", label: language === "ru" ? "В створ" : "Shots on target" },
      { key: "shots_inside_box", label: language === "ru" ? "Гол. моменты" : "Big chances" },
      { key: "goals", label: language === "ru" ? "Голы" : "Goals" },
      { key: "dangerous_attacks", label: language === "ru" ? "Опасные атаки" : "Dangerous attacks" },
    ],
    defense: [
      { key: "shots_conceded", label: language === "ru" ? "Допущ. удары" : "Shots conceded", dir: "asc" },
      { key: "xga", label: "xGA", dir: "asc" },
      { key: "goals_conceded", label: language === "ru" ? "Пропущ. голы" : "Goals conceded", dir: "asc" },
      { key: "tackles", label: language === "ru" ? "Отборы" : "Tackles" },
      { key: "corners", label: language === "ru" ? "Угловые" : "Corners" },
      { key: "shots_diff", label: language === "ru" ? "Разница ударов" : "Shot difference" },
    ],
    possession: [
      { key: "possession", label: language === "ru" ? "Владение" : "Possession" },
      { key: "attacks", label: language === "ru" ? "Атаки" : "Attacks" },
      { key: "dangerous_attacks", label: language === "ru" ? "Опасные атаки" : "Dangerous attacks" },
      { key: "corners", label: language === "ru" ? "Угловые" : "Corners" },
      { key: "deep_avg", label: "Deep progressions" },
      { key: "tempo_shots_per_game", label: language === "ru" ? "Темп ударов" : "Shot tempo" },
    ],
    advanced: [
      { key: "xg_diff", label: language === "ru" ? "Разница xG" : "xG difference" },
      { key: "shots_diff", label: language === "ru" ? "Разница ударов" : "Shot difference" },
      { key: "goal_diff", label: language === "ru" ? "Разница голов" : "Goal difference" },
      { key: "xg", label: "xG" },
      { key: "xga", label: "xGA", dir: "asc" },
      { key: "goals", label: language === "ru" ? "Голы" : "Goals" },
    ],
  };

  return (
    <div className="w-full min-w-0 overflow-x-hidden px-1 py-5 space-y-6 sm:px-4 sm:py-8 sm:space-y-8">
      {/* HEADER */}
      <div>
        <div className="surface-hero p-4 sm:p-6 md:p-8">
          <div className="flex flex-col items-start justify-between gap-4 sm:flex-row">
            <div className="min-w-0 space-y-1.5">
              <div className="type-eyebrow">
                {language === "ru" ? "АНАЛИТИКА" : "INSIGHTS"}
              </div>

              <div className="type-page-title break-words text-xl sm:text-2xl">
                {leagueParam}
              </div>

              <p className="type-subtitle max-w-[640px]">
                {language === "ru" ? "Премиальная визуальная аналитика лиги." : "Premium visual league analytics."}
              </p>
            </div>

            <div className="flex w-full min-w-0 flex-col gap-3 sm:w-auto sm:items-end">
              <span className="text-[10px] uppercase tracking-[0.18em] text-muted mb-1">
                {language === "ru" ? "СЕЗОН" : "SEASON"}
              </span>
              <select
                value={season}
                onChange={(e) => setSeason(e.target.value)}
                className="surface-select h-8 w-full min-w-0 text-[13px] text-left text-white/80 sm:w-[168px]"
              >
                {SEASONS.map((s) => (
                  <option key={s} value={s} className="bg-slate-900">
                    {s}
                  </option>
                ))}
              </select>
              <div className="flex w-full min-w-0 flex-col gap-2 sm:w-auto sm:flex-row sm:items-center">
                <span className="text-[10px] uppercase tracking-[0.18em] text-muted">
                  {language === "ru" ? "Период" : "Window"}
                </span>
                <select
                  value={window}
                  onChange={(e) => setWindow(e.target.value)}
                  className="surface-select h-7 w-full min-w-0 text-[12px] text-left text-white/80 sm:w-[168px]"
                >
                  <option value="season" className="bg-slate-900">{language === "ru" ? "Сезон" : "Season"}</option>
                  <option value="1" className="bg-slate-900">{language === "ru" ? "Последний тур" : "Last round"}</option>
                  <option value="5" className="bg-slate-900">{language === "ru" ? "Последние 5" : "Last 5"}</option>
                  <option value="10" className="bg-slate-900">{language === "ru" ? "Последние 10" : "Last 10"}</option>
                  <option value="15" className="bg-slate-900">{language === "ru" ? "Последние 15" : "Last 15"}</option>
                </select>
              </div>
              {isUcl && (
                <div className="flex w-full min-w-0 flex-col gap-2 sm:w-auto sm:flex-row sm:items-center">
                  <span className="text-[10px] uppercase tracking-[0.18em] text-muted">
                    {language === "ru" ? "Стадия" : "Stage"}
                  </span>
                  <select
                    value={uclStage}
                    onChange={(e) => setUclStage(e.target.value)}
                    className="surface-select h-7 w-full min-w-0 text-[12px] text-left text-white/80 sm:w-[168px]"
                  >
                    <option value="league" className="bg-slate-900">{language === "ru" ? "Турнирная таблица" : "League table"}</option>
                    <option value="playoff" className="bg-slate-900">{language === "ru" ? "Плей-офф" : "Playoffs"}</option>
                  </select>
                </div>
              )}
              <div className="flex items-center justify-end" />
            </div>
          </div>
        </div>
      </div>

      {/* VIEW TABS */}
      <SegmentedTabs
        items={[
          { key: "teams", label: language === "ru" ? "Команды" : "Teams" },
          { key: "players", label: language === "ru" ? "Игроки" : "Players" },
          { key: "insights", label: language === "ru" ? "Инсайты" : "Insights" },
        ]}
        value={view}
        onChange={setView}
      />

      {view === "teams" && (
      <>
      {/* CARDS */}
      {summaryCards.length > 0 && (
      <div className="mt-6 grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6 mb-8">
        {summaryCards.map((c) => (
          <div
            key={c.title}
            className="glass-card p-4 transition hover:bg-white/[0.045]"
          >
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              {c.title}
            </div>
            <div className="mt-2 flex items-center gap-3">
              <SafeImg
                src={getTeamLogo(resolveTeamId(c.data?.team_id))}
                alt={c.data?.team || "team"}
                className="h-7 w-7 object-contain"
                fallbackSrc={getTeamLogoFallback(resolveTeamId(c.data?.team_id))}
              />
              <div className="text-lg font-semibold text-white">
                {c.data?.team || "—"}
              </div>
            </div>
            <div className="mt-1 text-sm text-white/60">
              {c.data?.[c.field] != null
                ? `${fmt(c.data?.[c.field])} ${cardMetricLabel(c.field)}`
                : "—"}
            </div>
            <div className="mt-2 text-xs text-white/35">
              {window === "season"
                ? language === "ru" ? `${leagueParam} ${season} · сыграно ${c.data?.matches ?? "—"}` : `${leagueParam} ${season} · played ${c.data?.matches ?? "—"}`
                : `${selectedPeriodLabel} · ${c.data?.matches ?? "—"}`
              }
            </div>
          </div>
        ))}
      </div>
      )}

      {/* TEAM METRICS */}
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div className="text-lg font-semibold text-white">Team Insights</div>
          <SegmentedTabs
            items={TAB_OPTIONS}
            value={tab}
            onChange={setTab}
          />
        </div>

        <div className="grid [grid-template-columns:repeat(auto-fit,minmax(260px,1fr))] gap-5">
          {(metricCards[tab] || []).map((m) => {
            const { top, max } = buildTopList(m.key, m.dir || "desc");
            if (!top.length) return null;
            return (
              <div
                key={`${tab}-${m.key}`}
                className="glass-card p-4"
              >
                <div className="text-xs uppercase tracking-[0.18em] text-white/45">
                  {m.label}
                </div>
                <div className="mt-3 space-y-2">
                  {top.map((t, idx) => {
                    const value = Number(t[m.key]);
                    const pct = max ? Math.max(4, (value / max) * 100) : 0;
                    return (
                      <div
                        key={`${t.team_id}-${m.key}`}
                        className="metric-row border-b border-white/5 last:border-b-0 py-1.5"
                        style={{
                          display: "grid",
                          gridTemplateColumns: "24px 18px 1fr 120px 50px",
                          alignItems: "center",
                          gap: "10px",
                        }}
                      >
                        <span className="text-[11px] text-white/45 tabular-nums text-right">
                          {idx + 1}
                        </span>
                        <SafeImg
                          src={getTeamLogo(resolveTeamId(t.team_id))}
                          alt={t.team}
                          className="h-[16px] w-[16px] object-contain flex-shrink-0"
                          fallbackSrc={getTeamLogoFallback(resolveTeamId(t.team_id))}
                        />
                        <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis">
                          {t.team}
                        </span>
                        <div className="w-full h-[6px] rounded-full bg-white/8 overflow-hidden">
                          <div
                            className="h-full rounded-full bg-primary/42"
                            style={{ width: `${Math.min(100, pct)}%` }}
                          />
                        </div>
                        <div className="text-xs text-white/70 tabular-nums text-right">
                          {fmt(value)}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </div>

        <div className="text-lg font-semibold text-white">Team Rankings</div>
        <div className="glass-card overflow-x-auto">
          <div
            className="sticky top-0 bg-[#0f1422]/96 text-slate-300 text-sm font-semibold backdrop-blur"
            style={{ display: "grid", gridTemplateColumns: buildGridTemplate(allColumns), width: "100%" }}
          >
            <div className="px-3 py-2 text-center">Rank</div>
            <div className="px-3 py-2">Team</div>
            <div className="px-3 py-2 text-center">Matches</div>
            {allColumns.map((c) => (
              <button
                key={c.key}
                type="button"
                onClick={() => toggleSort(c.key)}
                className="px-3 py-2 text-left cursor-pointer select-none"
              >
                <div className="flex items-center gap-1">
                  <span>{c.label}</span>
                  {sort.key === c.key && (
                    <span className="text-[10px] text-white/60">
                      {sort.dir === "asc" ? "↑" : "↓"}
                    </span>
                  )}
                </div>
              </button>
            ))}
          </div>

          <div style={{ width: "100%" }}>
            {pageRows.map((t, idx) => (
              <div
                key={`${t.team_id}-${t.team}`}
                className="group hover:bg-card/50 h-[42px] cursor-pointer border-b border-white/5"
                style={{ display: "grid", gridTemplateColumns: buildGridTemplate(allColumns), alignItems: "center", width: "100%" }}
                onClick={() =>
                  t.team_id &&
                  navigate(
                    `/team/${t.team_id}?league=${encodeURIComponent(
                      leagueParam
                    )}&season=${season}`
                  )
                }
              >
                <div className="px-3 text-xs text-white/60 text-center tabular-nums">
                  {(page - 1) * pageSize + idx + 1}
                </div>
                <div className="px-3">
                  <div className="flex items-center gap-2">
                    <SafeImg
                      src={getTeamLogo(resolveTeamId(t.team_id))}
                      alt={t.team}
                      className="h-[18px] w-[18px] object-contain"
                      fallbackSrc={getTeamLogoFallback(resolveTeamId(t.team_id))}
                    />
                    <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis max-w-[200px]">
                      {t.team}
                    </span>
                  </div>
                </div>
                <div className="px-3 text-sm text-white/70 tabular-nums text-center">
                  {t.matches}
                </div>
                {allColumns.map((c) => (
                  <div key={`${t.team_id}-${c.key}`} className="px-3">
                    {renderBar(t[c.key], c.key)}
                  </div>
                ))}
              </div>
            ))}
          </div>
        </div>
      </div>

      {loading && (
        <div className="surface-loading">{language === "ru" ? "Загрузка данных…" : "Loading data…"}</div>
      )}
      </>
      )}

      {/* PLAYER METRICS */}
      {view === "players" && (
      <div className="space-y-6">
        <div className="text-lg font-semibold text-white">{language === "ru" ? "Инсайты игроков" : "Player insights"}</div>
        {playersLoading && (
          <div className="surface-loading">{language === "ru" ? "Загрузка игроков…" : "Loading players…"}</div>
        )}
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-8">
          {advancedPlayerLeaders.length > 0 && (
          <div className="glass-card p-5">
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              Advanced player metrics
            </div>
            <div className="mt-4 space-y-1">
              {advancedPlayerLeaders.map((row) => (
                <div
                  key={`adv-${row.key}-${row.item?.player_id || row.item?.understat_player_id || row.item?.player_name}`}
                  className="grid cursor-pointer items-center gap-3 rounded-2xl border-b border-white/5 px-2 py-3 transition hover:bg-white/[0.028] last:border-b-0"
                  style={{ gridTemplateColumns: "1fr 86px" }}
                  onClick={() =>
                    row.item?.player_id &&
                    navigate(
                      `/player/${row.item.player_id}?league=${encodeURIComponent(
                        leagueParam
                      )}&season=${season}`
                    )
                  }
                >
                  <div className="flex min-w-0 items-center gap-2">
                    <SafeImg
                      src={getPlayerPhoto(resolvePlayerId(row.item?.player_id, row.item?.api_player_id, row.item?.understat_player_id))}
                      alt={row.item?.player_name || row.item?.player}
                      className="h-[28px] w-[28px] rounded-full border border-white/20 object-cover flex-shrink-0"
                      fallbackSrc={getPlayerPhotoFallback(resolvePlayerId(row.item?.player_id, row.item?.api_player_id, row.item?.understat_player_id))}
                    />
                    <div className="min-w-0">
                      <div className="truncate text-sm text-white">
                        {row.item?.player_name || row.item?.player}
                      </div>
                      <div className="truncate text-xs text-white/50">
                        {row.item?.team_name || row.item?.team || "—"}
                      </div>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-[10px] uppercase tracking-[0.14em] text-white/45">{row.label}</div>
                    <div className="text-xs tabular-nums text-primary">{Number(row.value || 0).toFixed(2)}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
          )}

          {topXgPlayers.length > 0 && (
          <div className="glass-card p-5">
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              Top xG
            </div>
            <div className="mt-4 space-y-2.5">
              {topXgPlayers.map((p, idx) => (
                <div
                  key={`xg-${p.player_id}-${idx}`}
                  className="grid cursor-pointer items-center gap-3 rounded-2xl border-b border-white/5 px-2 py-2.5 transition hover:bg-white/[0.028] last:border-b-0"
                  style={{ gridTemplateColumns: "30px 1fr 110px" }}
                  onClick={() =>
                    p.api_player_id &&
                    navigate(
                      `/player/${p.api_player_id}?league=${encodeURIComponent(
                        leagueParam
                      )}&season=${season}`
                    )
                  }
                  role="button"
                >
                  <span className="text-[11px] text-white/45 tabular-nums text-center">
                    {idx + 1}
                  </span>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <SafeImg
                        src={getPlayerPhoto(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                        alt={p.player_name || p.player}
                        className="h-[28px] w-[28px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                      />
                      <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis">
                        {p.player_name || p.player}
                      </span>
                    </div>
                    <div className="text-xs text-white/50 whitespace-nowrap overflow-hidden text-ellipsis">
                      {p.team_name || p.team}
                    </div>
                  </div>
                  <div className="text-xs text-white/80 tabular-nums text-right">
                    {Number(p.xg || 0).toFixed(2)}
                  </div>
                </div>
              ))}
            </div>
          </div>
          )}

          <div className="glass-card p-5">
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              {language === "ru" ? "Лучшие бомбардиры" : "Top scorers"}
            </div>
            <div className="mt-4 space-y-2.5">
              {topScorers.map((p, idx) => (
                <div
                  key={`sc-${p.player_id}-${idx}`}
                  className="grid cursor-pointer items-center gap-3 rounded-2xl border-b border-white/5 px-2 py-2.5 transition hover:bg-white/[0.028] last:border-b-0"
                  style={{ gridTemplateColumns: "30px 1fr 110px" }}
                  onClick={() =>
                    p.player_id &&
                    navigate(
                      `/player/${p.player_id}?league=${encodeURIComponent(
                        leagueParam
                      )}&season=${season}`
                    )
                  }
                  role="button"
                >
                  <span className="text-[11px] text-white/45 tabular-nums text-center">
                    {idx + 1}
                  </span>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <SafeImg
                        src={getPlayerPhoto(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                        alt={p.player_name}
                        className="h-[28px] w-[28px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                      />
                      <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis">
                        {p.player_name}
                      </span>
                    </div>
                    <div className="text-xs text-white/50 whitespace-nowrap overflow-hidden text-ellipsis">
                      {p.team_name || p.team}
                    </div>
                  </div>
                  <div className="flex items-center justify-end gap-2">
                    <div className="h-[6px] w-[70px] rounded-full bg-white/5 overflow-hidden">
                      <div
                        className="h-full bg-primary/40 rounded-full"
                        style={{
                          width: `${Math.min(
                            100,
                            topScorers.length
                              ? Math.max(
                                  6,
                                  (Number(p.goals || 0) /
                                    Math.max(...topScorers.map((x) => Number(x.goals || 0)))) *
                                    100
                                )
                              : 0
                          )}%`,
                        }}
                      />
                    </div>
                    <span className="text-xs text-white/80 tabular-nums">
                      {p.goals ?? "—"}
                    </span>
                  </div>
                </div>
              ))}
              {topScorers.length === 0 && (
                <div className="surface-empty">{language === "ru" ? "Нет данных" : "No data"}</div>
              )}
            </div>
          </div>

          <div className="glass-card p-5">
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              {language === "ru" ? "Лучшие ассистенты" : "Top assists"}
            </div>
            <div className="mt-4 space-y-2.5">
              {topAssists.map((p, idx) => (
                <div
                  key={`as-${p.player_id}-${idx}`}
                  className="grid cursor-pointer items-center gap-3 rounded-2xl border-b border-white/5 px-2 py-2.5 transition hover:bg-white/[0.028] last:border-b-0"
                  style={{ gridTemplateColumns: "30px 1fr 110px" }}
                  onClick={() =>
                    p.player_id &&
                    navigate(
                      `/player/${p.player_id}?league=${encodeURIComponent(
                        leagueParam
                      )}&season=${season}`
                    )
                  }
                  role="button"
                >
                  <span className="text-[11px] text-white/45 tabular-nums text-center">
                    {idx + 1}
                  </span>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <SafeImg
                        src={getPlayerPhoto(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                        alt={p.player_name}
                        className="h-[28px] w-[28px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                      />
                      <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis">
                        {p.player_name}
                      </span>
                    </div>
                    <div className="text-xs text-white/50 whitespace-nowrap overflow-hidden text-ellipsis">
                      {p.team_name || p.team}
                    </div>
                  </div>
                  <div className="flex items-center justify-end gap-2">
                    <div className="h-[6px] w-[70px] rounded-full bg-white/5 overflow-hidden">
                      <div
                        className="h-full bg-primary/40 rounded-full"
                        style={{
                          width: `${Math.min(
                            100,
                            topAssists.length
                              ? Math.max(
                                  6,
                                  (Number(p.assists ?? p.goals_assists ?? 0) /
                                    Math.max(
                                      ...topAssists.map((x) =>
                                        Number(x.assists ?? x.goals_assists ?? 0)
                                      )
                                    )) *
                                    100
                                )
                              : 0
                          )}%`,
                        }}
                      />
                    </div>
                    <span className="text-xs text-white/80 tabular-nums">
                      {p.assists ?? p.goals_assists ?? "—"}
                    </span>
                  </div>
                </div>
              ))}
              {topAssists.length === 0 && (
                <div className="surface-empty">{language === "ru" ? "Нет данных" : "No data"}</div>
              )}
            </div>
          </div>

          <div className="glass-card p-4">
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              Most MVP awards
            </div>
            <div className="mt-3 space-y-2">
              {topRated.map((p, idx) => (
                <div
                  key={`rt-${p.player_id}-${idx}`}
                  className="grid items-center gap-3 border-b border-white/5 last:border-b-0 py-1.5"
                  style={{ gridTemplateColumns: "30px 1fr 110px" }}
                  onClick={() =>
                    p.player_id &&
                    navigate(
                      `/player/${p.player_id}?league=${encodeURIComponent(
                        leagueParam
                      )}&season=${season}`
                    )
                  }
                  role="button"
                >
                  <span className="text-[11px] text-white/45 tabular-nums text-center">
                    {idx + 1}
                  </span>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <SafeImg
                        src={getPlayerPhoto(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                      />
                      <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis">
                        {p.player_name}
                      </span>
                    </div>
                    <div className="text-xs text-white/50 whitespace-nowrap overflow-hidden text-ellipsis">
                      {p.team_name || p.team}
                    </div>
                  </div>
                  <div className="flex items-center justify-end gap-2">
                    <div className="h-[6px] w-[70px] rounded-full bg-white/5 overflow-hidden">
                      <div
                        className="h-full bg-primary/40 rounded-full"
                        style={{
                          width: `${Math.min(
                            100,
                            topRated.length
                              ? Math.max(
                                  6,
                                  (Number(p.mvp_count || 0) /
                                    Math.max(...topRated.map((x) => Number(x.mvp_count || 0)))) *
                                    100
                                )
                              : 0
                          )}%`,
                        }}
                      />
                    </div>
                    <span className="text-xs text-white/80 tabular-nums">
                      {p.mvp_count ?? "—"}
                    </span>
                  </div>
                </div>
              ))}
              {topRated.length === 0 && (
                <div className="surface-empty">{language === "ru" ? "Нет данных" : "No data"}</div>
              )}
            </div>
          </div>

          {topShots.length > 0 && (
          <div className="glass-card p-4">
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              Most shots
            </div>
            <div className="mt-3 space-y-2">
              {topShots.map((p, idx) => (
                <div
                  key={`ms-${p.player_id}-${idx}`}
                  className="grid items-center gap-3 border-b border-white/5 last:border-b-0 py-1.5"
                  style={{ gridTemplateColumns: "30px 1fr 110px" }}
                  onClick={() =>
                    p.player_id &&
                    navigate(
                      `/player/${p.player_id}?league=${encodeURIComponent(
                        leagueParam
                      )}&season=${season}`
                    )
                  }
                  role="button"
                >
                  <span className="text-[11px] text-white/45 tabular-nums text-center">
                    {idx + 1}
                  </span>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <SafeImg
                        src={getPlayerPhoto(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                      />
                      <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis">
                        {p.player_name}
                      </span>
                    </div>
                    <div className="text-xs text-white/50 whitespace-nowrap overflow-hidden text-ellipsis">
                      {p.team_name || p.team}
                    </div>
                  </div>
                  <div className="flex items-center justify-end gap-2">
                    <div className="h-[6px] w-[70px] rounded-full bg-white/5 overflow-hidden">
                      <div
                        className="h-full bg-primary/40 rounded-full"
                        style={{
                          width: `${Math.min(
                            100,
                            topShots.length
                              ? Math.max(
                                  6,
                                  (Number(p.shots_total || 0) /
                                    Math.max(...topShots.map((x) => Number(x.shots_total || 0)))) *
                                    100
                                )
                              : 0
                          )}%`,
                        }}
                      />
                    </div>
                    <span className="text-xs text-white/80 tabular-nums">
                      {p.shots_total ?? "—"}
                    </span>
                  </div>
                </div>
              ))}
              {topShots.length === 0 && (
                <div className="surface-empty">{language === "ru" ? "Нет данных" : "No data"}</div>
              )}
            </div>
          </div>
          )}

          {topKeyPasses.length > 0 && (
          <div className="glass-card p-4">
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              Most key passes
            </div>
            <div className="mt-3 space-y-2">
              {topKeyPasses.map((p, idx) => (
                <div
                  key={`kp-${p.player_id}-${idx}`}
                  className="grid items-center gap-3 border-b border-white/5 last:border-b-0 py-1.5"
                  style={{ gridTemplateColumns: "30px 1fr 110px" }}
                  onClick={() =>
                    p.player_id &&
                    navigate(
                      `/player/${p.player_id}?league=${encodeURIComponent(
                        leagueParam
                      )}&season=${season}`
                    )
                  }
                  role="button"
                >
                  <span className="text-[11px] text-white/45 tabular-nums text-center">
                    {idx + 1}
                  </span>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <SafeImg
                        src={getPlayerPhoto(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                      />
                      <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis">
                        {p.player_name}
                      </span>
                    </div>
                    <div className="text-xs text-white/50 whitespace-nowrap overflow-hidden text-ellipsis">
                      {p.team_name || p.team}
                    </div>
                  </div>
                  <div className="flex items-center justify-end gap-2">
                    <div className="h-[6px] w-[70px] rounded-full bg-white/5 overflow-hidden">
                      <div
                        className="h-full bg-primary/40 rounded-full"
                        style={{
                          width: `${Math.min(
                            100,
                            topKeyPasses.length
                              ? Math.max(
                                  6,
                                  (Number(p.key_passes || 0) /
                                    Math.max(...topKeyPasses.map((x) => Number(x.key_passes || 0)))) *
                                    100
                                )
                              : 0
                          )}%`,
                        }}
                      />
                    </div>
                    <span className="text-xs text-white/80 tabular-nums">
                      {p.key_passes ?? "—"}
                    </span>
                  </div>
                </div>
              ))}
              {topKeyPasses.length === 0 && (
                <div className="surface-empty">{language === "ru" ? "Нет данных" : "No data"}</div>
              )}
            </div>
          </div>
          )}

          {topTackles.length > 0 && (
          <div className="glass-card p-4">
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              Most tackles
            </div>
            <div className="mt-3 space-y-2">
              {topTackles.map((p, idx) => (
                <div
                  key={`tk-${p.player_id}-${idx}`}
                  className="grid items-center gap-3 border-b border-white/5 last:border-b-0 py-1.5"
                  style={{ gridTemplateColumns: "30px 1fr 110px" }}
                  onClick={() =>
                    p.player_id &&
                    navigate(
                      `/player/${p.player_id}?league=${encodeURIComponent(
                        leagueParam
                      )}&season=${season}`
                    )
                  }
                  role="button"
                >
                  <span className="text-[11px] text-white/45 tabular-nums text-center">
                    {idx + 1}
                  </span>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <SafeImg
                        src={getPlayerPhoto(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                      />
                      <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis">
                        {p.player_name}
                      </span>
                    </div>
                    <div className="text-xs text-white/50 whitespace-nowrap overflow-hidden text-ellipsis">
                      {p.team_name || p.team}
                    </div>
                  </div>
                  <div className="flex items-center justify-end gap-2">
                    <div className="h-[6px] w-[70px] rounded-full bg-white/5 overflow-hidden">
                      <div
                        className="h-full bg-primary/40 rounded-full"
                        style={{
                          width: `${Math.min(
                            100,
                            topTackles.length
                              ? Math.max(
                                  6,
                                  (Number(p.tackles || 0) /
                                    Math.max(...topTackles.map((x) => Number(x.tackles || 0)))) *
                                    100
                                )
                              : 0
                          )}%`,
                        }}
                      />
                    </div>
                    <span className="text-xs text-white/80 tabular-nums">
                      {p.tackles ?? "—"}
                    </span>
                  </div>
                </div>
              ))}
              {topTackles.length === 0 && (
                <div className="surface-empty">{language === "ru" ? "Нет данных" : "No data"}</div>
              )}
            </div>
          </div>
          )}

          {topDribbles.length > 0 && (
          <div className="glass-card p-4">
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              Most dribbles
            </div>
            <div className="mt-3 space-y-2">
              {topDribbles.map((p, idx) => (
                <div
                  key={`dr-${p.player_id}-${idx}`}
                  className="grid items-center gap-3 border-b border-white/5 last:border-b-0 py-1.5"
                  style={{ gridTemplateColumns: "30px 1fr 110px" }}
                  onClick={() =>
                    p.player_id &&
                    navigate(
                      `/player/${p.player_id}?league=${encodeURIComponent(
                        leagueParam
                      )}&season=${season}`
                    )
                  }
                  role="button"
                >
                  <span className="text-[11px] text-white/45 tabular-nums text-center">
                    {idx + 1}
                  </span>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <SafeImg
                        src={getPlayerPhoto(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                      />
                      <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis">
                        {p.player_name}
                      </span>
                    </div>
                    <div className="text-xs text-white/50 whitespace-nowrap overflow-hidden text-ellipsis">
                      {p.team_name || p.team}
                    </div>
                  </div>
                  <div className="flex items-center justify-end gap-2">
                    <div className="h-[6px] w-[70px] rounded-full bg-white/5 overflow-hidden">
                      <div
                        className="h-full bg-primary/40 rounded-full"
                        style={{
                          width: `${Math.min(
                            100,
                            topDribbles.length
                              ? Math.max(
                                  6,
                                  (Number(p.dribbles || 0) /
                                    Math.max(...topDribbles.map((x) => Number(x.dribbles || 0)))) *
                                    100
                                )
                              : 0
                          )}%`,
                        }}
                      />
                    </div>
                    <span className="text-xs text-white/80 tabular-nums">
                      {p.dribbles ?? "—"}
                    </span>
                  </div>
                </div>
              ))}
              {topDribbles.length === 0 && (
                <div className="surface-empty">{language === "ru" ? "Нет данных" : "No data"}</div>
              )}
            </div>
          </div>
          )}

          {topDuelsWon.length > 0 && (
          <div className="glass-card p-4">
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              Most duels won
            </div>
            <div className="mt-3 space-y-2">
              {topDuelsWon.map((p, idx) => (
                <div
                  key={`dw-${p.player_id}-${idx}`}
                  className="grid items-center gap-3 border-b border-white/5 last:border-b-0 py-1.5"
                  style={{ gridTemplateColumns: "30px 1fr 110px" }}
                  onClick={() =>
                    p.player_id &&
                    navigate(
                      `/player/${p.player_id}?league=${encodeURIComponent(
                        leagueParam
                      )}&season=${season}`
                    )
                  }
                  role="button"
                >
                  <span className="text-[11px] text-white/45 tabular-nums text-center">
                    {idx + 1}
                  </span>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <SafeImg
                        src={getPlayerPhoto(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                      />
                      <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis">
                        {p.player_name}
                      </span>
                    </div>
                    <div className="text-xs text-white/50 whitespace-nowrap overflow-hidden text-ellipsis">
                      {p.team_name || p.team}
                    </div>
                  </div>
                  <div className="flex items-center justify-end gap-2">
                    <div className="h-[6px] w-[70px] rounded-full bg-white/5 overflow-hidden">
                      <div
                        className="h-full bg-primary/40 rounded-full"
                        style={{
                          width: `${Math.min(
                            100,
                            topDuelsWon.length
                              ? Math.max(
                                  6,
                                  (Number(p.duels_won || 0) /
                                    Math.max(...topDuelsWon.map((x) => Number(x.duels_won || 0)))) *
                                    100
                                )
                              : 0
                          )}%`,
                        }}
                      />
                    </div>
                    <span className="text-xs text-white/80 tabular-nums">
                      {p.duels_won ?? "—"}
                    </span>
                  </div>
                </div>
              ))}
              {topDuelsWon.length === 0 && (
                <div className="surface-empty">{language === "ru" ? "Нет данных" : "No data"}</div>
              )}
            </div>
          </div>
          )}

          {topInterceptions.length > 0 && (
          <div className="glass-card p-4">
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              Most interceptions
            </div>
            <div className="mt-3 space-y-2">
              {topInterceptions.map((p, idx) => (
                <div
                  key={`it-${p.player_id}-${idx}`}
                  className="grid items-center gap-3 border-b border-white/5 last:border-b-0 py-1.5"
                  style={{ gridTemplateColumns: "30px 1fr 110px" }}
                  onClick={() =>
                    p.player_id &&
                    navigate(
                      `/player/${p.player_id}?league=${encodeURIComponent(
                        leagueParam
                      )}&season=${season}`
                    )
                  }
                  role="button"
                >
                  <span className="text-[11px] text-white/45 tabular-nums text-center">
                    {idx + 1}
                  </span>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <SafeImg
                        src={getPlayerPhoto(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                      />
                      <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis">
                        {p.player_name}
                      </span>
                    </div>
                    <div className="text-xs text-white/50 whitespace-nowrap overflow-hidden text-ellipsis">
                      {p.team_name || p.team}
                    </div>
                  </div>
                  <div className="flex items-center justify-end gap-2">
                    <div className="h-[6px] w-[70px] rounded-full bg-white/5 overflow-hidden">
                      <div
                        className="h-full bg-primary/40 rounded-full"
                        style={{
                          width: `${Math.min(
                            100,
                            topInterceptions.length
                              ? Math.max(
                                  6,
                                  (Number(p.interceptions || 0) /
                                    Math.max(...topInterceptions.map((x) => Number(x.interceptions || 0)))) *
                                    100
                                )
                              : 0
                          )}%`,
                        }}
                      />
                    </div>
                    <span className="text-xs text-white/80 tabular-nums">
                      {p.interceptions ?? "—"}
                    </span>
                  </div>
                </div>
              ))}
              {topInterceptions.length === 0 && (
                <div className="surface-empty">{language === "ru" ? "Нет данных" : "No data"}</div>
              )}
            </div>
          </div>
          )}

          {topMinutes.length > 0 && (
          <div className="glass-card p-4">
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              Most minutes
            </div>
            <div className="mt-3 space-y-2">
              {topMinutes.map((p, idx) => (
                <div
                  key={`mn-${p.player_id}-${idx}`}
                  className="grid items-center gap-3 border-b border-white/5 last:border-b-0 py-1.5"
                  style={{ gridTemplateColumns: "30px 1fr 110px" }}
                  onClick={() =>
                    p.player_id &&
                    navigate(
                      `/player/${p.player_id}?league=${encodeURIComponent(
                        leagueParam
                      )}&season=${season}`
                    )
                  }
                  role="button"
                >
                  <span className="text-[11px] text-white/45 tabular-nums text-center">
                    {idx + 1}
                  </span>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <SafeImg
                        src={getPlayerPhoto(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(resolvePlayerId(p.player_id, p.api_player_id, p.understat_player_id))}
                      />
                      <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis">
                        {p.player_name}
                      </span>
                    </div>
                    <div className="text-xs text-white/50 whitespace-nowrap overflow-hidden text-ellipsis">
                      {p.team_name || p.team}
                    </div>
                  </div>
                  <div className="flex items-center justify-end gap-2">
                    <div className="h-[6px] w-[70px] rounded-full bg-white/5 overflow-hidden">
                      <div
                        className="h-full bg-primary/40 rounded-full"
                        style={{
                          width: `${Math.min(
                            100,
                            topMinutes.length
                              ? Math.max(
                                  6,
                                  (Number(p.minutes || 0) /
                                    Math.max(...topMinutes.map((x) => Number(x.minutes || 0)))) *
                                    100
                                )
                              : 0
                          )}%`,
                        }}
                      />
                    </div>
                    <span className="text-xs text-white/80 tabular-nums">
                      {p.minutes ?? "—"}
                    </span>
                  </div>
                </div>
              ))}
              {topMinutes.length === 0 && (
                <div className="surface-empty">{language === "ru" ? "Нет данных" : "No data"}</div>
              )}
            </div>
          </div>
          )}
        </div>
      </div>
      )}

      {view === "insights" && (
        <div className="space-y-8">
          {analyticsLoading && (
            <div className="surface-loading">{language === "ru" ? "Загрузка аналитики…" : "Loading insights…"}</div>
          )}

          <div className="glass-card p-6">
            <div className="mb-3 text-xs uppercase tracking-[0.16em] text-[#9aa3b2]">{language === "ru" ? "Фильтры" : "Filters"}</div>
            <div className="mb-5">
              <SegmentedTabs
                items={[
                  { key: "teams", label: language === "ru" ? "Команды" : "Teams" },
                  { key: "players", label: language === "ru" ? "Игроки" : "Players" },
                ]}
                value={insightsSection}
                onChange={setInsightsSection}
                listClassName="gap-6"
                buttonClassName="tracking-wide"
                activeClassName="text-white"
              />
            </div>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
              {insightsSection === "teams" ? (
                <select
                  value={trendWindow}
                  onChange={(e) => setTrendWindow(Number(e.target.value))}
                  className="surface-select h-8 w-full min-w-0 text-[12px] text-left text-white/80"
                >
                  <option value={5} className="bg-slate-900">{language === "ru" ? "Последние 5 матчей" : "Last 5 matches"}</option>
                  <option value={10} className="bg-slate-900">{language === "ru" ? "Последние 10 матчей" : "Last 10 matches"}</option>
                  <option value={15} className="bg-slate-900">{language === "ru" ? "Последние 15 матчей" : "Last 15 matches"}</option>
                  <option value={20} className="bg-slate-900">{language === "ru" ? "Последние 20 матчей" : "Last 20 matches"}</option>
                </select>
              ) : (
                <>
                  <select
                    value={minMinutes}
                    onChange={(e) => setMinMinutes(Number(e.target.value))}
                    className="surface-select h-8 w-full min-w-0 text-[12px] text-left text-white/80"
                  >
                    <option value={900} className="bg-slate-900">{language === "ru" ? "Игроки: 900+ минут" : "Players: 900+ minutes"}</option>
                    <option value={0} className="bg-slate-900">{language === "ru" ? "Игроки: без лимита минут" : "Players: no minutes limit"}</option>
                    <option value={90} className="bg-slate-900">{language === "ru" ? "Игроки: 90+ минут" : "Players: 90+ minutes"}</option>
                    <option value={180} className="bg-slate-900">{language === "ru" ? "Игроки: 180+ минут" : "Players: 180+ minutes"}</option>
                    <option value={360} className="bg-slate-900">{language === "ru" ? "Игроки: 360+ минут" : "Players: 360+ minutes"}</option>
                    <option value={720} className="bg-slate-900">{language === "ru" ? "Игроки: 720+ минут" : "Players: 720+ minutes"}</option>
                  </select>
                  <select
                    value={minShots}
                    onChange={(e) => setMinShots(Number(e.target.value))}
                    className="surface-select h-8 w-full min-w-0 text-[12px] text-left text-white/80"
                  >
                    <option value={5} className="bg-slate-900">{language === "ru" ? "Игроки: 5+ ударов" : "Players: 5+ shots"}</option>
                    <option value={10} className="bg-slate-900">{language === "ru" ? "Игроки: 10+ ударов" : "Players: 10+ shots"}</option>
                    <option value={20} className="bg-slate-900">{language === "ru" ? "Игроки: 20+ ударов" : "Players: 20+ shots"}</option>
                    <option value={30} className="bg-slate-900">{language === "ru" ? "Игроки: 30+ ударов" : "Players: 30+ shots"}</option>
                    <option value={40} className="bg-slate-900">{language === "ru" ? "Игроки: 40+ ударов" : "Players: 40+ shots"}</option>
                  </select>
                  <select
                    value={teamFilter}
                    onChange={(e) => setTeamFilter(e.target.value)}
                    className="surface-select h-8 w-full min-w-0 text-[12px] text-left text-white/80"
                  >
                    <option value="all" className="bg-slate-900">{language === "ru" ? "Все команды" : "All teams"}</option>
                    {teamFilterOptions.map((teamName) => (
                      <option key={teamName} value={teamName} className="bg-slate-900">{teamName}</option>
                    ))}
                  </select>
                </>
              )}
            </div>
            {analytics.fallback_mode && (
              <div className="mt-3 text-xs text-white/50">
                {language === "ru" ? "Для этой лиги часть Understat-метрик недоступна. Показаны базовые командные инсайты из API-статистики." : "Some Understat metrics are unavailable for this league. Basic team insights from API stats are shown instead."}
              </div>
            )}
          </div>

          {insightsSection === "teams" && hasTeamMap && (
            <Suspense fallback={renderAnalyticsFallback(language)}>
              <>
                <div className="space-y-1">
                  <div className="text-[11px] uppercase tracking-[0.16em] text-[#9aa3b2]">{language === "ru" ? "Ключевой график" : "Key chart"}</div>
                  <div className="text-lg font-semibold text-white">{language === "ru" ? "Карта силы команд" : "Team strength map"}</div>
                </div>
                <LeaguePerformanceMap
                  teams={analytics.teams}
                  height={480}
                  highlightedTeam={highlightedTeam}
                  onTeamHover={setHighlightedTeam}
                />
              </>
            </Suspense>
          )}

          {insightsSection === "teams" && (hasOverperformance || hasShotEfficiency) && (
            <Suspense fallback={renderAnalyticsFallback(language)}>
              <div className="space-y-6">
                {hasOverperformance && (
                  <OverperformanceChart
                    teams={analytics.teams}
                    highlightedTeam={highlightedTeam}
                    onTeamHover={setHighlightedTeam}
                  />
                )}
                {hasShotEfficiency && (
                  <ShotEfficiencyChart
                    teams={analytics.teams}
                    highlightedTeam={highlightedTeam}
                    onTeamHover={setHighlightedTeam}
                  />
                )}
              </div>
            </Suspense>
          )}

          {insightsSection === "players" && (hasPlayerFinishing || hasChanceCreators) && (
            <Suspense fallback={renderAnalyticsFallback(language)}>
              <div className="space-y-6">
                {hasPlayerFinishing && (
                  <PlayerFinishingChart
                    players={analytics.players}
                    minMinutes={minMinutes}
                    minShots={minShots}
                    teamFilter={teamFilter}
                    onPlayerSelect={openPlayerCard}
                  />
                )}
                {hasChanceCreators && (
                  <ChanceCreatorsChart
                    players={analytics.players}
                    teamFilter={teamFilter}
                    onPlayerSelect={openPlayerCard}
                  />
                )}
              </div>
            </Suspense>
          )}

          {insightsSection === "teams" && (hasTrends || hasLeaders) && (
            <Suspense fallback={renderAnalyticsFallback(language)}>
              <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
                {hasTrends && (
                  <TeamFormGrid
                    trends={analytics.trends}
                    teams={analytics.teams}
                    trendWindow={trendWindow}
                    highlightedTeam={highlightedTeam}
                    onTeamHover={setHighlightedTeam}
                  />
                )}
                {hasLeaders && <HistoricalLeaders leaders={analytics.leaders} />}
              </div>
            </Suspense>
          )}

          {insightsSection === "teams" && filteredTeamsForInsights.length > 0 && (
            <Suspense fallback={renderAnalyticsFallback(language)}>
              <InsightsPanel teams={filteredTeamsForInsights} />
            </Suspense>
          )}
        </div>
      )}

      {view === "teams" && (
        <div className="flex items-center justify-between text-xs text-white/55">
          <div>
            {language === "ru" ? "Показано" : "Showing"} {(page - 1) * pageSize + 1}–{Math.min(page * pageSize, sortedRows.length)} {language === "ru" ? "из" : "of"} {sortedRows.length}
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              className="rounded-full border border-white/10 px-3 py-1 hover:border-white/25"
              disabled={page === 1}
            >
              Prev
            </button>
            <span className="tabular-nums">
              {page} / {totalPages}
            </span>
            <button
              type="button"
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              className="rounded-full border border-white/10 px-3 py-1 hover:border-white/25"
              disabled={page === totalPages}
            >
              Next
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
