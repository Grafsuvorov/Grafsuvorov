import { useEffect, useState, useMemo } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function HomePage({ onSelectTable }) {
  const [activeIncidents, setActiveIncidents] = useState([]);
  const [orderBreaches, setOrderBreaches] = useState([]);
  const [history, setHistory] = useState([]);
  const [metrics, setMetrics] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setLoading(true);

        const [
          activeResp,
          orderResp,
          historyResp,
          metricsResp
        ] = await Promise.all([
          fetch(`${API_BASE}/api/incidents/active`),
          fetch(`${API_BASE}/api/orderbreaches`),
          fetch(`${API_BASE}/api/incidents/history`),
          fetch(`${API_BASE}/api/metrics`)
        ]);

        const activeJson = await activeResp.json();
        const orderJson = await orderResp.json();
        const historyJson = await historyResp.json();
        const metricsJson = await metricsResp.json();

        if (!cancelled) {
          setActiveIncidents(Array.isArray(activeJson) ? activeJson : []);
          setOrderBreaches(Array.isArray(orderJson) ? orderJson : []);
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
    return () => {
      cancelled = true;
    };
  }, []);

  /* =============================
     INCIDENT TREND (simple)
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

      {/* ===== ORDER BREACHES ===== */}
      {!loading && orderBreaches.length > 0 && (
        <section className="cc-surface">
          <div className="section-title">
            Нарушения порядка загрузки
            <span className="section-meta">{orderBreaches.length}</span>
          </div>
          <div className="order-list">
            {orderBreaches.slice(0, 4).map((breach) => (
              <article key={breach.target_fqn} className="order-row">
                <header className="order-row-header">
                  <div>
                    <div className="order-row-target mono" title={breach.target_fqn}>{breach.target_fqn}</div>
                    <div className="order-row-meta">
                      Источник стартовал позже: <span title={breach.worst_upstream}>{breach.worst_upstream}</span>
                    </div>
                  </div>
                  <div className={`order-pill order-pill-${breach.severity?.toLowerCase() || "warning"}`}>
                    {severityLabel(breach.severity)}
                  </div>
                </header>
                <div className="order-row-chain">
                  <span className="order-node mono" title={breach.worst_upstream}>{breach.worst_upstream}</span>
                  <span className="order-arrow">→</span>
                  <span className="order-node mono" title={breach.target_fqn}>{breach.target_fqn}</span>
                  <span className="order-arrow">→</span>
                  <span className="order-node">витрины и отчёты</span>
                </div>
                <p className="order-row-text">
                  {breach.worst_upstream} завершилась {formatTime(breach.worst_upstream_time)}, а {breach.target_fqn} стартовала
                  {" "}
                  {formatTime(breach.target_last_load)}. Задержка +{breach.gap_minutes} мин.
                </p>
                <p className="order-row-text" style={{ color: "#9ca3af" }}>
                  Нарушение зацепило {breach.violations_count} источников. Чтобы увидеть полную цепочку и витрины,
                  откройте карточку или граф зависимостей.
                </p>
                {breach.violations && breach.violations.length > 0 && (
                  <div className="order-violations">
                    {breach.violations.slice(0, 3).map((v) => (
                      <div key={`${breach.target_fqn}-${v.source_fqn}`} className="order-violation">
                        <span className="mono" title={v.source_fqn}>{v.source_fqn}</span>
                        <span className="order-violation-gap">+{Math.round(v.gap_sec / 60)} мин</span>
                      </div>
                    ))}
                  </div>
                )}
                <div className="order-row-actions">
                  <button
                    className="btn btn-secondary"
                    onClick={() => onSelectTable({ view: "table_info", table: breach.target_fqn }, "home")}
                  >
                    Карточка таблицы
                  </button>
                  <button
                    className="btn btn-ghost"
                    onClick={() => onSelectTable({ view: "dependency_graph", table: breach.target_fqn }, "home")}
                  >
                    Граф зависимостей
                  </button>
                </div>
              </article>
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
          <div className="history-board">
            <div className="history-board-head">
              <span>#</span>
              <span>Таблица</span>
              <span>Инцидентов</span>
              <span>Последний случай</span>
            </div>
            {history.map((h, idx) => (
              <button
                key={h.table}
                className="history-board-row"
                onClick={() => onSelectTable({ view: "incident", table: h.table }, "home")}
              >
                <span className="history-rank">#{idx + 1}</span>
                <span className="history-table mono" title={h.table}>{h.table}</span>
                <span className="history-count-chip">{h.count}</span>
                <span className="history-last-date">{h.last_incident || "—"}</span>
              </button>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
  const formatTime = (value) => {
    if (!value) return "—";
    const dt = new Date(value.replace(" ", "T"));
    if (Number.isNaN(dt.getTime())) return value;
    return dt.toLocaleString("ru-RU", {
      day: "2-digit",
      month: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  const severityLabel = (sev) => {
    switch (sev) {
      case "CRITICAL":
        return "Критично";
      case "MAJOR":
        return "Важно";
      default:
        return "Предупреждение";
    }
  };
