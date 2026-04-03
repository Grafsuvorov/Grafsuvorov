// src/layout/AppShell.jsx
import {
  lazy,
  Suspense,
  useCallback,
  useEffect,
  useState,
} from "react";
import {
  useLocation,
  useNavigate,
  useSearchParams,
} from "react-router-dom";
import { createPortal } from "react-dom";
import clsx from "clsx";

import LeagueTabsHeader, {
  LeagueQuickNavCard,
} from "@/components/LeagueTabsHeader";

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
   LAZY MODAL
=========================================== */
const MatchModalLazy = lazy(() =>
  import("@/pages/MatchSchedulePage").then((mod) => ({
    default: mod.MatchModal,
  }))
);

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
  const season = seasonParam || "2025";

  const [modalMatch, setModalMatch] = useState(null);
  const hideLeftRail = false;
  const tightContent =
    location.pathname.startsWith("/table") ||
    location.pathname.startsWith("/matches-v3") ||
    location.pathname.startsWith("/schedule") ||
    location.pathname.startsWith("/match/") ||
    location.pathname.startsWith("/team/") ||
    location.pathname.startsWith("/player/") ||
    location.pathname.startsWith("/insights") ||
    location.pathname.startsWith("/roi-admin") ||
    location.pathname.startsWith("/best-picks") ||
    location.pathname.startsWith("/graf-picks");

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

  const goToTeam = useCallback(
    (teamId) => {
      if (!teamId) return;
      navigate(`/team/${teamId}?league=${encodeURIComponent(league)}&season=${season}`);
    },
    [navigate, league, season]
  );

  /* ===========================================
     CLEAN HEADER — ONLY LeagueTabsHeader
  ============================================ */
  return (
    <div
      className="min-h-screen relative text-white overflow-hidden"
      style={{
        background:
          "radial-gradient(circle at 10% 0%, #141927 0%, #080a14 45%, #04050d 100%)",
      }}
    >
      {/* BACKGROUND */}
      <div className="fixed inset-0 -z-10 overflow-hidden pointer-events-none">
        <div className="aurora-blob aurora-blob--1 -top-40 -left-40" />
        <div className="aurora-blob aurora-blob--2 -top-64 right-[-180px]" />
        <div className="aurora-blob aurora-blob--3 bottom-[-220px] left-[-140px]" />
        <div className="absolute inset-0 bg-[rgba(4,7,15,0.65)] backdrop-blur-[2px]" />
      </div>

      {/* HEADER — только выбор лиги/сезона, БЕЗ вкладок */}
      <header className="sticky top-0 z-50 border-b border-white/5 bg-black/10 backdrop-blur-2xl">
        <div className="w-full px-6 pt-3 pb-3">
          <div className="mx-auto max-w-[1440px] grid grid-cols-1 xl:grid-cols-[280px_minmax(0,1fr)_280px] gap-8">
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
      <div className="w-full pb-10 mt-6">
        <div className="mx-auto max-w-[1440px] px-6 grid grid-cols-1 xl:grid-cols-[280px_minmax(0,1fr)_280px] gap-8 items-start">
          <aside className={clsx("hidden xl:block", hideLeftRail && "xl:hidden")}>
            <div className="sticky top-8 mt-8 space-y-5">
              <div className="rounded-3xl border border-white/10 bg-white/[0.04] backdrop-blur-xl shadow-[0_8px_35px_rgba(0,0,0,0.55)] p-4">
                <LeagueQuickNavCard
                  activeLeague={league}
                  onSelectLeague={handleChangeLeague}
                />
              </div>
            </div>
          </aside>

          <main
            className={clsx(
              "app-typography type-page space-y-6 min-w-0",
              tightContent && "w-full xl:col-span-2 xl:pl-4",
              hideLeftRail && "xl:col-span-3 xl:pl-0"
            )}
          >
            {children}
          </main>

          {!tightContent && !hideLeftRail && <div className="hidden xl:block" aria-hidden="true" />}
        </div>
      </div>

      {modalMatch &&
        createPortal(
          <Suspense fallback={null}>
            <MatchModalLazy
              initialMatch={modalMatch}
              league={league}
              season={season}
              onClose={() => setModalMatch(null)}
              onGoTeam={goToTeam}
            />
          </Suspense>,
          document.body
        )}

    </div>
  );
}
