import { useEffect, useMemo, useState } from "react";
import "../style/app.css";
import GraphViewer from "./GraphViewer.jsx";
import GanttChart from "./GanttChart.jsx";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function TableCard({
  schema,
  tableName,
  onBack,
  setSchema,
  setTableName,
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

  const loadDependencies = () => {
    if (!schema || !tableName) return;
    setLoadingDeps(true);
    setDepsError(null);
    setShowGraph(false);
    setShowList(false);

    fetch(`${API_BASE}/api/dependencies-graph/${schema}/${tableName}`)
      .then((res) =>
        res.ok ? res.json() : Promise.reject("Не удалось построить граф зависимостей"),
      )
      .then((data) => {
        setEdges(data.edges || []);
        setCentralNode(data.central_node || `${schema}.${tableName}`);
        setShowGraph(true);
      })
      .catch((err) => {
        console.error(err);
        setDepsError(typeof err === "string" ? err : "Ошибка загрузки графа");
      })
      .finally(() => setLoadingDeps(false));
  };

  const tableList = useMemo(() => {
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

  const copyList = () => {
    if (!tableList.length) return;
    navigator.clipboard.writeText(tableList.join("\n"));
    alert("Список таблиц скопирован");
  };

  const handleNodeClick = (newSchema, newTable) => {
    setShowGraph(false);
    setEdges([]);
    setCentralNode("");
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
              disabled={!tableList.length}
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

          {showGraph && edges.length > 0 && (
            <GraphViewer
              centralNode={centralNode}
              edges={edges}
              onNodeClick={handleNodeClick}
            />
          )}

          {showGraph && (
            <div className="table-graph-actions">
              <button className="btn" onClick={() => setShowList(!showList)}>
                {showList ? "Скрыть список" : "Показать список"}
              </button>
              {showList && (
                <pre className="table-code" style={{ marginTop: 12 }}>
                  {tableList.length ? tableList.join("\n") : "—"}
                </pre>
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
