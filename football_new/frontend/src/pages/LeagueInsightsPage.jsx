import { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import clsx from "clsx";
import SafeImg from "@/components/SafeImg";
import LeaguePerformanceMap from "@/components/analytics/LeaguePerformanceMap";
import OverperformanceChart from "@/components/analytics/OverperformanceChart";
import ShotEfficiencyChart from "@/components/analytics/ShotEfficiencyChart";
import PlayerFinishingChart from "@/components/analytics/PlayerFinishingChart";
import ChanceCreatorsChart from "@/components/analytics/ChanceCreatorsChart";
import TeamFormGrid from "@/components/analytics/TeamFormGrid";
import HistoricalLeaders from "@/components/analytics/HistoricalLeaders";
import InsightsPanel from "@/components/analytics/InsightsPanel";
import SegmentedTabs from "@/components/ui/SegmentedTabs";

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

const periodLabel = (windowValue) => {
  if (!windowValue || windowValue === "season") return "Сезон";
  const n = Number(windowValue);
  if (!Number.isFinite(n)) return "Сезон";
  if (n === 1) return "1 матч";
  return `${n} матчей`;
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

const getTeamLogo = (id) =>
  id ? `/icons/team_logos/${id}.png` : "/icons/default_league.png";
const getTeamLogoFallback = (id) =>
  id ? `https://media.api-sports.io/football/teams/${id}.png` : "/icons/default_league.png";
const getPlayerPhoto = (id) =>
  id ? `/icons/player_photos/${id}.png` : "/icons/player_photos/default.png";
const getPlayerPhotoFallback = (id) =>
  id ? `https://media.api-sports.io/football/players/${id}.png` : "/icons/player_photos/default.png";

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

export default function LeagueInsightsPage() {
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
    fetch(`/api/insights?${params.toString()}`)
      .then((r) => r.json())
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
    fetch(`/api/league-analytics?${qs.toString()}`)
      .then((r) => r.json())
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
  }, [leagueParam, season, window, uclStage, trendWindow, minMinutes, minShots, isUcl]);

  useEffect(() => {
    setPlayersLoading(true);
    const qs = new URLSearchParams({
      league: leagueParam,
      season,
    });
    if (window && window !== "season") qs.set("window", window);
    if (isUcl) qs.set("ucl_stage", uclStage);
    Promise.all([
      fetch(`/api/top-scorers?${qs.toString()}`).then((r) => r.json()),
      fetch(`/api/top-assists?${qs.toString()}`).then((r) => r.json()),
      fetch(`/api/players/mvp?${qs.toString()}&limit=5`).then((r) => r.json()),
      fetch(`/api/players/shots?${qs.toString()}&limit=5`).then((r) => r.json()),
      fetch(`/api/players/key-passes?${qs.toString()}&limit=5`).then((r) => r.json()),
      fetch(`/api/players/tackles?${qs.toString()}&limit=5`).then((r) => r.json()),
      fetch(`/api/players/dribbles?${qs.toString()}&limit=5`).then((r) => r.json()),
      fetch(`/api/players/duels-won?${qs.toString()}&limit=5`).then((r) => r.json()),
      fetch(`/api/players/interceptions?${qs.toString()}&limit=5`).then((r) => r.json()),
      fetch(`/api/players/minutes?${qs.toString()}&limit=5`).then((r) => r.json()),
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
  }, [leagueParam, season, window, uclStage, isUcl]);

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

  const selectedPeriodLabel = useMemo(() => periodLabel(window), [window]);

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
      { key: "shots", label: "Shots" },
      { key: "shots_on_target", label: "Shots on target" },
      { key: "shots_inside_box", label: "Big chances" },
      { key: "goals", label: "Goals" },
      { key: "dangerous_attacks", label: "Dangerous attacks" },
    ],
    defense: [
      { key: "shots_conceded", label: "Shots conceded", dir: "asc" },
      { key: "xga", label: "xGA", dir: "asc" },
      { key: "goals_conceded", label: "Goals conceded", dir: "asc" },
      { key: "tackles", label: "Tackles" },
      { key: "corners", label: "Corners" },
      { key: "shots_diff", label: "Shot difference" },
    ],
    possession: [
      { key: "possession", label: "Possession" },
      { key: "attacks", label: "Attacks" },
      { key: "dangerous_attacks", label: "Dangerous attacks" },
      { key: "corners", label: "Corners" },
      { key: "deep_avg", label: "Deep progressions" },
      { key: "tempo_shots_per_game", label: "Shot tempo" },
    ],
    advanced: [
      { key: "xg_diff", label: "xG difference" },
      { key: "shots_diff", label: "Shot difference" },
      { key: "goal_diff", label: "Goal difference" },
      { key: "xg", label: "xG" },
      { key: "xga", label: "xGA", dir: "asc" },
      { key: "goals", label: "Goals" },
    ],
  };

  return (
    <div className="w-full px-4 py-8 space-y-8">
      {/* HEADER */}
      <div>
        <div className="panel rounded-3xl p-6 md:p-8">
          <div className="flex items-start justify-between gap-4">
            <div className="space-y-1.5">
              <div className="text-[11px] uppercase tracking-[0.18em] text-muted">
                АНАЛИТИКА
              </div>

              <div className="text-xl sm:text-2xl font-semibold text-white">
                {leagueParam}
              </div>

              <p className="text-sm text-slate-400 max-w-[640px] leading-relaxed">
                Премиальная визуальная аналитика лиги.
              </p>
            </div>

            <div className="flex flex-col items-end gap-3">
              <span className="text-[10px] uppercase tracking-[0.18em] text-muted mb-1">
                СЕЗОН
              </span>
              <select
                value={season}
                onChange={(e) => setSeason(e.target.value)}
                className="h-8 w-[168px] rounded-full bg-white/5 border border-white/10 px-3 text-[13px] text-left text-white/80 tabular-nums focus:outline-none focus:ring-1 focus:ring-white/20"
              >
                {SEASONS.map((s) => (
                  <option key={s} value={s} className="bg-slate-900">
                    {s}
                  </option>
                ))}
              </select>
              <div className="flex items-center gap-2">
                <span className="text-[10px] uppercase tracking-[0.18em] text-muted">
                  Период
                </span>
                <select
                  value={window}
                  onChange={(e) => setWindow(e.target.value)}
                  className="h-7 w-[168px] rounded-full bg-white/5 border border-white/10 px-3 text-[12px] text-left text-white/80 tabular-nums focus:outline-none focus:ring-1 focus:ring-white/20"
                >
                  <option value="season" className="bg-slate-900">Сезон</option>
                  <option value="1" className="bg-slate-900">Последний тур</option>
                  <option value="5" className="bg-slate-900">Последние 5</option>
                  <option value="10" className="bg-slate-900">Последние 10</option>
                  <option value="15" className="bg-slate-900">Последние 15</option>
                </select>
              </div>
              {isUcl && (
                <div className="flex items-center gap-2">
                  <span className="text-[10px] uppercase tracking-[0.18em] text-muted">
                    Стадия
                  </span>
                  <select
                    value={uclStage}
                    onChange={(e) => setUclStage(e.target.value)}
                    className="h-7 w-[168px] rounded-full bg-white/5 border border-white/10 px-3 text-[12px] text-left text-white/80 tabular-nums focus:outline-none focus:ring-1 focus:ring-white/20"
                  >
                    <option value="league" className="bg-slate-900">Турнирная таблица</option>
                    <option value="playoff" className="bg-slate-900">Плей-офф</option>
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
          { key: "teams", label: "Команды" },
          { key: "players", label: "Игроки" },
          { key: "insights", label: "Инсайты" },
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
            className="glass-card p-4 transition hover:border-primary"
          >
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              {c.title}
            </div>
            <div className="mt-2 flex items-center gap-3">
              <SafeImg
                src={getTeamLogo(c.data?.team_id)}
                alt={c.data?.team || "team"}
                className="h-7 w-7 object-contain"
                fallbackSrc={getTeamLogoFallback(c.data?.team_id)}
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
                ? `${leagueParam} ${season} · сыграно ${c.data?.matches ?? "—"}`
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
                          src={getTeamLogo(t.team_id)}
                          alt={t.team}
                          className="h-[16px] w-[16px] object-contain flex-shrink-0"
                          fallbackSrc={getTeamLogoFallback(t.team_id)}
                        />
                        <span className="text-sm text-white whitespace-nowrap overflow-hidden text-ellipsis">
                          {t.team}
                        </span>
                        <div className="w-full h-[6px] bg-white/10 rounded overflow-hidden">
                          <div
                            className="h-full bg-primary/50 rounded"
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
            className="sticky top-0 bg-[#0f1422] text-slate-300 text-sm font-semibold"
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
                      src={getTeamLogo(t.team_id)}
                      alt={t.team}
                      className="h-[18px] w-[18px] object-contain"
                      fallbackSrc={getTeamLogoFallback(t.team_id)}
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
        <div className="text-sm text-white/45">Загрузка данных…</div>
      )}
      </>
      )}

      {/* PLAYER METRICS */}
      {view === "players" && (
      <div className="space-y-6">
        <div className="text-lg font-semibold text-white">Player Insights</div>
        {playersLoading && (
          <div className="text-sm text-white/45">Загрузка игроков…</div>
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
                  className="grid items-center gap-3 rounded-2xl border-b border-white/5 last:border-b-0 py-3 px-2 transition hover:bg-white/[0.03] cursor-pointer"
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
                      src={getPlayerPhoto(row.item?.player_id)}
                      alt={row.item?.player_name || row.item?.player}
                      className="h-[28px] w-[28px] rounded-full border border-white/20 object-cover flex-shrink-0"
                      fallbackSrc={getPlayerPhotoFallback(row.item?.player_id)}
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
                  className="grid items-center gap-3 rounded-2xl border-b border-white/5 last:border-b-0 py-2.5 px-2 transition hover:bg-white/[0.03] cursor-pointer"
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
                        src={getPlayerPhoto(p.player_id)}
                        alt={p.player_name || p.player}
                        className="h-[28px] w-[28px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(p.player_id)}
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
              Top scorers
            </div>
            <div className="mt-4 space-y-2.5">
              {topScorers.map((p, idx) => (
                <div
                  key={`sc-${p.player_id}-${idx}`}
                  className="grid items-center gap-3 rounded-2xl border-b border-white/5 last:border-b-0 py-2.5 px-2 transition hover:bg-white/[0.03] cursor-pointer"
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
                        src={getPlayerPhoto(p.player_id)}
                        alt={p.player_name}
                        className="h-[28px] w-[28px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(p.player_id)}
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
                <div className="text-sm text-white/45">No data</div>
              )}
            </div>
          </div>

          <div className="glass-card p-5">
            <div className="text-xs uppercase tracking-[0.18em] text-white/45">
              Top assists
            </div>
            <div className="mt-4 space-y-2.5">
              {topAssists.map((p, idx) => (
                <div
                  key={`as-${p.player_id}-${idx}`}
                  className="grid items-center gap-3 rounded-2xl border-b border-white/5 last:border-b-0 py-2.5 px-2 transition hover:bg-white/[0.03] cursor-pointer"
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
                        src={getPlayerPhoto(p.player_id)}
                        alt={p.player_name}
                        className="h-[28px] w-[28px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(p.player_id)}
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
                <div className="text-sm text-white/45">No data</div>
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
                        src={getPlayerPhoto(p.player_id)}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(p.player_id)}
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
                <div className="text-sm text-white/45">No data</div>
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
                        src={getPlayerPhoto(p.player_id)}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(p.player_id)}
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
                <div className="text-sm text-white/45">No data</div>
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
                        src={getPlayerPhoto(p.player_id)}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(p.player_id)}
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
                <div className="text-sm text-white/45">No data</div>
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
                        src={getPlayerPhoto(p.player_id)}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(p.player_id)}
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
                <div className="text-sm text-white/45">No data</div>
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
                        src={getPlayerPhoto(p.player_id)}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(p.player_id)}
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
                <div className="text-sm text-white/45">No data</div>
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
                        src={getPlayerPhoto(p.player_id)}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(p.player_id)}
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
                <div className="text-sm text-white/45">No data</div>
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
                        src={getPlayerPhoto(p.player_id)}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(p.player_id)}
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
                <div className="text-sm text-white/45">No data</div>
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
                        src={getPlayerPhoto(p.player_id)}
                        alt={p.player_name}
                        className="h-[24px] w-[24px] rounded-full border border-white/20 object-cover flex-shrink-0"
                        fallbackSrc={getPlayerPhotoFallback(p.player_id)}
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
                <div className="text-sm text-white/45">No data</div>
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
            <div className="text-sm text-white/45">Загрузка аналитики…</div>
          )}

          <div className="glass-card p-6">
            <div className="mb-3 text-xs uppercase tracking-[0.16em] text-[#9aa3b2]">Фильтры</div>
            <div className="mb-5">
              <SegmentedTabs
                items={[
                  { key: "teams", label: "Команды" },
                  { key: "players", label: "Игроки" },
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
                  className="h-8 w-full min-w-0 rounded-full bg-white/5 border border-white/10 px-3 text-[12px] text-left text-white/80 focus:outline-none"
                >
                  <option value={5} className="bg-slate-900">Последние 5 матчей</option>
                  <option value={10} className="bg-slate-900">Последние 10 матчей</option>
                  <option value={15} className="bg-slate-900">Последние 15 матчей</option>
                  <option value={20} className="bg-slate-900">Последние 20 матчей</option>
                </select>
              ) : (
                <>
                  <select
                    value={minMinutes}
                    onChange={(e) => setMinMinutes(Number(e.target.value))}
                    className="h-8 w-full min-w-0 rounded-full bg-white/5 border border-white/10 px-3 text-[12px] text-left text-white/80 focus:outline-none"
                  >
                    <option value={900} className="bg-slate-900">Игроки: 900+ минут</option>
                    <option value={0} className="bg-slate-900">Игроки: без лимита минут</option>
                    <option value={90} className="bg-slate-900">Игроки: 90+ минут</option>
                    <option value={180} className="bg-slate-900">Игроки: 180+ минут</option>
                    <option value={360} className="bg-slate-900">Игроки: 360+ минут</option>
                    <option value={720} className="bg-slate-900">Игроки: 720+ минут</option>
                  </select>
                  <select
                    value={minShots}
                    onChange={(e) => setMinShots(Number(e.target.value))}
                    className="h-8 w-full min-w-0 rounded-full bg-white/5 border border-white/10 px-3 text-[12px] text-left text-white/80 focus:outline-none"
                  >
                    <option value={5} className="bg-slate-900">Игроки: 5+ ударов</option>
                    <option value={10} className="bg-slate-900">Игроки: 10+ ударов</option>
                    <option value={20} className="bg-slate-900">Игроки: 20+ ударов</option>
                    <option value={30} className="bg-slate-900">Игроки: 30+ ударов</option>
                    <option value={40} className="bg-slate-900">Игроки: 40+ ударов</option>
                  </select>
                  <select
                    value={teamFilter}
                    onChange={(e) => setTeamFilter(e.target.value)}
                    className="h-8 w-full min-w-0 rounded-full bg-white/5 border border-white/10 px-3 text-[12px] text-left text-white/80 focus:outline-none"
                  >
                    <option value="all" className="bg-slate-900">Все команды</option>
                    {teamFilterOptions.map((teamName) => (
                      <option key={teamName} value={teamName} className="bg-slate-900">{teamName}</option>
                    ))}
                  </select>
                </>
              )}
            </div>
            {analytics.fallback_mode && (
              <div className="mt-3 text-xs text-white/50">
                Для этой лиги часть Understat-метрик недоступна. Показаны базовые командные инсайты из API-статистики.
              </div>
            )}
          </div>

          {insightsSection === "teams" && hasTeamMap && (
            <>
              <div className="space-y-1">
                <div className="text-[11px] uppercase tracking-[0.16em] text-[#9aa3b2]">Ключевой график</div>
                <div className="text-lg font-semibold text-white">Карта силы команд</div>
              </div>
              <LeaguePerformanceMap
                teams={analytics.teams}
                height={480}
                highlightedTeam={highlightedTeam}
                onTeamHover={setHighlightedTeam}
              />
            </>
          )}

          {insightsSection === "teams" && (hasOverperformance || hasShotEfficiency) && (
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
          )}

          {insightsSection === "players" && (hasPlayerFinishing || hasChanceCreators) && (
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
          )}

          {insightsSection === "teams" && (hasTrends || hasLeaders) && (
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
          )}

          {insightsSection === "teams" && filteredTeamsForInsights.length > 0 && <InsightsPanel teams={filteredTeamsForInsights} />}
        </div>
      )}

      {view === "teams" && (
        <div className="flex items-center justify-between text-xs text-white/55">
          <div>
            Показано {(page - 1) * pageSize + 1}–{Math.min(page * pageSize, sortedRows.length)} из {sortedRows.length}
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
