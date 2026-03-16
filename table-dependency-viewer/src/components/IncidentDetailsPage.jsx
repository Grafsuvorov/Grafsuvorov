import { useEffect, useMemo, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

function relTime(dtStr) {
  if (!dtStr) return "—";
  const dt = new Date(String(dtStr).replace(" ", "T"));
  if (Number.isNaN(dt.getTime())) return dtStr;
  const diff = Math.floor((Date.now() - dt.getTime()) / 1000);
  if (diff < 60) return `${diff} сек назад`;
  if (diff < 3600) return `${Math.floor(diff / 60)} мин назад`;
  if (diff < 86400) return `${Math.floor(diff / 3600)} ч назад`;
  return `${Math.floor(diff / 86400)} д назад`;
}

function fmtDateTime(value) {
  if (!value) return "—";
  const dt = new Date(String(value).replace(" ", "T"));
  return Number.isNaN(dt.getTime()) ? value : dt.toLocaleString("ru-RU");
}

export default function IncidentDetailsPage({ tableFqn, onBack, onOpenTable }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [expandedError, setExpandedError] = useState({});
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!tableFqn) return;

    let cancelled = false;

    (async () => {
      try {
        setLoading(true);
        setError(null);
        const res = await fetch(
          `${API_BASE}/api/incident?table_fqn=${encodeURIComponent(tableFqn)}`,
        );
        if (!res.ok) {
          throw new Error(`HTTP ${res.status}`);
        }
        const json = await res.json();
        if (!cancelled) setData(json);
      } catch (e) {
        if (!cancelled) setError(String(e));
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [tableFqn]);

  const summary = data?.summary || {};
  const timeline = Array.isArray(data?.timeline) ? data.timeline : [];
  const dependencies = Array.isArray(data?.dependencies) ? data.dependencies : [];
  const impact = data?.impact || {};

  const latestFailure = useMemo(
    () => timeline.find((row) => String(row.state || "").toUpperCase() === "FAILED") || timeline[0] || null,
    [timeline],
  );

  if (loading) {
    return <div className="page-loading">Загрузка инцидента...</div>;
  }

  if (error || !data) {
    return <div className="page-error">Не удалось загрузить инцидент</div>;
  }

  return (
    <div className="container cc-page incident-page">
      <section className="cc-header-zone incident-hero">
        <button className="btn btn-ghost" onClick={onBack}>
          ← Назад
        </button>
        <div className="incident-hero-main">
          <div className="incident-title">{summary.table_fqn}</div>
          <div className="incident-meta">
            Последняя ошибка: {fmtDateTime(latestFailure?.finish || latestFailure?.start)} ({relTime(latestFailure?.finish || latestFailure?.start)})
          </div>
        </div>
        <div className="incident-badges">
          <span className={`badge ${summary.state === "FAILING" ? "danger" : "ok"}`}>
            {summary.state === "FAILING" ? "Сбой" : "Восстановлено"}
          </span>
          <span className="badge warning">Цепочка: {dependencies.length}</span>
        </div>
      </section>

      <section className="cc-surface">
        <div className="section-title">Сводка инцидента</div>
        <div className="incident-impact">
          <div>
            <div className="impact-value">{impact.blocked_tables_count || 0}</div>
            <div className="impact-label">Затронуто таблиц</div>
          </div>
          <div>
            <div className="impact-value">{impact.affected_entities?.length || 0}</div>
            <div className="impact-label">Затронуто сущностей</div>
          </div>
          <div>
            <div className="impact-value">{timeline.length}</div>
            <div className="impact-label">Запусков в истории</div>
          </div>
        </div>
      </section>

      <section className="cc-surface">
        <div className="section-title">История загрузок</div>
        <div className="incident-timeline">
          {timeline.map((row, idx) => (
            <div key={`${row.finish || row.start || idx}`} className="incident-run-card">
              <div className="incident-run-head">
                <span className={`history-state history-${String(row.state || "unknown").toLowerCase()}`}>
                  {row.state || "UNKNOWN"}
                </span>
                <span className="muted">
                  {fmtDateTime(row.start)} → {fmtDateTime(row.finish)}
                </span>
                <span className="incident-run-duration">
                  {row.duration_sec ? `${Math.round(row.duration_sec / 60)} мин` : "—"}
                </span>
              </div>
              {row.message ? (
                <div className="history-error-block">
                  <button
                    className="history-error-toggle"
                    onClick={() =>
                      setExpandedError((prev) => ({ ...prev, [idx]: !prev[idx] }))
                    }
                  >
                    {expandedError[idx] ? "Скрыть ошибку" : "Показать ошибку"}
                  </button>
                  {expandedError[idx] && <pre className="history-error-body">{row.message}</pre>}
                </div>
              ) : (
                <div className="muted">Сообщение об ошибке не сохранено.</div>
              )}
            </div>
          ))}
        </div>
      </section>

      <section className="cc-surface">
        <div className="section-title">
          Что блокируется
          <span className="section-meta">{dependencies.length}</span>
        </div>
        {dependencies.length === 0 && <div className="muted">Зависимых таблиц не найдено.</div>}
        {dependencies.length > 0 && (
          <div className="incident-dependency-list">
            {dependencies.map((dep, idx) => {
              const fqn = `${dep.schema}.${dep.table_name}`;
              return (
                <button
                  key={`${dep.table_id || fqn}-${idx}`}
                  className="incident-dependency-row"
                  onClick={() => onOpenTable?.(fqn)}
                >
                  <span className="incident-rank">#{idx + 1}</span>
                  <span className="mono">{fqn}</span>
                  <span className="muted">{dep.entity_name || "—"}</span>
                  <span className="incident-duration">{dep.avg_duration_minutes ?? "—"} мин</span>
                </button>
              );
            })}
          </div>
        )}
      </section>
    </div>
  );
}
