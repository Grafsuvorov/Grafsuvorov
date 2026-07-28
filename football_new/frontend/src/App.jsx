// src/App.jsx
import { lazy, Suspense } from "react";
import { BrowserRouter as Router, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider } from "./auth/AuthContext.jsx";
import ProtectedRoute from "./components/auth/ProtectedRoute";

import { HOME_URL } from "./routes/home";

import AppShell from "@/layout/AppShell";
import ActivityTracker from "@/components/ActivityTracker.jsx";
import BrandLockup, { BrandMark } from "@/components/brand/BrandLockup";
import { shouldHideMonetization } from "@/lib/pilotAccess.js";

const MatchesPageV3 = lazy(() => import("./pages/MatchesPageV3"));
const MatchCenterPage = lazy(() => import("./pages/MatchCenterPage.jsx"));
const LeagueTablePage = lazy(() => import("./pages/LeagueTablePage"));
const LeagueInsightsPage = lazy(() => import("./pages/LeagueInsightsPage"));
const MatchSchedulePage = lazy(() => import("./pages/MatchSchedulePage"));
const DashboardPage = lazy(() => import("./pages/DashboardPage"));
const BestPicksRoundPage = lazy(() => import("./pages/BestPicksRoundPage"));
const GrafPicksPage = lazy(() => import("./pages/GrafPicksPage"));
const RoiAdminPage = lazy(() => import("./pages/RoiAdminPage.jsx"));
const LoginPage = lazy(() => import("./pages/LoginPage"));
const RegisterPage = lazy(() => import("./pages/RegisterPage"));
const ProfilePagePremium = lazy(() => import("./pages/ProfilePagePremium"));
const SubscriptionsPage = lazy(() => import("./pages/SubscriptionsPage"));
const AboutPage = lazy(() => import("./pages/AboutPage.jsx"));
const PlayerPage = lazy(() => import("./pages/PlayerPage"));
const PlayersPage = lazy(() => import("./pages/PlayersPage"));
const CompareTeamsPage = lazy(() => import("./pages/CompareTeamsPage"));
const TeamPage = lazy(() => import("./pages/TeamPage"));
const TeamPageaAll = lazy(() => import("./pages/TeamPageaAll"));

const withShell = (node) => <AppShell>{node}</AppShell>;
const RouteFallback = (
  <div className="min-h-screen bg-[#04050d] px-4 py-8 text-white">
    <div className="mx-auto flex max-w-[1440px] items-center justify-center">
      <div className="surface-loading flex min-h-[220px] w-full max-w-[720px] flex-col items-center justify-center gap-4 rounded-[32px] border border-white/10 px-8 py-10 text-center">
        <BrandMark size="lg" />
        <div className="space-y-2">
          <BrandLockup size="sm" compact align="center" className="justify-center" textClassName="text-center" />
          <div className="text-[22px] font-semibold tracking-[-0.02em] text-white">
            Loading your football workspace
          </div>
          <div className="mx-auto max-w-[440px] text-sm text-white/58">
            Preparing live context, league data and key match views.
          </div>
        </div>
        <div className="surface-spinner" aria-hidden="true" />
      </div>
    </div>
  </div>
);
const withSuspense = (node) => <Suspense fallback={RouteFallback}>{node}</Suspense>;

const SHELL_ROUTES = [
  { path: "/dashboard", element: <DashboardPage /> },
  { path: "/matches-v3", element: <MatchesPageV3 /> },
  { path: "/match/:matchId", element: <MatchCenterPage /> },
  { path: "/table", element: <LeagueTablePage /> },
  { path: "/insights", element: <LeagueInsightsPage /> },
  { path: "/schedule", element: <MatchSchedulePage /> },
  { path: "/about", element: <AboutPage /> },
  { path: "/best-picks", element: <BestPicksRoundPage /> },
  { path: "/graf", element: <GrafPicksPage /> },
  { path: "/players", element: <PlayersPage /> },
  { path: "/player/:id", element: <PlayerPage /> },
  { path: "/compare", element: <CompareTeamsPage /> },
  { path: "/team/:id", element: <TeamPageaAll /> },
  { path: "/team-legacy/:id", element: <TeamPage /> },
];

function AppRoutes() {
  const hideMonetization = shouldHideMonetization();

  return (
    <Router>
      <ActivityTracker />
      <Routes>
        <Route path="/" element={<Navigate to={HOME_URL} replace />} />
        <Route path="/leagues" element={<Navigate to={HOME_URL} replace />} />
        <Route path="/matches" element={<Navigate to="/matches-v3" replace />} />
        {SHELL_ROUTES.map(({ path, element }) => (
          <Route key={path} path={path} element={withSuspense(withShell(element))} />
        ))}
        <Route path="/favorites" element={<Navigate to="/table?view=favorites" replace />} />
        <Route
          path="/roi-admin"
          element={
            <ProtectedRoute>
              {withSuspense(withShell(<RoiAdminPage />))}
            </ProtectedRoute>
          }
        />
        <Route
          path="/subscriptions"
          element={
            hideMonetization ? (
              <Navigate to="/profile" replace />
            ) : (
              <ProtectedRoute>
                {withSuspense(<SubscriptionsPage />)}
              </ProtectedRoute>
            )
          }
        />
        <Route path="/login" element={withSuspense(<LoginPage />)} />
        <Route path="/register" element={withSuspense(<RegisterPage />)} />
        <Route
          path="/profile"
          element={
            <ProtectedRoute>
              {withSuspense(<ProfilePagePremium />)}
            </ProtectedRoute>
          }
        />
        <Route path="*" element={<Navigate to={HOME_URL} replace />} />
      </Routes>
    </Router>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  );
}
