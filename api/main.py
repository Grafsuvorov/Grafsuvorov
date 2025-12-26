import { useEffect, useMemo, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

function formatDuration(sec) {
  if (sec == null) return "—";
  const m = Math.floor(sec / 60);
  const s = Math.round(sec % 60);
  return m > 0 ? `${m}м ${s}с` : `${s}с`;
}

function relTime(dtStr) {
  if (!dtStr) return "—";
  const dt = new Date(dtStr.replace(" ", "T"));
  const diff = Math.floor((Date.now() - dt) / 1000);
  if (diff < 60) return `${diff}с назад`;
  if (diff < 3600) return `${Math.floor(diff / 60)}м назад`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}ч назад`;
  return `${Math.floor(diff / 86400)}д назад`;
}

export default function IncidentDetailsPage({ tableFqn, onBack, onOpenGraph }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!tableFqn) return;
    fetch(`${API_BASE}/api/incident?table_fqn=${encodeURIComponent(tableFqn)}`)
      .then(r => r.json())
      .then(setData)
      .finally(() => setLoading(false));
  }, [tableFqn]);

  if (loading) return <div className="page-loading">Загрузка инцидента…</div>;
  if (!data) return null;

  const { summary, timeline = [], dependencies = [], impact = {} } = data;

  return (
    <div className="incident-page">
      <div className="incident-header">
        <button className="btn-back" onClick={onBack}>← Инциденты</button>

        <div>
          <div className="incident-title">{summary.table_fqn}</div>
          <div className="incident-sub">
            {summary.severity} · {summary.state}
          </div>
        </div>
      </div>

      <div className="incident-kpis">
        <Kpi label="24ч" value={summary.failures_24h} />
        <Kpi label="7д" value={summary.failures_7d} />
        <Kpi label="Подряд" value={summary.consecutive_failures} />
        <Kpi label="Таблиц" value={impact.blocked_tables_count} />
        <Kpi label="Отчётов" value={(impact.reports_at_risk || []).length} />
      </div>

      <div className="incident-grid">
        <section className="card">
          <h3>История падений</h3>
          {timeline.map((e, i) => (
            <div key={i} className={`event ${e.state === "FAILED" ? "fail" : "ok"}`}>
              <span>{e.state}</span>
              <span>{e.finish}</span>
              <span>{formatDuration(e.duration_sec)}</span>
            </div>
          ))}
        </section>

        <section className="card">
          <h3>SLA и отчёты</h3>
          <div className="metric-row">
            <span>SLA нарушений</span>
            <b>{impact.sla_violations}</b>
          </div>

          <ul className="list">
            {(impact.reports_at_risk || []).map(r => (
              <li key={r}>{r}</li>
            ))}
            {(!impact.reports_at_risk || impact.reports_at_risk.length === 0) && (
              <li className="muted">Нарушений нет</li>
            )}
          </ul>
        </section>
      </div>

      <section className="card">
        <h3>Затронутые таблицы</h3>
        <table className="clean-table">
          <thead>
            <tr>
              <th>Таблица</th>
              <th>Сущность</th>
              <th>Среднее, мин</th>
            </tr>
          </thead>
          <tbody>
            {dependencies.map(d => (
              <tr key={`${d.schema}.${d.table_name}`} onClick={() => onOpenGraph(`${d.schema}.${d.table_name}`)}>
                <td className="mono">{d.schema}.{d.table_name}</td>
                <td>{d.entity_name || "—"}</td>
                <td>{d.avg_duration_minutes ?? "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}

function Kpi({ label, value }) {
  return (
    <div className="kpi">
      <div className="kpi-value">{value ?? "—"}</div>
      <div className="kpi-label">{label}</div>
    </div>
  );
}



import { useEffect, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function DependencyViewer({ table, onBack }) {
  const [rows, setRows] = useState([]);

  useEffect(() => {
    if (!table) return;
    fetch(`${API_BASE}/api/dependencies?table=${table}`)
      .then(r => r.json())
      .then(setRows);
  }, [table]);

  if (!table) return null;

  return (
    <div className="dependency-page">
      <button className="btn-back" onClick={onBack}>← Назад</button>

      <h2>Зависимости</h2>
      <div className="mono muted">{table}</div>

      <section className="card">
        <h3>Порядок перезапуска</h3>
        <table className="clean-table">
          <thead>
            <tr>
              <th>#</th>
              <th>Таблица</th>
              <th>Сущность</th>
              <th>Среднее, мин</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r, i) => (
              <tr key={i}>
                <td>{i + 1}</td>
                <td className="mono">{r.schema}.{r.table_name}</td>
                <td>{r.entity_name}</td>
                <td>{r.avg_duration_minutes ?? "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}


/* ===== Buttons ===== */
.btn-back {
  background: none;
  border: none;
  color: #9ca3af;
  font-size: 13px;
  cursor: pointer;
  padding: 0;
}
.btn-back:hover {
  color: #e5e7eb;
}

/* ===== Incident ===== */
.incident-page {
  max-width: 1200px;
  margin: auto;
}

.incident-header {
  display: flex;
  gap: 16px;
  align-items: center;
  margin-bottom: 16px;
}

.incident-title {
  font-size: 22px;
  font-weight: 600;
}

.incident-sub {
  color: #9ca3af;
  font-size: 13px;
}

.incident-kpis {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 12px;
  margin-bottom: 20px;
}

.kpi {
  background: rgba(255,255,255,0.04);
  padding: 12px;
  border-radius: 8px;
  text-align: center;
}

.kpi-value {
  font-size: 20px;
  font-weight: 600;
}

.kpi-label {
  font-size: 11px;
  color: #9ca3af;
}

/* ===== Cards ===== */
.card {
  background: rgba(255,255,255,0.035);
  border-radius: 10px;
  padding: 16px;
  margin-bottom: 16px;
}

.incident-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 16px;
}

/* ===== Tables ===== */
.clean-table {
  width: 100%;
  border-collapse: collapse;
}

.clean-table th {
  text-align: left;
  font-size: 12px;
  color: #9ca3af;
  padding-bottom: 6px;
}

.clean-table td {
  padding: 6px 0;
  border-top: 1px solid rgba(255,255,255,0.05);
}

.clean-table tr:hover {
  background: rgba(255,255,255,0.03);
  cursor: pointer;
}

/* ===== Timeline ===== */
.event {
  display: grid;
  grid-template-columns: 80px 1fr 80px;
  padding: 6px 0;
  font-size: 13px;
}
.event.fail { color: #f87171; }
.event.ok { color: #6ee7b7; }
