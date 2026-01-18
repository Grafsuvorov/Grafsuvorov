import { useEffect, useState, useMemo } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function HomePage({ onSelectTable }) {
  const [activeIncidents, setActiveIncidents] = useState([]);
  const [orderBreaches, setOrderBreaches] = useState([]);
  const [history, setHistory] = useState([]);
  const [metrics, setMetrics] = useState(null);
  const [loading, setLoading] = useState(true);
  const [entityCycles, setEntityCycles] = useState([]);
  const [entityMutual, setEntityMutual] = useState([]);
  const [impactMap, setImpactMap] = useState({});
  const [impactOpen, setImpactOpen] = useState({});
  const [impactGroupOpen, setImpactGroupOpen] = useState({});
  const [impactEntityOpen, setImpactEntityOpen] = useState({});
  const [entityLinkOpen, setEntityLinkOpen] = useState({});

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setLoading(true);

        const [
          activeResp,
          orderResp,
          historyResp,
          metricsResp,
          diagResp
        ] = await Promise.all([
          fetch(`${API_BASE}/api/incidents/active`),
          fetch(`${API_BASE}/api/orderbreaches`),
          fetch(`${API_BASE}/api/incidents/history`),
          fetch(`${API_BASE}/api/metrics`),
          fetch(`${API_BASE}/api/graph/diagnostics`)
        ]);

        const activeJson = await activeResp.json();
        const orderJson = await orderResp.json();
        const historyJson = await historyResp.json();
        const metricsJson = await metricsResp.json();
        const diagJson = await diagResp.json();

        if (!cancelled) {
          setActiveIncidents(Array.isArray(activeJson) ? activeJson : []);
          setOrderBreaches(Array.isArray(orderJson) ? orderJson : []);
          setHistory(Array.isArray(historyJson) ? historyJson : []);
          setMetrics(metricsJson);
          setEntityCycles(Array.isArray(diagJson?.entity_cycles) ? diagJson.entity_cycles : []);
          setEntityMutual(Array.isArray(diagJson?.entity_mutual) ? diagJson.entity_mutual : []);
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

  const layerLabel = (fqn) => {
    const schema = (fqn || "").split(".")[0] || "";
    if (!schema) return "OTHER";
    if (schema.startsWith("dict_")) return "DICT";
    if (schema === "stg") return "STG";
    if (schema === "ods") return "ODS";
    if (schema === "dds") return "DDS";
    if (schema === "dm_calc") return "DM_CALC";
    if (schema.startsWith("dm")) return "DM";
    return schema.toUpperCase();
  };

  const layerOrder = ["DICT", "STG", "ODS", "DDS", "DM_CALC", "DM"];
  const impactLimit = 8;
  const entityLimit = 6;

  const sortLayers = (a, b) => {
    const aIndex = layerOrder.indexOf(a);
    const bIndex = layerOrder.indexOf(b);
    if (aIndex !== -1 || bIndex !== -1) {
      return (aIndex === -1 ? 999 : aIndex) - (bIndex === -1 ? 999 : bIndex);
    }
    return a.localeCompare(b);
  };

  const loadImpact = async (target) => {
    if (!target || impactMap[target]?.state === "loading" || impactMap[target]?.state === "ready") {
      return;
    }

    setImpactMap((prev) => ({
      ...prev,
      [target]: { state: "loading", rows: [], error: null },
    }));

    try {
      const resp = await fetch(`${API_BASE}/api/dependencies?table=${encodeURIComponent(target)}`);
      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status}`);
      }
      const json = await resp.json();
      const rows = Array.isArray(json) ? json : [];
      setImpactMap((prev) => ({
        ...prev,
        [target]: { state: "ready", rows, error: null },
      }));
    } catch (err) {
      console.error("Impact load error:", err);
      setImpactMap((prev) => ({
        ...prev,
        [target]: { state: "error", rows: [], error: "Не удалось загрузить список влияния." },
      }));
    }
  };

  const toggleImpact = (target) => {
    setImpactOpen((prev) => {
      const next = !prev[target];
      if (next) {
        loadImpact(target);
      }
      return { ...prev, [target]: next };
    });
  };

  const toggleImpactGroup = (target, label) => {
    const key = `${target}::${label}`;
    setImpactGroupOpen((prev) => ({ ...prev, [key]: !prev[key] }));
  };

  const toggleImpactEntities = (target) => {
    setImpactEntityOpen((prev) => ({ ...prev, [target]: !prev[target] }));
  };

  const toggleEntityLink = (key) => {
    setEntityLinkOpen((prev) => ({ ...prev, [key]: !prev[key] }));
  };

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
        <section className="cc-surface">
          <div className="system-ok system-ok-compact">
            <div className="system-ok-icon">✓</div>
            <div>
              <div className="system-ok-title">Активных инцидентов нет</div>
              <div className="system-ok-sub">
                За последние 24 часа система отработала без ошибок
              </div>
            </div>
          </div>
        </section>
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


                </div>
                <p className="order-row-text">
                  {breach.worst_upstream} завершилась {formatTime(breach.worst_upstream_time)}, а {breach.target_fqn} стартовала
                  {" "}
                  {formatTime(breach.target_last_load)}. Задержка +{breach.gap_minutes} мин.
                </p>


                <div className="order-row-actions">
                  <button
                    className="btn btn-secondary"
                    onClick={() => onSelectTable({ view: "table_info", table: breach.target_fqn }, "home")}
                  >
                    Карточка таблицы
                  </button>
                  <button
                    className="btn btn-ghost"
                    onClick={() => toggleImpact(breach.target_fqn)}
                  >
                    {impactOpen[breach.target_fqn] ? "Скрыть влияние" : "Показать влияние"}
                  </button>
                </div>
                {impactOpen[breach.target_fqn] && (
                  <div className="order-impact">
                    <div className="order-impact-header">
                      <div>
                        <div className="order-impact-title">Затронутые таблицы</div>
                        <div className="muted">
                          Построено по зависимостям от {breach.target_fqn}
                        </div>
                      </div>
                      <div className="order-impact-count">
                        {impactMap[breach.target_fqn]?.rows?.length || 0}
                      </div>
                    </div>
                    {impactMap[breach.target_fqn]?.state === "loading" && (
                      <div className="muted">Загружаем влияние…</div>
                    )}
                    {impactMap[breach.target_fqn]?.state === "error" && (
                      <div className="card dep-error">
                        <div className="dep-error-title">Ошибка загрузки</div>
                        <div className="muted">{impactMap[breach.target_fqn]?.error}</div>
                      </div>
                    )}
                    {impactMap[breach.target_fqn]?.state === "ready" &&
                      impactMap[breach.target_fqn]?.rows?.length === 0 && (
                        <div className="card muted">Нет зависимых таблиц.</div>
                      )}
                    {impactMap[breach.target_fqn]?.state === "ready" &&
                      impactMap[breach.target_fqn]?.rows?.length > 0 && (() => {
                        const rows = impactMap[breach.target_fqn].rows;
                        const entityMap = rows.reduce((acc, row) => {
                          const fqn = `${row.schema}.${row.table_name}`;
                          const label = layerLabel(fqn);
                          const entityKey = row.entity_id ? `id:${row.entity_id}` : `name:${row.entity_name || fqn}`;
                          const entityName = row.entity_name || (row.entity_id ? `Entity ${row.entity_id}` : fqn);
                          const entry = acc[entityKey] ??= {
                            key: entityKey,
                            name: entityName,
                            layers: new Set(),
                            tables: [],
                            minDepth: row.depth ?? 0,
                          };
                          entry.layers.add(label);
                          entry.tables.push({ fqn, layer: label, depth: row.depth ?? 0 });
                          entry.minDepth = Math.min(entry.minDepth, row.depth ?? 0);
                          return acc;
                        }, {});
                        const entityList = Object.values(entityMap)
                          .map((entry) => ({
                            ...entry,
                            layers: Array.from(entry.layers),
                            tables: entry.tables.sort((a, b) => a.depth - b.depth),
                          }))
                          .sort((a, b) => {
                            if (a.minDepth !== b.minDepth) return a.minDepth - b.minDepth;
                            const aLayerIndex = Math.min(...a.layers.map((l) => {
                              const idx = layerOrder.indexOf(l);
                              return idx === -1 ? 999 : idx;
                            }));
                            const bLayerIndex = Math.min(...b.layers.map((l) => {
                              const idx = layerOrder.indexOf(l);
                              return idx === -1 ? 999 : idx;
                            }));
                            if (aLayerIndex !== bLayerIndex) return aLayerIndex - bLayerIndex;
                            return a.name.localeCompare(b.name);
                          });
                        const showAllEntities = !!impactEntityOpen[breach.target_fqn];
                        const visibleEntities = showAllEntities
                          ? entityList
                          : entityList.slice(0, entityLimit);
                        const grouped = rows.reduce((acc, row) => {
                          const fqn = `${row.schema}.${row.table_name}`;
                          const label = layerLabel(fqn);
                          (acc[label] ??= []).push({
                            fqn,
                            entity: row.entity_name,
                            path: row.path || [],
                            depth: row.depth ?? null,
                          });
                          return acc;
                        }, {});
                        const groups = Object.keys(grouped)
                          .sort(sortLayers)
                          .map((label) => {
                            const key = `${breach.target_fqn}::${label}`;
                            const items = grouped[label];
                            const filteredItems = items;
                            const isOpen = impactGroupOpen[key];
                            const visibleItems = isOpen
                              ? filteredItems
                              : filteredItems.slice(0, impactLimit);
                            const hasMore = filteredItems.length > impactLimit;
                            return (
                              <div key={label} className="order-impact-group">
                                <div className="order-impact-group-title">
                                  <span>{label}</span>
                                  <span className="order-impact-badge">
                                    {items.length}
                                  </span>
                                </div>
                                <div className="order-impact-list">
                                  {visibleItems.map((item) => (
                                    <div key={item.fqn} className="order-impact-item">
                                      <span className="mono" title={item.fqn}>{item.fqn}</span>
                                      <span className="muted">{item.entity || "—"}</span>
                                      <span className="order-impact-path">
                                        {item.path && item.path.length > 2
                                          ? `через ${item.path.slice(1, -1).join(" → ")}`
                                          : item.path
                                            ? "прямая зависимость"
                                            : "—"}
                                      </span>
                                    </div>
                                  ))}
                                </div>
                                {hasMore && (
                                  <button
                                    className="order-impact-more"
                                    onClick={() => toggleImpactGroup(breach.target_fqn, label)}
                                  >
                                    {isOpen ? "Свернуть список" : `Показать все (${filteredItems.length})`}
                                  </button>
                                )}
                              </div>
                            );
                          })
                        return (
                          <>
                            <div className="order-impact-note muted">
                              Список включает косвенные зависимости. Для каждой таблицы показан путь от источника.
                            </div>
                            <div className="order-runbook">
                              <div className="order-runbook-title">Перезапуск сущностей</div>
                              <div className="muted order-runbook-sub">
                                Рекомендуемый порядок для пересчёта после {breach.target_fqn}
                              </div>
                              <ol className="order-runbook-list">
                                {visibleEntities.map((entity, idx) => (
                                  <li key={entity.key} className="order-runbook-item">
                                    <div className="order-runbook-head">
                                      <span className="order-runbook-step">{idx + 1}</span>
                                      <span className="order-runbook-name" title={entity.name}>
                                        {entity.name}
                                      </span>
                                      <span className="order-runbook-layers">
                                        {entity.layers.map((layer) => (
                                          <span key={layer} className="order-runbook-layer">
                                            {layer}
                                          </span>
                                        ))}
                                      </span>
                                    </div>
                                    <div className="order-runbook-meta">
                                      Таблиц: {entity.tables.length} · ближайшая зависимость: {entity.minDepth} шаг
                                    </div>
                                    <div className="order-runbook-tables">
                                      {entity.tables.slice(0, 3).map((table) => (
                                        <span key={table.fqn} className="order-runbook-table" title={table.fqn}>
                                          {table.fqn}
                                        </span>
                                      ))}
                                      {entity.tables.length > 3 && (
                                        <span className="order-runbook-more">
                                          +{entity.tables.length - 3}
                                        </span>
                                      )}
                                    </div>
                                  </li>
                                ))}
                              </ol>
                              {entityList.length > entityLimit && (
                                <button
                                  className="order-impact-more"
                                  onClick={() => toggleImpactEntities(breach.target_fqn)}
                                >
                                  {showAllEntities
                                    ? "Свернуть список"
                                    : `Показать все сущности (${entityList.length})`}
                                </button>
                              )}
                            </div>
                            <div className="order-impact-grid">
                              {groups}
                            </div>
                          </>
                        );
                      })()}
                  </div>
                )}
              </article>
            ))}
          </div>
        </section>
      )}

      {/* ===== ENTITY CYCLES ===== */}
      {!loading && (entityCycles.length > 0 || entityMutual.length > 0) && (
        <section className="cc-surface">
          <div className="section-title">
            Циклические зависимости сущностей
            <span className="section-meta">
              {entityCycles.length + entityMutual.length}
            </span>
          </div>
          <div className="order-list">
            {entityCycles.slice(0, 4).map((cycle, idx) => (
              <article key={`cycle-${idx}`} className="order-row">
                <header className="order-row-header">
                  <div>
                    <div className="order-row-target mono">Цикл</div>
                    <div className="order-row-meta">
                      Сущностей: {cycle.size}
                    </div>
                  </div>
                  <div className="order-pill order-pill-warning">CYCLE</div>
                </header>
                <div className="order-row-chain">
                  {cycle.nodes.slice(0, 6).map((node, i) => (
                    <span key={`${node}-${i}`} className="order-node mono">{node}</span>
                  ))}
                  {cycle.nodes.length > 6 && <span className="order-node">…</span>}
                </div>
              </article>
            ))}
            {entityMutual.slice(0, 4).map((pair, idx) => {
              const key = `${pair.a}::${pair.b}`;
              return (
              <article key={`mutual-${idx}`} className="order-row">
                <header className="order-row-header">
                  <div>
                    <div className="order-row-target mono">Взаимозависимость</div>
                    <div className="order-row-meta">
                      {pair.a} ↔ {pair.b}
                    </div>
                  </div>
                  <div className="order-pill order-pill-warning">MUTUAL</div>
                </header>
                <div className="order-row-chain">
                  <span className="order-node mono">{pair.a}</span>
                  <span className="order-arrow">↔</span>
                  <span className="order-node mono">{pair.b}</span>
                </div>
                <div className="order-row-actions">
                  <button className="btn btn-ghost" onClick={() => toggleEntityLink(key)}>
                    {entityLinkOpen[key] ? "Скрыть таблицы" : "Показать таблицы"}
                  </button>
                  <div className="muted">{pair.edges_count || 0} связей</div>
                </div>
                {entityLinkOpen[key] && (
                  <div className="order-impact">
                    <div className="order-impact-title">Связующие таблицы</div>
                    <div className="order-row-chain" style={{ flexWrap: "wrap", gap: 8 }}>
                      {(pair.edges_sample || []).map((edge, edgeIdx) => (
                        <span key={`${edge.source}-${edge.target}-${edgeIdx}`} className="order-node mono">
                          <button
                            className="btn btn-ghost"
                            onClick={() => onSelectTable({ view: "table_info", table: edge.source }, "home")}
                          >
                            {edge.source}
                          </button>
                          <span className="order-arrow">→</span>
                          <button
                            className="btn btn-ghost"
                            onClick={() => onSelectTable({ view: "table_info", table: edge.target }, "home")}
                          >
                            {edge.target}
                          </button>
                        </span>
                      ))}
                      {!pair.edges_sample?.length && <span className="muted">Нет примеров</span>}
                    </div>
                    <div className="order-row-chain" style={{ marginTop: 8 }}>
                      <span className="order-node mono" style={{ borderColor: "#38bdf8" }}>{pair.a}</span>
                      <span className="order-arrow">источник → потребитель</span>
                      <span className="order-node mono" style={{ borderColor: "#f97316" }}>{pair.b}</span>
                    </div>
                  </div>
                )}
              </article>
            )})}
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
          <div className="muted" style={{ marginBottom: 12 }}>
            Клик по строке откроет карточку инцидента.
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
