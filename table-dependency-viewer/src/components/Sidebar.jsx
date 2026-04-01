import "../style/app.css";

export default function Sidebar({ currentPath, onChangeView, authEnabled, userProfile, onLogout }) {
  const isActive = (path) => currentPath === path;
  const roleLabel = userProfile?.role === "admin"
    ? "Админ"
    : userProfile?.role === "engineer"
      ? "Инженер"
      : userProfile?.role === "analyst"
        ? "Аналитик"
        : userProfile?.role;
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
                Обзор
              </button>

              <button
                className={isActive("/tables") ? "active" : ""}
                onClick={() => onChangeView("table_search")}
              >
                Каталог
              </button>
            </div>

            <div className="nav-secondary">
              <button
                className={isActive("/slow-tables") ? "active" : ""}
                onClick={() => onChangeView("__slowest_tables__")}
              >
                Производительность
              </button>
              <button
                className={isActive("/night-ops") ? "active" : ""}
                onClick={() => onChangeView("night_ops")}
              >
                Мониторинг
              </button>
              <button
                className={isActive("/entities") ? "active" : ""}
                onClick={() => onChangeView("__entity_schedule__")}
              >
                Сущности
              </button>
              <button
                className={isActive("/releases") ? "active" : ""}
                onClick={() => onChangeView("releases")}
              >
                Релизы
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
              {authEnabled && userProfile?.role === "admin" && (
                <button
                  className={isActive("/admin/engineering") ? "active" : ""}
                  onClick={() => onChangeView("/admin/engineering")}
                >
                  Эффективность
                </button>
              )}
              {authEnabled && userProfile?.role === "admin" && (
                <button
                  className={isActive("/admin/dev-meta") ? "active" : ""}
                  onClick={() => onChangeView("/admin/dev-meta")}
                >
                  DEV Meta
                </button>
              )}
              <button
                className={isActive("/onboarding") ? "active" : ""}
                onClick={() => onChangeView("onboarding")}
              >
                Гид
              </button>
            </div>
          </nav>
        </div>

        {/* RIGHT */}
        {authEnabled && userProfile && (
          <div className="topnav-right">
            <div className="auth-pill">
              <div className="auth-user">
                {userProfile?.username || userProfile?.email || "Пользователь"}
              </div>
              <div className="auth-role">{roleLabel}</div>
            </div>
            <button className="auth-logout" onClick={onLogout}>
              Выйти
            </button>
          </div>
        )}
      </div>
    </header>
  );
}
