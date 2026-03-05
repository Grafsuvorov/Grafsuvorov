import { useEffect, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";
const YT_BASE = "https://yt.rusal.ru/issue/";

export default function Sidebar({ currentPath, onChangeView, authEnabled, userProfile, onLogout }) {
  const isActive = (path) => currentPath === path;
  const roleLabel = userProfile?.role === "admin"
    ? "Админ"
    : userProfile?.role === "engineer"
      ? "Инженер"
      : userProfile?.role === "analyst"
        ? "Аналитик"
        : userProfile?.role;
  const [query, setQuery] = useState("");
  const [results, setResults] = useState({ tables: [], tasks: [], releases: [] });
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!query || query.trim().length < 2) {
      setResults({ tables: [], tasks: [], releases: [] });
      setLoading(false);
      return;
    }

    const handle = setTimeout(() => {
      setLoading(true);
      fetch(`${API_BASE}/api/search?q=${encodeURIComponent(query.trim())}`)
        .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось выполнить поиск")))
        .then((data) => {
          setResults({
            tables: Array.isArray(data?.tables) ? data.tables : [],
            tasks: Array.isArray(data?.tasks) ? data.tasks : [],
            releases: Array.isArray(data?.releases) ? data.releases : [],
          });
        })
        .catch(() => setResults({ tables: [], tasks: [], releases: [] }))
        .finally(() => setLoading(false));
    }, 300);

    return () => clearTimeout(handle);
  }, [query]);

  const hasResults =
    results.tables.length || results.tasks.length || results.releases.length;
  const showDropdown = query.trim().length >= 2;

  return (
    <header className="topnav">
      <div className="topnav-inner">
        {/* LEFT */}
        <div className="topnav-left">
          <div className="topnav-brand">DWH Контроль</div>

          <nav className="topnav-nav">
            <div className="nav-primary">
              <button
                className={isActive("/") ? "active" : ""}
                onClick={() => onChangeView(null)}
              >
                Главная
              </button>

              <button
                className={isActive("/tables") ? "active" : ""}
                onClick={() => onChangeView("table_search")}
              >
                Таблицы
              </button>
            </div>

            <div className="nav-secondary">
              <button onClick={() => onChangeView("__slowest_tables__")}>
                Медленные
              </button>
              <button onClick={() => onChangeView("night_ops")}>
                Ночное окно
              </button>
              <button onClick={() => onChangeView("__entity_schedule__")}>
                Сущности
              </button>
              <button
                className={isActive("/releases") ? "active" : ""}
                onClick={() => onChangeView("releases")}
              >
                Релизы
              </button>
              <button
                className={isActive("/analytics") ? "active" : ""}
                onClick={() => onChangeView("analytics")}
              >
                Аналитика
              </button>
              <button
                className={isActive("/logic-audit") ? "active" : ""}
                onClick={() => onChangeView("logic_audit")}
              >
                Аудит логики
              </button>
              {authEnabled && userProfile && (
                <button
                  className={isActive("/account") ? "active" : ""}
                  onClick={() => onChangeView("/account")}
                >
                  Профиль
                </button>
              )}
              {authEnabled && userProfile?.role === "admin" && (
                <button
                  className={isActive("/admin/users") ? "active" : ""}
                  onClick={() => onChangeView("/admin/users")}
                >
                  Админка
                </button>
              )}
              <button
                className={isActive("/onboarding") ? "active" : ""}
                onClick={() => onChangeView("onboarding")}
              >
                Как пользоваться
              </button>
            </div>
          </nav>
        </div>

        {/* RIGHT */}
        <div className="topnav-right">
          <div className="topnav-search">
            <input
              className="input"
              type="text"
              placeholder="🔎 Search tables / tasks / releases"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
            />
            {showDropdown && (
              <div className="search-dropdown">
                {loading && <div className="muted">Поиск...</div>}
                {!loading && !hasResults && <div className="muted">Ничего не найдено</div>}
                {!loading && results.tables.length > 0 && (
                  <div className="search-group">
                    <div className="search-group-title">Tables</div>
                    {results.tables.map((row, idx) => (
                      <button
                        key={`tbl-${idx}`}
                        className="search-option"
                        onClick={() => {
                          onChangeView({ view: "table_info", table: `${row.schema_name}.${row.table_name}` });
                          setQuery("");
                        }}
                      >
                        <span className="mono">{row.schema_name}.{row.table_name}</span>
                      </button>
                    ))}
                  </div>
                )}
                {!loading && results.tasks.length > 0 && (
                  <div className="search-group">
                    <div className="search-group-title">Tasks</div>
                    {results.tasks.map((row, idx) => (
                      <button
                        key={`task-${idx}`}
                        className="search-option"
                        onClick={() => {
                          const url = `${YT_BASE}${row.issue_id}`;
                          window.open(url, "_blank", "noopener");
                          setQuery("");
                        }}
                      >
                        <span className="mono">{row.issue_id}</span>
                        <span className="muted">{row.summary || ""}</span>
                      </button>
                    ))}
                  </div>
                )}
                {!loading && results.releases.length > 0 && (
                  <div className="search-group">
                    <div className="search-group-title">Releases</div>
                    {results.releases.map((row, idx) => (
                      <button
                        key={`rel-${idx}`}
                        className="search-option"
                        onClick={() => {
                          onChangeView({ view: "release_details", release_id: row.release_id });
                          setQuery("");
                        }}
                      >
                        <span className="mono">{row.release_id}</span>
                        <span className="muted">{row.status || "—"}</span>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>

          {authEnabled && userProfile && (
            <>
              <div className="auth-pill">
                <div className="auth-user">
                  {userProfile?.username || userProfile?.email || "Пользователь"}
                </div>
                <div className="auth-role">{roleLabel}</div>
              </div>
              <button className="auth-logout" onClick={onLogout}>
                Выйти
              </button>
            </>
          )}
        </div>
      </div>
    </header>
  );
}
