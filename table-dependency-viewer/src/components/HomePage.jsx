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
  const [tableCycles, setTableCycles] = useState([]);
  const [impactMap, setImpactMap] = useState({});
  const [impactOpen, setImpactOpen] = useState({});
  const [impactGroupOpen, setImpactGroupOpen] = useState({});
  const [impactEntityOpen, setImpactEntityOpen] = useState({});
  const [entityLinkOpen, setEntityLinkOpen] = useState({});
  const [entityLinkDetails, setEntityLinkDetails] = useState({});
  const [nightSummary, setNightSummary] = useState(null);
  const [nightLoading, setNightLoading] = useState(false);
  const [nightError, setNightError] = useState(null);
  const [incidentTimeline, setIncidentTimeline] = useState([]);

  useEffect(() => {
    let cancelled = false;

    setNightLoading(true);
    setNightError(null);

    async function load() {
      try {
        setLoading(true);
        const cachedRaw = sessionStorage.getItem("home:payload");
        if (cachedRaw) {
          const cached = JSON.parse(cachedRaw);
          if (cached?.ts && Date.now() - cached.ts < 120000) {
            setActiveIncidents(Array.isArray(cached.activeIncidents) ? cached.activeIncidents : []);
            setOrderBreaches(Array.isArray(cached.orderBreaches) ? cached.orderBreaches : []);
            setHistory(Array.isArray(cached.history) ? cached.history : []);
            setMetrics(cached.metrics || null);
            setEntityCycles(Array.isArray(cached.entityCycles) ? cached.entityCycles : []);
            setEntityMutual(Array.isArray(cached.entityMutual) ? cached.entityMutual : []);
            setTableCycles(Array.isArray(cached.tableCycles) ? cached.tableCycles : []);
            setNightSummary(cached.nightSummary || null);
            setIncidentTimeline(Array.isArray(cached.incidentTimeline) ? cached.incidentTimeline : []);
            setNightLoading(false);
            setLoading(false);
            return;
          }
        }

        const [
          activeResp,
          orderResp,
          historyResp,
          metricsResp,
          diagResp,
          nightResp,
          timelineResp
        ] = await Promise.all([
          fetch(`${API_BASE}/api/incidents/active`),
          fetch(`${API_BASE}/api/orderbreaches`),
          fetch(`${API_BASE}/api/incidents/history?days=7&limit=10`),
          fetch(`${API_BASE}/api/metrics`),
          fetch(`${API_BASE}/api/graph/diagnostics?include_any=true`),
          fetch(`${API_BASE}/api/night-summary?days=30&limit=10`),
          fetch(`${API_BASE}/api/incidents/timeline?days=7`)
        ]);

        const activeJson = await activeResp.json();
        const orderJson = await orderResp.json();
        const historyJson = await historyResp.json();
        const metricsJson = await metricsResp.json();
        const diagJson = await diagResp.json();
        const nightJson = await nightResp.json();
        const timelineJson = await timelineResp.json();

        if (!cancelled) {
          setActiveIncidents(Array.isArray(activeJson) ? activeJson : []);
          setOrderBreaches(Array.isArray(orderJson) ? orderJson : []);
          setHistory(Array.isArray(historyJson) ? historyJson : []);
          setMetrics(metricsJson);
          setEntityCycles(Array.isArray(diagJson?.entity_cycles) ? diagJson.entity_cycles : []);
          setEntityMutual(Array.isArray(diagJson?.entity_mutual) ? diagJson.entity_mutual : []);
          setTableCycles(Array.isArray(diagJson?.table_cycles) ? diagJson.table_cycles : []);
          setNightSummary(nightJson || null);
          setIncidentTimeline(Array.isArray(timelineJson) ? timelineJson : []);
          setNightLoading(false);
          sessionStorage.setItem(
            "home:payload",
            JSON.stringify({
              ts: Date.now(),
              activeIncidents: Array.isArray(activeJson) ? activeJson : [],
              orderBreaches: Array.isArray(orderJson) ? orderJson : [],
              history: Array.isArray(historyJson) ? historyJson : [],
              metrics: metricsJson || null,
              entityCycles: Array.isArray(diagJson?.entity_cycles) ? diagJson.entity_cycles : [],
              entityMutual: Array.isArray(diagJson?.entity_mutual) ? diagJson.entity_mutual : [],
              tableCycles: Array.isArray(diagJson?.table_cycles) ? diagJson.table_cycles : [],
              nightSummary: nightJson || null,
              incidentTimeline: Array.isArray(timelineJson) ? timelineJson : [],
            })
          );
        }
      } catch (e) {
        console.error("HomePage load error:", e);
        setNightError("Failed to load night summary.");
        setNightLoading(false);
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
        [target]: { state: "error", rows: [], error: "Failed to load impact list." },
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

  const loadEntityLinkDetails = (pair, key) => {
    if (!pair || !pair.a || !pair.b) return;
    if (entityLinkDetails[key]?.state === "loading" || entityLinkDetails[key]?.state === "ready") {
      return;
    }
    setEntityLinkDetails((prev) => ({
      ...prev,
      [key]: { state: "loading", edges_ab: [], edges_ba: [] },
    }));
    fetch(
      `${API_BASE}/api/graph/diagnostics/mutual?entity_a=${encodeURIComponent(pair.a)}&entity_b=${encodeURIComponent(pair.b)}&strict=true`
    )
      .then((res) => (res.ok ? res.json() : Promise.reject("Failed to load edges")))
      .then((data) => {
        setEntityLinkDetails((prev) => ({
          ...prev,
          [key]: {
            state: "ready",
            edges_ab: Array.isArray(data.edges_ab) ? data.edges_ab : [],
            edges_ba: Array.isArray(data.edges_ba) ? data.edges_ba : [],
          },
        }));
      })
      .catch(() => {
        setEntityLinkDetails((prev) => ({
          ...prev,
          [key]: { state: "error", edges_ab: [], edges_ba: [] },
        }));
      });
  };

  const toggleEntityLink = (pair, key) => {
    setEntityLinkOpen((prev) => {
      const next = !prev[key];
      if (next) {
        loadEntityLinkDetails(pair, key);
      }
      return { ...prev, [key]: next };
    });
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

  const nightPeakHour = useMemo(() => {
    if (!nightSummary?.hourly?.length) return null;
    const sorted = [...nightSummary.hourly].sort(
      (a, b) => (b.total_duration_minutes || 0) - (a.total_duration_minutes || 0)
    );
    return sorted[0];
  }, [nightSummary]);

  const timelineMax = useMemo(() => {
    if (!incidentTimeline.length) return 0;
    return Math.max(...incidentTimeline.map((d) => d.count || 0));
  }, [incidentTimeline]);

  const healthScore = useMemo(() => {
    const base = 100;
    const incidentPenalty = Math.min(activeIncidents.length * 15, 45);
    const errorPenalty = metrics?.error_count ? Math.min(metrics.error_count * 2, 30) : 0;
    const breachPenalty = Math.min(orderBreaches.length * 3, 25);
    const score = Math.max(0, Math.round(base - incidentPenalty - errorPenalty - breachPenalty));
    let level = "Healthy";
    if (score < 65) level = "Critical";
    else if (score < 85) level = "Degraded";
    return { score, level };
  }, [activeIncidents.length, metrics?.error_count, orderBreaches.length]);

  return (
    <div className="container cc-page">
      <section className="cc-hero">
        <div className="cc-hero-main">
          <div className="cc-hero-title">DWH Control Center</div>
          <div className="cc-hero-subtitle">
            Operational overview of incidents, load reliability, and dependency risks.
          </div>
          <div className="cc-hero-status">
            <span className={`status-dot ${activeIncidents.length ? "degraded" : ""}`} />
            <span className="status-text">
              {activeIncidents.length ? "Active incidents detected" : "System is operating normally"}
            </span>
            {incidentTrend && (
              <span className="status-meta">
                Incident trend:&nbsp;
                {incidentTrend === "up" && "up ↑"}
                {incidentTrend === "down" && "down ↓"}
                {incidentTrend === "stable" && "stable"}
              </span>
            )}
          </div>
        </div>
        <div className="cc-hero-health">
          <div className="health-card">
            <div className="health-label">DWH health</div>
            <div className="health-score">{healthScore.score}</div>
            <div className={`health-badge health-${healthScore.level.toLowerCase()}`}>
              {healthScore.level}
            </div>
            <div className="health-meta">
              Based on active incidents, failed loads, and order breaches.
            </div>
          </div>
        </div>
      </section>

      {metrics && (
        <section className="cc-overview-bar">
          <div className="overview-item">
            <span className="overview-value">{metrics.total_tables}</span>
            <span className="overview-label">Tables</span>
          </div>

          <div className="overview-item danger">
            <span className="overview-value">{metrics.error_count}</span>
            <span className="overview-label">Load failures (24h)</span>
          </div>

          <div className="overview-item">
            <span className="overview-value">
              {metrics.avg_duration_minutes ?? "—"}
            </span>
            <span className="overview-label">Avg duration (24h), min</span>
          </div>

          <div className="overview-item">
            <span className="overview-value">{metrics.active_entities}</span>
            <span className="overview-label">Entities</span>
          </div>
        </section>
      )}

      <section className="cc-surface">
        <div className="section-title">Why this matters</div>
        <div className="cc-hero-copy">
          Use this page to identify incidents that block analytics, spot late upstream loads,
          and prioritize entities at risk. The health score summarizes operational stability at a glance.
        </div>
      </section>

      {/* ===== ACTIVE INCIDENTS ===== */}
      {loading && <div className="muted">Loading...</div>}

      {!loading && activeIncidents.length === 0 && (
        <section className="cc-surface">
          <div className="system-ok system-ok-compact">
            <div className="system-ok-icon">✓</div>
            <div>
              <div className="system-ok-title">No active incidents</div>
              <div className="system-ok-sub">
                No failures in the last 24 hours
              </div>
            </div>
          </div>
        </section>
      )}

      {!loading && activeIncidents.length > 0 && (
        <section className="cc-surface">
          <div className="section-title">
            Active incidents
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
                  Failed tables: {i.failed_tables}
                </div>

                <div className="entity-meta">
                  Last failure: {i.last_failure_time}
                </div>

                <div className="incident-hint">
                  Click to review incident →
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ===== NIGHT SUMMARY ===== */}
      {!loading && (
        <section className="cc-surface">
          <div className="section-title">Night summary (last window)</div>
          {nightLoading && <div className="muted">Loading night summary...</div>}
          {nightError && <div className="dep-error-title">{nightError}</div>}
          {!nightLoading && !nightError && nightSummary && (
            <>
              <div className="night-kpis">
                <div className="night-kpi-card">
                  <div className="night-kpi-label">Runs</div>
                  <div className="night-kpi-value">{nightSummary?.summary?.runs_count ?? 0}</div>
                </div>
                <div className="night-kpi-card">
                  <div className="night-kpi-label">Tables</div>
                  <div className="night-kpi-value">{nightSummary?.summary?.tables_count ?? 0}</div>
                </div>
                <div className="night-kpi-card">
                  <div className="night-kpi-label">Entities</div>
                  <div className="night-kpi-value">{nightSummary?.summary?.entities_count ?? 0}</div>
                </div>
                <div className="night-kpi-card">
                  <div className="night-kpi-label">Total duration</div>
                  <div className="night-kpi-value">
                    {nightSummary?.summary?.total_duration_minutes ?? 0} min
                  </div>
                </div>
                <div className="night-kpi-card">
                  <div className="night-kpi-label">Peak hour</div>
                  <div className="night-kpi-value">
                    {nightPeakHour ? String(nightPeakHour.hour).padStart(2, "0") + ":00" : "—"}
                  </div>
                </div>
              </div>
              <div className="night-columns">
                <div className="night-panel">
                  <div className="night-panel-title">Longest runs</div>
                  <div className="night-panel-sub muted">Top 5 by duration</div>
                  <div className="night-list">
                    {(nightSummary.top_runs || []).slice(0, 5).map((row) => (
                      <button
                        key={`${row.table_fqn}-${row.start}`}
                        className="night-row"
                        onClick={() => onSelectTable({ view: "table_info", table: row.table_fqn }, "home")}
                      >
                        <div className="night-row-main">
                          <div className="night-row-title mono">{row.table_fqn}</div>
                          <div className="night-row-sub muted">
                            Entity: {row.entity_name || "—"} · ID {row.table_id ?? "—"}
                          </div>
                        </div>
                        <div className="night-row-meta">
                          <span className="night-row-badge">{row.duration_minutes ?? "—"} min</span>
                        </div>
                      </button>
                    ))}
                    {!nightSummary?.top_runs?.length && (
                      <div className="muted">No runs found.</div>
                    )}
                  </div>
                </div>
                <div className="night-panel">
                  <div className="night-panel-title">Anomalies vs p95</div>
                  <div className="night-panel-sub muted">Runs &gt; 1.5x p95</div>
                  <div className="night-list">
                    {(nightSummary.anomalies || []).slice(0, 5).map((row) => (
                      <button
                        key={`${row.table_fqn}-${row.start}`}
                        className="night-row"
                        onClick={() => onSelectTable({ view: "table_info", table: row.table_fqn }, "home")}
                      >
                        <div className="night-row-main">
                          <div className="night-row-title mono">{row.table_fqn}</div>
                          <div className="night-row-sub muted">
                            Entity: {row.entity_name || "—"} · ID {row.table_id ?? "—"}
                          </div>
                        </div>
                        <div className="night-row-meta">
                          <span className="night-row-badge">{row.duration_minutes ?? "—"} min</span>
                          <span className="night-row-badge night-row-badge-warn">{row.ratio ?? "—"}x</span>
                        </div>
                      </button>
                    ))}
                    {!nightSummary?.anomalies?.length && (
                      <div className="muted">No anomalies.</div>
                    )}
                  </div>
                </div>
                <div className="night-panel">
                  <div className="night-panel-title">Failed runs</div>
                  <div className="night-panel-sub muted">
                    {nightSummary?.failed_summary?.runs_count ?? 0} failures
                  </div>
                  <div className="night-list">
                    {(nightSummary.failed_runs || []).slice(0, 5).map((row) => (
                      <button
                        key={`${row.table_fqn}-${row.start}`}
                        className="night-row"
                        onClick={() => onSelectTable({ view: "table_info", table: row.table_fqn }, "home")}
                      >
                        <div className="night-row-main">
                          <div className="night-row-title mono">{row.table_fqn}</div>
                          <div className="night-row-sub muted">
                            Entity: {row.entity_name || "—"} · ID {row.table_id ?? "—"}
                          </div>
                          <div className="night-row-message">
                            {row.message || "FAILED"}
                          </div>
                        </div>
                      </button>
                    ))}
                    {!nightSummary?.failed_runs?.length && (
                      <div className="muted">No failed runs.</div>
                    )}
                  </div>
                </div>
              </div>
            </>
          )}
          {!nightLoading && !nightError && !nightSummary && (
            <div className="muted">Night summary is unavailable.</div>
          )}
        </section>
      )}

      {/* ===== ORDER BREACHES ===== */}
      {!loading && orderBreaches.length > 0 && (
        <section className="cc-surface">
          <div className="section-title">
            Load order breaches
            <span className="section-meta">{orderBreaches.length}</span>
          </div>
          <div className="order-list">
            {orderBreaches.slice(0, 4).map((breach) => (
              <article key={breach.target_fqn} className="order-row">
                <header className="order-row-header">
                  <div>
                    <div className="order-row-target mono" title={breach.target_fqn}>{breach.target_fqn}</div>
                    <div className="order-row-meta">
                      Upstream started later: <span title={breach.worst_upstream}>{breach.worst_upstream}</span>
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
                  {breach.worst_upstream} finished at {formatTime(breach.worst_upstream_time)}, while {breach.target_fqn} started
                  {" "}
                  {formatTime(breach.target_last_load)}. Delay +{breach.gap_minutes} min.
                </p>


                <div className="order-row-actions">
                  <button
                    className="btn btn-secondary"
                    onClick={() => onSelectTable({ view: "table_info", table: breach.target_fqn }, "home")}
                  >
                    Table card
                  </button>
                  <button
                    className="btn btn-ghost"
                    onClick={() => toggleImpact(breach.target_fqn)}
                  >
                    {impactOpen[breach.target_fqn] ? "Hide impact" : "Show impact"}
                  </button>
                </div>
                {impactOpen[breach.target_fqn] && (
                  <div className="order-impact">
                    <div className="order-impact-header">
                      <div>
                        <div className="order-impact-title">Affected tables</div>
                        <div className="muted">
                          Built from dependencies of {breach.target_fqn}
                        </div>
                      </div>
                      <div className="order-impact-count">
                        {impactMap[breach.target_fqn]?.rows?.length || 0}
                      </div>
                    </div>
                    {impactMap[breach.target_fqn]?.state === "loading" && (
                      <div className="muted">Loading impact...</div>
                    )}
                    {impactMap[breach.target_fqn]?.state === "error" && (
                      <div className="card dep-error">
                        <div className="dep-error-title">Load error</div>
                        <div className="muted">{impactMap[breach.target_fqn]?.error}</div>
                      </div>
                    )}
                    {impactMap[breach.target_fqn]?.state === "ready" &&
                      impactMap[breach.target_fqn]?.rows?.length === 0 && (
                        <div className="card muted">No dependent tables.</div>
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
                                          ? `via ${item.path.slice(1, -1).join(" → ")}`
                                          : item.path
                                            ? "direct dependency"
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
                                    {isOpen ? "Collapse list" : `Show all (${filteredItems.length})`}
                                  </button>
                                )}
                              </div>
                            );
                          })
                        return (
                          <>
                            <div className="order-impact-note muted">
                              The list includes indirect dependencies. Each table shows the path from the source.
                            </div>
                            <div className="order-runbook">
                              <div className="order-runbook-title">Entity rerun order</div>
                              <div className="muted order-runbook-sub">
                                Recommended recalculation order after {breach.target_fqn}
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
                                      Tables: {entity.tables.length} · nearest dependency: {entity.minDepth} step
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
                                    ? "Collapse list"
                                    : `Show all entities (${entityList.length})`}
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
            Entity cycles
            <span className="section-meta">
              {entityCycles.length + entityMutual.length}
            </span>
          </div>
          <div className="order-list">
            {entityCycles.slice(0, 4).map((cycle, idx) => (
              <article key={`cycle-${idx}`} className="order-row">
                <header className="order-row-header">
                  <div>
                    <div className="order-row-target mono">Cycle</div>
                    <div className="order-row-meta">
                      Entities: {cycle.size}
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
              const details = entityLinkDetails[key];
              return (
              <article key={`mutual-${idx}`} className="order-row">
                <header className="order-row-header">
                  <div>
                    <div className="order-row-target mono">Mutual dependency</div>
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
                  <button className="btn btn-ghost" onClick={() => toggleEntityLink(pair, key)}>
                    {entityLinkOpen[key] ? "Hide tables" : "Show tables"}
                  </button>
                  <div className="muted">
                    {pair.edges_ab_count || 0} → {pair.edges_ba_count || 0}
                  </div>
                </div>
                {entityLinkOpen[key] && (
                  <div className="order-impact">
                    <div className="order-impact-title">Connecting tables</div>
                    <div className="order-row-chain" style={{ flexWrap: "wrap", gap: 8 }}>
                      <span className="order-node mono" style={{ borderColor: "#38bdf8" }}>{pair.a}</span>
                      <span className="order-arrow">→</span>
                      <span className="order-node mono" style={{ borderColor: "#f97316" }}>{pair.b}</span>
                    </div>
                    <div className="order-row-chain" style={{ flexWrap: "wrap", gap: 8, marginTop: 8 }}>
                      {(details?.edges_ab || pair.edges_ab_sample || []).map((edge, edgeIdx) => (
                        <span key={`ab-${edge.source}-${edge.target}-${edgeIdx}`} className="order-node mono">
                          <button
                            className="btn btn-ghost"
                            onClick={() => onSelectTable({ view: "table_info", table: edge.source }, "home")}
                          >
                            {edge.source}
                          </button>
                          {edge.source_entities && edge.source_entities.length > 0 && (
                            <span className="muted">[{edge.source_entities.join(", ")}]</span>
                          )}
                          <span className="order-arrow">→</span>
                          <button
                            className="btn btn-ghost"
                            onClick={() => onSelectTable({ view: "table_info", table: edge.target }, "home")}
                          >
                            {edge.target}
                          </button>
                          {edge.target_entities && edge.target_entities.length > 0 && (
                            <span className="muted">[{edge.target_entities.join(", ")}]</span>
                          )}
                        </span>
                      ))}
                      {!details?.edges_ab?.length && !pair.edges_ab_sample?.length && (
                        <span className="muted">No examples for {pair.a} → {pair.b}</span>
                      )}
                    </div>
                    <div className="order-row-chain" style={{ flexWrap: "wrap", gap: 8, marginTop: 8 }}>
                      <span className="order-node mono" style={{ borderColor: "#f97316" }}>{pair.b}</span>
                      <span className="order-arrow">→</span>
                      <span className="order-node mono" style={{ borderColor: "#38bdf8" }}>{pair.a}</span>
                    </div>
                    <div className="order-row-chain" style={{ flexWrap: "wrap", gap: 8, marginTop: 8 }}>
                      {(details?.edges_ba || pair.edges_ba_sample || []).map((edge, edgeIdx) => (
                        <span key={`ba-${edge.source}-${edge.target}-${edgeIdx}`} className="order-node mono">
                          <button
                            className="btn btn-ghost"
                            onClick={() => onSelectTable({ view: "table_info", table: edge.source }, "home")}
                          >
                            {edge.source}
                          </button>
                          {edge.source_entities && edge.source_entities.length > 0 && (
                            <span className="muted">[{edge.source_entities.join(", ")}]</span>
                          )}
                          <span className="order-arrow">→</span>
                          <button
                            className="btn btn-ghost"
                            onClick={() => onSelectTable({ view: "table_info", table: edge.target }, "home")}
                          >
                            {edge.target}
                          </button>
                          {edge.target_entities && edge.target_entities.length > 0 && (
                            <span className="muted">[{edge.target_entities.join(", ")}]</span>
                          )}
                        </span>
                      ))}
                      {!details?.edges_ba?.length && !pair.edges_ba_sample?.length && (
                        <span className="muted">No examples for {pair.b} → {pair.a}</span>
                      )}
                    </div>
                    <div className="order-row-actions" style={{ marginTop: 8 }}>
                      <button
                        className="btn btn-secondary"
                        onClick={() => loadEntityLinkDetails(pair, key)}
                      >
                        Show all tables
                      </button>
                      {details?.state === "loading" && <span className="muted">Loading...</span>}
                      {details?.state === "error" && <span className="muted">Load error</span>}
                    </div>
                  </div>
                )}
              </article>
            )})}
          </div>
        </section>
      )}

      {/* ===== TABLE CYCLES ===== */}
      {!loading && tableCycles.length > 0 && (
        <section className="cc-surface">
          <div className="section-title">
            Table cycles
            <span className="section-meta">{tableCycles.length}</span>
          </div>
          <div className="order-list">
            {tableCycles.slice(0, 4).map((cycle, idx) => (
              <article key={`table-cycle-${idx}`} className="order-row">
                <header className="order-row-header">
                  <div>
                    <div className="order-row-target mono">Table cycle</div>
                    <div className="order-row-meta">Tables: {cycle.size}</div>
                  </div>
                  <div className="order-pill order-pill-warning">CYCLE</div>
                </header>
                <div className="order-row-chain">
                  {cycle.nodes.map((node) => (
                    <span key={node} className="order-node mono">{node}</span>
                  ))}
                  {cycle.size > cycle.nodes.length && <span className="order-node">…</span>}
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
            Incident highlights (7 days)
            <span className="section-meta">top problematic tables</span>
          </div>
          <div className="muted" style={{ marginBottom: 12 }}>
            Shows tables with the most failures in the last 7 days.
          </div>
          {incidentTimeline.length > 0 && (
            <div className="incident-mini">
              {incidentTimeline.map((row) => {
                const height = timelineMax ? Math.max(6, (row.count / timelineMax) * 48) : 6;
                return (
                  <div key={row.day} className="incident-mini-day" title={`${row.day}: ${row.count}`}>
                    <span className="incident-mini-bar" style={{ height }} />
                    <span className="incident-mini-label">{row.day.slice(5)}</span>
                  </div>
                );
              })}
            </div>
          )}
          <div className="history-board">
            <div className="history-board-head">
              <span>#</span>
              <span>Table</span>
              <span>Incidents</span>
              <span>Last occurrence</span>
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
          <div className="order-row-actions" style={{ marginTop: 12 }}>
            <button className="btn btn-secondary" onClick={() => onSelectTable("__show_errors__", "home")}>
              Open full incident history
            </button>
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
    return dt.toLocaleString("en-GB", {
      day: "2-digit",
      month: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  const severityLabel = (sev) => {
    switch (sev) {
      case "CRITICAL":
        return "Critical";
      case "MAJOR":
        return "Major";
      default:
        return "Warning";
    }
  };
