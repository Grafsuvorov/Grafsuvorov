import { useEffect, useMemo, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

function formatDuration(sec) {
  if (sec == null) return "—";
  const s = Math.round(sec);
  const m = Math.floor(s / 60);
  const r = s % 60;
  if (m <= 0) return `${r}s`;
  return `${m}m ${r}s`;
}

function relTime(dtStr) {
  if (!dtStr) return "—";
  const dt = new Date(dtStr.replace(" ", "T"));
  const now = new Date();
  const diff = Math.floor((now - dt) / 1000);
  if (diff < 60) return `${diff}s назад`;
  const mins = Math.floor(diff / 60);
  if (mins < 60) return `${mins}м назад`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 48) return `${hrs}ч назад`;
  return `${Math.floor(hrs / 24)}д назад`;
}

export default function IncidentDetailsPage({ tableFqn, onBack, onOpenGraph }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!tableFqn) return;

    let cancelled = false;
    async function load() {
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
    }
    load();
    return () => (cancelled = true);
  }, [tableFqn]);

  const summary = data?.summary;
  const impact = data?.impact;
  const deps = data?.dependencies || [];
  const timeline = data?.timeline || [];

  const severityClass = useMemo(() => {
    if (summary?.severity === "CRITICAL") return "pill-critical";
    if (summary?.severity === "HIGH") return "pill-high";
    return "pill-medium";
  }, [summary?.severity]);

  return (
    <div className="incident-page">
      <div className="incident-header">
        <button className="link-back" onClick={onBack}>← Инциденты</button>

        <div className="incident-title">
          <div className="incident-name mono">{summary?.table_fqn}</div>
          <div className="incident-sub">
            Последнее падение: <b>{summary?.last_failure_time || "—"}</b>
            <span className="muted"> ({relTime(summary?.last_failure_time)})</span>
          </div>
        </div>

        <div className="incident-badges">
          <span className={`pill ${severityClass}`}>{summary?.severity}</span>
          <span className={`pill ${summary?.state === "FAILING" ? "pill-bad" : "pill-ok"}`}>
            {summary?.state}
          </span>
        </div>
      </div>

      {/* KPI */}
      <div className="incident-kpis">
        <Kpi label="24ч" value={summary?.failures_24h} />
        <Kpi label="7д" value={summary?.failures_7d} />
        <Kpi label="Подряд" value={summary?.consecutive_failures} />
        <Kpi label="Таблиц" value={impact?.blocked_tables_count} />
        <Kpi label="Отчётов" value={(impact?.reports_at_risk || []).length} />
      </div>

      {/* Timeline */}
      <section className="card">
        <h3>История событий</h3>

        {loading && <div className="muted">Загрузка…</div>}
        {error && <div className="error">{error}</div>}

        <div className="timeline">
          {timeline.map((e, i) => (
            <div key={i} className={`timeline-row ${e.state === "FAILED" ? "fail" : "ok"}`}>
              <div className="timeline-dot" />
              <div className="timeline-main">
                <div className="timeline-head">
                  <span className="state">{e.state}</span>
                  <span className="mono">{e.finish}</span>
                  <span className="muted">{formatDuration(e.duration_sec)}</span>
                </div>
                {e.message && <div className="timeline-msg">{e.message}</div>}
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Downstream */}
      {expanded && (
        <section className="card">
          <h3>Последствия</h3>
          <div className="sub muted">Клик — открыть граф</div>

          <div className="table-list">
            {deps.map(d => {
              const fqn = `${d.schema}.${d.table_name}`;
              return (
                <div
                  key={fqn}
                  className="table-row clickable"
                  onClick={() => onOpenGraph?.(fqn)}
                >
                  <span className="mono">{fqn}</span>
                  <span className="muted">{d.entity_name || "—"}</span>
                  <span>{d.avg_duration_minutes ?? "—"} мин</span>
                </div>
              );
            })}
          </div>
        </section>
      )}
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





dep
import { useEffect, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function DependencyViewer({ table, onBack }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!table) return;
    setLoading(true);
    fetch(`${API_BASE}/api/dependencies?table=${table}`)
      .then(r => r.json())
      .then(setRows)
      .finally(() => setLoading(false));
  }, [table]);

  if (!table) return null;

  return (
    <div className="dependency-page">
      <button className="link-back" onClick={onBack}>← Назад</button>

      <h2 className="mono">{table}</h2>
      <div className="sub muted">План восстановления цепочки</div>

      {loading && <div className="muted">Загрузка зависимостей…</div>}

      <div className="dep-list">
        {rows.map((r, i) => (
          <div key={i} className="dep-row">
            <div className="dep-step">{i + 1}</div>
            <div className="dep-main">
              <div className="mono">{r.schema}.{r.table_name}</div>
              <div className="muted">{r.entity_name || "—"}</div>
            </div>
            <div className="dep-meta">
              <span>{r.start_time || "—"}</span>
              <span>{r.avg_duration_minutes ?? "—"} мин</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}


/* INCIDENTS */
.incident-page { max-width: 1200px; margin: auto; }
.incident-header { display: flex; justify-content: space-between; gap: 24px; }
.incident-name { font-size: 20px; }
.incident-kpis { display: grid; grid-template-columns: repeat(5,1fr); gap: 12px; margin: 20px 0; }

.kpi { background: var(--surface); padding: 14px; border-radius: 10px; text-align: center; }
.kpi-value { font-size: 20px; font-weight: 600; }

.timeline-row { display: flex; gap: 12px; padding: 12px 0; border-bottom: 1px solid rgba(255,255,255,0.05); }
.timeline-row.fail { background: rgba(239,68,68,0.05); }
.timeline-row.ok { background: rgba(34,197,94,0.05); }

.timeline-dot { width: 10px; height: 10px; border-radius: 50%; margin-top: 6px; background: currentColor; }

.table-row { display: grid; grid-template-columns: 1fr 1fr auto; padding: 10px; border-radius: 8px; }
.table-row:hover { background: rgba(255,255,255,0.04); }

/* DEPENDENCIES */
.dep-row {
  display: grid;
  grid-template-columns: 32px 1fr auto;
  gap: 12px;
  padding: 12px;
  border-radius: 10px;
  background: var(--surface);
  margin-bottom: 8px;
}
.dep-step {
  font-weight: 600;
  color: var(--muted);
}
