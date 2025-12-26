import { useEffect, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function HomePage({ onSelectTable }) {
  const [entities, setEntities] = useState([]);
  const [metrics, setMetrics] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setLoading(true);

        const [incResp, metResp] = await Promise.all([
          fetch(`${API_BASE}/api/incidents/active`),
          fetch(`${API_BASE}/api/metrics`)
        ]);

        const incidents = await incResp.json();
        const metricsJson = await metResp.json();

        if (!cancelled) {
          setEntities(incidents || []);
          setMetrics(metricsJson);
        }
      } catch (e) {
        console.error("Control Center load error:", e);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    load();
    return () => { cancelled = true; };
  }, []);

  return (
    <div className="container">
      {/* ===== Header ===== */}
      <section className="cc-header-zone">
        <h1>Control Center</h1>
        <div className="cc-subtitle">
          Инциденты, зависимости и SLA — единая картина системы
        </div>
      </section>

      {/* ===== Metrics ===== */}
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

      {/* ===== Degradation by entity ===== */}
      <section className="cc-surface">
  <div className="section-title">
    Деградация по сущностям
    <span className="section-meta">{entities.length}</span>
  </div>

  {loading && (
    <div className="muted">Загрузка…</div>
  )}

  {/* ===== SYSTEM OK STATE ===== */}
  {!loading && entities.length === 0 && (
    <div className="system-ok">
      <div className="system-ok-icon">✓</div>

      <div className="system-ok-title">
        Система работает штатно
      </div>

      <div className="system-ok-sub">
        За последние 24 часа не зафиксировано ошибок загрузки
        и нарушений SLA
      </div>

      <div className="system-ok-metrics">
        <div>
          <strong>{metrics?.total_tables}</strong>
          <span>таблиц</span>
        </div>

        <div>
          <strong>{metrics?.active_entities}</strong>
          <span>сущностей</span>
        </div>

        <div>
          <strong>{metrics?.avg_duration_minutes ?? "—"}</strong>
          <span>ср. время, мин</span>
        </div>
      </div>
    </div>
  )}

  {/* ===== INCIDENTS ===== */}
  {!loading && entities.length > 0 && (
    <div className="entity-grid">
      {entities.map((e, idx) => (
        <div key={`${e.entity}-${idx}`} className="entity-card critical">
          <div className="entity-card-head">
            <div className="entity-name">{e.entity}</div>
            <span className="pill pill-critical">CRITICAL</span>
          </div>

          <div className="entity-impact">
            <div>
              <strong>{e.affected_tables}</strong> таблиц под риском
            </div>
            <div className="muted">
              Упало: {e.failed_tables}
            </div>
          </div>

          <div className="entity-meta">
            Последнее падение: {e.last_failure_time}
          </div>

          <div className="entity-actions">
            <button
              className="btn btn-primary"
              disabled={!e.root_tables?.length}
              onClick={() =>
                onSelectTable(
                  { view: "incident", table: e.root_tables[0] },
                  "home"
                )
              }
            >
              Анализ последствий
            </button>
          </div>
        </div>
      ))}
    </div>
  )}
</section>

    </div>
  );
}
