// ========================
// Premium Global League Header (Variant C)
// ========================

import { useEffect, useMemo, useRef, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import clsx from "clsx";
import { AnimatePresence, motion } from "framer-motion";
import { createPortal } from "react-dom";

import { shouldHideMonetization } from "@/lib/pilotAccess.js";
import LanguageSwitcher from "@/components/LanguageSwitcher.jsx";
import { useLanguage } from "@/context/LanguageContext.jsx";
import SafeImg from "@/components/SafeImg.jsx";

/* ========= constants & helpers ========= */

const DEFAULT_LEAGUE_ICON =
  "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='16' fill='%2310223a'/%3E%3Cpath fill='%23e5e7eb' d='M32 10 48 54h-8l-8-22-8 22h-8z'/%3E%3C/svg%3E";

function defaultSeasonForLeague(name) {
  const value = String(name || "");
  if (value === "Euro Championship") return 2024;
  if (value === "Euro Championship - Qualification") return 2023;
  return 2026;
}

function safeGet(k, def) {
  try {
    const v = localStorage.getItem(k);
    return v ? JSON.parse(v) : def;
  } catch {
    return def;
  }
}
function safeSet(k, v) {
  try {
    localStorage.setItem(k, JSON.stringify(v));
  } catch {}
}

function getLeagueLogo(name) {
  return "/icons/" + String(name).replace(/\s/g, "_") + ".png";
}

const TOP_LEAGUES_META = [
  {
    name: "Premier League",
    country: "Англия",
    teams: 20,
    seasonYear: defaultSeasonForLeague("Premier League"),
    logo: "/icons/leagues/premier_league.png",
  },
  {
    name: "La Liga",
    country: "Испания",
    teams: 20,
    seasonYear: defaultSeasonForLeague("La Liga"),
    logo: "/icons/leagues/la_liga.png",
  },
  {
    name: "Bundesliga",
    country: "Германия",
    teams: 18,
    seasonYear: defaultSeasonForLeague("Bundesliga"),
    logo: "/icons/leagues/bundesliga.png",
  },
  {
    name: "Serie A",
    country: "Италия",
    teams: 20,
    seasonYear: defaultSeasonForLeague("Serie A"),
    logo: "/icons/leagues/serie_a.png",
  },
  {
    name: "Ligue 1",
    country: "Франция",
    teams: 18,
    seasonYear: defaultSeasonForLeague("Ligue 1"),
    logo: "/icons/leagues/ligue_1.png",
  },
  {
    name: "UEFA Champions League",
    country: "Европа",
    teams: 32,
    seasonYear: defaultSeasonForLeague("UEFA Champions League"),
    logo: "/icons/cups/champions_league.png",
  },
  {
    name: "UEFA Europa League",
    country: "Европа",
    teams: 36,
    seasonYear: defaultSeasonForLeague("UEFA Europa League"),
    logo: "/icons/cups/europa_league.png",
  },
  {
    name: "World Cup",
    country: "Сборные",
    teams: 32,
    seasonYear: defaultSeasonForLeague("World Cup"),
    logo: "/icons/World_Cup.png",
  },
  {
    name: "Euro Championship",
    country: "Сборные",
    teams: 24,
    seasonYear: defaultSeasonForLeague("Euro Championship"),
    logo: "/icons/Euro_Championship.png",
  },
];

const LEAGUE_LOGO_OVERRIDES = {
  "Premier League": "/icons/Premier_League.png",
  "La Liga": "/icons/La_Liga.png",
  Bundesliga: "/icons/Bundesliga.png",
  "Serie A": "/icons/Serie_A.png",
  "Ligue 1": "/icons/Ligue_1.png",
  "UEFA Champions League": "/icons/UEFA_Champions_League.png",
  "UEFA Europa League": "/icons/UEFA_Europa_League.png",
  "World Cup": "/icons/World_Cup.png",
  "Euro Championship": "/icons/Euro_Championship.png",
  "Euro Championship - Qualification": "/icons/Euro_Championship_Qualification.png",
  "World Cup - Qualification Europe": "/icons/World_Cup_Qualification_Europe.png",
  "World Cup - Qualification Africa": "/icons/World_Cup_Qualification_Africa.png",
  "World Cup - Qualification Asia": "/icons/World_Cup_Qualification_Asia.png",
  "World Cup - Qualification CONCACAF": "/icons/World_Cup_Qualification_CONCACAF.png",
  "World Cup - Qualification South America": "/icons/World_Cup_Qualification_South_America.png",
  "World Cup - Qualification Oceania": "/icons/World_Cup_Qualification_Oceania.png",
  "World Cup - Qualification Intercontinental Play-offs": "/icons/World_Cup_Qualification_Intercontinental_Play-offs.png",
  "Primeira Liga": "/icons/Primeira_Liga.png",
  Eredivisie: "/icons/Eredivisie.png",
  "Süper Lig": "/icons/Süper_Lig.png",
};

const CATALOG_LEAGUES_META = [
  ...TOP_LEAGUES_META,
  {
    name: "Primeira Liga",
    country: "Португалия",
    teams: 18,
    seasonYear: defaultSeasonForLeague("Primeira Liga"),
    logo: "/icons/Primeira_Liga.png",
  },
  {
    name: "Eredivisie",
    country: "Нидерланды",
    teams: 18,
    seasonYear: defaultSeasonForLeague("Eredivisie"),
    logo: "/icons/Eredivisie.png",
  },
  {
    name: "Süper Lig",
    country: "Турция",
    teams: 20,
    seasonYear: defaultSeasonForLeague("Süper Lig"),
    logo: "/icons/Süper_Lig.png",
  },
  {
    name: "Euro Championship - Qualification",
    country: "Сборные",
    teams: 53,
    seasonYear: defaultSeasonForLeague("Euro Championship - Qualification"),
    logo: "/icons/Euro_Championship_Qualification.png",
  },
  {
    name: "World Cup - Qualification Europe",
    country: "Сборные",
    teams: 54,
    seasonYear: defaultSeasonForLeague("World Cup - Qualification Europe"),
    logo: "/icons/World_Cup_Qualification_Europe.png",
  },
  {
    name: "World Cup - Qualification Africa",
    country: "Сборные",
    teams: 54,
    seasonYear: defaultSeasonForLeague("World Cup - Qualification Africa"),
    logo: "/icons/World_Cup_Qualification_Africa.png",
  },
  {
    name: "World Cup - Qualification Asia",
    country: "Сборные",
    teams: 46,
    seasonYear: defaultSeasonForLeague("World Cup - Qualification Asia"),
    logo: "/icons/World_Cup_Qualification_Asia.png",
  },
  {
    name: "World Cup - Qualification CONCACAF",
    country: "Сборные",
    teams: 35,
    seasonYear: defaultSeasonForLeague("World Cup - Qualification CONCACAF"),
    logo: "/icons/World_Cup_Qualification_CONCACAF.png",
  },
  {
    name: "World Cup - Qualification South America",
    country: "Сборные",
    teams: 10,
    seasonYear: defaultSeasonForLeague("World Cup - Qualification South America"),
    logo: "/icons/World_Cup_Qualification_South_America.png",
  },
  {
    name: "World Cup - Qualification Oceania",
    country: "Сборные",
    teams: 11,
    seasonYear: defaultSeasonForLeague("World Cup - Qualification Oceania"),
    logo: "/icons/World_Cup_Qualification_Oceania.png",
  },
  {
    name: "World Cup - Qualification Intercontinental Play-offs",
    country: "Сборные",
    teams: 6,
    seasonYear: defaultSeasonForLeague("World Cup - Qualification Intercontinental Play-offs"),
    logo: "/icons/World_Cup_Qualification_Intercontinental_Play-offs.png",
  },
];

const LEAGUE_LOGO_INDEX = (() => {
  const map = {};
  TOP_LEAGUES_META.forEach((item) => {
    map[item.name] =
      LEAGUE_LOGO_OVERRIDES[item.name] || item.logo || getLeagueLogo(item.name);
  });
  return map;
})();

function resolveLeagueLogo(name) {
  if (!name) return DEFAULT_LEAGUE_ICON;
  return LEAGUE_LOGO_INDEX[name] || getLeagueLogo(name) || DEFAULT_LEAGUE_ICON;
}

function countryLabel(country, t) {
  const map = {
    Англия: "countryEngland",
    Испания: "countrySpain",
    Германия: "countryGermany",
    Италия: "countryItaly",
    Франция: "countryFrance",
    Европа: "countryEurope",
    Сборные: "countryNationalTeams",
    Португалия: "countryPortugal",
    Нидерланды: "countryNetherlands",
    Турция: "countryTurkey",
  };
  return map[country] ? t(map[country]) : country;
}

/* ========= MAIN HEADER ========= */

export default function LeagueTabsHeader({
  league,
  season,
  onLeagueChange,
  hideTabs,
}) {
  const navigate = useNavigate();
  const location = useLocation();
  const hideMonetization = shouldHideMonetization();
  const { t } = useLanguage();

  const isMatchCenter = location.pathname.startsWith("/match/");
  const active = isMatchCenter
    ? null
    : location.pathname.includes("/dashboard")
    ? "today"
    : location.pathname.includes("/matches-v3")
    ? "results"
    : location.pathname.includes("/schedule")
    ? "calendar"
    : location.pathname.includes("/about")
    ? "about"
    : location.pathname.includes("/insights")
    ? "insights"
    : location.pathname.includes("/best-picks")
    ? "picks"
    : location.pathname.includes("/subscriptions")
    ? "subscriptions"
    : "table";

  const [openAll, setOpenAll] = useState(false);

  const tabs = [
    { key: "today", label: t("today"), path: "dashboard" },
    { key: "results", label: t("results"), path: "matches-v3" },
    { key: "calendar", label: t("calendar"), path: "schedule" },
    { key: "table", label: t("table"), path: "table" },
    { key: "insights", label: t("insights"), path: "insights" },
    { key: "picks", label: t("picks"), path: "best-picks" },
    { key: "about", label: t("aboutProject"), path: "about" },
    ...(!hideMonetization
      ? [{ key: "subscriptions", label: t("subscriptions"), path: "subscriptions" }]
      : []),
  ];

  const tabRefs = useRef([]);

  const hasTabs = !hideTabs;

  /* recent leagues */
  useEffect(() => {
    if (!league) return;
    const prev = safeGet("recent_leagues", []);
    const next = [league, ...prev.filter((x) => x !== league)].slice(0, 8);
    safeSet("recent_leagues", next);
  }, [league]);

  /* open catalog modal from event */
  useEffect(() => {
    const handler = () => setOpenAll(true);
    window.addEventListener("open-league-catalog", handler);
    return () => window.removeEventListener("open-league-catalog", handler);
  }, []);

  useEffect(() => {
    TOP_LEAGUES_META.forEach((item) => {
      const img = new Image();
      img.decoding = "async";
      img.src = resolveLeagueLogo(item.name);
    });
  }, []);

  function emitLeagueChange(name, seasonYear) {
    onLeagueChange?.(name, seasonYear);
  }

  const focusTab = (idx) => {
    const el = tabRefs.current[idx];
    el?.focus();
  };

  const onTabKeyDown = (e) => {
    const currentIndex = tabs.findIndex((t) => t.key === active);
    if (currentIndex < 0) return;
    if (e.key === "ArrowRight") {
      e.preventDefault();
      focusTab((currentIndex + 1) % tabs.length);
    } else if (e.key === "ArrowLeft") {
      e.preventDefault();
      focusTab((currentIndex - 1 + tabs.length) % tabs.length);
    }
  };

  function renderTab(tab, label, index) {
    const isActive = active === tab;

    let path;
    if (tab === "today") path = "dashboard";
    else if (tab === "results") path = "matches-v3";
    else if (tab === "calendar") path = "schedule";
    else if (tab === "insights") path = "insights";
    else if (tab === "picks") path = "best-picks";
    else if (tab === "about") path = "about";
    else if (tab === "subscriptions") path = "subscriptions";
    else path = "table";

    const href =
      path === "subscriptions"
        ? `/${path}`
        : `/${path}?league=${encodeURIComponent(league)}&season=${season}`;

    return (
      <motion.button
        key={tab}
        ref={(el) => (tabRefs.current[index] = el)}
        onKeyDown={onTabKeyDown}
        onClick={() => navigate(href)}
        role="tab"
        aria-selected={isActive}
        className={clsx(
          "relative shrink-0 rounded-full px-3 py-1.5 text-[13px] font-medium transition-colors sm:px-4 sm:text-[15px]",
          tab === "results" && "sm:min-w-[136px]",
          isActive ? "text-white" : "text-slate-200/80 hover:text-white"
        )}
        whileTap={{ scale: 0.97 }}
      >
        {isActive && (
          <span className="absolute inset-0 rounded-full bg-gradient-to-r from-[#7b5cff] to-[#5b3fd6] shadow-[0_0_14px_rgba(123,92,255,0.24)]" />
        )}

        <span
          className={clsx(
            "relative z-[1]",
            tab === "insights" && "translate-y-[1px] inline-block"
          )}
        >
          {label}
        </span>
      </motion.button>
    );
  }

  return (
    <>
      {/* ------- HEADER ------- */}

      <div className="relative flex min-w-0 flex-col gap-2 select-none">
        <div className="sm:hidden space-y-3">
          <button
            type="button"
            onClick={() => setOpenAll(true)}
            className="flex w-full min-w-0 items-center gap-3 rounded-[22px] bg-[linear-gradient(180deg,rgba(255,255,255,0.05),rgba(255,255,255,0.022))] px-3.5 py-3 text-left shadow-[0_14px_30px_rgba(0,0,0,0.22)] transition hover:bg-white/[0.06]"
            aria-label={t("changeLeague")}
          >
            <span className="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-[#0f1527]/85 shadow-[0_8px_18px_rgba(0,0,0,0.22)]">
              <img
                src={resolveLeagueLogo(league)}
                alt={league}
                className="h-6 w-6 object-contain"
                onError={(e) => {
                  e.currentTarget.onerror = null;
                  e.currentTarget.src = DEFAULT_LEAGUE_ICON;
                }}
              />
            </span>

            <span className="flex min-w-0 flex-1 flex-col">
              <span className="text-[10px] font-semibold uppercase tracking-[0.16em] text-slate-400">
                {t("currentLeague")}
              </span>
              <span className="truncate pt-0.5 text-[16px] font-semibold leading-tight text-white">
                {league}
              </span>
              <span className="pt-1 text-[11px] text-slate-400">
                {t("season")} {season}
              </span>
            </span>

            <span className="shrink-0 rounded-full bg-white/[0.055] px-3 py-1.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-slate-100/92">
              {t("changeLeague")}
            </span>
          </button>

          <div className="flex items-center justify-between gap-3 rounded-[18px] bg-white/[0.02] px-3 py-2.5">
            <div className="text-[10px] uppercase tracking-[0.2em] text-slate-500">
              {t("language")}
            </div>
            <LanguageSwitcher compact />
          </div>

          {!hideTabs && (
            <div className="rounded-[20px] bg-white/[0.025] px-2 py-2">
              <div className="no-scrollbar overflow-x-auto overscroll-x-contain">
                <div className="flex w-max items-center gap-2 pr-1">
                  {tabs.map((t, idx) => renderTab(t.key, t.label, idx))}
                </div>
              </div>
            </div>
          )}
        </div>

        <div className="hidden sm:grid grid-cols-1 items-center gap-2 px-0 pb-1 pt-2 sm:gap-3 xl:grid-cols-[260px_minmax(0,1120px)] xl:gap-6 xl:pb-2 xl:pt-3">
          <div className="min-w-0 xl:pl-6">
            <button
              type="button"
              onClick={() => setOpenAll(true)}
              className="flex w-full min-w-0 items-center gap-3 rounded-3xl bg-white/[0.03] px-3 py-3 text-left shadow-[0_12px_30px_rgba(0,0,0,0.24)] transition hover:bg-white/[0.05] sm:bg-transparent sm:px-0 sm:py-0 sm:shadow-none xl:rounded-none"
              aria-label={t("changeLeague")}
            >
              <span
                className="
                  grid h-10 w-10 shrink-0 place-items-center rounded-2xl
                  bg-[#0f1527]/70
                  backdrop-blur-md
                  shadow-[0_0_12px_rgba(255,255,255,0.04)]
                  sm:h-9 sm:w-9
                "
              >
                <img
                  src={resolveLeagueLogo(league)}
                  alt={league}
                  className="h-6 w-6 object-contain"
                  onError={(e) => {
                    e.currentTarget.onerror = null;
                    e.currentTarget.src = DEFAULT_LEAGUE_ICON;
                  }}
                />
              </span>

              <span className="flex min-w-0 flex-1 flex-col">
                <span className="text-[10px] font-semibold uppercase tracking-[0.16em] text-slate-400 sm:hidden">
                  {t("currentLeague")}
                </span>
                <span className="truncate text-[16px] font-semibold text-white sm:text-[15px]">
                  {league}
                </span>
                <span className="text-[11px] text-slate-400">
                  {t("season")} {season}
                </span>
              </span>

              <span className="rounded-full bg-white/[0.055] px-3 py-1.5 text-[11px] font-semibold text-slate-100 sm:hidden">
                {t("changeLeague")}
              </span>
            </button>
          </div>

          <div className="flex min-w-0 flex-col gap-2 sm:flex-row sm:items-center sm:justify-between sm:gap-3">
            {!hideTabs && (
              <div className="no-scrollbar min-w-0 flex-1 overflow-x-auto overscroll-x-contain pr-1">
                <div className="flex w-max min-w-full items-center gap-1.5 sm:justify-end sm:gap-2">
                  {tabs.map((t, idx) => renderTab(t.key, t.label, idx))}
                </div>
              </div>
            )}
            <div className="hidden sm:block">
              <LanguageSwitcher compact />
            </div>
          </div>
        </div>
      </div>

      {/* ------- CATALOG MODAL ------- */}
      {openAll &&
        createPortal(
          <AnimatePresence>
            <MegaCatalogModal
              current={league}
              onClose={() => setOpenAll(false)}
              onSelect={(name, seasonYear) => {
                emitLeagueChange(name, seasonYear);
                setOpenAll(false);
              }}
            />
          </AnimatePresence>,
          document.body
        )}
    </>
  );
}

/* ========= Quick nav (НЕО-СТЕКЛО iOS 18) ========= */

export function LeagueQuickNavCard({ activeLeague, onSelectLeague }) {
  const { t } = useLanguage();

  function handleCatalogClick() {
    window.dispatchEvent(new Event("open-league-catalog"));
  }

  return (
    <div className="space-y-4">
      {/* HEADER SMALL */}
      <div className="flex items-center justify-between">
        <div className="flex flex-col">
          <span className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-100/85">
            {t("topTournaments")}
          </span>
          <span className="text-[10px] text-slate-400/80">
            {t("quickLeagueNav")}
          </span>
        </div>

        <button
          type="button"
          onClick={handleCatalogClick}
          className="
            inline-flex items-center gap-1.5
            rounded-full
            border border-white/18
            bg-white/[0.04]
            px-3 py-1.5
            text-[11px] font-medium
            text-slate-50/90
            shadow-[0_0_0_1px_rgba(255,255,255,0.10),0_10px_25px_rgba(0,0,0,0.45)]
            hover:bg-white/[0.08]
            transition
          "
        >
          <span className="h-1.5 w-1.5 rounded-full bg-pink-400 shadow-[0_0_8px_rgba(244,114,182,0.9)]" />
          <span>{t("catalog")}</span>
        </button>
      </div>

      {/* LEAGUES LIST */}
      <div className="flex flex-col gap-1.5">
        {TOP_LEAGUES_META.map((meta) => {
          const isActive = meta.name === activeLeague;

          return (
            <button
              key={meta.name}
              onClick={() => onSelectLeague?.(meta.name, meta.seasonYear)}
              title={`${countryLabel(meta.country, t)} · ${meta.teams} ${t("teams")}`}
              className={clsx(
                "relative flex items-center gap-3 rounded-2xl px-3 py-2.5 text-left text-sm transition-colors duration-150",
                "border backdrop-blur-md",
                !isActive &&
                  "border-white/10 bg-white/[0.02] text-slate-300 hover:bg-white/[0.04] hover:text-white",
                isActive &&
                  "border-white/25 bg-white/[0.06] text-white"
              )}
            >
              <div className="relative z-[1] flex w-full items-start gap-3 min-w-0">
                <span
                  className={clsx(
                    "grid h-8 w-8 place-items-center rounded-2xl border backdrop-blur-md",
                    isActive
                      ? "border-white/40 bg-white/85"
                      : "border-white/20 bg-white/75"
                  )}
                >
                  <SafeImg
                    src={resolveLeagueLogo(meta.name)}
                    alt={meta.name}
                    className="h-5 w-5 object-contain"
                    fallbackSrc={DEFAULT_LEAGUE_ICON}
                    loading="eager"
                    decoding="sync"
                    fetchPriority="high"
                  />
                </span>

                <div className="flex-1 min-w-0">
                  <div className="truncate font-semibold text-[13px]">
                    {meta.name}
                  </div>
                  <div className="text-[10px] text-slate-300/85">
                    {countryLabel(meta.country, t)} · {meta.teams} {t("teams")}
                  </div>
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

/* ========= Premium catalog modal (centered via portal) ========= */

function MegaCatalogModal({ current, onClose, onSelect }) {
  const [search, setSearch] = useState("");
  const searchRef = useRef(null);
  const { t } = useLanguage();

  const entries = useMemo(
    () =>
      CATALOG_LEAGUES_META.map((x) => ({
        ...x,
        searchKey: x.name.toLowerCase(),
      })),
    []
  );

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) return entries;
    return entries.filter((e) => e.searchKey.includes(term));
  }, [entries, search]);

  const ordered = useMemo(() => {
    const topNames = [
      "Premier League",
      "La Liga",
      "Bundesliga",
      "Serie A",
      "Ligue 1",
    ];
    const cupNames = ["UEFA Champions League", "UEFA Europa League"];
    const rank = (name) => {
      const topIdx = topNames.indexOf(name);
      if (topIdx >= 0) return `0-${String(topIdx).padStart(2, "0")}`;
      const cupIdx = cupNames.indexOf(name);
      if (cupIdx >= 0) return `1-${String(cupIdx).padStart(2, "0")}`;
      return `2-${name}`;
    };
    return [...filtered].sort((a, b) =>
      rank(a.name).localeCompare(rank(b.name))
    );
  }, [filtered]);

  function handleSelect(entry) {
    if (!entry?.name) return;
    onSelect(entry.name, entry.seasonYear);
  }

  useEffect(() => {
    const id = setTimeout(() => {
      searchRef.current?.focus();
    }, 0);
    return () => clearTimeout(id);
  }, []);

  return (
    <motion.div
      className="fixed inset-0 z-[9999] flex items-center justify-center px-4"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
    >

      {/* BACKDROP */}
      <motion.div
        className="absolute inset-0 bg-black/60 backdrop-blur-sm"
        onClick={onClose}
      />

      {/* MODAL CARD */}
      <motion.div
        className="
          w-[min(900px,95vw)]
          max-h-[80vh]
          overflow-hidden
          surface-toolbar
          shadow-[0_18px_50px_rgba(15,23,42,0.85)]
        "
        initial={{ opacity: 0, scale: 0.97 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.97 }}
        transition={{ duration: 0.18, ease: "easeOut" }}
      >

        {/* HEADER */}
        <div className="flex items-start justify-between border-b border-white/10 px-6 py-4">
          <div>
            <h2 className="text-base font-semibold text-white">{t("catalog")}</h2>
            <p className="text-xs text-white/55">{t("chooseLeague")}</p>
          </div>
        </div>

        {/* SEARCH */}
        <div className="border-b border-white/10 px-6 py-3">
          <div className="relative">
            <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-white/45">
              <svg
                viewBox="0 0 20 20"
                className="h-4 w-4"
                aria-hidden="true"
              >
                <path
                  fill="currentColor"
                  d="M8.5 2a6.5 6.5 0 1 1 4.01 11.62l3.43 3.43-1.41 1.41-3.43-3.43A6.5 6.5 0 0 1 8.5 2Zm0 2a4.5 4.5 0 1 0 0 9 4.5 4.5 0 0 0 0-9Z"
                />
              </svg>
            </span>
            <input
              ref={searchRef}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={t("searchLeague")}
              className="surface-input w-full rounded-lg pl-9 pr-3 py-1.5 text-[13px] text-white placeholder:text-white/45 focus:ring-0"
            />
          </div>
        </div>

        {/* LIST */}
        <div className="h-[calc(100%-112px)] overflow-y-auto px-6 py-4">
          {ordered.length === 0 ? (
            <div className="surface-empty border-dashed px-4 py-6 text-slate-300">
              {t("nothingFound")}
            </div>
          ) : (
            <div className="grid gap-2 sm:grid-cols-2">
              {ordered.map((league) => {
                const isActive = league.name === current;

                return (
                  <button
                    key={league.name}
                    onClick={() => handleSelect(league)}
                    className={clsx(
                      "flex items-center gap-3 rounded-xl px-3 py-2 text-left text-sm transition duration-150",
                      isActive
                        ? "bg-white/[0.05] text-white border-l-2 border-violet-400/80"
                        : "text-slate-100 hover:bg-white/[0.04]"
                    )}
                  >
                    <span className="grid h-9 w-9 place-items-center rounded-full bg-surface-2/80 border border-white/5">
                      <img
                        src={resolveLeagueLogo(league.name)}
                        alt={league.name}
                        className="h-6 w-6 object-contain"
                        onError={(e) => {
                          e.currentTarget.onerror = null;
                          e.currentTarget.src = DEFAULT_LEAGUE_ICON;
                        }}
                      />
                    </span>

                    <div className="flex-1 min-w-0">
                      <div className="truncate font-semibold">
                        {league.name}
                      </div>
                      <div className="text-xs text-slate-400">
                        {countryLabel(league.country, t)} • {league.teams} {t("teams")}
                      </div>
                    </div>
                  </button>
                );
              })}
            </div>
          )}
        </div>
      </motion.div>
    </motion.div>
  );
}
