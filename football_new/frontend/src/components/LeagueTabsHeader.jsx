// ========================
// Premium Global League Header (Variant C)
// ========================

import { useEffect, useMemo, useRef, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import clsx from "clsx";
import { AnimatePresence, motion } from "framer-motion";
import { createPortal } from "react-dom";

import AuthIndicator from "@/components/auth/AuthIndicator";
import ThemeSwitcher from "@/components/ThemeSwitcher";

/* ========= constants & helpers ========= */

const DEFAULT_LEAGUE_ICON =
  "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='16' fill='%2310223a'/%3E%3Cpath fill='%23e5e7eb' d='M32 10 48 54h-8l-8-22-8 22h-8z'/%3E%3C/svg%3E";

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
    seasonYear: 2025,
    logo: "/icons/leagues/premier_league.png",
  },
  {
    name: "La Liga",
    country: "Испания",
    teams: 20,
    seasonYear: 2025,
    logo: "/icons/leagues/la_liga.png",
  },
  {
    name: "Bundesliga",
    country: "Германия",
    teams: 18,
    seasonYear: 2025,
    logo: "/icons/leagues/bundesliga.png",
  },
  {
    name: "Serie A",
    country: "Италия",
    teams: 20,
    seasonYear: 2025,
    logo: "/icons/leagues/serie_a.png",
  },
  {
    name: "Ligue 1",
    country: "Франция",
    teams: 18,
    seasonYear: 2025,
    logo: "/icons/leagues/ligue_1.png",
  },
  {
    name: "UEFA Champions League",
    country: "Европа",
    teams: 32,
    seasonYear: 2025,
    logo: "/icons/cups/champions_league.png",
  },
];

const LEAGUE_LOGO_OVERRIDES = {
  "Premier League": "/icons/Premier_League.png",
  "La Liga": "/icons/La_Liga.png",
  Bundesliga: "/icons/Bundesliga.png",
  "Serie A": "/icons/Serie_A.png",
  "Ligue 1": "/icons/Ligue_1.png",
  "UEFA Champions League": "/icons/UEFA_Champions_League.png",
};

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

/* ========= MAIN HEADER ========= */

export default function LeagueTabsHeader({
  league,
  season,
  onLeagueChange,
  hideTabs,
}) {
  const navigate = useNavigate();
  const location = useLocation();

  const active =
    location.pathname.includes("/matches-v3")
      ? "results"
      : location.pathname.includes("/schedule")
      ? "calendar"
      : location.pathname.includes("/best-picks")
      ? "picks"
      : location.pathname.includes("/subscriptions")
      ? "subscriptions"
      : "table";

  const [openAll, setOpenAll] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);

  const tabs = [
    { key: "overview", label: "Обзор", path: "table" },
    { key: "results", label: "Матчи", path: "matches-v3" },
    { key: "calendar", label: "Календарь", path: "schedule" },
    { key: "table", label: "Таблица", path: "table" },
    { key: "picks", label: "Подборки", path: "best-picks" },
    { key: "subscriptions", label: "Подписки", path: "subscriptions" },
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

  function emitLeagueChange(name) {
    onLeagueChange?.(name);
  }

  const focusTab = (idx) => {
    const el = tabRefs.current[idx];
    el?.focus();
  };

  const onTabKeyDown = (e) => {
    const currentIndex = tabs.findIndex((t) => t.key === active);
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
    if (tab === "results") path = "matches-v3";
    else if (tab === "calendar") path = "schedule";
    else if (tab === "picks") path = "best-picks";
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
          "relative px-4 py-1.5 text-sm font-medium rounded-full",
          !isActive && "text-slate-200/80 hover:text-white"
        )}
        whileTap={{ scale: 0.97 }}
      >
        <AnimatePresence>
          {isActive && (
            <motion.span
              layoutId="activeTabPill"
              className="absolute inset-0 rounded-full bg-gradient-to-r from-pink-500 via-fuchsia-500 to-violet-500 shadow-[0_14px_40px_rgba(236,72,153,0.55)]"
            />
          )}
        </AnimatePresence>

        <span className="relative z-[1]">{label}</span>
      </motion.button>
    );
  }

  return (
    <>
      {/* ------- HEADER ------- */}

      <div className="relative flex flex-col gap-2 select-none">
        {/* BRAND */}
        <div className="flex items-center justify-between px-1 pt-1.5">
          <div className="flex items-center gap-3">
            <span className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-200">
              EDGESCORE
            </span>
            <span className="text-[11px] uppercase tracking-[0.18em] text-slate-500">
              Football Analytics
            </span>
          </div>

          <div className="flex items-center gap-3">
            <ThemeSwitcher />
            <AuthIndicator />
          </div>
        </div>

        {/* MAIN HEADER ROW */}
        <div className="relative flex items-center justify-between px-1 pb-2 pt-1">
          {/* LEFT — logo + league */}
          <div className="flex min-w-0 items-center gap-3">
            <span
  className="
    grid h-9 w-9 place-items-center rounded-2xl
    bg-[#0f1527]/70
    border border-white/8
    backdrop-blur-md
    shadow-[0_0_12px_rgba(255,255,255,0.04)]
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

            <div className="flex flex-col min-w-0">
              <span className="truncate text-[15px] font-semibold text-white">
                {league}
              </span>
              <span className="text-[11px] text-slate-400">
                Сезон {season}
              </span>
            </div>
          </div>

          {/* CENTER — tabs */}
          {!hideTabs && (
            <div className="absolute inset-x-0 flex justify-center pointer-events-none">
              <motion.div className="pointer-events-auto inline-flex rounded-full border border-white/14 bg-slate-950/80 px-2 py-1 shadow-lg">
                <div className="flex items-center gap-1">
                  {tabs.map((t, idx) => renderTab(t.key, t.label, idx))}
                </div>
              </motion.div>
            </div>
          )}

          {/* RIGHT — buttons */}
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => setDrawerOpen(true)}
              className="inline-flex lg:hidden items-center gap-2 rounded-full border border-white/20 bg-slate-950/80 px-3 py-1.5 text-xs text-white/90"
            >
              ≡ Лиги
            </button>
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
              onSelect={(name) => {
                emitLeagueChange(name);
                setOpenAll(false);
              }}
            />
          </AnimatePresence>,
          document.body
        )}

      {/* MOBILE DRAWER можно оставить как есть, я его не трогал */}
    </>
  );
}

/* ========= Quick nav (НЕО-СТЕКЛО iOS 18) ========= */

export function LeagueQuickNavCard({ activeLeague, onSelectLeague }) {
  function handleCatalogClick() {
    window.dispatchEvent(new Event("open-league-catalog"));
  }

  return (
    <div className="space-y-4">
      {/* HEADER SMALL */}
      <div className="flex items-center justify-between">
        <div className="flex flex-col">
          <span className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-100/85">
            Топ турниры
          </span>
          <span className="text-[10px] text-slate-400/80">
            Быстрый переход по лигам
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
          <span>Каталог</span>
        </button>
      </div>

      {/* LEAGUES LIST */}
      <div className="flex flex-col gap-1.5">
        {TOP_LEAGUES_META.map((meta) => {
          const isActive = meta.name === activeLeague;

          return (
            <motion.button
              key={meta.name}
              onClick={() => onSelectLeague?.(meta.name)}
              whileHover={{ scale: 1.01 }}
              whileTap={{ scale: 0.97 }}
              className={clsx(
                "relative flex items-center gap-3 rounded-2xl px-3 py-2.5 text-sm transition-all duration-150",
                "border backdrop-blur-md",
                // базовое стекло
                !isActive &&
                  "border-white/12 bg-white/[0.02] text-slate-100/85 hover:bg-white/[0.05] hover:border-white/25 hover:text-white",
                // активная лига — яркое iOS-стекло
                isActive &&
                  "border-pink-300/80 bg-white/[0.10] text-white shadow-[0_0_30px_rgba(236,72,153,0.65)]"
              )}
            >
              {/* градиентный свет активного элемента */}
              {isActive && (
                <span className="pointer-events-none absolute inset-0 rounded-2xl bg-[radial-gradient(circle_at_0%_0%,rgba(244,114,182,0.65),transparent_55%),radial-gradient(circle_at_100%_100%,rgba(129,140,248,0.55),transparent_55%)] opacity-80" />
              )}

              {/* контур-glow поверх градиента */}
              {isActive && (
                <span className="pointer-events-none absolute -inset-px rounded-[22px] ring-1 ring-pink-200/80" />
              )}

              {/* контент — поверх эффектов */}
              <div className="relative z-[1] flex items-center gap-3 min-w-0">
                <span
                  className={clsx(
                    "grid h-8 w-8 place-items-center rounded-2xl border backdrop-blur-md",
                    isActive
                      ? "border-white/60 bg-white/90"
                      : "border-white/20 bg-white/80"
                  )}
                >
                  <img
                    src={resolveLeagueLogo(meta.name)}
                    alt={meta.name}
                    className="h-5 w-5 object-contain"
                  />
                </span>

                <div className="flex-1 min-w-0">
                  <div className="truncate font-semibold text-[13px]">
                    {meta.name}
                  </div>
                  <div className="text-[10px] text-slate-300/85">
                    {meta.country} · {meta.teams} команд
                  </div>
                </div>
              </div>
            </motion.button>
          );
        })}
      </div>
    </div>
  );
}

/* ========= Premium catalog modal (centered via portal) ========= */

function MegaCatalogModal({ current, onClose, onSelect }) {
  const [search, setSearch] = useState("");

  const entries = useMemo(
    () =>
      TOP_LEAGUES_META.map((x) => ({
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

  function handleSelect(value) {
    if (!value) return;
    onSelect(value);
  }

  return (
    <motion.div
      className="
        fixed inset-0 z-[9999]
        flex items-center justify-center
        px-4
        -translate-y-12
      "
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
          w-[min(880px,95vw)]
          max-h-[82vh]
          overflow-hidden
          rounded-3xl
          bg-slate-950/95
          shadow-[0_24px_70px_rgba(15,23,42,1)]
          backdrop-blur-2xl
          ring-1 ring-pink-400/60
        "
        initial={{ opacity: 0, scale: 0.92 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.92 }}
        transition={{ type: "spring", stiffness: 380, damping: 32 }}
      >

        {/* HEADER */}
        <div className="flex items-start justify-between border-b border-white/10 px-6 py-4">
          <div>
            <h2 className="text-lg font-semibold text-white">Каталог лиг</h2>
            <p className="text-xs text-slate-300">Выберите лигу</p>
          </div>

          <button
            onClick={onClose}
            className="h-8 w-8 grid place-items-center rounded-full border border-white/20 text-white hover:bg-white/10"
          >
            ×
          </button>
        </div>

        {/* SEARCH */}
        <div className="border-b border-white/10 px-6 py-3">
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Поиск"
            className="
              w-full rounded-xl
              border border-white/25
              bg-slate-950/70
              px-3 py-2 text-sm text-white
              shadow-inner
              focus:border-pink-400 focus:ring-2 focus:ring-pink-300/40
            "
          />
        </div>

        {/* LIST */}
        <div className="h-[calc(100%-112px)] overflow-y-auto px-6 py-4">
          {filtered.length === 0 ? (
            <div className="rounded-xl border border-dashed border-white/20 bg-slate-900/70 px-4 py-6 text-slate-300">
              Ничего не найдено
            </div>
          ) : (
            <div className="grid gap-3 sm:grid-cols-2">
              {filtered.map((league) => {
                const isActive = league.name === current;

                return (
                  <button
                    key={league.name}
                    onClick={() => handleSelect(league.name)}
                    className={clsx(
                      "flex items-center gap-3 rounded-2xl border px-4 py-3 text-left text-sm transition",
                      isActive
                        ? "border-pink-400/80 bg-pink-500/10 text-pink-50 shadow-[0_8px_30px_rgba(236,72,153,0.35)]"
                        : "border-white/15 bg-slate-900/70 text-slate-100 hover:border-pink-300/60 hover:bg-slate-900"
                    )}
                  >
                    <span className="grid h-9 w-9 place-items-center rounded-full bg-white">
                      <img
                        src={resolveLeagueLogo(league.name)}
                        alt={league.name}
                        className="h-6 w-6 object-contain"
                      />
                    </span>

                    <div className="flex-1 min-w-0">
                      <div className="truncate font-semibold">
                        {league.name}
                      </div>
                      <div className="text-xs text-slate-400">
                        {league.country} • {league.teams} команд
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

