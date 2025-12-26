import { useEffect, useMemo, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

function relTime(dtStr) {
  if (!dtStr) return "—";
  const dt = new Date(dtStr.replace(" ", "T"));
  const diff = Math.floor((Date.now() - dt.getTime()) / 1000);
  if (diff < 60) return `${diff}s назад`;
  if (diff < 3600) return `${Math.floor(diff / 60)}м назад`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}ч назад`;
  return `${Math.floor(diff / 86400)}д назад`;
}

export default function IncidentDetailsPage({ tableFqn, onBack, onOpenGraph }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!tableFqn) return;

    let cancelled = false;
    (async () => {
      try {
        setLoading(true);
        const res = await fetch(
          `${API_BASE}/api/incident?table_fqn=${encodeURIComponent(tableFqn)}`
        );
        const json = await res.json();
        if (!cancelled) setData(json);
      } catch (e) {
        if (!cancelled) setError(String(e));
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => (cancelled = true);
  }, [tableFqn]);

  if (loading) {
    return <div className="page-loading">Загрузка инцидента…</div>;
  }

  if (error || !data) {
    return <div className="page-error">Ошибка загрузки инцидента</div>;
  }

  const { summary, timeline = [], impact = {}, dependencies = [] } = data;

  return (
    <div className="incident-page">
      {/* HEADER */}
      <div className="incident-header">
        <button className="btn" onClick={onBack}>← Назад</button>

        <div>
          <div className="incident-title">{summary.table_fqn}</div>
          <div className="incident-meta">
            Последнее падение: {summary.last_failure_time || "—"} ({relTime(summary.last_failure_time)})
          </div>
        </div>

        <div className="incident-badges">
          <span className={`badge ${summary.severity?.toLowerCase()}`}>
            {summary.severity}
          </span>
          <span className={`badge ${summary.state === "FAILING" ? "danger" : "ok"}`}>
            {summary.state}
          </span>
        </div>
      </div>

      {/* IMPACT */}
      <div className="incident-impact">
        <div>
          <div className="impact-value">{impact.sla_violations || 0}</div>
          <div className="impact-label">SLA нарушений</div>
        </div>
        <div>
          <div className="impact-value">{impact.blocked_tables_count || 0}</div>
          <div className="impact-label">Затронуто таблиц</div>
        </div>
        <div>
          <div className="impact-value">{impact.reports_at_risk?.length || 0}</div>
          <div className="impact-label">Отчётов под риском</div>
        </div>
      </div>

      {/* TIMELINE */}
      <div className="card">
        <div className="card-title">История загрузок</div>
        <div className="timeline">
          {timeline.map((t, i) => (
            <div key={i} className={`timeline-row ${t.state === "FAILED" ? "fail" : "ok"}`}>
              <span>{t.state}</span>
              <span>{t.finish}</span>
              <span>{Math.round(t.duration_sec / 60)} мин</span>
              {t.message && <div className="timeline-msg">{t.message}</div>}
            </div>
          ))}
        </div>
      </div>

      {/* DEPENDENCIES */}
      {expanded && (
        <div className="card">
          <div className="card-title">Что блокируется</div>
          <div className="dep-grid">
            {dependencies.map(d => {
              const fqn = `${d.schema}.${d.table_name}`;
              return (
                <div
                  key={fqn}
                  className="dep-card"
                  onClick={() => onOpenGraph(fqn)}
                >
                  <div className="mono">{fqn}</div>
                  <div className="muted">{d.entity_name || "—"}</div>
                  <div className="muted">{d.avg_duration_minutes ?? "—"} мин</div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

.btn {
  background: rgba(255,255,255,0.04);
  border: 1px solid rgba(255,255,255,0.08);
  color: var(--text);
  padding: 6px 12px;
  border-radius: 8px;
  font-size: 13px;
  cursor: pointer;
}

.btn:hover {
  background: rgba(255,255,255,0.08);
}

.btn-danger {
  border-color: rgba(239,68,68,0.4);
  color: #fecaca;
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

  return (
    <div className="incident-page">
      <button className="btn" onClick={onBack}>← Назад</button>

      <h2>Зависимости для {table}</h2>

      <div className="dep-grid">
        {rows.map(r => (
          <div key={`${r.schema}.${r.table_name}`} className="dep-card">
            <div className="mono">{r.schema}.{r.table_name}</div>
            <div className="muted">{r.entity_name || "—"}</div>
            <div className="muted">⏱ {r.avg_duration_minutes ?? "—"} мин</div>
          </div>
        ))}
      </div>
    </div>
  );
}


.incident-page {
  padding: 24px;
}

.incident-header {
  display: flex;
  gap: 16px;
  align-items: center;
}

.incident-title {
  font-size: 20px;
  font-weight: 600;
}

.incident-badges {
  margin-left: auto;
  display: flex;
  gap: 8px;
}

.badge {
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 12px;
  background: rgba(255,255,255,0.08);
}

.badge.danger { background: rgba(239,68,68,0.25); }
.badge.ok { background: rgba(34,197,94,0.25); }

.card {
  margin-top: 16px;
  background: var(--card);
  padding: 16px;
  border-radius: 12px;
}

.dep-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 12px;
}

.dep-card {
  background: var(--card-soft);
  padding: 12px;
  border-radius: 10px;
  cursor: pointer;
}

.dep-card:hover {
  background: rgba(255,255,255,0.08);
}
