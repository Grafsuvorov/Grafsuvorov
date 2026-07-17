import "../style/app.css";
import { useNavigate } from "react-router-dom";

export default function Sidebar({
  currentPath,
  onChangeView,
  authEnabled,
  userProfile,
  currentTheme = "dark",
  onThemeChange,
  onLogout,
}) {
  const navigate = useNavigate();
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
                type="button"
                className={isActive("/") ? "active" : ""}
                onClick={() => onChangeView(null)}
              >
                Обзор
              </button>

              <button
                type="button"
                className={isActive("/tables") ? "active" : ""}
                onClick={() => onChangeView("table_search")}
              >
                Каталог
              </button>
            </div>

            <div className="nav-secondary">
              <button
                type="button"
                className={isActive("/slow-tables") ? "active" : ""}
                onClick={() => onChangeView("__slowest_tables__")}
              >
                Производительность
              </button>
              <button
                type="button"
                className={isActive("/night-ops") ? "active" : ""}
                onClick={() => onChangeView("night_ops")}
              >
                Мониторинг
              </button>
              <button
                type="button"
                className={isActive("/entities") ? "active" : ""}
                onClick={() => onChangeView("__entity_schedule__")}
              >
                Сущности
              </button>
              <button
                type="button"
                className={isActive("/releases") ? "active" : ""}
                onClick={() => onChangeView("releases")}
              >
                Релизы
              </button>
              {authEnabled && userProfile && (
                <button
                  type="button"
                  className={isActive("/account") ? "active" : ""}
                  onClick={() => onChangeView("/account")}
                >
                  Профиль
                </button>
              )}
              {authEnabled && userProfile?.role === "admin" && (
                <button
                  type="button"
                  className={isActive("/admin/users") ? "active" : ""}
                  onClick={() => onChangeView("/admin/users")}
                >
                  Админка
                </button>
              )}
              {authEnabled && userProfile && (
                <button
                  type="button"
                  className={isActive("/admin/dev-meta") ? "active" : ""}
                  onClick={() => onChangeView("/admin/dev-meta")}
                >
                  DEV Meta
                </button>
              )}
              {authEnabled && (userProfile?.role === "admin" || userProfile?.role === "engineer") && (
                <button
                  type="button"
                  className={isActive("/admin/meta-workspace") ? "active" : ""}
                  onClick={() => onChangeView("/admin/meta-workspace")}
                >
                  Meta Workspace
                </button>
              )}
              {authEnabled && userProfile && (
                <button
                  type="button"
                  className={isActive("/admin/dev-copy") ? "active" : ""}
                  onClick={() => onChangeView("/admin/dev-copy")}
                >
                  DEV Copy
                </button>
              )}
              {authEnabled && userProfile?.role === "admin" && (
                <button
                  type="button"
                  className={isActive("/admin/engineering") ? "active" : ""}
                  onClick={() => {
                    console.log("[Sidebar] open /admin/engineering");
                    navigate("/admin/engineering");
                  }}
                >
                  Репорты
                </button>
              )}
              {authEnabled && userProfile?.role === "admin" && (
                <button
                  type="button"
                  className={isActive("/admin/feedback") ? "active" : ""}
                  onClick={() => onChangeView("/admin/feedback")}
                >
                  Фидбек
                </button>
              )}
              <button
                type="button"
                className={isActive("/onboarding") ? "active" : ""}
                onClick={() => onChangeView("onboarding")}
              >
                Гид
              </button>
            </div>
          </nav>
        </div>

        {/* RIGHT */}
        <div className="topnav-right">
          {userProfile?.role === "admin" ? (
            <div className="theme-switch" aria-label="Переключение темы">
              <button
                type="button"
                className={`theme-switch-option ${currentTheme === "light" ? "active" : ""}`}
                onClick={() => onThemeChange?.("light")}
              >
                Светлая
              </button>
              <button
                type="button"
                className={`theme-switch-option ${currentTheme === "dark" ? "active" : ""}`}
                onClick={() => onThemeChange?.("dark")}
              >
                Тёмная
              </button>
            </div>
          ) : null}
          {authEnabled && userProfile && (
            <>
            <div className="auth-pill">
              <div className="auth-user">
                {userProfile?.username || userProfile?.email || "Пользователь"}
              </div>
              <div className="auth-role">{roleLabel}</div>
            </div>
            <button type="button" className="auth-logout" onClick={onLogout}>
              Выйти
            </button>
            </>
          )}
        </div>
      </div>
    </header>
  );
}
