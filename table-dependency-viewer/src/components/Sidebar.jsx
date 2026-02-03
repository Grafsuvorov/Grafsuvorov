import "../style/app.css";

export default function Sidebar({ currentPath, onChangeView }) {
  const isActive = (path) => currentPath === path;
  return (
    <header className="topnav">
      <div className="topnav-inner">
        {/* LEFT */}
        <div className="topnav-left">
          <div className="topnav-brand">Data Control</div>

          <nav className="topnav-nav">
            <div className="nav-primary">
              <button
                className={isActive("/") ? "active" : ""}
                onClick={() => onChangeView(null)}
              >
                Dashboard
              </button>

              <button
                className={isActive("/errors") ? "active" : ""}
                onClick={() => onChangeView("__show_errors__")}
              >
                Errors
              </button>

              <button
                className={isActive("/tables") ? "active" : ""}
                onClick={() => onChangeView("table_search")}
              >
                Tables
              </button>
            </div>

            <div className="nav-secondary">
              <button onClick={() => onChangeView("__slowest_tables__")}>
                Slow Tables
              </button>
              <button onClick={() => onChangeView("night_ops")}>
                Night Ops
              </button>
              <button onClick={() => onChangeView("__entity_schedule__")}>
                Entities
              </button>
              <button
                className={isActive("/onboarding") ? "active" : ""}
                onClick={() => onChangeView("onboarding")}
              >
                Onboarding
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
