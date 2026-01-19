import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function EntityShedule() {
  const [entities, setEntities] = useState([]);
  const [error, setError] = useState(null);
  const [loadingEntities, setLoadingEntities] = useState(false);
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const navigate = useNavigate();

  useEffect(() => {
    setLoadingEntities(true);
    fetch(`${API_BASE}/api/entities`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((data) => setEntities(Array.isArray(data) ? data : []))
      .catch(() => setError('Не удалось загрузить список сущностей'))
      .finally(() => setLoadingEntities(false));
  }, []);

  const openEntityTables = (row) => {
    const q = new URLSearchParams({ name: row.entity_name ?? '' }).toString();
    navigate(`/entity/${row.entity_id}/tables?${q}`);
  };

  const normalized = useMemo(() => {
    return entities.map((row) => {
      const lastLoad = row.entity_last_load ? new Date(row.entity_last_load) : null;
      return {
        ...row,
        lastLoad,
        status: (row.entity_load_status || "UNKNOWN").toUpperCase().replace("SUCCESS", "LOADED"),
      };
    });
  }, [entities]);

  const stats = useMemo(() => {
    const total = normalized.length;
    const statusCounts = normalized.reduce((acc, row) => {
      const key = row.status || "UNKNOWN";
      acc[key] = (acc[key] || 0) + 1;
      return acc;
    }, {});
    return { total, statusCounts };
  }, [normalized]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return normalized.filter((row) => {
      if (statusFilter !== "all" && row.status !== statusFilter) return false;
      if (!q) return true;
      return String(row.entity_name || "")
        .toLowerCase()
        .includes(q) || String(row.entity_id || "").includes(q);
    });
  }, [normalized, query, statusFilter]);

  return (
    <div className="container entity-page">
      <div className="entity-hero">
        <div>
          <div className="entity-title">Entities</div>
          <div className="entity-subtitle">Список сущностей, расписание и быстрый доступ к таблицам</div>
        </div>
        <div className="entity-toolbar">
          <input
            className="entity-search"
            placeholder="Поиск по имени или ID"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <div className="entity-filters">
            {["all", "LOADED", "FAILED", "RUNNING"].map((status) => (
              <button
                key={status}
                className={`pill ${statusFilter === status ? "pill-active" : ""}`}
                onClick={() => setStatusFilter(status)}
              >
                {status === "all" ? "Все" : status}
              </button>
            ))}
          </div>
        </div>
      </div>

      <section className="cc-surface">
        <div className="section-title">
          Сводка
          <span className="section-meta">{stats.total}</span>
        </div>
        <div className="entity-kpis">
          <div className="entity-kpi-card">
            <div className="entity-kpi-label">Всего сущностей</div>
            <div className="entity-kpi-value">{stats.total}</div>
          </div>
          {Object.entries(stats.statusCounts).map(([status, count]) => (
            <div key={status} className="entity-kpi-card">
              <div className="entity-kpi-label">{status}</div>
              <div className="entity-kpi-value">{count}</div>
            </div>
          ))}
        </div>
      </section>

      <section className="cc-surface">
        <div className="section-title">
          Сущности
          <span className="section-meta">{filtered.length}</span>
        </div>
        {loadingEntities && <div className="muted">Загрузка…</div>}
        {error && <div className="dep-error-title">{error}</div>}
        {!loadingEntities && filtered.length === 0 && (
          <div className="muted">Нет сущностей по заданным фильтрам</div>
        )}
        <div className="entity-grid entity-grid-schedule">
          {filtered.map((row) => (
            <article key={row.entity_id} className="entity-schedule-card">
              <div className="entity-card-head">
                <div>
                  <div className="entity-name">{row.entity_name || "—"}</div>
                  <div className="entity-meta">ID: {row.entity_id}</div>
                </div>
                <span className={`status-pill status-${row.status.toLowerCase()}`}>
                  {row.status}
                </span>
              </div>
              <div className="entity-meta-grid">
                <div>
                  <div className="entity-meta-label">Последняя загрузка</div>
                  <div className="entity-meta-value">{row.entity_last_load || "—"}</div>
                </div>
                <div>
                  <div className="entity-meta-label">Интервал</div>
                  <div className="entity-meta-value">{row.entity_load_interval || "—"}</div>
                </div>
              </div>
              <div className="entity-actions">
                <button className="btn btn-secondary" onClick={() => openEntityTables(row)}>
                  Таблицы сущности
                </button>
              </div>
            </article>
          ))}
        </div>
      </section>
    </div>
  );
}
