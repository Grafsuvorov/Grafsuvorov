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
  const primaryNav = [
    { path: "/", label: "Обзор", action: () => onChangeView(null) },
    { path: "/tables", label: "Каталог", action: () => onChangeView("table_search") },
  ];
  const secondaryNav = [
    { path: "/slow-tables", label: "Производительность", action: () => onChangeView("__slowest_tables__") },
    { path: "/night-ops", label: "Мониторинг", action: () => onChangeView("night_ops") },
    { path: "/entities", label: "Сущности", action: () => onChangeView("__entity_schedule__") },
    { path: "/releases", label: "Релизы", action: () => onChangeView("releases") },
    ...(authEnabled && userProfile ? [{ path: "/account", label: "Профиль", action: () => onChangeView("/account") }] : []),
    ...(authEnabled && userProfile?.role === "admin"
      ? [{ path: "/admin/users", label: "Админка", action: () => onChangeView("/admin/users") }]
      : []),
    ...(authEnabled && userProfile ? [{ path: "/admin/dev-meta", label: "DEV Meta", action: () => onChangeView("/admin/dev-meta") }] : []),
    ...(authEnabled && (userProfile?.role === "admin" || userProfile?.role === "engineer")
      ? [{ path: "/admin/meta-workspace", label: "Meta Workspace", action: () => onChangeView("/admin/meta-workspace") }]
      : []),
    ...(authEnabled && userProfile ? [{ path: "/admin/dev-copy", label: "DEV Copy", action: () => onChangeView("/admin/dev-copy") }] : []),
    ...(authEnabled && userProfile?.role === "admin"
      ? [{ path: "/admin/architecture", label: "Архитектура", action: () => onChangeView("/admin/architecture") }]
      : []),
    ...(authEnabled && userProfile?.role === "admin"
      ? [{
          path: "/admin/engineering",
          label: "Репорты",
          action: () => {
            console.log("[Sidebar] open /admin/engineering");
            navigate("/admin/engineering");
          },
        }]
      : []),
    ...(authEnabled && userProfile?.role === "admin"
      ? [{ path: "/admin/feedback", label: "Фидбек", action: () => onChangeView("/admin/feedback") }]
      : []),
    { path: "/onboarding", label: "Гид", action: () => onChangeView("onboarding") },
  ];
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
          <div className="topnav-brand">
            <div className="topnav-brand-mark">DW</div>
            <div className="topnav-brand-copy">
              <div className="topnav-brand-title">DWH Контроль</div>
              <div className="topnav-brand-subtitle">операционная панель платформы</div>
            </div>
          </div>

          <nav className="topnav-nav">
            <div className="nav-stack">
              <div className="nav-section">
                <div className="nav-section-label">Основное</div>
                <div className="nav-primary">
                  {primaryNav.map((item) => (
                    <button
                      key={item.path}
                      type="button"
                      className={isActive(item.path) ? "active" : ""}
                      onClick={item.action}
                    >
                      {item.label}
                    </button>
                  ))}
                </div>
              </div>

              <div className="nav-section nav-section-muted">
                <div className="nav-section-label">Контуры</div>
                <div className="nav-secondary">
                  {secondaryNav.map((item) => (
                    <button
                      key={item.path}
                      type="button"
                      className={isActive(item.path) ? "active" : ""}
                      onClick={item.action}
                    >
                      {item.label}
                    </button>
                  ))}
                </div>
              </div>
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
