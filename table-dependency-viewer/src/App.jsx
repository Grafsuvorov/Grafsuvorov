import React, { useEffect, useRef, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";

import "./index.css";
import "./style/app.css";

import Sidebar from "./components/Sidebar.jsx";
import HomePage from "./components/HomePage.jsx";
import SearchPage from "./components/SearchPage.jsx";
import IncidentsPage from "./components/IncidentsPage.jsx"; 
import TableSearch from "./components/TableSearch.jsx";
import InconsistencyPage from "./components/InconsistencyPage.jsx";
import SlowestTables from "./components/SlowestTables.jsx";
import SlaPage from "./components/SlaPage.jsx";
import DependencyViewer from "./components/DependencyViewer.jsx";
import TableCard from "./components/TableCard.jsx";
import EntityShedule from "./components/EntityShedule.jsx";
import EntityTablesPage from "./components/EntityTablesPage.jsx";

// NEW
import IncidentDetailsPage from "./components/IncidentDetailsPage.jsx";

export default function App() {
  const location = useLocation();
  const navigate = useNavigate();
  const [view, setView] = useState("home");

  const [schema, setSchema] = useState(null);
  const [tableName, setTableName] = useState(null);
  const [selectedTable, setSelectedTable] = useState(null);
  const [autoShowGraph, setAutoShowGraph] = useState(false);
  const [tableContext, setTableContext] = useState(null);

  // NEW: куда возвращаться
  const [returnView, setReturnView] = useState("home");
  const lastRouteRef = useRef({ search: "", path: "" });

  const openView = (target, source = "home") => {
    if (!target) {
      setView("home");
      setReturnView("home");
      return;
    }

    // системные экраны
    if (target === "__show_errors__") {
      setReturnView(view);
      setView("errors");
      return;
    }

    if (target === "__check_inconsistencies__") {
      setReturnView(view);
      setView("__check_inconsistencies__");
      return;
    }

    if (target === "__slowest_tables__") {
      setReturnView(view);
      setView("slowest_tables");
      return;
    }

    if (target === "__entity_schedule__") {
      setReturnView(view);
      setView("entity_schedule");
      return;
    }

    if (target === "sla") {
      setReturnView(view);
      setView("sla");
      setAutoShowGraph(false);
      setTableContext(null);
      return;
    }

    if (target === "search") {
      setReturnView(view);
      setView("search");
      setAutoShowGraph(false);
      setTableContext(null);
      return;
    }

    if (target === "table_search") {
      setReturnView(view);
      setView("table_search");
      setAutoShowGraph(false);
      setTableContext(null);
      return;
    }

    // OBJECT navigation
    if (typeof target === "object" && target.view) {
      if (target.view === "incident") {
        setReturnView(source || view || "home");
        setSelectedTable(target.table);
        setView("incident");
        setAutoShowGraph(false);
        setTableContext(null);
        return;
      }

      if (target.view === "table_info") {
        setReturnView(source || view || "home");
        const table = typeof target.table === "string" ? target.table.trim() : null;

        if (table && table.includes(".")) {
          const clean = table.replaceAll("/", "").replaceAll("-", "");
          const [sch, tbl] = clean.split(".");
          setSchema(sch);
          setTableName(tbl);
          setSelectedTable(`${sch}.${tbl}`);
        }

        setView("table_info");
        setAutoShowGraph(Boolean(target.openGraph));
        setTableContext(target.context || null);
        return;
      }

      if (target.view === "dependency_graph") {
        setReturnView(source || view || "home");
        const table = typeof target.table === "string" ? target.table.trim() : target.table;

        if (typeof table === "string" && table.includes(".")) {
          const clean = table.replaceAll("/", "").replaceAll("-", "");
          const [sch, tbl] = clean.split(".");
          setSchema(sch);
          setTableName(tbl);
          setSelectedTable(table);
        } else {
          setSelectedTable(table);
        }

        setView("dependencies");
        setAutoShowGraph(false);
        setTableContext(null);
        return;
      }
    }

    // table string
    if (typeof target === "string" && target.includes(".")) {
      setReturnView(source || view || "home");

      const clean = target.replaceAll("/", "").replaceAll("-", "");
      const [sch, tbl] = clean.split(".");

      setSchema(sch);
      setTableName(tbl);
      setSelectedTable(target.trim());

      setView("dependencies");
      setAutoShowGraph(false);
      setTableContext(null);
      return;
    }
  };

  useEffect(() => {
    const search = location.search || "";
    const path = location.pathname || "";
    if (lastRouteRef.current.search === search && lastRouteRef.current.path === path) {
      return;
    }
    lastRouteRef.current = { search, path };

    if (path.startsWith("/entity/") && path.includes("/tables")) {
      setView("entity_tables");
      return;
    }
    if (path === "/entity_schedule") {
      setView("entity_schedule");
      return;
    }

    const params = new URLSearchParams(search);
    const viewParam = params.get("view");
    const tableParam = params.get("table");
    if (viewParam === "table_info" && tableParam) {
      openView({ view: "table_info", table: tableParam }, "home");
      navigate("/", { replace: true });
    }
  }, [location.pathname, location.search, navigate]);

  const renderContent = () => {
    switch (view) {
      case "home":
        return <HomePage onSelectTable={openView} />;

      case "search":
        return <SearchPage onSelectTable={openView} />;

      case "errors":
        return (
          <IncidentsPage
            onSelectTable={(name, source) => openView(name, source)}
          />
        );

      // NEW: новый экран инцидента 
      case "incident":
        return (
          <IncidentDetailsPage
            tableFqn={selectedTable}
            onBack={() => setView(returnView || "home")}
            onOpenTable={(table) => openView({ view: "table_info", table }, "incident")}
          />
        );

      case "table_search":
        return (
          <TableSearch
            onSelectTable={(name) => openView(name, "table_search")}
          />
        );

      case "__check_inconsistencies__":
        return <InconsistencyPage onBack={() => setView("home")} />;

      case "slowest_tables":
        return <SlowestTables onSelectTable={openView} />;

      case "entity_schedule":
        return <EntityShedule />;

      case "sla":
        return <SlaPage />;

      case "entity_tables":
        return <EntityTablesPage />;

      case "table_info":
        return (
          <TableCard
            schema={schema}
            tableName={tableName}
            setSchema={setSchema}
            setTableName={setTableName}
            autoShowGraph={autoShowGraph}
            tableContext={tableContext}
            onBack={() => setView(returnView || "table_search")}
          />
        );

      case "dependencies":
        return (
          <DependencyViewer
            table={selectedTable}
            onBack={() => setView(returnView || "home")}
          />
        );

      default:
        return <div>Page not found</div>;
    }
  };

  return (
    <div className="app-container">
      <Sidebar
        currentView={view}
        onChangeView={(target) => openView(target, view)}
      />

      <main className="content">
        <div className="content-inner">
          <div className="page">{renderContent()}</div>
        </div>
      </main>
    </div>
  );
}
