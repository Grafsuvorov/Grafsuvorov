import { useEffect, useMemo, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

function relTime(dtStr) {
  if (!dtStr) return "—";
  const dt = new Date(dtStr.replace(" ", "T"));
  const diff = Math.floor((Date.now() - dt.getTime()) / 1000);
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
  if (!data) return <div className="page-error">Инцидент не найден</div>;

  const { summary, impact, dependencies, timeline } = data;

  return (
    <div className="incident-page">

      {/* HEADER */}
      <div className="incident-header">
        <button className="btn-link" onClick={onBack}>← Все инциденты</button>

        <div className="incident-title">
          <h1>{summary.table_fqn}</h1>
          <div className="incident-badges">
            <span className={`badge sev-${summary.severity.toLowerCase()}`}>
              {summary.severity}
            </span>
            <span className={`badge state-${summary.state.toLowerCase()}`}>
              {summary.state}
            </span>
          </div>
        </div>
      </div>

      {/* META */}
      <div className="incident-meta">
        <div>Последнее падение: <b>{summary.last_failure_time || "—"}</b> ({relTime(summary.last_failure_time)})</div>
        <div>Последний успех: <b>{summary.last_success_time || "—"}</b></div>
      </div>

      {/* KPI */}
      <div className="incident-kpis">
        <div className="kpi"><b>{summary.failures_24h}</b><span>за 24ч</span></div>
        <div className="kpi"><b>{summary.failures_7d}</b><span>за 7д</span></div>
        <div className="kpi"><b>{summary.consecutive_failures}</b><span>подряд</span></div>
        <div className="kpi"><b>{impact.blocked_tables_count}</b><span>таблиц под риском</span></div>
      </div>

      {/* MAIN GRID */}
      <div className="incident-grid">

        {/* TIMELINE */}
        <div className="card">
          <h3>История загрузок</h3>
          <div className="timeline">
            {timeline.map((e, i) => (
              <div key={i} className={`event ${e.state === "FAILED" ? "fail" : "ok"}`}>
                <div className="event-time">{e.finish}</div>
                <div className="event-state">{e.state}</div>
                {e.message && <div className="event-msg">{e.message}</div>}
              </div>
            ))}
          </div>
        </div>

        {/* SLA */}
        <div className="card">
          <h3>Влияние на отчёты (SLA)</h3>

          {impact.reports_at_risk.length === 0 ? (
            <div className="muted">SLA не нарушены</div>
          ) : (
            <ul className="risk-list">
              {impact.reports_at_risk.map(r => (
                <li key={r} className="risk-item">{r}</li>
              ))}
            </ul>
          )}

          <div className="divider" />

          <h4>Затронутые сущности</h4>
          <div className="chips">
            {impact.affected_entities.map(e => (
              <span key={e} className="chip">{e}</span>
            ))}
          </div>
        </div>
      </div>

      {/* DEPENDENCIES */}
      <div className="card wide">
        <h3>Downstream зависимости</h3>
        <div className="dep-list">
          {dependencies.map(d => (
            <div
              key={`${d.schema}.${d.table_name}`}
              className="dep-item"
              onClick={() => onOpenGraph(`${d.schema}.${d.table_name}`)}
            >
              <div className="dep-name">{d.schema}.{d.table_name}</div>
              <div className="dep-entity">{d.entity_name || "—"}</div>
              <div className="dep-time">{d.avg_duration_minutes ?? "—"} мин</div>
            </div>
          ))}
        </div>
      </div>

    </div>
  );
}


import { useEffect, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL;

export default function DependencyViewer({ table, onBack }) {
  const [data, setData] = useState([]);

  useEffect(() => {
    if (!table) return;
    fetch(`${API_BASE}/api/dependencies?table=${table}`)
      .then(r => r.json())
      .then(setData);
  }, [table]);

  if (!table) return null;

  const entities = {};
  data.forEach(d => {
    if (!entities[d.entity_name]) entities[d.entity_name] = [];
    entities[d.entity_name].push(d);
  });

  return (
    <div className="dependency-page">

      <button className="btn-link" onClick={onBack}>← Назад</button>
      <h1>Что нужно перезапустить</h1>
      <div className="muted">Источник: {table}</div>

      {Object.entries(entities).map(([entity, items]) => (
        <div key={entity} className="card">
          <h3>{entity}</h3>

          <div className="dep-list">
            {items.map(t => (
              <div key={`${t.schema}.${t.table_name}`} className="dep-item">
                <div className="dep-name">{t.schema}.{t.table_name}</div>
                <div className="dep-time">
                  ~{t.avg_duration_minutes ?? "—"} мин
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}


/* buttons */
.btn-link {
  background: none;
  border: none;
  color: #9ca3af;
  cursor: pointer;
  padding: 0;
  font-size: 14px;
}
.btn-link:hover {
  color: #e5e7eb;
}

/* cards */
.card {
  background: rgba(255,255,255,0.03);
  border-radius: 12px;
  padding: 16px;
}
.card.wide { margin-top: 24px; }

/* badges */
.badge {
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 12px;
}
.sev-critical { background:#7f1d1d; }
.sev-high { background:#78350f; }
.sev-medium { background:#1e293b; }

/* dependency */
.dep-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.dep-item {
  display: grid;
  grid-template-columns: 1fr auto auto;
  gap: 12px;
  padding: 10px;
  border-radius: 8px;
  cursor: pointer;
}
.dep-item:hover {
  background: rgba(255,255,255,0.05);
}

/* timeline */
.event {
  padding: 10px;
  border-left: 3px solid transparent;
}
.event.fail { border-color: #ef4444; }
.event.ok { border-color: #22c55e; }
