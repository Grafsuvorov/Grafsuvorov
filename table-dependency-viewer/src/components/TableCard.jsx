import { useEffect, useMemo, useRef, useState } from "react";
import "../style/app.css";
import GraphViewer from "./GraphViewer.jsx";
import GanttChart from "./GanttChart.jsx";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function TableCard({
  schema,
  tableName,
  onBack,
  onNavigateTable,
  onOpenImpact,
  autoShowGraph = false,
  tableContext = null,
}) {
  const [meta, setMeta] = useState(null);
  const [loadingMeta, setLoadingMeta] = useState(false);
  const [error, setError] = useState(null);

  const [edges, setEdges] = useState([]);
  const [graphNodes, setGraphNodes] = useState([]);
  const [graphLayout, setGraphLayout] = useState({});
  const [centralNode, setCentralNode] = useState("");
  const [loadingDeps, setLoadingDeps] = useState(false);
  const [depsError, setDepsError] = useState(null);
  const [showGraph, setShowGraph] = useState(false);
  const [showList, setShowList] = useState(false);
  const [graphTooLarge, setGraphTooLarge] = useState(false);
  const [graphStats, setGraphStats] = useState({ nodes: 0, edges: 0 });
  const [graphTruncated, setGraphTruncated] = useState(false);
  const [showGantt, setShowGantt] = useState(false);
  const [activeSqlBlock, setActiveSqlBlock] = useState(null);
  const [isSqlModalOpen, setSqlModalOpen] = useState(false);
  const [historyRows, setHistoryRows] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyError, setHistoryError] = useState(null);
  const [variants, setVariants] = useState([]);
  const [variantsLoading, setVariantsLoading] = useState(false);
  const [variantsError, setVariantsError] = useState(null);
  const [dqData, setDqData] = useState(null);
  const [dqLoading, setDqLoading] = useState(false);
  const [dqError, setDqError] = useState(null);
  const [dqHistory, setDqHistory] = useState([]);
  const [dqHistoryLoading, setDqHistoryLoading] = useState(false);
  const [dqHistoryError, setDqHistoryError] = useState(null);
  const [showDqHistory, setShowDqHistory] = useState(false);
  const [clickRuns, setClickRuns] = useState([]);
  const [clickStages, setClickStages] = useState([]);
  const [clickLoading, setClickLoading] = useState(false);
  const [clickError, setClickError] = useState(null);
  const [clickMeta, setClickMeta] = useState(null);
  const [clickMetaLoading, setClickMetaLoading] = useState(false);
  const [clickMetaError, setClickMetaError] = useState(null);

  useEffect(() => {
    if (!schema || !tableName) return;

    setLoadingMeta(true);
    setError(null);

    fetch(`${API_BASE}/api/card/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}`)
      .then((res) => {
        if (!res.ok) throw new Error("Не удалось загрузить карточку таблицы");
        return res.json();
      })
      .then(setMeta)
      .catch((err) => setError(err.message || String(err)))
      .finally(() => setLoadingMeta(false));
  }, [schema, tableName]);

  useEffect(() => {
    if (!schema || !tableName) return;
    setHistoryLoading(true);
    setHistoryError(null);
    fetch(`${API_BASE}/api/table-history/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}?limit=10`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить историю запусков")))
      .then((data) => setHistoryRows(Array.isArray(data) ? data : []))
      .catch((err) => {
        console.error(err);
        setHistoryError(typeof err === "string" ? err : "Не удалось загрузить историю запусков");
      })
      .finally(() => setHistoryLoading(false));
  }, [schema, tableName]);

  useEffect(() => {
    if (!schema || !tableName) return;
    setVariantsLoading(true);
    setVariantsError(null);
    fetch(`${API_BASE}/api/table-variants/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить варианты таблицы")))
      .then((data) => setVariants(Array.isArray(data) ? data : []))
      .catch((err) => {
        console.error(err);
        setVariantsError(typeof err === "string" ? err : "Не удалось загрузить варианты таблицы");
      })
      .finally(() => setVariantsLoading(false));
  }, [schema, tableName]);

  useEffect(() => {
    if (!schema || !tableName) return;
    setDqLoading(true);
    setDqError(null);
    fetch(`${API_BASE}/api/dq/table/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить качество данных")))
      .then((data) => setDqData(data))
      .catch((err) => {
        console.error(err);
        setDqError(typeof err === "string" ? err : "Не удалось загрузить качество данных");
      })
      .finally(() => setDqLoading(false));
  }, [schema, tableName]);

  useEffect(() => {
    if (!schema || !tableName) return;
    setDqHistoryLoading(true);
    setDqHistoryError(null);
    fetch(`${API_BASE}/api/dq/history/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}?limit=20`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить историю качества данных")))
      .then((data) => setDqHistory(Array.isArray(data) ? data : []))
      .catch((err) => {
        console.error(err);
        setDqHistoryError(typeof err === "string" ? err : "Не удалось загрузить историю качества данных");
      })
      .finally(() => setDqHistoryLoading(false));
  }, [schema, tableName]);

  useEffect(() => {
    if (!schema || !tableName) return;
    setClickLoading(true);
    setClickError(null);
    fetch(`${API_BASE}/api/click/table/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}?limit=6`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить ClickHouse-логи")))
      .then((data) => {
        setClickRuns(Array.isArray(data?.runs) ? data.runs : []);
        setClickStages(Array.isArray(data?.stages) ? data.stages : []);
      })
      .catch((err) => {
        console.error(err);
        setClickError(typeof err === "string" ? err : "Не удалось загрузить ClickHouse-логи");
      })
      .finally(() => setClickLoading(false));
  }, [schema, tableName]);

  useEffect(() => {
    if (!schema || !tableName) return;
    setClickMetaLoading(true);
    setClickMetaError(null);
    fetch(`${API_BASE}/api/click/meta/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}`)
      .then((res) => {
        if (res.status === 404) return null;
        if (!res.ok) throw new Error("Не удалось загрузить ClickHouse-метаданные");
        return res.json();
      })
      .then((data) => setClickMeta(data || null))
      .catch((err) => {
        console.error(err);
        setClickMetaError(typeof err === "string" ? err : "Не удалось загрузить ClickHouse-метаданные");
      })
      .finally(() => setClickMetaLoading(false));
  }, [schema, tableName]);

  const status = useMemo(() => {
    if (!meta) return "ok";
    const avg = meta.avg_duration_minutes;
    if (avg && avg > 20) return "risk";
    if (avg && avg > 10) return "warn";
    return "ok";
  }, [meta]);

  const healthBadge = useMemo(() => {
    if (!tableContext?.status) return null;
    switch (tableContext.status) {
      case "slow_unstable":
        return { label: "Медленно и нестабильно", tone: "danger" };
      case "slow":
        return { label: "Медленно", tone: "danger" };
      case "unstable":
        return { label: "Нестабильно", tone: "warn" };
      case "low_sample":
        return { label: "Мало запусков", tone: "muted" };
      default:
        return { label: "OK", tone: "ok" };
    }
  }, [tableContext]);

  const fmt = (value) => (Number.isFinite(value) ? value.toFixed(2) : "—");
  const fmtInt = (value) => (Number.isFinite(value) ? Math.round(value).toLocaleString("ru-RU") : "—");
  const fmtPct = (value) => (Number.isFinite(value) ? `${value > 0 ? "+" : ""}${value.toFixed(1)}%` : "—");

  const tableFqn = meta
    ? `${meta.table_schema}.${meta.table_name}`
    : schema && tableName
    ? `${schema}.${tableName}`
    : "";

  const metrics = useMemo(() => {
    if (!meta) return [];
    return [
      {
        label: "Последняя успешная загрузка",
        value: meta.last_success_time || "—",
        hint: "по логам",
      },
      {
        label: "Средняя длительность",
        value:
          meta.avg_duration_minutes !== null && meta.avg_duration_minutes !== undefined
            ? `${meta.avg_duration_minutes} мин`
            : "—",
        hint: "только успешные",
      },
      {
        label: "Режим загрузки",
        value: meta.table_load_mode || "—",
        hint: "настройка ETL",
      },
      {
        label: "Размер таблицы",
        value:
          meta.table_size_mb !== null && meta.table_size_mb !== undefined
            ? `${meta.table_size_mb} MB`
            : "—",
        hint: "оценка БД",
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

  const clickLastRun = clickRuns[0] || null;
  const clickStatusLabel = (status) => {
    switch (status) {
      case "SUCCESS":
        return "Успешно";
      case "FAILED":
        return "Ошибка";
      case "RUNNING":
        return "В процессе";
      case "UP_FOR_RETRY":
        return "Повтор";
      default:
        return status || "—";
    }
  };

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
    setGraphTooLarge(false);
    setGraphTruncated(false);
    setGraphNodes([]);
    setGraphLayout({});

    fetch(`${API_BASE}/api/graph/table/${schema}/${tableName}?depth=3`)
      .then((res) =>
        res.ok ? res.json() : Promise.reject("Не удалось построить граф зависимостей"),
      )
      .then((data) => {
        const nodes = Array.isArray(data.nodes) ? data.nodes : [];
        const incomingEdges = Array.isArray(data.edges) ? data.edges : [];
        const resolvedCentral = data?.table?.id || `${schema}.${tableName}`;
        const stats = { nodes: nodes.length, edges: incomingEdges.length };
        setGraphStats(stats);
        setEdges(incomingEdges);
        setGraphNodes(nodes);
        setGraphLayout(data.layout || {});
        setCentralNode(resolvedCentral);
        const isTooLarge = stats.nodes > 350 || stats.edges > 800;
        setGraphTooLarge(isTooLarge);
        setGraphTruncated(Boolean(data.truncated));
        setShowGraph(!isTooLarge);
      })
      .catch((err) => {
        console.error(err);
        setDepsError(typeof err === "string" ? err : "Не удалось загрузить граф");
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

  const tableList = useMemo(() => {
    return graphNodes.map((n) => n.id).filter(Boolean).sort();
  }, [graphNodes]);

  const copyList = () => {
    if (!tableList.length) return;
    navigator.clipboard.writeText(tableList.join("\n"));
    alert("Список таблиц скопирован");
  };

  const handleNodeClick = (newSchema, newTable) => {
    setShowGraph(false);
    setEdges([]);
    setGraphNodes([]);
    setGraphLayout({});
    setCentralNode("");
    setGraphTooLarge(false);
    setGraphStats({ nodes: 0, edges: 0 });
    setGraphTruncated(false);
    if (onNavigateTable) {
      onNavigateTable(newSchema, newTable);
    }
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
        <div className="card muted">Загрузка карточки...</div>
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
        <div className="table-status-wrap">
          <div className={`table-status ${status}`}>
            {status === "risk" ? "Риск" : status === "warn" ? "Внимание" : "OK"}
          </div>
          <button
            className="status-help"
            title={
              status === "risk"
                ? "Риск: средняя длительность > 20 мин по успешным загрузкам."
                : status === "warn"
                ? "Внимание: средняя длительность > 10 мин по успешным загрузкам."
                : "OK: средняя длительность ≤ 10 мин по успешным загрузкам."
            }
          >
            ?
          </button>
        </div>
      </div>

      {tableContext && (
        <div className="table-health-card">
          <div className="table-health-header">
            <div>
              <div className="table-health-title">Стабильность загрузки</div>
              <div className="table-health-subtitle muted">
                На основе успешных запусков (Slow/Unstable).
              </div>
            </div>
            {healthBadge && (
              <span className={`table-health-pill ${healthBadge.tone}`}>
                {healthBadge.label}
              </span>
            )}
          </div>
          <div className="table-health-legend">
            <span className="table-health-legend-item">
              Медленно и нестабильно: p95 &gt; 10 мин и CV &gt; 0.6
            </span>
            <span className="table-health-legend-item">
              Медленно: p95 &gt; 10 мин
            </span>
            <span className="table-health-legend-item">
              Нестабильно: CV &gt; 0.3
            </span>
            <span className="table-health-legend-item">
              Мало запусков: недостаточно данных
            </span>
          </div>
          <div className="table-health-metrics">
            <div>
              <div className="table-health-label">Запусков</div>
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
              Недостаточно запусков для уверенной оценки.
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
              Граф зависимостей
            </button>
            <button
              className="btn btn-secondary"
              onClick={() => onOpenImpact?.(schema, tableName)}
            >
              Граф влияния
            </button>
            <button
              className="btn btn-secondary"
              onClick={() => setShowGantt(!showGantt)}
            >
              {showGantt ? "Скрыть таймлайн" : "Показать таймлайн"}
            </button>
            <button
              className="btn btn-secondary"
              onClick={copyList}
              disabled={!tableList.length}
            >
              Скопировать список
            </button>
            <button className="btn" onClick={onBack}>
              Назад
            </button>
          </div>
        </div>
      </div>

      <div className="table-section">
        <div className="section-title">Качество данных</div>
        <div className="card">
          {dqLoading && <div className="muted">Загрузка качества данных...</div>}
          {dqError && <div className="dep-error-title">{dqError}</div>}
          {!dqLoading && !dqError && !dqData && (
            <div className="muted">Проверки качества не найдены.</div>
          )}
          {!dqLoading && !dqError && dqData && (
            <div className="dq-grid">
              <div className="dq-card">
                <div className="dq-label">Проверка дублей</div>
                <div className="dq-value">
                  {dqData.duplicate?.count !== null && dqData.duplicate?.count !== undefined
                    ? fmtInt(dqData.duplicate.count)
                    : "—"}
                </div>
                <div className="dq-hint muted">
                  Последняя проверка: {dqData.duplicate?.last_check || "—"}
                </div>
              </div>
              <div className="dq-card">
                <div className="dq-label">Кол-во строк</div>
                <div className="dq-value">
                  {dqData.row_count?.count !== null && dqData.row_count?.count !== undefined
                    ? fmtInt(dqData.row_count.count)
                    : "—"}
                </div>
                <div className="dq-hint muted">
                  Базовая медиана (7 проверок):{" "}
                  {dqData.row_count?.baseline_median !== null && dqData.row_count?.baseline_median !== undefined
                    ? fmtInt(dqData.row_count.baseline_median)
                    : "—"}
                  {" · "}
                  Δ {fmtPct(dqData.row_count?.delta_pct)}
                </div>
                {Number.isFinite(dqData.row_count?.delta_pct) &&
                  Math.abs(dqData.row_count.delta_pct) >= 10 && (
                    <div className="dq-alert">Отклонение больше 10%</div>
                  )}
              </div>
            </div>
          )}
          <div className="dq-history">
            <button
              className="btn btn-secondary"
              onClick={() => setShowDqHistory((prev) => !prev)}
            >
              {showDqHistory ? "Скрыть историю" : "Показать историю"}
            </button>
            {showDqHistory && (
              <>
                {dqHistoryLoading && <div className="muted">Загрузка истории качества...</div>}
                {dqHistoryError && <div className="dep-error-title">{dqHistoryError}</div>}
                {!dqHistoryLoading && !dqHistoryError && dqHistory.length === 0 && (
                  <div className="muted">Истории качества пока нет.</div>
                )}
                {!dqHistoryLoading && !dqHistoryError && dqHistory.length > 0 && (
                  <div className="dq-history-table">
                    <div className="dq-history-head">
                      <span>Проверка</span>
                      <span>Значение</span>
                      <span>Дата</span>
                    </div>
                    {dqHistory.map((row, idx) => (
                      <div key={`${row.dt || "row"}-${idx}`} className="dq-history-row">
                        <span className="dq-history-type">{row.verification_type || "—"}</span>
                        <span>{row.value !== null && row.value !== undefined ? fmtInt(row.value) : "—"}</span>
                        <span>{row.dt || "—"}</span>
                      </div>
                    ))}
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      </div>

      <div className="table-section">
        <div className="section-title">Загрузка в ClickHouse</div>
        <div className="card">
          {clickLoading && <div className="muted">Загрузка ClickHouse-логов...</div>}
          {clickError && <div className="dep-error-title">{clickError}</div>}
          {!clickLoading && !clickError && clickRuns.length === 0 && (
            <div className="muted">Запусков ClickHouse не найдено.</div>
          )}
          {!clickLoading && !clickError && clickRuns.length > 0 && (
            <>
              <div className="click-run-head">
                <div>
                  <div className="click-run-title">Последний запуск</div>
                  <div className="muted">
                    {clickLastRun?.dag_name || "—"} · {clickLastRun?.dag_run || "—"}
                  </div>
                </div>
                <div className={`click-run-status status-${String(clickLastRun?.status || "").toLowerCase()}`}>
                  {clickStatusLabel(clickLastRun?.status)}
                </div>
              </div>
              <div className="click-run-meta">
                <div>
                  <div className="click-label">Старт</div>
                  <div className="click-value">{clickLastRun?.start_dttm || "—"}</div>
                </div>
                <div>
                  <div className="click-label">Финиш</div>
                  <div className="click-value">{clickLastRun?.end_dttm || "—"}</div>
                </div>
                <div>
                  <div className="click-label">Длительность</div>
                  <div className="click-value">
                    {clickLastRun?.duration_min !== null && clickLastRun?.duration_min !== undefined
                      ? `${clickLastRun.duration_min} мин`
                      : "—"}
                  </div>
                </div>
              </div>
              {clickLastRun?.error_text && (
                <div className="click-run-error">
                  {clickLastRun.error_text}
                </div>
              )}

              {clickStages.length > 0 && (
                <div className="click-stages">
                  <div className="section-subtitle">Этапы загрузки</div>
                  <div className="click-stage-table">
                    <div className="click-stage-head">
                      <span>Этап</span>
                      <span>Старт</span>
                      <span>Финиш</span>
                      <span>Длит.</span>
                      <span>Статус</span>
                    </div>
                    {clickStages.map((stage, idx) => (
                      <div key={`${stage.stage_name}-${idx}`} className="click-stage-row">
                        <span className="mono">{stage.stage_name}</span>
                        <span>{stage.start_dttm || "—"}</span>
                        <span>{stage.end_dttm || "—"}</span>
                        <span>
                          {stage.duration_min !== null && stage.duration_min !== undefined
                            ? `${stage.duration_min} мин`
                            : "—"}
                        </span>
                        <span className={`click-stage-status status-${String(stage.status || "").toLowerCase()}`}>
                          {clickStatusLabel(stage.status)}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              <div className="click-meta-block">
                <div className="section-subtitle">ClickHouse метаданные</div>
                {clickMetaLoading && <div className="muted">Загрузка метаданных...</div>}
                {clickMetaError && <div className="dep-error-title">{clickMetaError}</div>}
                {!clickMetaLoading && !clickMetaError && !clickMeta?.meta && !clickMeta?.view_sql && (
                  <div className="muted">Метаданные не найдены.</div>
                )}
                {!clickMetaLoading && !clickMetaError && (clickMeta?.meta || clickMeta?.view_sql) && (
                  <>
                    {clickMeta?.meta && (
                      <div className="click-meta-grid">
                        <div>
                          <div className="click-label">Схема GP</div>
                          <div className="click-value">{clickMeta.meta.schema_name_gp || "—"}</div>
                        </div>
                        <div>
                          <div className="click-label">Схема ClickHouse</div>
                          <div className="click-value">{clickMeta.meta.schema_name_click || "—"}</div>
                        </div>
                        <div>
                          <div className="click-label">Тип загрузки</div>
                          <div className="click-value">{clickMeta.meta.load_type || "—"}</div>
                        </div>
                        <div>
                          <div className="click-label">Recreate</div>
                          <div className="click-value">{clickMeta.meta.recreate_mode || "—"}</div>
                        </div>
                        <div>
                          <div className="click-label">Truncate</div>
                          <div className="click-value">
                            {clickMeta.meta.truncate_mode_on !== undefined ? String(clickMeta.meta.truncate_mode_on) : "—"}
                          </div>
                        </div>
                        <div>
                          <div className="click-label">Колонки</div>
                          <div className="click-value">
                            {Array.isArray(clickMeta.meta.attributes) ? clickMeta.meta.attributes.length : "—"}
                          </div>
                        </div>
                      </div>
                    )}
                    {clickMeta?.view_sql && (
                      <div className="click-meta-actions">
                        <button
                          className="btn btn-secondary"
                          onClick={() => openSqlModal({ title: "ClickHouse VIEW", sql: clickMeta.view_sql })}
                        >
                          Открыть SQL view
                        </button>
                      </div>
                    )}
                  </>
                )}
              </div>
            </>
          )}
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
                      {hasSql ? `${lines.length} строк · ${block.sql.length} символов` : "Скрипт недоступен"}
                    </div>
                  </div>
                  <div className="table-sql-actions">
                    <button
                      className="btn btn-secondary"
                      onClick={() => openSqlModal(block)}
                      disabled={!hasSql}
                    >
                      Открыть
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      <div className="table-section">
        <div className="section-title">Последние запуски (10)</div>
        <div className="card">
          {historyLoading && <div className="muted">Загрузка запусков...</div>}
          {historyError && <div className="dep-error-title">{historyError}</div>}
          {!historyLoading && !historyError && historyRows.length === 0 && (
            <div className="muted">Запусков не найдено.</div>
          )}
          {!historyLoading && !historyError && historyRows.length > 0 && (
            <div className="history-table">
              <div className="history-table-head">
                <span>Статус</span>
                <span>Старт</span>
                <span>Финиш</span>
                <span>Длит.</span>
                <span>Сообщение</span>
              </div>
              {historyRows.map((row, idx) => (
                <div key={`${row.finish || "row"}-${idx}`} className="history-table-row">
                  <span className={`history-state history-${String(row.state || "unknown").toLowerCase()}`}>
                    {row.state || "UNKNOWN"}
                  </span>
                  <span>{row.start || "—"}</span>
                  <span>{row.finish || "—"}</span>
                  <span>{row.duration_minutes ?? "—"} мин</span>
                  <span className="history-message">{row.message || "—"}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="table-section">
        <div className="section-title">Варианты таблицы (другие сущности)</div>
        <div className="card">
          {variantsLoading && <div className="muted">Загрузка вариантов...</div>}
          {variantsError && <div className="dep-error-title">{variantsError}</div>}
          {!variantsLoading && !variantsError && variants.length <= 1 && (
            <div className="muted">Других вариантов нет.</div>
          )}
          {!variantsLoading && !variantsError && variants.length > 1 && (
            <div className="variants-table">
              <div className="variants-table-head">
                <span>Сущность</span>
                <span>ID таблицы</span>
                <span>Последняя загрузка</span>
              </div>
              {variants.map((row) => (
                <div key={`${row.entity_id}-${row.table_id}`} className="variants-table-row">
                  <span className="mono">{row.entity_name || "—"}</span>
                  <span>{row.table_id ?? "—"}</span>
                  <span>{row.table_last_load || "—"}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {Array.isArray(meta.key_attributes) && meta.key_attributes.length > 0 && (
        <div className="table-section">
          <div className="section-title">Ключевые поля</div>
          <div className="card">
            <div className="table-key-list">
              {meta.key_attributes.map((key) => (
                <span key={key} className="table-key-pill mono">
                  {key}
                </span>
              ))}
            </div>
          </div>
        </div>
      )}

      <div className="table-section">
        <div className="section-title">Граф зависимостей</div>
        <div className="card">
          {loadingDeps && <div className="muted">Построение графа...</div>}
          {depsError && (
            <div className="dep-error-title">{depsError}</div>
          )}
          {!loadingDeps && !depsError && !showGraph && (
            <div className="muted">Нажмите «Граф зависимостей», чтобы построить.</div>
          )}
          {!loadingDeps && !depsError && graphTruncated && (
            <div className="card dep-error" style={{ marginTop: 12 }}>
              <div className="dep-error-title">Граф усечён</div>
              <div className="muted">
                Ограничение глубины. Для полного обзора используйте граф сущности.
              </div>
            </div>
          )}
          {!loadingDeps && !depsError && graphTooLarge && (
            <div className="card dep-error" style={{ marginTop: 12 }}>
              <div className="dep-error-title">Слишком большой граф</div>
              <div className="muted">
                Узлов: {graphStats.nodes}, связей: {graphStats.edges}. Может подвисать.
              </div>
              <div className="table-graph-actions" style={{ marginTop: 10 }}>
                <button className="btn btn-secondary" onClick={() => setShowGraph(true)}>
                  Отрисовать
                </button>
                <button className="btn" onClick={() => setShowList(true)}>
                  Показать список
                </button>
              </div>
            </div>
          )}

          {showGraph && graphNodes.length > 0 && (
            <GraphViewer
              centralNode={centralNode}
              edges={edges}
              onNodeClick={handleNodeClick}
              nodes={graphNodes}
              layout={graphLayout}
            />
          )}

          {(showGraph || showList) && (
            <div className="table-graph-actions">
              <button className="btn" onClick={() => setShowList(!showList)}>
                {showList ? "Скрыть список" : "Показать список"}
              </button>
              {showList && (
                <div style={{ width: "100%" }}>
                  {graphTruncated && (
                    <div className="muted" style={{ marginTop: 10 }}>
                      Глубина ограничена — список показывает текущий срез.
                    </div>
                  )}
                  <pre className="table-code" style={{ marginTop: 12 }}>
                    {tableList.length ? tableList.join("\n") : "—"}
                  </pre>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {showGantt && (
        <div className="table-section">
          <div className="section-title">Таймлайн загрузок</div>
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
                <span className="sql-modal-hint">Ctrl+F для поиска</span>
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
