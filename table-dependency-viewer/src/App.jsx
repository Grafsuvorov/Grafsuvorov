import React, { useCallback } from "react";
import { Routes, Route, Navigate, useLocation, useNavigate, useParams } from "react-router-dom";

import "./index.css";
import "./style/app.css";

import Sidebar from "./components/Sidebar.jsx";
import HomePage from "./components/HomePage.jsx";
import IncidentsPage from "./components/IncidentsPage.jsx";
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

export default function App() {
  const location = useLocation();
  const navigate = useNavigate();

  const normalizeFqn = useCallback((value) => {
    if (typeof value !== "string") return null;
    const trimmed = value.trim();
    if (!trimmed.includes(".")) return null;
    const clean = trimmed.replaceAll("\"", "").replaceAll("`", "");
    const [schema, table] = clean.split(".", 2);
    if (!schema || !table) return null;
    return { schema, table, fqn: `${schema}.${table}` };
  }, []);

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
      if (target === "logic_audit") {
        navigate("/logic-audit");
        return;
      }

      if (typeof target === "object" && target.view) {
        if (target.view === "incident") {
          navigate(`/incident?table=${encodeURIComponent(target.table || "")}`);
          return;
        }
        if (target.view === "table_info") {
          const parsed = normalizeFqn(target.table);
          if (parsed) {
            navigate(`/table/${encodeURIComponent(parsed.schema)}/${encodeURIComponent(parsed.table)}`, {
              state: { from: location.pathname + location.search },
            });
          }
          return;
        }
        if (target.view === "dependency_graph") {
          const parsed = normalizeFqn(target.table);
          if (parsed) {
            navigate(`/dependencies?table=${encodeURIComponent(parsed.fqn)}`);
          }
          return;
        }
      }

      if (typeof target === "string") {
        const parsed = normalizeFqn(target);
        if (parsed) {
          navigate(`/dependencies?table=${encodeURIComponent(parsed.fqn)}`);
        }
      }
    },
    [location.pathname, location.search, navigate, normalizeFqn]
  );

  const TableRoute = () => {
    const params = useParams();
    const handleBack = () => navigate(location.state?.from || "/tables");
    const handleNavigateTable = (schema, table) => {
      navigate(`/table/${schema}/${table}`, {
        state: { from: location.pathname + location.search },
      });
    };
    return (
      <TableCard
        schema={params.schema}
        tableName={params.table}
        onBack={handleBack}
        onNavigateTable={handleNavigateTable}
        onOpenImpact={(s, t) => navigate(`/impact/${s}/${t}`, { state: { from: location.pathname + location.search } })}
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

  return (
    <div className="app">
      <Sidebar currentPath={location.pathname} onChangeView={openView} />
      <Routes>
        <Route path="/" element={<HomePage onSelectTable={openView} />} />
        <Route path="/errors" element={<IncidentsPage onSelectTable={openView} />} />
        <Route path="/dependency-search" element={<Navigate to="/" replace />} />
        <Route path="/tables" element={<TableSearch onSelectTable={(name) => openView({ view: "table_info", table: name })} />} />
        <Route path="/dependency-issues" element={<Navigate to="/" replace />} />
        <Route path="/slow-tables" element={<SlowestTables onSelectTable={openView} />} />
        <Route path="/entities" element={<EntityShedule />} />
        <Route path="/entity/:id/tables" element={<EntityTablesPage />} />
        <Route path="/sla" element={<SlaPage />} />
        <Route path="/table/:schema/:table" element={<TableRoute />} />
        <Route path="/impact/:schema/:table" element={<ImpactGraphPage />} />
        <Route path="/night-ops" element={<NightOpsPage />} />
        <Route path="/logic-audit" element={<LogicAuditPage />} />
        <Route path="/onboarding" element={<OnboardingPage />} />
        <Route path="/dependencies" element={<DependenciesRoute />} />
        <Route path="/incident" element={<IncidentRoute />} />
        <Route path="/entity_schedule" element={<Navigate to="/entities" replace />} />
        <Route path="*" element={<div className="page-error">Page not found</div>} />
      </Routes>
    </div>
  );
}
