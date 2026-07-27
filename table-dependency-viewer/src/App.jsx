import React, { useCallback, useEffect, useMemo, useState } from "react";
import { Routes, Route, Navigate, useLocation, useNavigate, useParams } from "react-router-dom";

import "./index.css";
import "./style/app.css";

import Sidebar from "./components/Sidebar.jsx";
import HomePage from "./components/HomePage.jsx";
import IncidentsPage from "./components/IncidentsPage.jsx";
import ErrorDashboard from "./components/ErrorDashboard.jsx";
import TableSearch from "./components/TableSearch.jsx";
import SlowestTables from "./components/SlowestTables.jsx";
import SlaPage from "./components/SlaPage.jsx";
import DependencyViewer from "./components/DependencyViewer.jsx";
import TableCard from "./components/TableCard.jsx";
import EntityShedule from "./components/EntityShedule.jsx";
import EntityTablesPage from "./components/EntityTablesPage.jsx";
import IncidentDetailsPage from "./components/IncidentDetailsPage.jsx";
import ImpactGraphPage from "./components/ImpactGraphPage.jsx";
import NightOpsPage from "./components/NightOpsPage.jsx";
import OnboardingPage from "./components/OnboardingPage.jsx";
import LogicAuditPage from "./components/LogicAuditPage.jsx";
import LoginPage from "./components/LoginPage.jsx";
import AdminUsersPage from "./components/AdminUsersPage.jsx";
import DevMetaAdminPage from "./components/DevMetaAdminPage.jsx";
import AdminEngineeringPage from "./components/AdminEngineeringPage.jsx";
import AdminFeedbackPage from "./components/AdminFeedbackPage.jsx";
import AccountPage from "./components/AccountPage.jsx";
import ReleasesPage from "./components/ReleasesPage.jsx";
import AdminAssistantPanel from "./components/AdminAssistantPanel.jsx";
import EntityDevMetaWorkspace from "./components/EntityDevMetaWorkspace.jsx";
import MetaWorkspacePage from "./components/MetaWorkspacePage.jsx";
import DevCopyDagPage from "./components/DevCopyDagPage.jsx";
import GlobalHoverLabel from "./components/GlobalHoverLabel.jsx";
import { sendAuditEvent } from "./utils/audit.js";
import { shouldUseCustomHoverLabel } from "./utils/customHoverUser.js";

const AUTH_ENABLED = import.meta.env.VITE_AUTH_ENABLED === "true";
const API_BASE = import.meta.env.VITE_API_BASE_URL || "";
const TOKEN_KEY = "tdv_access_token";
const USER_KEY = "tdv_user_profile";
const THEME_KEY = "tdv_theme";

export default function App() {
  const location = useLocation();
  const navigate = useNavigate();
  const [authToken, setAuthToken] = useState(
    () => localStorage.getItem(TOKEN_KEY) || sessionStorage.getItem(TOKEN_KEY)
  );
  const [userProfile, setUserProfile] = useState(() => {
    try {
      return (
        JSON.parse(localStorage.getItem(USER_KEY) || "null") ||
        JSON.parse(sessionStorage.getItem(USER_KEY) || "null")
      );
    } catch {
      return null;
    }
  });
  const [assistantOpen, setAssistantOpen] = useState(false);
  const [theme, setTheme] = useState(() => {
    if (typeof window === "undefined") return "dark";
    const saved = window.localStorage.getItem(THEME_KEY);
    if (saved === "light" || saved === "dark") return saved;
    return "dark";
  });

  useEffect(() => {
    if (!AUTH_ENABLED) return;
    setAuthToken(localStorage.getItem(TOKEN_KEY) || sessionStorage.getItem(TOKEN_KEY));
    try {
      setUserProfile(
        JSON.parse(localStorage.getItem(USER_KEY) || "null") ||
          JSON.parse(sessionStorage.getItem(USER_KEY) || "null")
      );
    } catch {
      setUserProfile(null);
    }
  }, []);

  useEffect(() => {
    if (!AUTH_ENABLED || !authToken || userProfile) return;
    fetch(`${API_BASE}/auth/me`)
      .then((res) => (res.ok ? res.json() : null))
      .then((profile) => {
        if (profile) {
          setUserProfile(profile);
          const storage =
            localStorage.getItem(TOKEN_KEY) ? localStorage : sessionStorage;
          storage.setItem(USER_KEY, JSON.stringify(profile));
        }
      })
      .catch(() => {});
  }, [authToken, userProfile]);

  useEffect(() => {
    if (!AUTH_ENABLED || !authToken) return;
    sendAuditEvent({
      event_type: "page_view",
      page: location.pathname,
      details: { search: location.search || "" },
    });
  }, [authToken, location.pathname, location.search]);

  useEffect(() => {
    if (typeof document === "undefined") return;
    document.documentElement.dataset.theme = theme;
    document.documentElement.style.colorScheme = theme;
    window.localStorage.setItem(THEME_KEY, theme);
  }, [theme]);

  useEffect(() => {
    if (userProfile?.role !== "admin" && theme !== "dark") {
      setTheme("dark");
    }
  }, [theme, userProfile?.role]);

  const normalizeFqn = useCallback((value) => {
    if (typeof value !== "string") return null;
    const trimmed = value.trim();
    if (!trimmed.includes(".")) return null;
    const clean = trimmed.replaceAll("\"", "").replaceAll("`", "");
    const [schema, table] = clean.split(".", 2);
    if (!schema || !table) return null;
    return { schema, table, fqn: `${schema}.${table}` };
  }, []);

  const normalizeTableTarget = useCallback(
    (value) => {
      if (!value) return null;
      if (typeof value === "string") {
        const parsed = normalizeFqn(value);
        return parsed ? { ...parsed, source: "current" } : null;
      }
      if (typeof value === "object") {
        if (typeof value.schema === "string" && typeof value.table === "string") {
          const schema = value.schema.trim();
          const table = value.table.trim();
          if (!schema || !table) return null;
          return {
            schema,
            table,
            fqn: `${schema}.${table}`,
            source: value.source || "current",
          };
        }
        if (typeof value.table === "string") {
          const parsed = normalizeFqn(value.table);
          return parsed ? { ...parsed, source: value.source || "current" } : null;
        }
      }
      return null;
    },
    [normalizeFqn]
  );

  const openView = useCallback(
    (target) => {
      if (!target) {
        navigate("/", { replace: true });
        return;
      }

      if (target === "__show_errors__") {
        navigate("/errors");
        return;
      }
      if (target === "__check_inconsistencies__") {
        navigate("/");
        return;
      }
      if (target === "__slowest_tables__") {
        navigate("/slow-tables");
        return;
      }
      if (target === "__entity_schedule__") {
        navigate("/entities");
        return;
      }
      if (target === "sla") {
        navigate("/sla");
        return;
      }
      if (target === "search") {
        navigate("/");
        return;
      }
      if (target === "table_search") {
        navigate("/tables");
        return;
      }
      if (target === "night_ops") {
        navigate("/night-ops");
        return;
      }
      if (target === "onboarding") {
        navigate("/onboarding");
        return;
      }
      if (target === "/admin/users") {
        navigate("/admin/users");
        return;
      }
      if (target === "/admin/dev-meta") {
        navigate("/admin/dev-meta");
        return;
      }
      if (target === "/admin/meta-workspace") {
        navigate("/admin/meta-workspace");
        return;
      }
      if (target === "/admin/dev-copy") {
        navigate("/admin/dev-copy");
        return;
      }
      if (target === "/admin/entity-meta") {
        navigate("/admin/entity-meta");
        return;
      }
      if (target === "/admin/engineering") {
        navigate("/admin/engineering");
        return;
      }
      if (target === "/admin/feedback") {
        navigate("/admin/feedback");
        return;
      }
      if (target === "/account") {
        navigate("/account");
        return;
      }
      if (target === "releases") {
        navigate("/releases");
        return;
      }
      if (typeof target === "object" && target.view) {
        if (target.view === "incident") {
          sendAuditEvent({
            event_type: "open_incident",
            page: location.pathname,
            object_type: "table",
            object_name: target.table || "",
          });
          navigate(`/incident?table=${encodeURIComponent(target.table || "")}`);
          return;
        }
        if (target.view === "table_info") {
          const parsed = normalizeTableTarget(target.table || target);
          if (parsed) {
            sendAuditEvent({
              event_type: "open_table",
              page: location.pathname,
              object_type: "table",
              object_name: parsed.fqn,
            });
            const suffix = parsed.source && parsed.source !== "current" ? `?source=${encodeURIComponent(parsed.source)}` : "";
            navigate(`/table/${encodeURIComponent(parsed.schema)}/${encodeURIComponent(parsed.table)}${suffix}`, {
              state: { from: location.pathname + location.search },
            });
          }
          return;
        }
        if (target.view === "dependency_graph") {
          const parsed = normalizeTableTarget(target.table || target);
          if (parsed) {
            sendAuditEvent({
              event_type: "open_dependency_graph",
              page: location.pathname,
              object_type: "table",
              object_name: parsed.fqn,
            });
            navigate(`/dependencies?table=${encodeURIComponent(parsed.fqn)}`);
          }
          return;
        }
        if (target.view === "release_details") {
          if (target.release_id) {
            sendAuditEvent({
              event_type: "open_release",
              page: location.pathname,
              object_type: "release",
              object_id: String(target.release_id),
              object_name: String(target.release_id),
            });
            navigate("/releases", { state: { releaseId: target.release_id } });
          }
          return;
        }
        if (target.view === "logic_audit") {
          sendAuditEvent({
            event_type: "open_logic_audit",
            page: location.pathname,
            object_type: target.table ? "table" : "page",
            object_name: target.table || null,
          });
          if (target.table) {
            navigate(`/logic-audit?table=${encodeURIComponent(target.table)}`);
          } else {
            navigate("/logic-audit");
          }
          return;
        }
      }

      if (typeof target === "string") {
        const parsed = normalizeFqn(target);
        if (parsed) {
          navigate(`/dependencies?table=${encodeURIComponent(parsed.fqn)}`);
        }
        return;
      }

      if (typeof target === "object") {
        const parsed = normalizeTableTarget(target);
        if (parsed) {
          const suffix = parsed.source && parsed.source !== "current" ? `?source=${encodeURIComponent(parsed.source)}` : "";
          navigate(`/table/${encodeURIComponent(parsed.schema)}/${encodeURIComponent(parsed.table)}${suffix}`, {
            state: { from: location.pathname + location.search },
          });
        }
      }
    },
    [location.pathname, location.search, navigate, normalizeFqn, normalizeTableTarget]
  );

  const TableRoute = () => {
    const params = useParams();
    const searchParams = new URLSearchParams(location.search);
    const source = searchParams.get("source") || "current";
    const tableIdRaw = searchParams.get("table_id");
    const tableId = tableIdRaw ? Number(tableIdRaw) : null;
    const handleBack = () => navigate(location.state?.from || "/tables");
    const handleNavigateTable = (schema, table, nextTableId = null) => {
      const params = new URLSearchParams();
      if (source && source !== "current") {
        params.set("source", source);
      }
      if (nextTableId) {
        params.set("table_id", String(nextTableId));
      }
      const suffix = params.toString() ? `?${params.toString()}` : "";
      navigate(`/table/${encodeURIComponent(schema)}/${encodeURIComponent(table)}${suffix}`, {
        state: { from: location.pathname + location.search },
      });
    };
    return (
      <TableCard
        schema={params.schema}
        tableName={params.table}
        source={source}
        onBack={handleBack}
        onNavigateTable={handleNavigateTable}
        tableContext={tableId ? { table_id: tableId } : null}
        onOpenImpact={(s, t) =>
          navigate(
            `/impact/${encodeURIComponent(s)}/${encodeURIComponent(t)}${source && source !== "current" ? `?source=${encodeURIComponent(source)}` : ""}`,
            {
            state: { from: location.pathname + location.search },
            }
          )
        }
        onOpenLogicAudit={(table) => openView({ view: "logic_audit", table })}
      />
    );
  };

  const DependenciesRoute = () => {
    const params = new URLSearchParams(location.search);
    const table = params.get("table") || "";
    const handleBack = () => navigate(location.state?.from || "/");
    return <DependencyViewer table={table} onBack={handleBack} />;
  };

  const IncidentRoute = () => {
    const params = new URLSearchParams(location.search);
    const table = params.get("table") || "";
    const handleBack = () => navigate(location.state?.from || "/errors");
    return (
      <IncidentDetailsPage
        tableFqn={table}
        onBack={handleBack}
        onOpenTable={(tbl) => openView({ view: "table_info", table: tbl })}
      />
    );
  };

  const isAdmin = useMemo(() => userProfile?.role === "admin", [userProfile]);
  const canUseMetaWorkspace = useMemo(
    () => userProfile?.role === "admin" || userProfile?.role === "engineer",
    [userProfile],
  );
  const canUseDevMeta = useMemo(() => Boolean(userProfile), [userProfile]);
  const useCustomHoverLabel = useMemo(() => shouldUseCustomHoverLabel(userProfile), [userProfile]);
  const assistantContext = useMemo(() => {
    const params = new URLSearchParams(location.search);
    const source = params.get("source") || "current";
    const tableRoute = location.pathname.match(/^\/table\/([^/]+)\/(.+)$/);
    if (tableRoute) {
      return {
        page: "table",
        schema: decodeURIComponent(tableRoute[1]),
        table: decodeURIComponent(tableRoute[2]),
        source,
      };
    }
    const impactRoute = location.pathname.match(/^\/impact\/([^/]+)\/(.+)$/);
    if (impactRoute) {
      return {
        page: "impact",
        schema: decodeURIComponent(impactRoute[1]),
        table: decodeURIComponent(impactRoute[2]),
        source,
      };
    }
    const depsTable = params.get("table");
    if (location.pathname === "/dependencies" && depsTable && depsTable.includes(".")) {
      const [schema, table] = depsTable.split(".", 2);
      return { page: "dependencies", schema, table, source: "current" };
    }
    return { page: location.pathname, source: "current" };
  }, [location.pathname, location.search]);

  return (
    <div className="app-container">
      <GlobalHoverLabel enabled={useCustomHoverLabel} />
      <Sidebar
        currentPath={location.pathname}
        onChangeView={openView}
        authEnabled={AUTH_ENABLED}
        userProfile={userProfile}
        currentTheme={theme}
        onThemeChange={setTheme}
        onLogout={() => {
          if (AUTH_ENABLED && authToken) {
            fetch(`${API_BASE}/auth/logout`, { method: "POST", keepalive: true }).catch(() => {});
          }
          localStorage.removeItem(TOKEN_KEY);
          localStorage.removeItem(USER_KEY);
          sessionStorage.removeItem(TOKEN_KEY);
          sessionStorage.removeItem(USER_KEY);
          setAuthToken(null);
          setUserProfile(null);
          navigate("/login");
        }}
      />
      {userProfile ? (
        <AdminAssistantPanel
          open={assistantOpen}
          onOpen={() => setAssistantOpen(true)}
          onClose={() => setAssistantOpen(false)}
          context={assistantContext}
          onOpenTable={(item) => {
            setAssistantOpen(false);
            openView({
              view: "table_info",
              table: {
                schema: item.schema,
                table: item.table,
                source: item.source || "current",
              },
            });
          }}
        />
      ) : null}
        <Routes>
        <Route
          path="/login"
          element={
            <LoginPage
              onLogin={({ token, profile }) => {
                if (token) setAuthToken(token);
                if (profile) setUserProfile(profile);
              }}
            />
          }
        />
        <Route
          path="/admin/users"
          element={
            AUTH_ENABLED && !authToken ? (
              <Navigate to="/login" replace />
            ) : isAdmin ? (
              <AdminUsersPage userProfile={userProfile} />
            ) : (
              <Navigate to="/" replace />
            )
          }
        />
        <Route
          path="/admin/dev-meta"
          element={
            AUTH_ENABLED && !authToken ? (
              <Navigate to="/login" replace />
            ) : canUseDevMeta ? (
              <DevMetaAdminPage userProfile={userProfile} />
            ) : (
              <Navigate to="/" replace />
            )
          }
        />
        <Route
          path="/admin/meta-workspace"
          element={
            AUTH_ENABLED && !authToken ? (
              <Navigate to="/login" replace />
            ) : canUseMetaWorkspace ? (
              <MetaWorkspacePage userProfile={userProfile} />
            ) : (
              <Navigate to="/" replace />
            )
          }
        />
        <Route
          path="/admin/dev-copy"
          element={
            AUTH_ENABLED && !authToken ? (
              <Navigate to="/login" replace />
            ) : canUseDevMeta ? (
              <DevCopyDagPage userProfile={userProfile} />
            ) : (
              <Navigate to="/" replace />
            )
          }
        />
        <Route
          path="/admin/entity-meta"
          element={
            AUTH_ENABLED && !authToken ? (
              <Navigate to="/login" replace />
            ) : canUseMetaWorkspace ? (
              <Navigate to="/admin/meta-workspace" replace />
            ) : (
              <Navigate to="/" replace />
            )
          }
        />
        <Route
          path="/admin/engineering"
          element={
            AUTH_ENABLED && !authToken ? (
              <Navigate to="/login" replace />
            ) : isAdmin ? (
              <AdminEngineeringPage userProfile={userProfile} />
            ) : (
              <Navigate to="/" replace />
            )
          }
        />
        <Route
          path="/admin/feedback"
          element={
            AUTH_ENABLED && !authToken ? (
              <Navigate to="/login" replace />
            ) : isAdmin ? (
              <AdminFeedbackPage />
            ) : (
              <Navigate to="/" replace />
            )
          }
        />
        <Route
          path="/account"
          element={
            AUTH_ENABLED && !authToken ? (
              <Navigate to="/login" replace />
            ) : (
              <AccountPage userProfile={userProfile} />
            )
          }
        />
        <Route
          path="/"
          element={
            AUTH_ENABLED && !authToken ? (
              <Navigate to="/login" replace />
            ) : (
              <HomePage onSelectTable={openView} />
            )
          }
        />
        <Route
          path="/errors"
          element={
            AUTH_ENABLED && !authToken ? (
              <Navigate to="/login" replace />
            ) : (
              <IncidentsPage onSelectTable={openView} />
            )
          }
        />
        <Route
          path="/failures"
          element={
            AUTH_ENABLED && !authToken ? (
              <Navigate to="/login" replace />
            ) : (
              <ErrorDashboard onSelectTable={(table) => openView({ view: "table_info", table })} />
            )
          }
        />
        <Route path="/dependency-search" element={<Navigate to="/" replace />} />
        <Route
          path="/tables"
          element={
            AUTH_ENABLED && !authToken ? (
              <Navigate to="/login" replace />
            ) : (
              <TableSearch onSelectTable={(table) => openView({ view: "table_info", table })} />
            )
          }
        />
        <Route path="/dependency-issues" element={<Navigate to="/" replace />} />
        <Route
          path="/slow-tables"
          element={
            AUTH_ENABLED && !authToken ? (
              <Navigate to="/login" replace />
            ) : (
              <SlowestTables onSelectTable={openView} />
            )
          }
        />
        <Route
          path="/entities"
          element={AUTH_ENABLED && !authToken ? <Navigate to="/login" replace /> : <EntityShedule />}
        />
        <Route
          path="/entity/:id/tables"
          element={AUTH_ENABLED && !authToken ? <Navigate to="/login" replace /> : <EntityTablesPage />}
        />
        <Route
          path="/sla"
          element={AUTH_ENABLED && !authToken ? <Navigate to="/login" replace /> : <SlaPage />}
        />
        <Route
          path="/table/:schema/:table"
          element={AUTH_ENABLED && !authToken ? <Navigate to="/login" replace /> : <TableRoute />}
        />
        <Route
          path="/impact/:schema/:table"
          element={AUTH_ENABLED && !authToken ? <Navigate to="/login" replace /> : <ImpactGraphPage />}
        />
        <Route
          path="/night-ops"
          element={AUTH_ENABLED && !authToken ? <Navigate to="/login" replace /> : <NightOpsPage />}
        />
          <Route
            path="/logic-audit"
            element={AUTH_ENABLED && !authToken ? <Navigate to="/login" replace /> : <LogicAuditPage />}
          />
          <Route
            path="/releases"
            element={AUTH_ENABLED && !authToken ? <Navigate to="/login" replace /> : <ReleasesPage />}
          />
          <Route path="/analytics" element={<Navigate to="/slow-tables" replace />} />
        <Route
          path="/onboarding"
          element={AUTH_ENABLED && !authToken ? <Navigate to="/login" replace /> : <OnboardingPage userProfile={userProfile} />}
        />
        <Route
          path="/about-app"
          element={<Navigate to="/onboarding" replace />}
        />
        <Route
          path="/dependencies"
          element={AUTH_ENABLED && !authToken ? <Navigate to="/login" replace /> : <DependenciesRoute />}
        />
        <Route
          path="/incident"
          element={AUTH_ENABLED && !authToken ? <Navigate to="/login" replace /> : <IncidentRoute />}
        />
        <Route path="/entity_schedule" element={<Navigate to="/entities" replace />} />
        <Route path="*" element={<div className="page-error">Page not found</div>} />
      </Routes>
    </div>
  );
}
