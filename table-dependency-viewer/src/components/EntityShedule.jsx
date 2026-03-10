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
  const [sharedMap, setSharedMap] = useState({});
  const [coverage, setCoverage] = useState(null);
  const [coverageRows, setCoverageRows] = useState([]);
  const [coverageError, setCoverageError] = useState(null);
  const [coverageLoading, setCoverageLoading] = useState(false);
  const [coverageHasMore, setCoverageHasMore] = useState(false);
  const [coverageOffset, setCoverageOffset] = useState(0);
  const [coverageQuery, setCoverageQuery] = useState("");
  const [coverageSchema, setCoverageSchema] = useState("all");
  const [showCoverageList, setShowCoverageList] = useState(false);
  const [dqEntities, setDqEntities] = useState([]);
  const [dqEntitiesError, setDqEntitiesError] = useState(null);
  const [dqEntitiesLoading, setDqEntitiesLoading] = useState(false);
  const navigate = useNavigate();
  const COVERAGE_PAGE_SIZE = 50;

  useEffect(() => {
    setLoadingEntities(true);
    fetch(`${API_BASE}/api/entities`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((data) => setEntities(Array.isArray(data) ? data : []))
      .catch(() => setError("Не удалось загрузить сущности"))
      .finally(() => setLoadingEntities(false));
  }, []);

  useEffect(() => {
    fetch(`${API_BASE}/api/entities/shared?limit=3`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить общие таблицы")))
      .then((data) => setSharedMap(data || {}))
      .catch(() => setSharedMap({}));
  }, []);

  const loadCoverage = (offset = 0, append = false) => {
    setCoverageLoading(true);
    fetch(`${API_BASE}/api/graph/orphans?limit=${COVERAGE_PAGE_SIZE}&offset=${offset}&meta_only=true`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить разрывы покрытия")))
      .then((data) => {
        setCoverage(data || null);
        setCoverageHasMore(!!data?.has_more);
        setCoverageOffset((data?.offset || 0) + (data?.orphans?.length || 0));
        setCoverageRows((prev) => (append ? [...prev, ...(data?.orphans || [])] : data?.orphans || []));
      })
      .catch(() => setCoverageError("Не удалось загрузить разрывы покрытия"))
      .finally(() => setCoverageLoading(false));
  };

  useEffect(() => {
    loadCoverage(0, false);
  }, []);

  useEffect(() => {
    setDqEntitiesLoading(true);
    setDqEntitiesError(null);
    fetch(`${API_BASE}/api/dq/entity?days=7&delta=10&limit=12`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить DQ по сущностям")))
      .then((data) => setDqEntities(Array.isArray(data) ? data : []))
      .catch((err) => {
        console.error(err);
        setDqEntitiesError(typeof err === "string" ? err : "Не удалось загрузить DQ по сущностям");
      })
      .finally(() => setDqEntitiesLoading(false));
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
    const normalize = (value) =>
      String(value || "")
        .toLowerCase()
        .replace(/\s+/g, "");
    const q = normalize(query);
    return normalized.filter((row) => {
      if (statusFilter !== "all" && row.status !== statusFilter) return false;
      if (!q) return true;
      const name = normalize(row.entity_name);
      const id = normalize(row.entity_id);
      const status = normalize(row.status);
      const shared = (sharedMap[row.entity_name]?.tables || [])
        .map((t) => normalize(t))
        .join(" ");
      return name.includes(q) || id.includes(q) || status.includes(q) || shared.includes(q);
    });
  }, [normalized, query, statusFilter, sharedMap]);

  const coverageFiltered = useMemo(() => {
    const normalize = (value) =>
      String(value || "")
        .toLowerCase()
        .replace(/\s+/g, "");
    const q = normalize(coverageQuery);
    return coverageRows.filter((row) => {
      if (coverageSchema !== "all" && row.schema !== coverageSchema) return false;
      if (!q) return true;
      const fqn = normalize(row.id);
      const entities = (row.entities || []).map((ent) => normalize(ent)).join(" ");
      return fqn.includes(q) || entities.includes(q);
    });
  }, [coverageRows, coverageQuery, coverageSchema]);

  const coverageSchemaOptions = useMemo(() => {
    if (!coverage?.count_by_schema) return ["all"];
    const schemas = Object.keys(coverage.count_by_schema).sort();
    return ["all", ...schemas];
  }, [coverage]);

  const openTable = (row) => {
    if (!row?.schema || !row?.table) return;
    const schema = String(row.schema).trim();
    const table = String(row.table).trim().replaceAll("/", "").replaceAll("-", "");
    if (!schema || !table) return;
    navigate(`/table/${schema}/${table}`);
  };

  return (
    <div className="container entity-page">
      <div className="entity-hero">
        <div>
          <div className="entity-title">Сущности</div>
          <div className="entity-subtitle">Каталог сущностей, статусы и быстрый доступ к таблицам</div>
        </div>
        <div className="entity-toolbar">
          <input
            className="entity-search"
            placeholder="Поиск по названию или ID"
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
          Разрывы покрытия
          <span className="section-meta">{coverage?.orphan_count ?? 0}</span>
        </div>
        {coverageError && <div className="dep-error-title">{coverageError}</div>}
        {!coverage && !coverageError && <div className="muted">Loading…</div>}
        {coverage && (
          <>
            <div className="coverage-kpis">
              <div className="coverage-card">
                <div className="coverage-label">Покрытие до DM (только YAML)</div>
                <div className="coverage-value">{coverage.coverage_pct}%</div>
                <div className="coverage-note">
                  {coverage.reachable_count} / {coverage.total_tables} tables
                </div>
              </div>
              <div className="coverage-card">
                <div className="coverage-label">Нет пути до DM</div>
                <div className="coverage-value">{coverage.orphan_count}</div>
                <div className="coverage-note">
                  Финальные схемы: {coverage.final_schemas?.join(", ") || "—"}
                </div>
              </div>
              <div className="coverage-card">
                <div className="coverage-label">Финальные таблицы</div>
                <div className="coverage-value">{coverage.final_count}</div>
                <div className="coverage-note">Входные точки слоя DM</div>
              </div>
            </div>

            <div className="coverage-summary">
              Таблиц без пути до DM: {coverage.orphan_count}. Они не питают витрины.
            </div>

            <button
              className="btn btn-secondary"
              onClick={() => setShowCoverageList((prev) => !prev)}
            >
              {showCoverageList ? "Скрыть список" : "Показать список"}
            </button>

            {showCoverageList && (
              <>
                <div className="coverage-toolbar">
                  <input
                    className="coverage-search"
                    placeholder="Поиск по таблице или сущности"
                    value={coverageQuery}
                    onChange={(e) => setCoverageQuery(e.target.value)}
                  />
                  <div className="coverage-filters">
                    {coverageSchemaOptions.map((schema) => (
                      <button
                        key={schema}
                        className={`pill ${coverageSchema === schema ? "pill-active" : ""}`}
                        onClick={() => setCoverageSchema(schema)}
                      >
                        {schema === "all" ? "Все схемы" : schema}
                      </button>
                    ))}
                  </div>
                  <div className="coverage-actions">
                    <button className="btn btn-secondary" onClick={() => loadCoverage(0, false)}>
                      Обновить
                    </button>
                    <button
                      className="btn btn-secondary"
                      disabled={!coverageHasMore || coverageLoading}
                      onClick={() => loadCoverage(coverageOffset, true)}
                    >
                      {coverageHasMore ? "Загрузить ещё" : "Всё загружено"}
                    </button>
                  </div>
                </div>

                <div className="coverage-summary">
                  Показано {coverageFiltered.length} из {coverage.orphan_count}
                </div>

                {coverage.orphan_count === 0 ? (
                  <div className="muted">Все таблицы достигают слоя DM</div>
                ) : (
                  <div className="coverage-list">
                    {coverageFiltered.map((row) => (
                      <div key={row.id} className="coverage-row">
                        <button className="coverage-fqn mono coverage-link" onClick={() => openTable(row)}>
                          {row.id}
                        </button>
                        <div className="coverage-meta">
                          <span className="coverage-pill">{row.schema || "unknown"}</span>
                          <span className="coverage-pill">in: {row.incoming}</span>
                          <span className="coverage-pill">out: {row.outgoing}</span>
                          {row.entities?.length > 0 ? (
                            <span className="coverage-entities">
                              {row.entities.join(", ")}
                            </span>
                          ) : (
                            <span className="coverage-entities muted">сущность неизвестна</span>
                          )}
                        </div>
                        <div className="coverage-actions-row">
                          <button className="btn btn-secondary" onClick={() => openTable(row)}>
                            Открыть
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </>
            )}
          </>
        )}
      </section>

      <section className="cc-surface">
        <div className="section-title">
          Качество данных по сущностям
          <span className="section-meta">{dqEntities.length}</span>
        </div>
        {dqEntitiesLoading && <div className="muted">Загрузка DQ-сводки...</div>}
        {dqEntitiesError && <div className="dep-error-title">{dqEntitiesError}</div>}
        {!dqEntitiesLoading && !dqEntitiesError && dqEntities.length === 0 && (
          <div className="muted">DQ-алертов нет.</div>
        )}
        {!dqEntitiesLoading && !dqEntitiesError && dqEntities.length > 0 && (
          <div className="dq-entity-grid">
            {dqEntities.map((row) => (
              <div key={row.entity} className="dq-entity-card">
                <div className="dq-entity-name">{row.entity}</div>
                <div className="dq-entity-metrics">
                  <span>Дубли: {row.duplicates}</span>
                  <span>Строки: {row.row_count}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="cc-surface">
        <div className="section-title">
          Сущности
          <span className="section-meta">{filtered.length}</span>
        </div>
        {loadingEntities && <div className="muted">Loading…</div>}
        {error && <div className="dep-error-title">{error}</div>}
        {!loadingEntities && filtered.length === 0 && (
          <div className="muted">Ничего не найдено</div>
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
                  <div>
                    <div className="entity-meta-label">Общие таблицы</div>
                    <div className="entity-meta-value">
                      {sharedMap[row.entity_name]?.count ?? 0}
                    </div>
                </div>
              </div>
              {sharedMap[row.entity_name]?.tables?.length > 0 && (
                <div className="entity-shared">
                  {sharedMap[row.entity_name].tables.map((tbl) => (
                    <span key={tbl} className="entity-shared-pill mono">{tbl}</span>
                  ))}
                </div>
              )}
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
