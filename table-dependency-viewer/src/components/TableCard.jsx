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

  useEffect(() => {
    if (!schema || !tableName) return;

    setLoadingMeta(true);
    setError(null);

    fetch(`${API_BASE}/api/card/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}`)
      .then((res) => {
        if (!res.ok) throw new Error("Failed to fetch table metadata");
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
      .then((res) => (res.ok ? res.json() : Promise.reject("Failed to load table history")))
      .then((data) => setHistoryRows(Array.isArray(data) ? data : []))
      .catch((err) => {
        console.error(err);
        setHistoryError(typeof err === "string" ? err : "Failed to load table history");
      })
      .finally(() => setHistoryLoading(false));
  }, [schema, tableName]);

  useEffect(() => {
    if (!schema || !tableName) return;
    setVariantsLoading(true);
    setVariantsError(null);
    fetch(`${API_BASE}/api/table-variants/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Failed to load table variants")))
      .then((data) => setVariants(Array.isArray(data) ? data : []))
      .catch((err) => {
        console.error(err);
        setVariantsError(typeof err === "string" ? err : "Failed to load table variants");
      })
      .finally(() => setVariantsLoading(false));
  }, [schema, tableName]);

  useEffect(() => {
    if (!schema || !tableName) return;
    setDqLoading(true);
    setDqError(null);
    fetch(`${API_BASE}/api/dq/table/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Failed to load data quality")))
      .then((data) => setDqData(data))
      .catch((err) => {
        console.error(err);
        setDqError(typeof err === "string" ? err : "Failed to load data quality");
      })
      .finally(() => setDqLoading(false));
  }, [schema, tableName]);

  useEffect(() => {
    if (!schema || !tableName) return;
    setDqHistoryLoading(true);
    setDqHistoryError(null);
    fetch(`${API_BASE}/api/dq/history/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}?limit=20`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Failed to load data quality history")))
      .then((data) => setDqHistory(Array.isArray(data) ? data : []))
      .catch((err) => {
        console.error(err);
        setDqHistoryError(typeof err === "string" ? err : "Failed to load data quality history");
      })
      .finally(() => setDqHistoryLoading(false));
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
  const fmtInt = (value) => (Number.isFinite(value) ? Math.round(value).toLocaleString("en-US") : "—");
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
        label: "Last successful load",
        value: meta.last_success_time || "—",
        hint: "log-based",
      },
      {
        label: "Average duration",
        value:
          meta.avg_duration_minutes !== null && meta.avg_duration_minutes !== undefined
            ? `${meta.avg_duration_minutes} min`
            : "—",
        hint: "successful runs only",
      },
      {
        label: "Load mode",
        value: meta.table_load_mode || "—",
        hint: "ETL configuration",
      },
      {
        label: "Table size",
        value:
          meta.table_size_mb !== null && meta.table_size_mb !== undefined
            ? `${meta.table_size_mb} MB`
            : "—",
        hint: "PostgreSQL estimate",
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
    setGraphTooLarge(false);
    setGraphTruncated(false);
    setGraphNodes([]);
    setGraphLayout({});

    fetch(`${API_BASE}/api/graph/table/${schema}/${tableName}?depth=3`)
      .then((res) =>
        res.ok ? res.json() : Promise.reject("Failed to build dependency graph"),
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
        setDepsError(typeof err === "string" ? err : "Failed to load graph");
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
    alert("Table list copied");
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
          <div className="dep-error-title">Failed to load table card</div>
          <div className="muted">{error}</div>
          <div style={{ marginTop: 12 }}>
            <button className="btn" onClick={onBack}>
              ← Back
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (loadingMeta || !meta) {
    return (
      <div className="table-page">
        <div className="card muted">Loading table card...</div>
      </div>
    );
  }

  return (
    <div className="table-page">
      <div className="table-header">
        <button className="btn" onClick={onBack}>
          ← Back
        </button>
        <div className="table-head-main">
          <div className="table-head-label">Table</div>
          <div className="table-title">{tableFqn}</div>
          <div className="table-head-meta">
            <span>{meta.entity_name || "—"}</span>
            <span>ID {meta.table_id ?? "—"}</span>
          </div>
        </div>
        <div className="table-status-wrap">
          <div className={`table-status ${status}`}>
            {status === "risk" ? "RISK" : status === "warn" ? "WARN" : "OK"}
          </div>
          <button
            className="status-help"
            title={
              status === "risk"
                ? "RISK: avg duration > 20 min based on recent SUCCESS runs."
                : status === "warn"
                ? "WARN: avg duration > 10 min based on recent SUCCESS runs."
                : "OK: avg duration <= 10 min based on recent SUCCESS runs."
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
              <div className="table-health-title">Load health</div>
              <div className="table-health-subtitle muted">
                Based on successful runs in Slow/Unstable.
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
              Slow &amp; Unstable: p95 &gt; 10 min and CV &gt; 0.6
            </span>
            <span className="table-health-legend-item">
              Slow: p95 &gt; 10 min
            </span>
            <span className="table-health-legend-item">
              Unstable: CV &gt; 0.3
            </span>
            <span className="table-health-legend-item">
              Low Sample: not enough runs
            </span>
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
              Not enough runs for stable assessment — use with caution.
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
          <div className="table-card-label">Actions</div>
          <div className="table-action-buttons">
            <button className="btn btn-secondary" onClick={loadDependencies}>
              Show dependency graph
            </button>
            <button
              className="btn btn-secondary"
              onClick={() => onOpenImpact?.(schema, tableName)}
            >
              Open impact graph
            </button>
            <button
              className="btn btn-secondary"
              onClick={() => setShowGantt(!showGantt)}
            >
              {showGantt ? "Hide timeline" : "Load timeline"}
            </button>
            <button
              className="btn btn-secondary"
              onClick={copyList}
              disabled={!tableList.length}
            >
              Copy dependency list
            </button>
            <button className="btn" onClick={onBack}>
              Return
            </button>
          </div>
        </div>
      </div>

      <div className="table-section">
        <div className="section-title">Data quality</div>
        <div className="card">
          {dqLoading && <div className="muted">Loading data quality...</div>}
          {dqError && <div className="dep-error-title">{dqError}</div>}
          {!dqLoading && !dqError && !dqData && (
            <div className="muted">No data quality checks found.</div>
          )}
          {!dqLoading && !dqError && dqData && (
            <div className="dq-grid">
              <div className="dq-card">
                <div className="dq-label">Duplicate check</div>
                <div className="dq-value">
                  {dqData.duplicate?.count !== null && dqData.duplicate?.count !== undefined
                    ? fmtInt(dqData.duplicate.count)
                    : "—"}
                </div>
                <div className="dq-hint muted">
                  Last check: {dqData.duplicate?.last_check || "—"}
                </div>
              </div>
              <div className="dq-card">
                <div className="dq-label">Row count</div>
                <div className="dq-value">
                  {dqData.row_count?.count !== null && dqData.row_count?.count !== undefined
                    ? fmtInt(dqData.row_count.count)
                    : "—"}
                </div>
                <div className="dq-hint muted">
                  Baseline median (last 7 checks):{" "}
                  {dqData.row_count?.baseline_median !== null && dqData.row_count?.baseline_median !== undefined
                    ? fmtInt(dqData.row_count.baseline_median)
                    : "—"}
                  {" · "}
                  Δ {fmtPct(dqData.row_count?.delta_pct)}
                </div>
                {Number.isFinite(dqData.row_count?.delta_pct) &&
                  Math.abs(dqData.row_count.delta_pct) >= 10 && (
                    <div className="dq-alert">Deviation exceeds 10%</div>
                  )}
              </div>
            </div>
          )}
          <div className="dq-history">
            <button
              className="btn btn-secondary"
              onClick={() => setShowDqHistory((prev) => !prev)}
            >
              {showDqHistory ? "Hide history" : "Show history"}
            </button>
            {showDqHistory && (
              <>
                {dqHistoryLoading && <div className="muted">Loading data quality history...</div>}
                {dqHistoryError && <div className="dep-error-title">{dqHistoryError}</div>}
                {!dqHistoryLoading && !dqHistoryError && dqHistory.length === 0 && (
                  <div className="muted">No data quality history yet.</div>
                )}
                {!dqHistoryLoading && !dqHistoryError && dqHistory.length > 0 && (
                  <div className="dq-history-table">
                    <div className="dq-history-head">
                      <span>Check</span>
                      <span>Value</span>
                      <span>Date</span>
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
        <div className="section-title">SQL scripts</div>
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
                      {hasSql ? `${lines.length} lines · ${block.sql.length} characters` : "Script not available"}
                    </div>
                  </div>
                  <div className="table-sql-actions">
                    <button
                      className="btn btn-secondary"
                      onClick={() => openSqlModal(block)}
                      disabled={!hasSql}
                    >
                      Open
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      <div className="table-section">
        <div className="section-title">Recent runs (last 10)</div>
        <div className="card">
          {historyLoading && <div className="muted">Loading recent runs...</div>}
          {historyError && <div className="dep-error-title">{historyError}</div>}
          {!historyLoading && !historyError && historyRows.length === 0 && (
            <div className="muted">No recent runs found.</div>
          )}
          {!historyLoading && !historyError && historyRows.length > 0 && (
            <div className="history-table">
              <div className="history-table-head">
                <span>Status</span>
                <span>Start</span>
                <span>Finish</span>
                <span>Duration</span>
                <span>Message</span>
              </div>
              {historyRows.map((row, idx) => (
                <div key={`${row.finish || "row"}-${idx}`} className="history-table-row">
                  <span className={`history-state history-${String(row.state || "unknown").toLowerCase()}`}>
                    {row.state || "UNKNOWN"}
                  </span>
                  <span>{row.start || "—"}</span>
                  <span>{row.finish || "—"}</span>
                  <span>{row.duration_minutes ?? "—"} min</span>
                  <span className="history-message">{row.message || "—"}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="table-section">
        <div className="section-title">Table variants (other entities)</div>
        <div className="card">
          {variantsLoading && <div className="muted">Loading variants...</div>}
          {variantsError && <div className="dep-error-title">{variantsError}</div>}
          {!variantsLoading && !variantsError && variants.length <= 1 && (
            <div className="muted">No other entity variants found.</div>
          )}
          {!variantsLoading && !variantsError && variants.length > 1 && (
            <div className="variants-table">
              <div className="variants-table-head">
                <span>Entity</span>
                <span>Table ID</span>
                <span>Last load</span>
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
          <div className="section-title">Key attributes</div>
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
        <div className="section-title">Dependency graph</div>
        <div className="card">
          {loadingDeps && <div className="muted">Building graph...</div>}
          {depsError && (
            <div className="dep-error-title">{depsError}</div>
          )}
          {!loadingDeps && !depsError && !showGraph && (
            <div className="muted">Click “Show dependency graph” to render.</div>
          )}
          {!loadingDeps && !depsError && graphTruncated && (
            <div className="card dep-error" style={{ marginTop: 12 }}>
              <div className="dep-error-title">Truncated graph shown</div>
              <div className="muted">
                Depth-limited. Use the entity graph for full coverage.
              </div>
            </div>
          )}
          {!loadingDeps && !depsError && graphTooLarge && (
            <div className="card dep-error" style={{ marginTop: 12 }}>
              <div className="dep-error-title">Graph is too large</div>
              <div className="muted">
                Nodes: {graphStats.nodes}, edges: {graphStats.edges}. This may hang in production.
              </div>
              <div className="table-graph-actions" style={{ marginTop: 10 }}>
                <button className="btn btn-secondary" onClick={() => setShowGraph(true)}>
                  Render anyway
                </button>
                <button className="btn" onClick={() => setShowList(true)}>
                  Show list
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
                {showList ? "Hide list" : "Show list"}
              </button>
              {showList && (
                <div style={{ width: "100%" }}>
                  {graphTruncated && (
                    <div className="muted" style={{ marginTop: 10 }}>
                      Depth-limited graph; list shows current slice only.
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
          <div className="section-title">Load timeline</div>
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
                  {tableFqn} · {activeSqlBlock.sql?.split("\n").length || 0} lines
                </div>
              </div>
              <div className="sql-modal-actions">
                <span className="sql-modal-hint">Use Ctrl+F to search</span>
                <button
                  className="btn btn-secondary"
                  onClick={() => copySql(activeSqlBlock.sql)}
                >
                  Copy
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
