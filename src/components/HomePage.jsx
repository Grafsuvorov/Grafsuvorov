import { useEffect, useState, useMemo } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function HomePage({ onSelectTable }) {
  const [activeIncidents, setActiveIncidents] = useState([]);
  const [history, setHistory] = useState([]);
  const [metrics, setMetrics] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setLoading(true);

        const [activeResp, historyResp, metricsResp] = await Promise.all([
          fetch(`${API_BASE}/api/incidents/active`),
          fetch(`${API_BASE}/api/incidents/history`),
          fetch(`${API_BASE}/api/metrics`)
        ]);

        const activeJson = await activeResp.json();
        const historyJson = await historyResp.json();
        const metricsJson = await metricsResp.json();

        if (!cancelled) {
          setActiveIncidents(Array.isArray(activeJson) ? activeJson : []);
          setHistory(Array.isArray(historyJson) ? historyJson : []);
          setMetrics(metricsJson);
        }
      } catch (e) {
        console.error("HomePage load error:", e);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    load();
    return () => { cancelled = true; };
  }, []);

  /* =============================
     TREND ANALYSIS (simple)
     ============================= */
  const incidentTrend = useMemo(() => {
    if (!history.length) return null;

    const counts = history.map(h => h.count);
    const avg = counts.reduce((a, b) => a + b, 0) / counts.length;

    const max = Math.max(...counts);

    if (max > avg * 1.3) return "up";
    if (max < avg * 0.9) return "down";
    return "stable";
  }, [history]);

  return (
    <div className="container cc-page">

      {/* ===== HEADER ===== */}
      <section className="cc-header-zone">
        <h1>Control Center</h1>
        <div className="cc-subtitle">
          Инциденты, стабильность и операционная надёжность системы
        </div>
      </section>

      {/* ===== OVERVIEW ===== */}
      {metrics && (
        <section className="cc-overview-bar">
          <div className="overview-item">
            <span className="overview-value">{metrics.total_tables}</span>
            <span className="overview-label">Таблиц</span>
          </div>

          <div className="overview-item danger">
            <span className="overview-value">{metrics.error_count}</span>
            <span className="overview-label">Ошибок</span>
          </div>

          <div className="overview-item">
            <span className="overview-value">
              {metrics.avg_duration_minutes ?? "—"}
            </span>
            <span className="overview-label">Среднее, мин</span>
          </div>

          <div className="overview-item">
            <span className="overview-value">{metrics.active_entities}</span>
            <span className="overview-label">Сущностей</span>
          </div>
        </section>
      )}

      {/* ===== STATUS ===== */}
      <section className="cc-status-line">
        <span
          className={`status-dot ${
            activeIncidents.length ? "degraded" : ""
          }`}
        />
        <span className="status-text">
          {activeIncidents.length
            ? "Обнаружены активные инциденты"
            : "Система работает штатно"}
        </span>

        {incidentTrend && (
          <span className="status-meta">
            Тренд инцидентов:&nbsp;
            {incidentTrend === "up" && "рост ↑"}
            {incidentTrend === "down" && "спад ↓"}
            {incidentTrend === "stable" && "стабильно"}
          </span>
        )}
      </section>

      {/* ===== ACTIVE INCIDENTS ===== */}
      {loading && <div className="muted">Загрузка…</div>}

      {!loading && activeIncidents.length === 0 && (
        <div className="system-ok">
          <div className="system-ok-icon">✓</div>
          <div className="system-ok-title">Активных инцидентов нет</div>
          <div className="system-ok-sub">
            За последние 24 часа система отработала без ошибок
          </div>
        </div>
      )}

      {!loading && activeIncidents.length > 0 && (
        <section className="cc-surface">
          <div className="section-title">
            Активные инциденты
            <span className="section-meta">{activeIncidents.length}</span>
          </div>

          <div className="entity-grid">
            {activeIncidents.map((i, idx) => (
              <div
                key={idx}
                className="entity-card critical clickable"
                onClick={() =>
                  onSelectTable(
                    { view: "incident", table: i.root_tables[0] },
                    "home"
                  )
                }
              >
                <div className="entity-card-head">
                  <div className="entity-name">{i.entity}</div>
                  <span className="pill pill-critical">CRITICAL</span>
                </div>

                <div className="entity-meta">
                  Упало таблиц: {i.failed_tables}
                </div>

                <div className="entity-meta">
                  Последнее падение: {i.last_failure_time}
                </div>

                <div className="incident-hint">
                  Нажмите для разбора инцидента →
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ===== INCIDENT HISTORY ===== */}
      {!loading && history.length > 0 && (
        <section className="cc-surface">
          <div className="section-title">
            История инцидентов (300 дней)
            <span className="section-meta">топ проблемных таблиц</span>
          </div>

          <div className="history-list">
            {history.map((h, idx) => (
              <div
                key={idx}
                className="history-row clickable"
                onClick={() =>
                  onSelectTable(
                    { view: "incident", table: h.table },
                    "home"
                  )
                }
              >
                <div className="history-left">
                  <span className="history-rank">#{idx + 1}</span>
                  <span className="history-table-name mono">
                    {h.table}
                  </span>
                </div>

                <div className="history-right">
                  <span className="history-count">{h.count}</span>
                  <span className="history-last">
                    &nbsp;последний:&nbsp;{h.last_incident}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
