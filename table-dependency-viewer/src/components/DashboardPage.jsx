import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function DashboardPage({ onSelectTable }) {
  const navigate = useNavigate();
  const [workloadSummary, setWorkloadSummary] = useState(null);
  const [workloadRows, setWorkloadRows] = useState([]);
  const [hotTables, setHotTables] = useState([]);
  const [releases, setReleases] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    Promise.all([
      fetch(`${API_BASE}/api/analytics/workload?days=30&group_by=executor`),
      fetch(`${API_BASE}/api/analytics/hot-tables?days=90&min_changes=3`),
      fetch(`${API_BASE}/api/releases?days=30&limit=10`),
    ])
      .then(async ([workRes, hotRes, relRes]) => {
        if (!workRes.ok || !hotRes.ok || !relRes.ok) {
          throw new Error("Не удалось загрузить дашборд");
        }
        const workJson = await workRes.json();
        const hotJson = await hotRes.json();
        const relJson = await relRes.json();
        if (!cancelled) {
          setWorkloadSummary(workJson?.summary || null);
          setWorkloadRows(Array.isArray(workJson?.items) ? workJson.items : []);
          setHotTables(Array.isArray(hotJson?.items) ? hotJson.items : []);
          setReleases(Array.isArray(relJson?.items) ? relJson.items : []);
        }
      })
      .catch((err) => {
        if (!cancelled) setError(err.message || "Не удалось загрузить дашборд");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, []);

  const formatHours = (minutes) => `${(Number(minutes || 0) / 60).toFixed(1)} ч`;

  const kpi = useMemo(() => {
    return {
      tasks: workloadSummary?.tasks_count ?? 0,
      tables: workloadSummary?.tables_count ?? 0,
      engineers: workloadSummary?.executors_count ?? 0,
      hours: workloadSummary?.minutes ? Math.round(workloadSummary.minutes / 60) : 0,
    };
  }, [workloadSummary]);

  return (
    <div className="page dashboard-page">
      <div className="page-header">
        <div>
          <h1>Dashboard</h1>
          <div className="muted">Ключевые метрики и горячие изменения.</div>
        </div>
      </div>

      {loading && <div className="muted">Загрузка...</div>}
      {error && <div className="dep-error-title">{error}</div>}

      {!loading && !error && (
        <>
          <section className="dashboard-kpi">
            <div className="kpi-card">
              <div className="kpi-label">Tasks last 30 days</div>
              <div className="kpi-value">{kpi.tasks}</div>
            </div>
            <div className="kpi-card">
              <div className="kpi-label">Tables changed</div>
              <div className="kpi-value">{kpi.tables}</div>
            </div>
            <div className="kpi-card">
              <div className="kpi-label">Engineers active</div>
              <div className="kpi-value">{kpi.engineers}</div>
            </div>
            <div className="kpi-card">
              <div className="kpi-label">Hours spent</div>
              <div className="kpi-value">{kpi.hours}</div>
            </div>
          </section>

          <section className="dashboard-grid">
            <div className="card dashboard-panel">
              <div className="section-title">Hot tables</div>
              <div className="dashboard-table">
                <div className="dashboard-head">
                  <span>Table</span>
                  <span>Changes</span>
                  <span>Hours</span>
                </div>
                {hotTables.slice(0, 10).map((row, idx) => (
                  <button
                    key={`${row.schema_name}.${row.table_name}-${idx}`}
                    className="dashboard-row"
                    onClick={() =>
                      onSelectTable?.({
                        view: "table_info",
                        table: `${row.schema_name}.${row.table_name}`,
                      })
                    }
                  >
                    <span className="mono">
                      {row.schema_name}.{row.table_name}
                    </span>
                    <span>{row.changes ?? 0}</span>
                    <span>{formatHours(row.minutes)}</span>
                  </button>
                ))}
                {hotTables.length === 0 && <div className="muted">Данных нет.</div>}
              </div>
            </div>

            <div className="card dashboard-panel">
              <div className="section-title">Team workload</div>
              <div className="dashboard-table">
                <div className="dashboard-head">
                  <span>Engineer</span>
                  <span>Tasks</span>
                  <span>Tables</span>
                  <span>Hours</span>
                </div>
                {workloadRows.slice(0, 10).map((row, idx) => (
                  <div key={`wl-${idx}`} className="dashboard-row static">
                    <span>{row.executor || "—"}</span>
                    <span>{row.tasks_count || 0}</span>
                    <span>{row.tables_count || 0}</span>
                    <span>{formatHours(row.minutes)}</span>
                  </div>
                ))}
                {workloadRows.length === 0 && <div className="muted">Данных нет.</div>}
              </div>
            </div>
          </section>

          <section className="card dashboard-panel">
            <div className="section-title">Last releases</div>
            <div className="dashboard-table">
              <div className="dashboard-head releases">
                <span>Release</span>
                <span>Objects</span>
                <span>Tasks</span>
                <span>Hours</span>
                <span>Status</span>
              </div>
              {releases.map((row) => (
                <button
                  key={row.release_id}
                  className="dashboard-row releases"
                  onClick={() => navigate("/releases", { state: { releaseId: row.release_id } })}
                >
                  <span className="mono">{row.release_id}</span>
                  <span>{row.objects_count ?? 0}</span>
                  <span>{Array.isArray(row.task_ids) ? row.task_ids.length : 0}</span>
                  <span>{row.hours_total ? `${row.hours_total.toFixed(1)} ч` : "0.0 ч"}</span>
                  <span className={`status-pill ${row.failed_count ? "status-failed" : "status-success"}`}>
                    {row.status || "—"}
                  </span>
                </button>
              ))}
              {releases.length === 0 && <div className="muted">Релизы не найдены.</div>}
            </div>
          </section>
        </>
      )}
    </div>
  );
}
