import "../style/app.css";

export default function Sidebar({ currentPath, onChangeView }) {
  const isActive = (path) => currentPath === path;
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
                className={isActive("/logic-audit") ? "active" : ""}
                onClick={() => onChangeView("logic_audit")}
              >
                Аудит логики
              </button>
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
      </div>
    </header>
  );
}
