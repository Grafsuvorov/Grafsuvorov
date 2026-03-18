import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import "../style/app.css";
import { formatLocalDateTime, parseLocalDateTime } from "../utils/datetime.js";
import { entitiesApi } from "../api/entities.js";
import { accountApi } from "../api/account.js";

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
  const [favoriteEntityIds, setFavoriteEntityIds] = useState(new Set());
  const [favoriteEntityLoadingId, setFavoriteEntityLoadingId] = useState(null);
  const [entityTimelineMap, setEntityTimelineMap] = useState({});
  const [expandedEntityIds, setExpandedEntityIds] = useState(new Set());
  const navigate = useNavigate();
  const COVERAGE_PAGE_SIZE = 50;

  useEffect(() => {
    setLoadingEntities(true);
    entitiesApi
      .list()
      .then((data) => setEntities(Array.isArray(data) ? data : []))
      .catch(() => setError("Не удалось загрузить сущности"))
      .finally(() => setLoadingEntities(false));
  }, []);

  useEffect(() => {
    entitiesApi
      .shared(3)
      .then((data) => setSharedMap(data || {}))
      .catch(() => setSharedMap({}));
  }, []);

  const loadCoverage = (offset = 0, append = false) => {
    setCoverageLoading(true);
    entitiesApi
      .coverage(COVERAGE_PAGE_SIZE, offset)
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
    entitiesApi
      .dq(7, 10, 12)
      .then((data) => setDqEntities(Array.isArray(data) ? data : []))
      .catch((err) => {
        console.error(err);
        setDqEntitiesError(typeof err === "string" ? err : "Не удалось загрузить DQ по сущностям");
      })
      .finally(() => setDqEntitiesLoading(false));
  }, []);

  useEffect(() => {
    accountApi
      .favoriteEntities()
      .then((data) => {
        const ids = new Set((Array.isArray(data?.items) ? data.items : []).map((item) => item.entity_id));
        setFavoriteEntityIds(ids);
      })
      .catch(() => setFavoriteEntityIds(new Set()));
  }, []);

  useEffect(() => {
    entitiesApi
      .timeline(7)
      .then((data) => setEntityTimelineMap(data?.items || {}))
      .catch(() => setEntityTimelineMap({}));
  }, []);

  const openEntityTables = (row) => {
    const q = new URLSearchParams({ name: row.entity_name ?? '' }).toString();
    navigate(`/entity/${row.entity_id}/tables?${q}`);
  };

  const toggleFavoriteEntity = async (row) => {
    if (!row?.entity_id || favoriteEntityLoadingId) return;
    const isFavorite = favoriteEntityIds.has(row.entity_id);
    setFavoriteEntityLoadingId(row.entity_id);
    try {
      if (isFavorite) {
        await accountApi.removeFavoriteEntity(row.entity_id);
      } else {
        await accountApi.addFavoriteEntity({
          entity_id: row.entity_id,
          entity_name: row.entity_name || null,
        });
      }
      setFavoriteEntityIds((prev) => {
        const next = new Set(prev);
        if (isFavorite) next.delete(row.entity_id);
        else next.add(row.entity_id);
        return next;
      });
    } catch {
      // keep UI silent here; page is operational
    } finally {
      setFavoriteEntityLoadingId(null);
    }
  };

  const toggleEntityExpand = (entityId) => {
    setExpandedEntityIds((prev) => {
      const next = new Set(prev);
      if (next.has(entityId)) next.delete(entityId);
      else next.add(entityId);
      return next;
    });
  };

  const normalized = useMemo(() => {
    return entities.map((row) => {
      const scheduleDate = parseLocalDateTime(row.entity_last_load);
      const scheduleStart = parseLocalDateTime(row.entity_schedule_start);
      const scheduleEnd = parseLocalDateTime(row.entity_schedule_end);
      return {
        ...row,
        scheduleDate,
        scheduleStart,
        scheduleEnd,
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
      const shared = (sharedMap[String(row.entity_id)]?.tables || [])
        .map((t) => normalize(t))
        .join(" ");
      return name.includes(q) || id.includes(q) || status.includes(q) || shared.includes(q);
    });
  }, [normalized, query, statusFilter, sharedMap]);

  const formatDateTime = (value) => {
    if (!value) return "—";
    return formatLocalDateTime(value);
  };

  const timelineMax = useMemo(() => {
    const values = Object.values(entityTimelineMap).flatMap((rows) =>
      Array.isArray(rows) ? rows.map((row) => Number(row.duration_minutes || 0)) : []
    );
    return values.length ? Math.max(...values) : 0;
  }, [entityTimelineMap]);

  const formatDuration = (value) => {
    const minutes = Number(value || 0);
    if (!Number.isFinite(minutes) || minutes <= 0) return "—";
    if (minutes >= 60) {
      const hours = Math.floor(minutes / 60);
      const rest = Math.round(minutes % 60);
      return rest ? `${hours} ч ${rest} мин` : `${hours} ч`;
    }
    return `${Math.round(minutes)} мин`;
  };

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
              <div className="entity-meta-grid compact">
                <div>
                  <div className="entity-meta-label">Расписание загрузки</div>
                  <div className="entity-meta-value">{formatDateTime(row.scheduleDate)}</div>
                </div>
                <div>
                  <div className="entity-meta-label">Старт загрузки</div>
                  <div className="entity-meta-value">{formatDateTime(row.scheduleStart)}</div>
                </div>
                <div>
                  <div className="entity-meta-label">Финиш загрузки</div>
                  <div className="entity-meta-value">{formatDateTime(row.scheduleEnd)}</div>
                </div>
                <div>
                  <div className="entity-meta-label">Общие таблицы</div>
                  <div className="entity-meta-value">
                    {sharedMap[String(row.entity_id)]?.count ?? 0}
                  </div>
                </div>
              </div>
              {sharedMap[String(row.entity_id)]?.tables?.length > 0 && (
                <div className="entity-shared">
                  {sharedMap[String(row.entity_id)].tables.slice(0, 3).map((tbl) => (
                    <span key={tbl} className="entity-shared-pill mono">{tbl}</span>
                  ))}
                  {sharedMap[String(row.entity_id)].tables.length > 3 && (
                    <span className="entity-shared-pill entity-shared-more">
                      +{sharedMap[String(row.entity_id)].tables.length - 3}
                    </span>
                  )}
                </div>
              )}
              <div className="entity-actions">
                <button className="btn btn-ghost entity-expand-toggle" onClick={() => toggleEntityExpand(row.entity_id)}>
                  {expandedEntityIds.has(row.entity_id) ? "Скрыть историю загрузки" : "История загрузки за 7 дней"}
                </button>
                <button className="btn btn-ghost" onClick={() => toggleFavoriteEntity(row)}>
                  {favoriteEntityLoadingId === row.entity_id
                    ? "Сохраняем..."
                    : favoriteEntityIds.has(row.entity_id)
                      ? "Убрать из избранного"
                      : "В избранное"}
                </button>
                <button className="btn btn-secondary" onClick={() => openEntityTables(row)}>
                  Таблицы сущности
                </button>
              </div>
              {expandedEntityIds.has(row.entity_id) && (
                <div className="entity-expanded-panel">
                  <div className="entity-expanded-head">
                    <div>
                      <div className="entity-expanded-title">История загрузки за 7 дней</div>
                      <div className="muted">Старт, финиш и длительность окна по сущности за каждый день.</div>
                    </div>
                  </div>
                  {(entityTimelineMap[String(row.entity_id)] || []).length > 0 ? (
                    <div className="entity-history-chart">
                      {(entityTimelineMap[String(row.entity_id)] || []).map((item) => {
                        const ratio = timelineMax ? Number(item.duration_minutes || 0) / timelineMax : 0;
                        const width = `${Math.max(16, ratio * 100)}%`;
                        return (
                          <div key={`${row.entity_id}-${item.day}`} className="entity-history-row">
                            <div className="entity-history-day">{String(item.day || "").slice(5)}</div>
                            <div className="entity-history-main">
                              <div className="entity-history-meta">
                                <span>Старт: {formatDateTime(item.start_dttm)}</span>
                                <span>Финиш: {formatDateTime(item.end_dttm)}</span>
                                <span>Шла: {formatDuration(item.duration_minutes)}</span>
                              </div>
                              <div className="entity-history-track">
                                <div className="entity-history-bar" style={{ width }} />
                              </div>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  ) : (
                    <div className="muted">Нет истории за 7 дней</div>
                  )}
                </div>
              )}
            </article>
          ))}
        </div>
      </section>
    </div>
  );
}
