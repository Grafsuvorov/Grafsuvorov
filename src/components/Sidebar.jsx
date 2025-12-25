import "../style/app.css";

export default function Sidebar({ currentView, onChangeView }) {
  return (
    <header className="topnav">
      <div className="topnav-inner">
        {/* LEFT */}
        <div className="topnav-left">
          <div className="topnav-brand">Data Control</div>

          <nav className="topnav-nav">
            <div className="nav-primary">
              <button
                className={currentView === "home" ? "active" : ""}
                onClick={() => onChangeView(null)}
              >
                Dashboard
              </button>

              <button
                className={currentView === "errors" ? "active" : ""}
                onClick={() => onChangeView("__show_errors__")}
              >
                Errors
              </button>

              <button
                className={currentView === "table_search" ? "active" : ""}
                onClick={() => onChangeView("table_search")}
              >
                Tables
              </button>
            </div>

            <div className="nav-secondary">
              <button onClick={() => onChangeView("search")}>
                Dependency graph
              </button>
              <button onClick={() => onChangeView("__check_inconsistencies__")}>
                Dependency issues
              </button>
              <button onClick={() => onChangeView("__slowest_tables__")}>
                Slow tables
              </button>
              <button onClick={() => onChangeView("__entity_schedule__")}>
                Entities
              </button>
            </div>
          </nav>
        </div>

        {/* RIGHT */}
        <div className="topnav-right">
          <div className="topnav-status">
            <span className="sla-dot degraded" />
            <span className="topnav-status-text">
              Partial degradation
            </span>
          </div>
        </div>
      </div>
    </header>
  );
}
