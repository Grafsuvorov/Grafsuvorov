// src/App.jsx
import { BrowserRouter as Router, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider } from "./auth/AuthContext.jsx";
import ProtectedRoute from "./components/auth/ProtectedRoute";

import MatchesPageV3 from "./pages/MatchesPageV3";
import LeagueTablePage from "./pages/LeagueTablePage";
import MatchSchedulePage from "./pages/MatchSchedulePage";
import DashboardPage from "./pages/DashboardPage";
import BestPicksRoundPage from "./pages/BestPicksRoundPage";
import GrafPicksPage from "./pages/GrafPicksPage";
import LoginPage from "./pages/LoginPage";
import RegisterPage from "./pages/RegisterPage";
import ProfilePage from "./pages/ProfilePage";
import SubscriptionsPage from "./pages/SubscriptionsPage";
import { HOME_URL } from "./routes/home";
import PlayerPage from "./pages/PlayerPage";



import PlayersPage from "./pages/PlayersPage";
import CompareTeamsPage from "./pages/CompareTeamsPage";
import TeamPage from "./pages/TeamPage";          // legacy
import TeamPageaAll from "./pages/TeamPageaAll";  // ����� �������� �������
import LeagueSelectorShowcase from "./pages/LeagueSelectorShowcase";
import LeagueHeaderShowcase from "./pages/LeagueHeaderShowcase";

import AppShell from "@/layout/AppShell";

const withShell = (node) => <AppShell>{node}</AppShell>;

export default function App() {
  return (
    <AuthProvider>
      <Router>
        <Routes>
          {/* �������� �������� */}
          <Route path="/" element={<Navigate to={HOME_URL} replace />} />

          {/* ���������� �������� (������ AppShell) */}
          {/* �������: /leagues � /matches ��� �������� � �� ������ ������ ��� */}
          {/* ������ ��� � ���������� ���������: */}
          <Route path="/leagues" element={<Navigate to={HOME_URL} replace />} />
          <Route path="/matches" element={<Navigate to="/matches-v3" replace />} />

          <Route path="/dashboard" element={withShell(<DashboardPage />)} />
          <Route path="/matches-v3" element={withShell(<MatchesPageV3 />)} />
          <Route path="/table" element={withShell(<LeagueTablePage />)} />
          {/* �������� ���� �� ��������� */}
          <Route path="/favorites" element={<Navigate to="/table?view=favorites" replace />} />
          <Route path="/schedule" element={withShell(<MatchSchedulePage />)} />
          <Route path="/best-picks" element={withShell(<BestPicksRoundPage />)} />
          <Route path="/graf" element={withShell(<GrafPicksPage />)} />
          <Route path="/ui/league-selector" element={withShell(<LeagueSelectorShowcase />)} />
          <Route path="/ui/league-header" element={withShell(<LeagueHeaderShowcase />)} />

          {/* ����� �������� */}
          <Route path="/players" element={withShell(<PlayersPage />)} />
          <Route path="/player/:id" element={withShell(<PlayerPage />)} />

          <Route path="/compare" element={withShell(<CompareTeamsPage />)} />
          <Route path="/team/:id" element={withShell(<TeamPageaAll />)} />
          <Route path="/team-legacy/:id" element={withShell(<TeamPage />)} />

          {/* �������� � ��� shell (��� � auth-��������) */}
          <Route path="/subscriptions" element={withShell(<SubscriptionsPage />)} />

          {/* ����������� */}
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />

          {/* ������� � ���������� ���� (������ AppShell) */}
          <Route
            path="/profile"
            element={
              <ProtectedRoute>
                <AppShell>
                  <ProfilePage />
                </AppShell>
              </ProtectedRoute>
            }
          />

          {/* ������ */}
          <Route path="*" element={<Navigate to={HOME_URL} replace />} />
        </Routes>
      </Router>
    </AuthProvider>
  );
}
