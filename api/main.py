import { useEffect, useMemo, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

function relTime(dtStr) {
  if (!dtStr) return "—";
  const dt = new Date(dtStr.replace(" ", "T"));
  const diff = Math.floor((Date.now() - dt) / 1000);
  if (diff < 60) return `${diff}s назад`;
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

  if (loading) return <div className="incident-loading">Загрузка инцидента…</div>;
  if (!data) return null;

  const { summary, impact, timeline, dependencies } = data;

  return (
    <div className="incident-page">
      {/* Header */}
      <div className="incident-header">
        <button className="btn-back" onClick={onBack}>← К списку инцидентов</button>
        <div>
          <div className="incident-title">Инцидент</div>
          <div className="incident-table mono">{summary.table_fqn}</div>
        </div>
        <div className={`incident-severity sev-${summary.severity.toLowerCase()}`}>
          {summary.severity}
        </div>
      </div>

      {/* Hero */}
      <div className="incident-hero">
        <div>
          <div className="hero-label">Последнее падение</div>
          <div className="hero-value danger">
            {summary.last_failure_time} <span>{relTime(summary.last_failure_time)}</span>
          </div>
        </div>

        <div>
          <div className="hero-label">Последний успех</div>
          <div className="hero-value">
            {summary.last_success_time || "—"}
          </div>
        </div>

        <div>
          <div className="hero-label">Подряд</div>
          <div className="hero-value">{summary.consecutive_failures}</div>
        </div>
      </div>

      {/* Impact */}
      <div className="incident-impact">
        <div className="impact-card">
          <div className="impact-title">SLA</div>
          <div className={`impact-value ${impact.sla_violations > 0 ? "danger" : ""}`}>
            {impact.sla_violations}
          </div>
        </div>

        <div className="impact-card">
          <div className="impact-title">Отчёты под риском</div>
          <div className="impact-list">
            {impact.reports_at_risk.length
              ? impact.reports_at_risk.map(r => <span key={r}>{r}</span>)
              : <span className="muted">Нет</span>}
          </div>
        </div>

        <div className="impact-card">
          <div className="impact-title">Сущности</div>
          <div className="impact-list">
            {impact.affected_entities.map(e => <span key={e}>{e}</span>)}
          </div>
        </div>
      </div>

      {/* Timeline */}
      <div className="incident-section">
        <div className="section-title">История падений</div>
        <div className="timeline">
          {timeline.map((t, i) => (
            <div key={i} className={`timeline-row ${t.state === "FAILED" ? "fail" : ""}`}>
              <div className="mono">{t.finish}</div>
              <div>{t.state}</div>
              <div className="muted">{t.message}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Dependencies */}
      <div className="incident-section">
        <div className="section-title">Затронутые таблицы</div>
        <div className="dep-grid">
          {dependencies.map(d => (
            <div
              key={`${d.schema}.${d.table_name}`}
              className="dep-card"
              onClick={() => onOpenGraph(`${d.schema}.${d.table_name}`)}
            >
              <div className="mono">{d.schema}.{d.table_name}</div>
              <div className="muted">{d.entity_name || "—"}</div>
              <div className="dep-meta">⏱ {d.avg_duration_minutes ?? "—"} мин</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}



import { useEffect, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function DependencyViewer({ table, onBack }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!table) return;
    fetch(`${API_BASE}/api/dependencies?table=${table}`)
      .then(r => r.json())
      .then(setRows)
      .finally(() => setLoading(false));
  }, [table]);

  if (!table) return null;

  return (
    <div className="dep-page">
      <button className="btn-back" onClick={onBack}>← Назад</button>

      <div className="dep-title mono">{table}</div>

      {loading && <div className="muted">Загрузка зависимостей…</div>}

      <div className="dep-grid">
        {rows.map((r, i) => (
          <div key={i} className="dep-card">
            <div className="dep-step">Шаг {r.step}</div>
            <div className="mono">{r.schema}.{r.table_name}</div>
            <div className="muted">{r.entity_name}</div>
            <div className="dep-meta">
              ⏱ {r.avg_duration_minutes ?? "—"} мин
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}


/* Buttons */
.btn-back {
  background: none;
  border: none;
  color: #9ca3af;
  cursor: pointer;
  padding: 0;
  font-size: 13px;
}
.btn-back:hover { color: #fff; }

/* Incident */
.incident-page { padding: 24px; }
.incident-header {
  display: flex; justify-content: space-between; align-items: center;
}
.incident-title { font-size: 18px; font-weight: 600; }
.incident-table { color: #9ca3af; }

.incident-severity {
  padding: 6px 12px;
  border-radius: 999px;
  font-size: 12px;
}
.sev-critical { background: rgba(239,68,68,.15); color:#ef4444; }
.sev-high { background: rgba(245,158,11,.15); color:#f59e0b; }

.incident-hero {
  display:grid;
  grid-template-columns: repeat(3,1fr);
  gap:16px;
  margin:20px 0;
}
.hero-label { font-size:12px; color:#9ca3af; }
.hero-value { font-size:16px; }
.hero-value.danger { color:#ef4444; }

.incident-impact {
  display:grid;
  grid-template-columns: repeat(3,1fr);
  gap:16px;
}
.impact-card {
  background: rgba(255,255,255,.03);
  padding:14px;
  border-radius:12px;
}
.impact-title { font-size:12px; color:#9ca3af; }
.impact-value { font-size:20px; }
.impact-value.danger { color:#ef4444; }

.incident-section { margin-top:28px; }
.section-title { margin-bottom:12px; font-weight:600; }

.timeline-row {
  padding:10px;
  border-radius:8px;
  background: rgba(255,255,255,.02);
  margin-bottom:6px;
}
.timeline-row.fail { border-left:3px solid #ef4444; }

/* Dependencies */
.dep-grid {
  display:grid;
  grid-template-columns: repeat(auto-fill,minmax(260px,1fr));
  gap:12px;
}
.dep-card {
  padding:14px;
  background: rgba(255,255,255,.03);
  border-radius:12px;
  cursor:pointer;
}
.dep-card:hover { background: rgba(255,255,255,.06); }
.dep-meta { font-size:12px; color:#9ca3af; }
