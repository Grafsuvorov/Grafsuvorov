import { useEffect, useMemo, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function AdminEngineeringPage() {
  const [days, setDays] = useState(90);
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    fetch(`${API_BASE}/api/admin/engineering-efficiency?days=${days}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить страницу эффективности")))
      .then((json) => {
        if (!cancelled) setData(json);
      })
      .catch((err) => {
        if (!cancelled) {
          setData(null);
          setError(typeof err === "string" ? err : "Не удалось загрузить страницу эффективности");
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [days]);

  const summary = data?.summary || {};
  const byExecutor = Array.isArray(data?.by_executor) ? data.by_executor : [];
  const byCreator = Array.isArray(data?.by_creator) ? data.by_creator : [];
  const byDirection = Array.isArray(data?.by_direction) ? data.by_direction : [];
  const topTables = Array.isArray(data?.top_tables) ? data.top_tables : [];

  const kpi = useMemo(
    () => ({
      releases: summary.releases ?? 0,
      tasks: summary.tasks ?? 0,
      objects: summary.objects ?? 0,
      executors: summary.executors ?? 0,
      hours: summary.minutes ? (Number(summary.minutes) / 60).toFixed(1) : "0.0",
    }),
    [summary]
  );

  const formatHours = (minutes) => `${(Number(minutes || 0) / 60).toFixed(1)} ч`;

  return (
    <div className="page dashboard-page">
      <div className="page-header">
        <div>
          <h1>Эффективность команды</h1>
          <div className="muted">Релизы, задачи и изменения по инженерам и направлениям.</div>
        </div>
        <div>
          <select className="impact-control-select" value={days} onChange={(e) => setDays(Number(e.target.value))}>
            {[30, 90, 180].map((value) => (
              <option key={value} value={value}>
                {value} дней
              </option>
            ))}
          </select>
        </div>
      </div>

      {loading && <div className="muted">Загрузка...</div>}
      {error && <div className="dep-error-title">{error}</div>}

      {!loading && !error && (
        <>
          <section className="dashboard-kpi">
            <div className="kpi-card">
              <div className="kpi-label">Релизы</div>
              <div className="kpi-value">{kpi.releases}</div>
            </div>
            <div className="kpi-card">
              <div className="kpi-label">Задачи</div>
              <div className="kpi-value">{kpi.tasks}</div>
            </div>
            <div className="kpi-card">
              <div className="kpi-label">Объекты</div>
              <div className="kpi-value">{kpi.objects}</div>
            </div>
            <div className="kpi-card">
              <div className="kpi-label">Инженеры</div>
              <div className="kpi-value">{kpi.executors}</div>
            </div>
            <div className="kpi-card">
              <div className="kpi-label">Часы</div>
              <div className="kpi-value">{kpi.hours}</div>
            </div>
          </section>

          <section className="dashboard-grid">
            <div className="card dashboard-panel">
              <div className="section-title">По инженерам</div>
              <div className="dashboard-table">
                <div className="dashboard-head">
                  <span>Инженер</span>
                  <span>Задачи</span>
                  <span>Таблицы</span>
                  <span>Часы</span>
                </div>
                {byExecutor.slice(0, 15).map((row, idx) => (
                  <div key={`exec-${idx}`} className="dashboard-row static">
                    <span>{row.executor || "—"}</span>
                    <span>{row.tasks_count || 0}</span>
                    <span>{row.tables_count || 0}</span>
                    <span>{formatHours(row.minutes)}</span>
                  </div>
                ))}
                {byExecutor.length === 0 && <div className="muted">Данных нет.</div>}
              </div>
            </div>

            <div className="card dashboard-panel">
              <div className="section-title">По постановщикам</div>
              <div className="dashboard-table">
                <div className="dashboard-head">
                  <span>Постановщик</span>
                  <span>Задачи</span>
                  <span>Таблицы</span>
                  <span>Часы</span>
                </div>
                {byCreator.slice(0, 15).map((row, idx) => (
                  <div key={`creator-${idx}`} className="dashboard-row static">
                    <span>{row.creator || "—"}</span>
                    <span>{row.tasks_count || 0}</span>
                    <span>{row.tables_count || 0}</span>
                    <span>{formatHours(row.minutes)}</span>
                  </div>
                ))}
                {byCreator.length === 0 && <div className="muted">Данных нет.</div>}
              </div>
            </div>
          </section>

          <section className="dashboard-grid">
            <div className="card dashboard-panel">
              <div className="section-title">По направлениям</div>
              <div className="dashboard-table">
                <div className="dashboard-head">
                  <span>Направление</span>
                  <span>Задачи</span>
                  <span>Таблицы</span>
                  <span>Часы</span>
                </div>
                {byDirection.slice(0, 15).map((row, idx) => (
                  <div key={`dir-${idx}`} className="dashboard-row static">
                    <span>{row.direction || "—"}</span>
                    <span>{row.tasks_count || 0}</span>
                    <span>{row.tables_count || 0}</span>
                    <span>{formatHours(row.minutes)}</span>
                  </div>
                ))}
                {byDirection.length === 0 && <div className="muted">Данных нет.</div>}
              </div>
            </div>

            <div className="card dashboard-panel">
              <div className="section-title">Топ изменяемых таблиц</div>
              <div className="dashboard-table">
                <div className="dashboard-head">
                  <span>Таблица</span>
                  <span>Изменения</span>
                  <span>Часы</span>
                </div>
                {topTables.slice(0, 15).map((row, idx) => (
                  <div key={`table-${idx}`} className="dashboard-row static">
                    <span className="mono">{row.schema_name}.{row.table_name}</span>
                    <span>{row.changes || 0}</span>
                    <span>{formatHours(row.minutes)}</span>
                  </div>
                ))}
                {topTables.length === 0 && <div className="muted">Данных нет.</div>}
              </div>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
