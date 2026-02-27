import { useEffect, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

function relTime(dtStr) {
  if (!dtStr) return "—";
  const dt = new Date(dtStr.replace(" ", "T"));
  const diff = Math.floor((Date.now() - dt.getTime()) / 1000);
  if (diff < 60) return `${diff} сек назад`;
  if (diff < 3600) return `${Math.floor(diff / 60)} мин назад`;
  if (diff < 86400) return `${Math.floor(diff / 3600)} ч назад`;
  return `${Math.floor(diff / 86400)} д назад`;
}

export default function IncidentDetailsPage({ tableFqn, onBack, onOpenTable }) {
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
    return <div className="page-loading">Загрузка инцидента...</div>;
  }

  if (error || !data) {
    return <div className="page-error">Не удалось загрузить инцидент</div>;
  }

  const { summary, timeline = [], impact = {}, dependencies = [] } = data;

  return (
    <div className="incident-page">
      {/* HEADER */}
      <div className="incident-header">
        <div className="incident-nav" onClick={onBack}>
          ← Назад
        </div>

        <div>
          <div className="incident-title">{summary.table_fqn}</div>
          <div className="incident-meta">
            Последняя ошибка: {summary.last_failure_time || "—"} ({relTime(summary.last_failure_time)})
          </div>
        </div>

        <div className="incident-badges">
          <span className={`badge ${summary.severity?.toLowerCase()}`}>
            {summary.severity || "—"}
          </span>
          <span className={`badge ${summary.state === "FAILING" ? "danger" : "ok"}`}>
            {summary.state === "FAILING" ? "Сбой" : "OK"}
          </span>
        </div>
      </div>


      {/* IMPACT */}
      <div className="incident-impact">
        <div>
          <div className="impact-value">{impact.sla_violations || 0}</div>
          <div className="impact-label">Нарушения SLA</div>
        </div>
        <div>
          <div className="impact-value">
            {impact.blocked_tables_count || 0}
          </div>
          <div className="impact-label">Затронуто таблиц</div>
        </div>
        <div>
          <div className="impact-value">
            {impact.reports_at_risk?.length || 0}
          </div>
          <div className="impact-label">Отчётов под риском</div>
        </div>
      </div>

      {/* TIMELINE */}
      <div className="card">
        <div className="card-title">История загрузок</div>
        <div className="timeline">
          {timeline.map((t, i) => (
            <div
              key={i}
              className={`timeline-row ${
                t.state === "FAILED" ? "fail" : "ok"
              }`}
            >
              <span>{t.state}</span>
              <span>{t.finish}</span>
              <span>
                {t.duration_sec
                  ? Math.round(t.duration_sec / 60)
                  : "—"}{" "}
                мин
              </span>
              {t.message && (
                <div className="timeline-msg">{t.message}</div>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* DEPENDENCIES */}
      <div className="card">
        <div className="card-title" style={{ display: "flex", justifyContent: "space-between" }}>
          Что блокируется
          <button className="btn btn-ghost" onClick={() => setExpanded((v) => !v)}>
            {expanded ? "Скрыть" : "Показать"}
          </button>
        </div>
        {expanded && (
          <>
            <div className="card-subtitle">
              ниже по цепочке · {dependencies.length}
            </div>
            <div className="dep-list">
              {dependencies.map((d, idx) => {
                const fqn = `${d.schema}.${d.table_name}`;
                return (
                  <div
                    key={fqn}
                    className="dep-row"
                    onClick={() => onOpenTable && onOpenTable(fqn)}
                  >
                    <div className="dep-step">{idx + 1}</div>

                    <div className="dep-main">
                      <div className="dep-fqn mono">{fqn}</div>
                      <div className="dep-entity muted">
                        {d.entity_name || "—"}
                      </div>
                    </div>

                    <div className="dep-metrics">
                      {d.avg_duration_minutes ?? "—"} мин
                    </div>
                  </div>
                );
              })}
            </div>
          </>
        )}
      </div>
      )}
    </div>
  );
}
