// src/layout/AppShell.jsx
import { useEffect } from "react";
import {
  NavLink,
  useLocation,
  useNavigate,
  useSearchParams,
} from "react-router-dom";
import clsx from "clsx";
import LeagueTabsHeader, {
  LeagueQuickNavCard,
} from "@/components/LeagueTabsHeader";
import AuthIndicator from "@/components/auth/AuthIndicator";
import { BrandMark, BrandText } from "@/components/brand/BrandLockup";

import { HOME_URL } from "@/routes/home";

/* ===========================================
   FORCE DARK THEME
=========================================== */
function forceDarkTheme() {
  if (typeof document === "undefined") return;
  const html = document.documentElement;
  html.classList.remove("light", "pink");
  html.classList.add("dark");
}

/* ===========================================
   RECENT LEAGUES
=========================================== */
function pushRecentLeague(name) {
  try {
    const prev = JSON.parse(localStorage.getItem("recent_leagues") || "[]");
    const list = [name, ...prev.filter((x) => x !== name)];
    localStorage.setItem("recent_leagues", JSON.stringify(list.slice(0, 5)));
  } catch {}
}

function getRecentLeagues() {
  try {
    return JSON.parse(localStorage.getItem("recent_leagues") || "[]");
  } catch {
    return [];
  }
}

/* ===========================================
   AURORA BACKGROUND
=========================================== */
function injectAuroraStyles() {
  if (typeof document === "undefined") return;
  if (document.getElementById("aurora-styles")) return;

  const style = document.createElement("style");
  style.id = "aurora-styles";
  style.innerHTML = `
    .aurora-blob {
      position: absolute;
      filter: blur(90px);
      opacity: 0.75;
      pointer-events: none;
      mix-blend-mode: screen;
    }
    .aurora-blob--1 {
      width: 520px;
      height: 520px;
      background: radial-gradient(circle at 30% 10%, rgba(236,72,153,0.7), transparent 65%);
      animation: auroraMove1 24s ease-in-out infinite alternate;
    }
    .aurora-blob--2 {
      width: 560px;
      height: 560px;
      background: radial-gradient(circle at 70% 0%, rgba(129,140,248,0.6), transparent 60%);
      animation: auroraMove2 32s ease-in-out infinite alternate;
    }
    .aurora-blob--3 {
      width: 520px;
      height: 520px;
      background: radial-gradient(circle at 10% 85%, rgba(45,212,191,0.55), transparent 65%);
      animation: auroraMove3 28s ease-in-out infinite alternate;
    }

    @keyframes auroraMove1 {
      0% { transform: translate3d(-8%, -6%, 0); }
      100% { transform: translate3d(6%, 10%, 0); }
    }
    @keyframes auroraMove2 {
      0% { transform: translate3d(6%, -12%, 0); }
      100% { transform: translate3d(-6%, 6%, 0); }
    }
    @keyframes auroraMove3 {
      0% { transform: translate3d(-10%, 16%, 0); }
      100% { transform: translate3d(4%, -6%, 0); }
    }
  `;
  document.head.appendChild(style);
}

const TIGHT_CONTENT_PREFIXES = [
  "/dashboard",
  "/about",
  "/table",
  "/matches-v3",
  "/schedule",
  "/match/",
  "/team/",
  "/player/",
  "/insights",
  "/roi-admin",
  "/best-picks",
  "/graf",
];

const usesTightContent = (pathname) =>
  TIGHT_CONTENT_PREFIXES.some((prefix) => pathname.startsWith(prefix));

function BrandCluster() {
  return (
    <div className="min-w-0">
      <NavLink
        to={HOME_URL}
        className="group inline-flex items-center gap-3 text-white no-underline"
      >
        <BrandMark size="md" className="transition group-hover:border-white/18" />
        <BrandText />
      </NavLink>
    </div>
  );
}

/* ===========================================
   MAIN APP SHELL
=========================================== */
export default function AppShell({ children }) {
  const [search] = useSearchParams();
  const location = useLocation();
  const navigate = useNavigate();
  const isTour = false;

  useEffect(() => {
    forceDarkTheme();
    injectAuroraStyles();
  }, []);

  const recent = getRecentLeagues();
  const leagueParam = search.get("league");
  const seasonParam = search.get("season");

  const fallbackLeague = recent[0] || "Premier League";
  const league = leagueParam || fallbackLeague;
  const season = seasonParam || "2026";

  const hideLeftRail = false;
  const tightContent = usesTightContent(location.pathname);
  /* auto populate params */
  useEffect(() => {
    if (!leagueParam) {
      const params = new URLSearchParams(location.search);
      params.set("league", league);
      params.set("season", season);
      navigate(`${location.pathname}?${params.toString()}`, { replace: true });
    }
  }, [leagueParam, league, season, location.pathname, location.search, navigate]);

  useEffect(() => {
    if (league) pushRecentLeague(league);
  }, [league]);

  const handleChangeLeague = (name, nextSeason) => {
    const targetSeason = String(nextSeason || season);
    const params = new URLSearchParams();
    params.set("league", name);
    params.set("season", targetSeason);
    navigate(`/table?${params.toString()}`);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  return (
    <div
      className="min-h-screen relative text-white overflow-x-hidden"
      style={{
        background:
          "radial-gradient(circle at 10% 0%, #141927 0%, #080a14 45%, #04050d 100%)",
        paddingBottom: "env(safe-area-inset-bottom, 0px)",
      }}
    >
      {/* BACKGROUND */}
      <div className="fixed inset-0 -z-10 overflow-hidden pointer-events-none">
        <div className="aurora-blob aurora-blob--1 -top-40 -left-40" />
        <div className="aurora-blob aurora-blob--2 -top-64 right-[-180px]" />
        <div className="aurora-blob aurora-blob--3 bottom-[-220px] left-[-140px]" />
        <div className="absolute inset-0 bg-[rgba(4,7,15,0.65)] backdrop-blur-[2px]" />
      </div>

      <header
        className="relative z-50 bg-[#040712] shadow-[0_16px_38px_rgba(0,0,0,0.58)]"
        style={{ paddingTop: "env(safe-area-inset-top, 0px)" }}
      >
        <div className="border-b border-white/[0.06] bg-[linear-gradient(180deg,rgba(255,255,255,0.028),rgba(255,255,255,0.008))] sm:hidden">
          <div className="mx-auto flex max-w-[1440px] items-center justify-between gap-3 px-3 py-3">
            <BrandText compact />
            <AuthIndicator compact />
          </div>
        </div>

        <div className="hidden border-b border-white/[0.06] bg-[linear-gradient(180deg,rgba(255,255,255,0.03),rgba(255,255,255,0.008))] sm:block">
          <div className="mx-auto flex max-w-[1440px] flex-col gap-4 px-3 py-3 sm:px-4 lg:px-6 lg:py-4 xl:flex-row xl:items-center xl:justify-between">
            <BrandCluster />
            <div className="flex items-center justify-between gap-3 xl:justify-end">
              <AuthIndicator />
            </div>
          </div>
        </div>

        <div className="w-full px-3 py-2 sm:px-4 lg:px-6 lg:pt-3 lg:pb-3">
          <div className="mx-auto grid max-w-[1440px] grid-cols-1 gap-4 xl:grid-cols-[280px_minmax(0,1fr)_280px] xl:gap-8">
            <div className="xl:col-span-3">
              <LeagueTabsHeader
                league={league}
                season={season}
                onLeagueChange={handleChangeLeague}
              />
            </div>
          </div>
        </div>
      </header>

      {/* GRID */}
      <div className="mt-3 w-full pb-8 lg:mt-5 lg:pb-10">
        <div className="mx-auto grid max-w-[1440px] grid-cols-1 items-start gap-4 px-3 sm:px-4 lg:px-6 xl:grid-cols-[280px_minmax(0,1fr)_280px] xl:gap-8">
          <aside className={clsx("hidden xl:block", hideLeftRail && "xl:hidden")}>
            <div className="sticky top-24 mt-8 space-y-5">
              <div className="rounded-3xl border border-white/[0.07] bg-[linear-gradient(180deg,rgba(255,255,255,0.04),rgba(255,255,255,0.012))] p-4 shadow-[0_18px_48px_rgba(0,0,0,0.44)] backdrop-blur-xl">
                <div className="mb-4 px-1">
                  <div className="text-[11px] font-medium uppercase tracking-[0.18em] text-white/42">
                    League flow
                  </div>
                  <div className="mt-1 text-sm font-semibold tracking-[-0.01em] text-white">
                    Fast switch between active competitions
                  </div>
                </div>
                <LeagueQuickNavCard
                  activeLeague={league}
                  onSelectLeague={handleChangeLeague}
                />
              </div>
            </div>
          </aside>

          <main
            className={clsx(
              "app-typography type-page min-w-0 overflow-x-hidden",
              tightContent && "w-full xl:col-span-2",
              hideLeftRail && "xl:col-span-3 xl:pl-0"
            )}
          >
            {children}
          </main>

          {!tightContent && !hideLeftRail && (
            <div className="hidden xl:block" aria-hidden="true" />
          )}
        </div>
      </div>
    </div>
  );
}
