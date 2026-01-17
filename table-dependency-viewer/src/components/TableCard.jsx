import { useEffect, useMemo, useRef, useState } from "react";
import "../style/app.css";
import GraphViewer from "./GraphViewer.jsx";
import GanttChart from "./GanttChart.jsx";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";
const DEFAULT_GRAPH_DEPTH = 3;
const DEFAULT_GRAPH_MAX_EDGES = 1200;

export default function TableCard({
  schema,
  tableName,
  onBack,
  setSchema,
  setTableName,
  autoShowGraph = false,
  tableContext = null,
}) {
  const [meta, setMeta] = useState(null);
  const [loadingMeta, setLoadingMeta] = useState(false);
  const [error, setError] = useState(null);

  const [edges, setEdges] = useState([]);
  const [centralNode, setCentralNode] = useState("");
  const [loadingDeps, setLoadingDeps] = useState(false);
  const [depsError, setDepsError] = useState(null);
  const [showGraph, setShowGraph] = useState(false);
  const [showList, setShowList] = useState(false);
  const [graphTooLarge, setGraphTooLarge] = useState(false);
  const [graphStats, setGraphStats] = useState({ nodes: 0, edges: 0 });
  const [graphTruncated, setGraphTruncated] = useState(false);
  const [fullList, setFullList] = useState(null);
  const [listLoading, setListLoading] = useState(false);
  const [listError, setListError] = useState(null);
  const [listTruncated, setListTruncated] = useState(false);
  const [showGantt, setShowGantt] = useState(false);
  const [activeSqlBlock, setActiveSqlBlock] = useState(null);
  const [isSqlModalOpen, setSqlModalOpen] = useState(false);

  useEffect(() => {
    if (!schema || !tableName) return;

    setLoadingMeta(true);
    setError(null);

    fetch(`${API_BASE}/api/card/${schema}/${tableName}`)
      .then((res) => {
        if (!res.ok) throw new Error("Не удалось получить метаданные таблицы");
        return res.json();
      })
      .then(setMeta)
      .catch((err) => setError(err.message || String(err)))
      .finally(() => setLoadingMeta(false));
  }, [schema, tableName]);

  const status = useMemo(() => {
    if (!meta) return "ok";
    if (meta.avg_duration_minutes && meta.avg_duration_minutes > 5) {
      return "risk";
    }
    return "ok";
  }, [meta]);

  const healthBadge = useMemo(() => {
    if (!tableContext?.status) return null;
    switch (tableContext.status) {
      case "slow_unstable":
        return { label: "Slow & Unstable", tone: "danger" };
      case "slow":
        return { label: "Slow", tone: "danger" };
      case "unstable":
        return { label: "Unstable", tone: "warn" };
      case "low_sample":
        return { label: "Low Sample", tone: "muted" };
      default:
        return { label: "OK", tone: "ok" };
    }
  }, [tableContext]);

  const fmt = (value) => (Number.isFinite(value) ? value.toFixed(2) : "—");

  const tableFqn = meta
    ? `${meta.table_schema}.${meta.table_name}`
    : schema && tableName
    ? `${schema}.${tableName}`
    : "";

  const metrics = useMemo(() => {
    if (!meta) return [];
    return [
      {
        label: "Последняя загрузка",
        value: meta.last_success_time || "—",
        hint: "по данным логов",
      },
      {
        label: "Средняя длительность",
        value:
          meta.avg_duration_minutes !== null && meta.avg_duration_minutes !== undefined
            ? `${meta.avg_duration_minutes} мин`
            : "—",
        hint: "только успешные загрузки",
      },
      {
        label: "Режим загрузки",
        value: meta.table_load_mode || "—",
        hint: "конфигурация ETL",
      },
      {
        label: "Размер таблицы",
        value:
          meta.table_size_mb !== null && meta.table_size_mb !== undefined
            ? `${meta.table_size_mb} MB`
            : "—",
        hint: "оценка PostgreSQL",
      },
    ];
  }, [meta]);

  const sqlSections = useMemo(() => {
    if (!meta) return [];
    return [
      { title: "SQL: insert", sql: meta.sql_query_insert_init_sql },
      { title: "SQL: recreate", sql: meta.sql_query_recreate_init_sql },
      { title: "SQL: truncate", sql: meta.sql_query_truncate_sql },
    ];
  }, [meta]);

  const copySql = (sql) => {
    if (!sql) return;
    navigator.clipboard.writeText(sql).catch(() => {});
  };

  const openSqlModal = (block) => {
    if (!block.sql) return;
    setActiveSqlBlock(block);
    setSqlModalOpen(true);
  };

  const closeSqlModal = () => {
    setSqlModalOpen(false);
    setActiveSqlBlock(null);
  };

  useEffect(() => {
    const handleKey = (e) => {
      if (e.key === "Escape") {
        closeSqlModal();
      }
    };

    if (isSqlModalOpen) {
      document.body.style.overflow = "hidden";
      window.addEventListener("keydown", handleKey);
    } else {
      document.body.style.overflow = "";
    }

    return () => {
      window.removeEventListener("keydown", handleKey);
      document.body.style.overflow = "";
    };
  }, [isSqlModalOpen]);

  const loadDependencies = ({ full = false } = {}) => {
    if (!schema || !tableName) return;
    setLoadingDeps(true);
    setDepsError(null);
    setShowGraph(false);
    setShowList(false);
    setGraphTooLarge(false);
    setGraphTruncated(false);
    setFullList(null);
    setListLoading(false);
    setListError(null);
    setListTruncated(false);

    const params = new URLSearchParams();
    if (!full) {
      params.set("max_depth", String(DEFAULT_GRAPH_DEPTH));
      params.set("max_edges", String(DEFAULT_GRAPH_MAX_EDGES));
    }
    const query = params.toString();
    const url = `${API_BASE}/api/dependencies-graph/${schema}/${tableName}${query ? `?${query}` : ""}`;

    fetch(url)
      .then((res) =>
        res.ok ? res.json() : Promise.reject("Не удалось построить граф зависимостей"),
      )
      .then((data) => {
        const incomingEdges = Array.isArray(data.edges) ? data.edges : [];
        const resolvedCentral =
          data.centralNode || data.central_node || `${schema}.${tableName}`;
        const nodeSet = new Set([resolvedCentral]);
        incomingEdges.forEach((edge) => {
          if (edge?.source) nodeSet.add(edge.source);
          if (edge?.target) nodeSet.add(edge.target);
        });
        const stats = { nodes: nodeSet.size, edges: incomingEdges.length };
        setGraphStats(stats);
        setEdges(incomingEdges);
        setCentralNode(resolvedCentral);
        const isTooLarge = stats.nodes > 350 || stats.edges > 800;
        setGraphTooLarge(isTooLarge);
        setGraphTruncated(Boolean(data.truncated));
        setShowGraph(!isTooLarge);
      })
      .catch((err) => {
        console.error(err);
        setDepsError(typeof err === "string" ? err : "Ошибка загрузки графа");
      })
      .finally(() => setLoadingDeps(false));
  };

  const autoGraphRef = useRef({ key: "", fired: false });
  useEffect(() => {
    if (!schema || !tableName) return;
    const key = `${schema}.${tableName}`;
    if (autoGraphRef.current.key !== key) {
      autoGraphRef.current = { key, fired: false };
    }
    if (autoShowGraph && !autoGraphRef.current.fired) {
      autoGraphRef.current.fired = true;
      loadDependencies();
    }
  }, [schema, tableName, autoShowGraph]);

  useEffect(() => {
    if (!showList || !schema || !tableName || fullList) return;
    if (!graphTruncated && !graphTooLarge) return;
    setListLoading(true);
    setListError(null);

    fetch(`${API_BASE}/api/dependencies-nodes/${schema}/${tableName}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить список таблиц")))
      .then((data) => {
        const nodes = Array.isArray(data.nodes) ? data.nodes : [];
        setFullList(nodes.slice().sort((a, b) => a.localeCompare(b)));
        setListTruncated(Boolean(data.truncated));
      })
      .catch((err) => {
        setListError(typeof err === "string" ? err : "Ошибка загрузки списка");
      })
      .finally(() => setListLoading(false));
  }, [showList, graphTruncated, schema, tableName, fullList]);

  const tableListFromEdges = useMemo(() => {
    const all = new Set();
    if (centralNode) {
      all.add(centralNode);
    }
    edges.forEach((e) => {
      all.add(e.source);
      all.add(e.target);
    });
    return Array.from(all).sort();
  }, [edges, centralNode]);

  const listToShow = fullList || tableListFromEdges;

  const copyList = () => {
    if (!listToShow.length) return;
    navigator.clipboard.writeText(listToShow.join("\n"));
    alert("Список таблиц скопирован");
  };

  const handleNodeClick = (newSchema, newTable) => {
    setShowGraph(false);
    setEdges([]);
    setCentralNode("");
    setGraphTooLarge(false);
    setGraphStats({ nodes: 0, edges: 0 });
    setGraphTruncated(false);
    setFullList(null);
    setListLoading(false);
    setListError(null);
    setListTruncated(false);
    setSchema(newSchema);
    setTableName(newTable);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  if (error) {
    return (
      <div className="table-page">
        <div className="card dep-error">
          <div className="dep-error-title">Не удалось загрузить карточку</div>
          <div className="muted">{error}</div>
          <div style={{ marginTop: 12 }}>
            <button className="btn" onClick={onBack}>
              ← Назад
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (loadingMeta || !meta) {
    return (
      <div className="table-page">
        <div className="card muted">Загружаем карточку таблицы…</div>
      </div>
    );
  }

  return (
    <div className="table-page">
      <div className="table-header">
        <button className="btn" onClick={onBack}>
          ← Назад
        </button>
        <div className="table-head-main">
          <div className="table-head-label">Таблица</div>
          <div className="table-title">{tableFqn}</div>
          <div className="table-head-meta">
            <span>{meta.entity_name || "—"}</span>
            <span>ID {meta.table_id ?? "—"}</span>
          </div>
        </div>
        <div className={`table-status ${status}`}>
          {status === "risk" ? "RISK" : "OK"}
        </div>
      </div>

      {tableContext && (
        <div className="table-health-card">
          <div className="table-health-header">
            <div>
              <div className="table-health-title">Состояние загрузки</div>
              <div className="table-health-subtitle muted">
                По анализу успешных запусков в Slow/Unstable.
              </div>
            </div>
            {healthBadge && (
              <span className={`table-health-pill ${healthBadge.tone}`}>
                {healthBadge.label}
              </span>
            )}
          </div>
          <div className="table-health-metrics">
            <div>
              <div className="table-health-label">Runs</div>
              <div className="table-health-value">{tableContext.runs_count ?? "—"}</div>
            </div>
            <div>
              <div className="table-health-label">P95</div>
              <div className="table-health-value">{fmt(tableContext.p95_duration)}</div>
            </div>
            <div>
              <div className="table-health-label">CV</div>
              <div className="table-health-value">{fmt(tableContext.cv)}</div>
            </div>
            <div>
              <div className="table-health-label">P95/AVG</div>
              <div className="table-health-value">{fmt(tableContext.p95_avg_ratio)}</div>
            </div>
          </div>
          {tableContext.low_sample && (
            <div className="table-health-note">
              Мало запусков для стабильной оценки — используйте с осторожностью.
            </div>
          )}
        </div>
      )}

      <div className="table-grid">
        {metrics.map((metric) => (
          <div key={metric.label} className="table-info-card">
            <div className="table-card-label">{metric.label}</div>
            <div className="table-card-value">{metric.value}</div>
            <div className="table-card-hint muted">{metric.hint}</div>
          </div>
        ))}

        <div className="table-info-card table-actions">
          <div className="table-card-label">Действия</div>
          <div className="table-action-buttons">
            <button className="btn btn-secondary" onClick={loadDependencies}>
              Показать граф зависимостей
            </button>
            <button
              className="btn btn-secondary"
              onClick={() => setShowGantt(!showGantt)}
            >
              {showGantt ? "Скрыть диаграмму" : "Хронология загрузок"}
            </button>
            <button
              className="btn btn-secondary"
              onClick={copyList}
              disabled={!listToShow.length}
            >
              Скопировать список
            </button>
            <button className="btn" onClick={onBack}>
              Вернуться
            </button>
          </div>
        </div>
      </div>

      <div className="table-section">
        <div className="section-title">SQL-скрипты</div>
        <div className="table-sql-grid">
          {sqlSections.map((block) => {
            const hasSql = Boolean(block.sql && block.sql.length);
            const lines = block.sql ? block.sql.split("\n") : [];
            return (
              <div key={block.title} className="table-sql-card">
                <div className="table-sql-row">
                  <div className="table-sql-type-block">
                    <div className="table-sql-type mono">{block.title}</div>
                    <div className="table-sql-meta muted">
                      {hasSql ? `${lines.length} строк · ${block.sql.length} символов` : "Скрипт отсутствует"}
                    </div>
                  </div>
                  <div className="table-sql-actions">
                    <button
                      className="btn btn-secondary"
                      onClick={() => openSqlModal(block)}
                      disabled={!hasSql}
                    >
                      Показать
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      <div className="table-section">
        <div className="section-title">Граф зависимостей</div>
        <div className="card">
          {loadingDeps && <div className="muted">Строим граф…</div>}
          {depsError && (
            <div className="dep-error-title">{depsError}</div>
          )}
          {!loadingDeps && !depsError && !showGraph && (
            <div className="muted">Нажмите «Показать граф зависимостей», чтобы отрисовать схему.</div>
          )}
          {!loadingDeps && !depsError && graphTruncated && (
            <div className="card dep-error" style={{ marginTop: 12 }}>
              <div className="dep-error-title">Показан укороченный граф</div>
              <div className="muted">
                Ограничение: глубина {DEFAULT_GRAPH_DEPTH}, связей до {DEFAULT_GRAPH_MAX_EDGES}.
              </div>
              <div className="table-graph-actions" style={{ marginTop: 10 }}>
                <button className="btn btn-secondary" onClick={() => loadDependencies({ full: true })}>
                  Загрузить полный граф
                </button>
              </div>
            </div>
          )}
          {!loadingDeps && !depsError && graphTooLarge && (
            <div className="card dep-error" style={{ marginTop: 12 }}>
              <div className="dep-error-title">Граф слишком большой</div>
              <div className="muted">
                Узлов: {graphStats.nodes}, связей: {graphStats.edges}. В проде это может зависать.
              </div>
              <div className="table-graph-actions" style={{ marginTop: 10 }}>
                <button className="btn btn-secondary" onClick={() => setShowGraph(true)}>
                  Показать граф всё равно
                </button>
                <button className="btn" onClick={() => setShowList(true)}>
                  Показать список
                </button>
              </div>
            </div>
          )}

          {showGraph && edges.length > 0 && (
            <GraphViewer
              centralNode={centralNode}
              edges={edges}
              onNodeClick={handleNodeClick}
              onRequestFull={() => loadDependencies({ full: true })}
            />
          )}

          {(showGraph || showList) && (
            <div className="table-graph-actions">
              <button className="btn" onClick={() => setShowList(!showList)}>
                {showList ? "Скрыть список" : "Показать список"}
              </button>
              {showList && (
                <div style={{ width: "100%" }}>
                  {listLoading && <div className="muted" style={{ marginTop: 10 }}>Готовим полный список…</div>}
                  {!listLoading && listError && (
                    <div className="dep-error-title" style={{ marginTop: 10 }}>{listError}</div>
                  )}
                  {!listLoading && !listError && listTruncated && (
                    <div className="muted" style={{ marginTop: 10 }}>
                      Список может быть неполным — достигнут лимит.
                    </div>
                  )}
                  {!listLoading && !listError && (
                    <pre className="table-code" style={{ marginTop: 12 }}>
                      {listToShow.length ? listToShow.join("\n") : "—"}
                    </pre>
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {showGantt && (
        <div className="table-section">
          <div className="section-title">Хронология загрузок</div>
          <div className="card">
            <GanttChart schema={schema} table={tableName} />
          </div>
        </div>
      )}

      {isSqlModalOpen && activeSqlBlock && (
        <div className="sql-modal-overlay" onClick={closeSqlModal}>
          <div className="sql-modal" onClick={(e) => e.stopPropagation()}>
            <div className="sql-modal-header">
              <div>
                <div className="sql-modal-type">{activeSqlBlock.title}</div>
                <div className="sql-modal-meta">
                  {tableFqn} · {activeSqlBlock.sql?.split("\n").length || 0} строк
                </div>
              </div>
              <div className="sql-modal-actions">
                <span className="sql-modal-hint">Используйте Ctrl+F для поиска</span>
                <button
                  className="btn btn-secondary"
                  onClick={() => copySql(activeSqlBlock.sql)}
                >
                  Копировать
                </button>
                <button className="btn btn-ghost" onClick={closeSqlModal}>
                  ✕
                </button>
              </div>
            </div>
            <div className="sql-modal-body">
              <div className="sql-modal-code">
                {(activeSqlBlock.sql || "").split("\n").map((line, idx) => (
                  <div className="sql-line" key={idx}>
                    <span className="sql-line-number">{idx + 1}</span>
                    <span className="sql-line-text">{line || " "}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
