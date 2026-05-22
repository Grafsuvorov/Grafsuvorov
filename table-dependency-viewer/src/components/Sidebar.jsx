import "../style/app.css";
import { useNavigate } from "react-router-dom";

export default function Sidebar({ currentPath, onChangeView, authEnabled, userProfile, onLogout }) {
  const navigate = useNavigate();
  const isActive = (path) => currentPath === path;
  const customCursorTargetUser =
    "" ||
    ""; // укажите username или email пользователя
  const useCustomHoverLabel = Boolean(
    customCursorTargetUser &&
    (
      String(userProfile?.username || "").trim() === customCursorTargetUser ||
      String(userProfile?.email || "").trim() === customCursorTargetUser
    )
  );
  const buttonClassName = (path) =>
    `${isActive(path) ? "active" : ""} ${useCustomHoverLabel ? "custom-cursor-target" : ""}`.trim();
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
                className={buttonClassName("/")}
                onClick={() => onChangeView(null)}
              >
                Обзор
              </button>

              <button
                type="button"
                className={buttonClassName("/tables")}
                onClick={() => onChangeView("table_search")}
              >
                Каталог
              </button>
            </div>

            <div className="nav-secondary">
              <button
                type="button"
                className={buttonClassName("/slow-tables")}
                onClick={() => onChangeView("__slowest_tables__")}
              >
                Производительность
              </button>
              <button
                type="button"
                className={buttonClassName("/night-ops")}
                onClick={() => onChangeView("night_ops")}
              >
                Мониторинг
              </button>
              <button
                type="button"
                className={buttonClassName("/entities")}
                onClick={() => onChangeView("__entity_schedule__")}
              >
                Сущности
              </button>
              <button
                type="button"
                className={buttonClassName("/releases")}
                onClick={() => onChangeView("releases")}
              >
                Релизы
              </button>
              {authEnabled && userProfile && (
                <button
                  type="button"
                  className={buttonClassName("/account")}
                  onClick={() => onChangeView("/account")}
                >
                  Профиль
                </button>
              )}
              {authEnabled && userProfile?.role === "admin" && (
                <button
                  type="button"
                  className={buttonClassName("/admin/users")}
                  onClick={() => onChangeView("/admin/users")}
                >
                  Админка
                </button>
              )}
              {authEnabled && userProfile && (
                <button
                  type="button"
                  className={buttonClassName("/admin/dev-meta")}
                  onClick={() => onChangeView("/admin/dev-meta")}
                >
                  DEV Meta
                </button>
              )}
              {authEnabled && userProfile?.role === "admin" && (
                <button
                  type="button"
                  className={buttonClassName("/admin/meta-workspace")}
                  onClick={() => onChangeView("/admin/meta-workspace")}
                >
                  Meta Workspace
                </button>
              )}
              {authEnabled && userProfile && (
                <button
                  type="button"
                  className={buttonClassName("/admin/dev-copy")}
                  onClick={() => onChangeView("/admin/dev-copy")}
                >
                  DEV Copy
                </button>
              )}
              {authEnabled && userProfile?.role === "admin" && (
                <button
                  type="button"
                  className={buttonClassName("/admin/engineering")}
                  onClick={() => {
                    console.log("[Sidebar] open /admin/engineering");
                    navigate("/admin/engineering");
                  }}
                >
                  Эффективность
                </button>
              )}
              <button
                type="button"
                className={buttonClassName("/onboarding")}
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
            <button type="button" className={`auth-logout ${useCustomHoverLabel ? "custom-cursor-target" : ""}`.trim()} onClick={onLogout}>
              Выйти
            </button>
          </div>
        )}
      </div>
    </header>
  );
}
