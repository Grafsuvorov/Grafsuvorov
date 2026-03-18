import { useEffect, useState, useMemo } from "react";
import { useNavigate } from "react-router-dom";
import "../style/app.css";
import { formatRuDateTime } from "../utils/datetime.js";
import { fetchHomePayload } from "../api/home.js";
import { apiClient } from "../api/client.js";
import { formatInt, formatMinutes, formatPercent } from "../utils/format.js";

const HOME_CACHE_KEY = "home:payload:v3";

function asArray(value) {
  if (Array.isArray(value)) return value;
  if (typeof value !== "string") return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export default function HomePage({ onSelectTable }) {
  const navigate = useNavigate();
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
  const [cycleOpen, setCycleOpen] = useState({});
  const [cycleDetails, setCycleDetails] = useState({});
  const [nightSummary, setNightSummary] = useState(null);
  const [nightLoading, setNightLoading] = useState(false);
  const [nightError, setNightError] = useState(null);
  const [incidentTimeline, setIncidentTimeline] = useState([]);
  const [dqSummary, setDqSummary] = useState(null);
  const [dqAlerts, setDqAlerts] = useState([]);
  const [clickSummary, setClickSummary] = useState(null);
  const [clickFailures, setClickFailures] = useState([]);
  const [clickSlow, setClickSlow] = useState([]);
  const [showAllOrderBreaches, setShowAllOrderBreaches] = useState(false);

  useEffect(() => {
    let cancelled = false;

    setNightLoading(true);
    setNightError(null);

    async function load() {
      try {
        setLoading(true);
        const cachedRaw = localStorage.getItem(HOME_CACHE_KEY);
        if (cachedRaw) {
          const cached = JSON.parse(cachedRaw);
          if (cached?.expiresAt && Date.now() < cached.expiresAt) {
            setActiveIncidents(asArray(cached.activeIncidents));
            setOrderBreaches(asArray(cached.orderBreaches));
            setHistory(asArray(cached.history));
            setMetrics(cached.metrics || null);
            setEntityCycles(asArray(cached.entityCycles));
            setEntityMutual(asArray(cached.entityMutual));
            setTableCycles(asArray(cached.tableCycles));
            setNightSummary(cached.nightSummary || null);
            setIncidentTimeline(asArray(cached.incidentTimeline));
            setDqSummary(cached.dqSummary || null);
            setDqAlerts(asArray(cached.dqAlerts));
            setClickSummary(cached.clickSummary || null);
            setClickFailures(asArray(cached.clickFailures));
            setClickSlow(asArray(cached.clickSlow));
            setNightLoading(false);
            setLoading(false);
          }
        }

        const payload = await fetchHomePayload();

        if (!cancelled) {
          const now = new Date();
          const nextRefresh = new Date(now);
          nextRefresh.setHours(9, 0, 0, 0);
          if (now >= nextRefresh) {
            nextRefresh.setDate(nextRefresh.getDate() + 1);
          }
          const expiresAt = nextRefresh.getTime();

          const activeRows = asArray(payload.activeIncidents);
          const orderRows = asArray(payload.orderBreaches);
          const historyRows = asArray(payload.history);
          const entityCyclesRows = asArray(payload.diagnostics?.entity_cycles);
          const entityMutualRows = asArray(payload.diagnostics?.entity_mutual);
          const tableCyclesRows = asArray(payload.diagnostics?.table_cycles);
          const timelineRows = asArray(payload.incidentTimeline);
          const dqAlertRows = asArray(payload.dqAlerts);
          const clickFailureRows = asArray(payload.clickFailures);
          const clickSlowRows = asArray(payload.clickSlow);

          setActiveIncidents(activeRows);
          setOrderBreaches(orderRows);
          setHistory(historyRows);
          setMetrics(payload.metrics);
          setEntityCycles(entityCyclesRows);
          setEntityMutual(entityMutualRows);
          setTableCycles(tableCyclesRows);
          setNightSummary(payload.nightSummary || null);
          setIncidentTimeline(timelineRows);
          setDqSummary(payload.dqSummary || null);
          setDqAlerts(dqAlertRows);
          setClickSummary(payload.clickSummary || null);
          setClickFailures(clickFailureRows);
          setClickSlow(clickSlowRows);
          setNightLoading(false);
          localStorage.setItem(
            HOME_CACHE_KEY,
            JSON.stringify({
              ts: Date.now(),
              expiresAt,
              activeIncidents: activeRows,
              orderBreaches: orderRows,
              history: historyRows,
              metrics: payload.metrics || null,
              entityCycles: entityCyclesRows,
              entityMutual: entityMutualRows,
              tableCycles: tableCyclesRows,
              nightSummary: payload.nightSummary || null,
              incidentTimeline: timelineRows,
              dqSummary: payload.dqSummary || null,
              dqAlerts: dqAlertRows,
              clickSummary: payload.clickSummary || null,
              clickFailures: clickFailureRows,
              clickSlow: clickSlowRows,
            })
          );
        }
      } catch (e) {
        console.error("HomePage load error:", e);
        setNightError("Не удалось загрузить ночное окно.");
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
  const dqLimit = 8;
  const isLocal =
    typeof window !== "undefined" &&
    (window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1");

  const fmtInt = formatInt;
  const fmtPct = formatPercent;

  const lastRefreshLabel = useMemo(() => {
    const cachedRaw = localStorage.getItem(HOME_CACHE_KEY);
    if (!cachedRaw) return "—";
    try {
      const cached = JSON.parse(cachedRaw);
      if (!cached?.ts) return "—";
      return new Date(cached.ts).toLocaleString("ru-RU");
    } catch {
      return "—";
    }
  }, [loading]);

  const demoActiveIncidents = useMemo(() => {
    if (!isLocal || loading || activeIncidents.length) return activeIncidents;
    return [
      {
        entity: "DEMO_ENTITY",
        failed_tables: 2,
        last_failure_time: "2026-02-24 04:52",
        root_tables: ["dm.demo_sales"]
      }
    ];
  }, [isLocal, loading, activeIncidents]);

  const demoDqSummary = useMemo(() => {
    if (!isLocal || dqSummary) return dqSummary;
    return { duplicate_tables: 4, row_count_tables: 6, row_count_checked: 42 };
  }, [isLocal, dqSummary]);

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

  const demoDqAlerts = useMemo(() => {
    if (!isLocal || dqAlerts.length) return dqAlerts;
    return [
      {
        table_schema: "dm",
        table_name: "demo_sales",
        entity_name: "DEMO_ENTITY",
        type: "row_count",
        delta_pct: 18.4,
        metric_value: 0,
        dt: "2026-02-24"
      }
    ];
  }, [isLocal, dqAlerts]);

  const toggleCycleDetails = async (cycle, key) => {
    setCycleOpen((prev) => ({ ...prev, [key]: !prev[key] }));
    if (cycleDetails[key]?.state || cycleOpen[key]) return;

    const entities = Array.isArray(cycle?.nodes) ? cycle.nodes : [];
    if (!entities.length) return;

    const maxEntities = 6;
    const limitedEntities = entities.slice(0, maxEntities);
    setCycleDetails((prev) => ({ ...prev, [key]: { state: "loading" } }));

    try {
      const responses = await Promise.all(
        limitedEntities.map((name) =>
          apiClient
            .get(`/api/graph/entity/${encodeURIComponent(name)}`)
            .catch(() => null)
            .then((payload) => ({ name, payload }))
        )
      );

      const entityTables = responses.map(({ name, payload }) => {
        const lower = (name || "").toLowerCase();
        const nodes = payload?.nodes || [];
        const tables = nodes
          .filter((node) => {
            const entities = node.entities || [];
            const entityMatch = entities.some((e) => String(e).toLowerCase() === lower);
            const singleMatch = String(node.entity || "").toLowerCase() === lower;
            return entityMatch || singleMatch;
          })
          .map((node) => node.id)
          .filter(Boolean);
        const uniqueTables = Array.from(new Set(tables));
        return { name, tables: uniqueTables };
      });

      setCycleDetails((prev) => ({
        ...prev,
        [key]: {
          state: "ready",
          entities: entityTables,
          hiddenCount: Math.max(entities.length - maxEntities, 0),
        },
      }));
    } catch (err) {
      setCycleDetails((prev) => ({ ...prev, [key]: { state: "error" } }));
    }
  };

  const demoNightSummary = useMemo(() => {
    if (!isLocal || nightSummary) return nightSummary;
    return {
      summary: { runs_count: 124, tables_count: 86, entities_count: 14, total_duration_minutes: 612 },
      failed_summary: { runs_count: 3 },
      top_runs: [
        { table_fqn: "dm.demo_sales", duration_minutes: 38.2, entity_name: "DEMO_ENTITY", table_id: 101 }
      ],
      anomalies: [
        { table_fqn: "ods.demo_orders", duration_minutes: 12.1, ratio: 1.7, entity_name: "DEMO_ENTITY", table_id: 55 }
      ],
      failed_runs: [
        { table_fqn: "dds.demo_fail", entity_name: "DEMO_ENTITY", table_id: 88, message: "Timeout" }
      ],
      hourly: [{ hour: 4, total_duration_minutes: 106 }]
    };
  }, [isLocal, nightSummary]);

  const demoOrderBreaches = useMemo(() => {
    if (!isLocal || orderBreaches.length) return orderBreaches;
    return [
      {
        target_fqn: "dm.demo_sales",
        worst_upstream: "dds.demo_source",
        worst_upstream_time: "2026-02-24 04:48",
        target_last_load: "2026-02-24 04:30",
        gap_minutes: 18,
        severity: "MAJOR"
      }
    ];
  }, [isLocal, orderBreaches]);

  const demoEntityMutual = useMemo(() => {
    if (!isLocal || entityMutual.length) return entityMutual;
    return [
      { a: "SALES", b: "FINANCE", edges_ab_count: 2, edges_ba_count: 1, edges_ab_sample: [], edges_ba_sample: [] }
    ];
  }, [isLocal, entityMutual]);

  const demoHistory = useMemo(() => {
    if (!isLocal || history.length) return history;
    return [
      { table: "dm.demo_sales", count: 3, last_incident: "2026-02-23 06:10" },
      { table: "ods.demo_orders", count: 2, last_incident: "2026-02-22 04:58" }
    ];
  }, [isLocal, history]);

  const demoTimeline = useMemo(() => {
    if (!isLocal || incidentTimeline.length) return incidentTimeline;
    return [
      { day: "2026-02-18", count: 1 },
      { day: "2026-02-19", count: 0 },
      { day: "2026-02-20", count: 2 },
      { day: "2026-02-21", count: 1 },
      { day: "2026-02-22", count: 1 },
      { day: "2026-02-23", count: 2 },
      { day: "2026-02-24", count: 1 }
    ];
  }, [isLocal, incidentTimeline]);

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
      const json = await apiClient.get("/api/dependencies", { params: { table: target } });
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

  const loadEntityLinkDetails = (pair, key) => {
    if (!pair || !pair.a || !pair.b) return;
    if (entityLinkDetails[key]?.state === "loading" || entityLinkDetails[key]?.state === "ready") {
      return;
    }
    setEntityLinkDetails((prev) => ({
      ...prev,
      [key]: { state: "loading", edges_ab: [], edges_ba: [] },
    }));
    apiClient
      .get("/api/graph/diagnostics/mutual", {
        params: { entity_a: pair.a, entity_b: pair.b, strict: true },
      })
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

  const incidentTrendLabel = useMemo(() => {
    if (incidentTrend === "up") return "Инцидентов становится больше";
    if (incidentTrend === "down") return "Инцидентов становится меньше";
    if (incidentTrend === "stable") return "Инциденты без заметного изменения";
    return null;
  }, [incidentTrend]);

  const nightPeakHour = useMemo(() => {
    if (!demoNightSummary?.hourly?.length) return null;
    const sorted = [...demoNightSummary.hourly].sort(
      (a, b) => (b.total_duration_minutes || 0) - (a.total_duration_minutes || 0)
    );
    return sorted[0];
  }, [demoNightSummary]);

  const timelineMax = useMemo(() => {
    if (!demoTimeline.length) return 0;
    return Math.max(...demoTimeline.map((d) => d.count || 0));
  }, [demoTimeline]);

  const healthScore = useMemo(() => {
    const base = 100;
    const incidentPenalty = Math.min(demoActiveIncidents.length * 15, 45);
    const errorPenalty = metrics?.error_count ? Math.min(metrics.error_count * 2, 30) : 0;
    const breachPenalty = Math.min(demoOrderBreaches.length * 3, 25);
    const score = Math.max(0, Math.round(base - incidentPenalty - errorPenalty - breachPenalty));
    let level = "Норма";
    let levelKey = "healthy";
    if (score < 65) {
      level = "Критично";
      levelKey = "critical";
    } else if (score < 85) {
      level = "Риск";
      levelKey = "degraded";
    }
    return { score, level, levelKey };
  }, [demoActiveIncidents.length, metrics?.error_count, demoOrderBreaches.length]);

  const visibleOrderBreaches = useMemo(() => {
    return showAllOrderBreaches ? demoOrderBreaches : demoOrderBreaches.slice(0, 10);
  }, [demoOrderBreaches, showAllOrderBreaches]);

  return (
    <div className="container cc-page">
      <section className="cc-hero">
        <div className="cc-hero-main">
          <div className="cc-hero-title">Операционный обзор DWH</div>
          <div className="cc-hero-subtitle">
            Инциденты, качество данных, надежность загрузок и риски зависимостей.
          </div>
          <div className="cc-hero-status">
            <span className={`status-dot ${demoActiveIncidents.length ? "degraded" : ""}`} />
            <span className="status-text">
              {demoActiveIncidents.length ? "Есть активные инциденты" : "Система работает стабильно"}
            </span>
          </div>
          <div className="cc-hero-refresh">
            <span className="muted">Последнее обновление</span>
            <span className="muted">{lastRefreshLabel}</span>
          </div>
        </div>
        <div className="cc-hero-health">
          <div className="health-card">
            <div className="health-label">Здоровье DWH</div>
            <div className="health-score">{healthScore.score}</div>
            <div className={`health-badge health-${healthScore.levelKey}`}>
              {healthScore.level}
            </div>
            <div className="health-meta">
              На основе инцидентов, сбоев и нарушений порядка загрузки.
            </div>
            {incidentTrendLabel && (
              <div className={`health-trend trend-${incidentTrend}`}>
                {incidentTrendLabel}
              </div>
            )}
          </div>
        </div>
      </section>

      {metrics && (
        <section className="cc-overview-bar">
          <div className="overview-item">
            <span className="overview-value">{metrics.total_tables}</span>
            <span className="overview-label">Таблиц</span>
          </div>

          <div className="overview-item danger">
            <span className="overview-value">{metrics.error_count}</span>
            <span className="overview-label">Неуспешных запусков (24ч)</span>
          </div>

          <div className="overview-item">
            <span className="overview-value">
              {metrics.avg_duration_minutes ?? "—"}
            </span>
            <span className="overview-label">Средняя длит. (24ч), мин</span>
          </div>

          <div className="overview-item">
            <span className="overview-value">{metrics.active_entities}</span>
            <span className="overview-label">Сущностей</span>
          </div>
        </section>
      )}

      {/* ===== NIGHT SUMMARY ===== */}
      {!loading && (
        <section className="cc-surface">
          <div className="section-title">Ночное окно (последний запуск)</div>
          {nightLoading && <div className="muted">Загрузка ночного окна...</div>}
          {nightError && <div className="dep-error-title">{nightError}</div>}
          {!nightLoading && !nightError && demoNightSummary && (
            <>
              <div className="night-kpis">
                <div className="night-kpi-card">
                  <div className="night-kpi-label">Запусков</div>
                  <div className="night-kpi-value">{demoNightSummary?.summary?.runs_count ?? 0}</div>
                </div>
                <div className="night-kpi-card">
                  <div className="night-kpi-label">Таблиц</div>
                  <div className="night-kpi-value">{demoNightSummary?.summary?.tables_count ?? 0}</div>
                </div>
                <div className="night-kpi-card">
                  <div className="night-kpi-label">Сущностей</div>
                  <div className="night-kpi-value">{demoNightSummary?.summary?.entities_count ?? 0}</div>
                </div>
                <div className="night-kpi-card">
                  <div className="night-kpi-label">Суммарно</div>
                  <div className="night-kpi-value">
                    {demoNightSummary?.summary?.total_duration_minutes ?? 0} мин
                  </div>
                </div>
                <div className="night-kpi-card">
                  <div className="night-kpi-label">Пик</div>
                  <div className="night-kpi-value">
                    {nightPeakHour ? String(nightPeakHour.hour).padStart(2, "0") + ":00" : "—"}
                  </div>
                </div>
              </div>
              <div className="night-columns">
                <div className="night-panel">
                  <div className="night-panel-title">Самые долгие</div>
                  <div className="night-panel-sub muted">Топ-5 по длительности</div>
                  <div className="night-list">
                    {(demoNightSummary.top_runs || []).slice(0, 5).map((row) => (
                      <button
                        key={`${row.table_fqn}-${row.start}`}
                        className="night-row"
                        onClick={() => onSelectTable({ view: "table_info", table: row.table_fqn }, "home")}
                      >
                        <div className="night-row-main">
                          <div className="night-row-title mono">{row.table_fqn}</div>
                          <div className="night-row-sub muted">
                            Сущность: {row.entity_name || "—"} · ID {row.table_id ?? "—"}
                          </div>
                        </div>
                        <div className="night-row-meta">
                          <span className="night-row-badge">{row.duration_minutes ?? "—"} мин</span>
                        </div>
                      </button>
                    ))}
                    {!demoNightSummary?.top_runs?.length && (
                      <div className="muted">Запусков не найдено.</div>
                    )}
                  </div>
                </div>
                <div className="night-panel">
                  <div className="night-panel-title">Аномалии vs p95</div>
                  <div className="night-panel-sub muted">Запуски &gt; 1.5× p95</div>
                  <div className="night-list">
                    {(demoNightSummary.anomalies || []).slice(0, 5).map((row) => (
                      <button
                        key={`${row.table_fqn}-${row.start}`}
                        className="night-row"
                        onClick={() => onSelectTable({ view: "table_info", table: row.table_fqn }, "home")}
                      >
                        <div className="night-row-main">
                          <div className="night-row-title mono">{row.table_fqn}</div>
                          <div className="night-row-sub muted">
                            Сущность: {row.entity_name || "—"} · ID {row.table_id ?? "—"}
                          </div>
                        </div>
                        <div className="night-row-meta">
                          <span className="night-row-badge">{row.duration_minutes ?? "—"} мин</span>
                          <span className="night-row-badge night-row-badge-warn">{row.ratio ?? "—"}x</span>
                        </div>
                      </button>
                    ))}
                    {!demoNightSummary?.anomalies?.length && (
                      <div className="muted">Аномалий нет.</div>
                    )}
                  </div>
                </div>
                <div className="night-panel">
                  <div className="night-panel-title">Падения</div>
                  <div className="night-panel-sub muted">
                    {demoNightSummary?.failed_summary?.runs_count ?? 0} ошибок
                  </div>
                  <div className="night-list">
                    {(demoNightSummary.failed_runs || []).slice(0, 5).map((row) => (
                      <button
                        key={`${row.table_fqn}-${row.start}`}
                        className="night-row"
                        onClick={() => onSelectTable({ view: "table_info", table: row.table_fqn }, "home")}
                      >
                        <div className="night-row-main">
                          <div className="night-row-title mono">{row.table_fqn}</div>
                          <div className="night-row-sub muted">
                            Сущность: {row.entity_name || "—"} · ID {row.table_id ?? "—"}
                          </div>
                          <div className="night-row-message">
                            {row.message || "FAILED"}
                          </div>
                        </div>
                      </button>
                    ))}
                    {!demoNightSummary?.failed_runs?.length && (
                      <div className="muted">Сбоев нет.</div>
                    )}
                  </div>
                </div>
              </div>
            </>
          )}
          {!nightLoading && !nightError && !demoNightSummary && (
            <div className="muted">Ночное окно недоступно.</div>
          )}
        </section>
      )}

      {/* ===== ORDER BREACHES ===== */}
      {!loading && (
        <section className="cc-surface">
          <div className="section-title">
            Нарушения порядка загрузки
            <span className="section-meta">{demoOrderBreaches.length}</span>
          </div>
          {demoOrderBreaches.length === 0 && (
            <div className="muted">Нарушений порядка загрузки не найдено.</div>
          )}
          {demoOrderBreaches.length > 0 && (
          <div className="order-list">
            {visibleOrderBreaches.map((breach) => (
              <article key={breach.target_fqn} className="order-row">
                <header className="order-row-header">
                  <div>
                    <div className="order-row-target mono" title={breach.target_fqn}>{breach.target_fqn}</div>
                    <div className="order-row-meta">
                      Источник завершился позже: <span title={breach.worst_upstream}>{breach.worst_upstream}</span>
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
                  {breach.worst_upstream} завершилась {formatTime(breach.worst_upstream_time)}, а {breach.target_fqn} завершилась
                  {" "}
                  {formatTime(breach.target_last_load)}. Разрыв +{breach.gap_minutes} мин.
                </p>


                <div className="order-row-actions">
                  <button
                    className="btn btn-secondary"
                    onClick={() => onSelectTable({ view: "table_info", table: breach.target_fqn }, "home")}
                  >
                    Карточка
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
                        <div className="order-impact-title">Зависимые таблицы</div>
                        <div className="muted">
                          Построено по зависимостям {breach.target_fqn}
                        </div>
                      </div>
                      <div className="order-impact-count">
                        {impactMap[breach.target_fqn]?.rows?.length || 0}
                      </div>
                    </div>
                    {impactMap[breach.target_fqn]?.state === "loading" && (
                      <div className="muted">Загрузка влияния...</div>
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
                          const entityName = row.entity_name || (row.entity_id ? `Сущность ${row.entity_id}` : fqn);
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
                              Есть косвенные зависимости — в пути показаны промежуточные таблицы.
                            </div>
                            <div className="order-runbook">
                              <div className="order-runbook-title">Порядок пересчета сущностей</div>
                              <div className="muted order-runbook-sub">
                                Рекомендуемый порядок пересчета после {breach.target_fqn}
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
            {demoOrderBreaches.length > 10 && (
              <div className="order-row-actions">
                <button
                  className="btn btn-ghost"
                  onClick={() => setShowAllOrderBreaches((prev) => !prev)}
                >
                  {showAllOrderBreaches
                    ? "Свернуть список"
                    : `Показать все (${demoOrderBreaches.length})`}
                </button>
              </div>
            )}
          </div>
          )}
        </section>
      )}

      {/* ===== CLICKHOUSE LOADS ===== */}
      {!loading && clickSummary && (
        <section className="cc-surface">
          <div className="section-title">
            ClickHouse загрузки (7 дней)
            <span className="section-meta">{clickSummary.total_runs || 0}</span>
          </div>
          <div className="muted" style={{ marginBottom: 12 }}>
            Источник: ClickHouse (этапы S3 и загрузка в ClickHouse).
          </div>
          <div className="entity-grid">
            <div className="entity-card">
              <div className="entity-name">Объектов</div>
              <div className="entity-meta">{clickSummary.total_tables || 0}</div>
            </div>
            <div className="entity-card critical">
              <div className="entity-name">Ошибки</div>
              <div className="entity-meta">{clickSummary.failed_runs || 0} запусков</div>
            </div>
            <div className="entity-card">
              <div className="entity-name">Успешных объектов</div>
              <div className="entity-meta">{clickSummary.ok_tables || 0}</div>
            </div>
            <div className="entity-card">
              <div className="entity-name">Запусков</div>
              <div className="entity-meta">{clickSummary.total_runs || 0}</div>
            </div>
            <div className="entity-card">
              <div className="entity-name">Средняя длительность</div>
              <div className="entity-meta">
                {Number.isFinite(clickSummary.avg_duration_min) ? `${clickSummary.avg_duration_min} мин` : "—"}
              </div>
            </div>
            <div className="entity-card">
              <div className="entity-name">Среднее ожидание</div>
              <div className="entity-meta">
                {Number.isFinite(clickSummary.avg_lag_min) ? `${clickSummary.avg_lag_min} мин` : "—"}
              </div>
            </div>
            <div className="entity-card">
              <div className="entity-name">Последняя выгрузка</div>
              <div className="entity-meta">{clickSummary.last_finish || "—"}</div>
            </div>
          </div>
          <div className="muted" style={{ marginTop: 10 }}>
            В процессе: {clickSummary.running_runs || 0} · Повторы: {clickSummary.retry_runs || 0}
          </div>

          {clickFailures.length > 0 && (
            <div className="order-list" style={{ marginTop: 12 }}>
              {clickFailures.map((row, idx) => {
                const fqn = `${row.schema_name}.${row.table_name}`;
                return (
                  <article key={`${fqn}-${idx}`} className="order-row">
                    <header className="order-row-header">
                      <div>
                        <div className="order-row-target mono">{fqn}</div>
                        <div className="order-row-meta">
                          {row.dag_name || "—"} · {row.dag_run || "—"}
                        </div>
                      </div>
                      <div className={`order-pill order-pill-warning status-${String(row.status || "").toLowerCase()}`}>
                        {clickStatusLabel(row.status)}
                      </div>
                    </header>
                    <div className="order-row-text">
                      Старт {formatTime(row.start_dttm)} · Финиш {formatTime(row.end_dttm)} · Работа {formatMinutes(row.actual_duration_min ?? row.duration_min)} · Ожидание/пауза {formatMinutes(row.lag_duration_min ?? 0)}
                    </div>
                    {(row.problem_area || row.stage_name) && (
                      <div className="order-row-meta" style={{ marginTop: 6 }}>
                        {row.problem_area ? `Проблема: ${row.problem_area}` : "Проблема: —"}
                        {row.stage_name ? ` · Этап: ${row.stage_name}` : ""}
                      </div>
                    )}
                    {row.error_text && (
                      <div className="order-row-meta" style={{ marginTop: 6 }}>
                        {row.error_text}
                      </div>
                    )}
                    <div className="order-row-actions">
                      <button
                        className="btn btn-secondary"
                        onClick={() => onSelectTable({ view: "table_info", table: fqn }, "home")}
                      >
                        Карточка
                      </button>
                    </div>
                  </article>
                );
              })}
            </div>
          )}

          {clickSlow.length > 0 && (
            <div className="order-list" style={{ marginTop: 16 }}>
              <div className="section-subtitle">Долгие выгрузки (топ 6)</div>
              {clickSlow.map((row, idx) => {
                const fqn = `${row.schema_name}.${row.table_name}`;
                return (
                  <article key={`${fqn}-${idx}`} className="order-row">
                    <header className="order-row-header">
                      <div>
                        <div className="order-row-target mono">{fqn}</div>
                        <div className="order-row-meta">
                          {row.dag_name || "—"} · {row.dag_run || "—"}
                        </div>
                      </div>
                      <div className={`order-pill status-${String(row.status || "").toLowerCase()}`}>
                        {clickStatusLabel(row.status)}
                      </div>
                    </header>
                    <div className="order-row-text">
                      Старт {formatTime(row.start_dttm)} · Финиш {formatTime(row.end_dttm)} · Работа {formatMinutes(row.actual_duration_min ?? row.duration_min)} · Ожидание/пауза {formatMinutes(row.lag_duration_min ?? 0)}
                    </div>
                    <div className="order-row-actions">
                      <button
                        className="btn btn-secondary"
                        onClick={() => onSelectTable({ view: "table_info", table: fqn }, "home")}
                      >
                        Карточка
                      </button>
                    </div>
                  </article>
                );
              })}
            </div>
          )}
        </section>
      )}

      {/* ===== ACTIVE INCIDENTS ===== */}
      {loading && <div className="muted">Загрузка...</div>}

      {!loading && demoActiveIncidents.length === 0 && (
        <section className="cc-surface">
          <div className="system-ok system-ok-compact">
            <div className="system-ok-icon">✓</div>
            <div>
              <div className="system-ok-title">Активных инцидентов нет</div>
              <div className="system-ok-sub">
                За последние 24 часа сбоев не было
              </div>
            </div>
          </div>
        </section>
      )}

      {!loading && demoActiveIncidents.length > 0 && (
        <section className="cc-surface">
          <div className="section-title">
            Активные инциденты
            <span className="section-meta">{demoActiveIncidents.length}</span>
          </div>

          <div className="entity-grid">
            {demoActiveIncidents.map((i, idx) => (
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
                  <span className="pill pill-critical">КРИТИЧНО</span>
                </div>

                <div className="entity-meta">
                  Ошибочных таблиц: {i.failed_tables}
                </div>

                <div className="entity-meta">
                  Последняя ошибка: {i.last_failure_time}
                </div>

                <div className="incident-hint">
                  Открыть инцидент →
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ===== DATA QUALITY ===== */}
      {!loading && (
        <section className="cc-surface">
          <div className="section-title">
            Качество данных (7 дней)
            <span className="section-meta">{demoDqAlerts.length}</span>
          </div>
          {demoDqSummary && (
            <div className="dq-summary-grid">
              <div className="dq-summary-card">
                <div className="dq-summary-label">Таблиц с дублями</div>
                <div className="dq-summary-value">{demoDqSummary.duplicate_tables ?? 0}</div>
              </div>
              <div className="dq-summary-card">
                <div className="dq-summary-label">Таблиц с отклонением по строкам</div>
                <div className="dq-summary-value">{demoDqSummary.row_count_tables ?? 0}</div>
                <div className="dq-summary-hint muted">
                  Проверено: {demoDqSummary.row_count_checked ?? 0} · порог отклонения от медианы: 10%
                </div>
              </div>
            </div>
          )}

          {demoDqAlerts.length === 0 && (
            <div className="muted">Алертов качества данных нет.</div>
          )}
          {demoDqAlerts.length > 0 && (
            <div className="dq-alerts-list">
              {demoDqAlerts.slice(0, dqLimit).map((row, idx) => {
                const fqn = `${row.table_schema}.${row.table_name}`;
                return (
                  <button
                    key={`${fqn}-${idx}`}
                    className="dq-alert-row"
                    onClick={() => onSelectTable({ view: "table_info", table: fqn }, "home")}
                  >
                    <div className="dq-alert-main">
                      <div className="dq-alert-title mono">{fqn}</div>
                      <div className="dq-alert-sub muted">
                        {row.entity_name || "—"} · {row.type === "duplicate_check" ? "Дубли" : "Кол-во строк"}
                      </div>
                    </div>
                    <div className="dq-alert-meta">
                      <span className="dq-alert-pill">
                        {row.type === "duplicate_check"
                          ? `${fmtInt(row.metric_value)} дублей`
                          : `Δ ${fmtPct(row.delta_pct)}`}
                      </span>
                      <span className="dq-alert-date muted">{row.dt || "—"}</span>
                    </div>
                  </button>
                );
              })}
            </div>
          )}
        </section>
      )}

      {/* ===== TABLE CYCLES ===== */}
      {/* table cycles hidden on homepage to reduce noise */}

      {/* ===== INCIDENT HISTORY ===== */}
      {!loading && demoHistory.length > 0 && (
        <section className="cc-surface">
          <div className="section-title">
            Инциденты: топ проблем (7 дней)
            <span className="section-meta">по частоте ошибок</span>
          </div>
          <div className="muted" style={{ marginBottom: 12 }}>
            Таблицы с наибольшим числом сбоев за 7 дней. При открытии показывается история запусков и затронутая цепочка.
          </div>
          {demoTimeline.length > 0 && (
            <div className="incident-mini">
              {demoTimeline.map((row) => {
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
              <span>Таблица</span>
              <span>Инцидентов</span>
              <span>Последний раз</span>
            </div>
            {demoHistory.slice(0, 8).map((h, idx) => (
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

      {!loading && (entityCycles.length > 0 || demoEntityMutual.length > 0) && (
        <section className="cc-surface">
          <div className="section-title">
            Архитектура и риски зависимостей
            <span className="section-meta">{entityCycles.length + demoEntityMutual.length}</span>
          </div>
          <div className="home-architecture-summary">
            <div className="home-architecture-card">
              <div className="home-architecture-value">{demoEntityMutual.length}</div>
              <div className="home-architecture-label">Взаимных связок сущностей</div>
            </div>
            <div className="home-architecture-card">
              <div className="home-architecture-value">{entityCycles.length}</div>
              <div className="home-architecture-label">Циклов сущностей</div>
            </div>
            <button className="home-architecture-card home-architecture-link" onClick={() => navigate("/entities")}>
              <div className="home-architecture-value">Открыть</div>
              <div className="home-architecture-label">Справочник сущностей и покрытие</div>
            </button>
          </div>

          <div className="home-architecture-grid">
            <div className="home-architecture-panel">
              <div className="section-subtitle">Взаимные зависимости</div>
              <div className="muted">Сущности зависят друг от друга в обе стороны и создают неоднозначный порядок пересчета.</div>
              <div className="order-list" style={{ marginTop: 12 }}>
                {demoEntityMutual.slice(0, 4).map((pair, idx) => {
                  const key = `${pair.a}::${pair.b}`;
                  const details = entityLinkDetails[key];
                  return (
                    <article key={`mutual-${idx}`} className="order-row">
                      <header className="order-row-header">
                        <div>
                          <div className="order-row-target mono">Взаимная зависимость</div>
                          <div className="order-row-meta">{pair.a} ↔ {pair.b}</div>
                        </div>
                        <div className="order-pill order-pill-warning">ВЗАИМНО</div>
                      </header>
                      <div className="order-row-chain">
                        <span className="order-node mono">{pair.a}</span>
                        <span className="order-arrow">↔</span>
                        <span className="order-node mono">{pair.b}</span>
                      </div>
                      <div className="order-row-actions">
                        <button className="btn btn-ghost" onClick={() => toggleEntityLink(pair, key)}>
                          {entityLinkOpen[key] ? "Скрыть таблицы" : "Показать таблицы"}
                        </button>
                        <div className="muted">{pair.edges_ab_count || 0} → {pair.edges_ba_count || 0}</div>
                      </div>
                      {entityLinkOpen[key] && (
                        <div className="order-impact">
                          <div className="order-impact-title">Связующие таблицы</div>
                          <div className="order-row-chain" style={{ flexWrap: "wrap", gap: 8 }}>
                            <span className="order-node mono" style={{ borderColor: "#38bdf8" }}>{pair.a}</span>
                            <span className="order-arrow">→</span>
                            <span className="order-node mono" style={{ borderColor: "#f97316" }}>{pair.b}</span>
                          </div>
                          <div className="order-row-chain" style={{ flexWrap: "wrap", gap: 8, marginTop: 8 }}>
                            {(details?.edges_ab || pair.edges_ab_sample || []).map((edge, edgeIdx) => (
                              <span key={`ab-${edge.source}-${edge.target}-${edgeIdx}`} className="order-node mono">
                                <button className="btn btn-ghost" onClick={() => onSelectTable({ view: "table_info", table: edge.source }, "home")}>
                                  {edge.source}
                                </button>
                                {edge.source_entities && edge.source_entities.length > 0 && (
                                  <span className="muted">[{edge.source_entities.join(", ")}]</span>
                                )}
                                <span className="order-arrow">→</span>
                                <button className="btn btn-ghost" onClick={() => onSelectTable({ view: "table_info", table: edge.target }, "home")}>
                                  {edge.target}
                                </button>
                                {edge.target_entities && edge.target_entities.length > 0 && (
                                  <span className="muted">[{edge.target_entities.join(", ")}]</span>
                                )}
                              </span>
                            ))}
                            {!details?.edges_ab?.length && !pair.edges_ab_sample?.length && (
                              <span className="muted">Нет примеров для {pair.a} → {pair.b}</span>
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
                                <button className="btn btn-ghost" onClick={() => onSelectTable({ view: "table_info", table: edge.source }, "home")}>
                                  {edge.source}
                                </button>
                                {edge.source_entities && edge.source_entities.length > 0 && (
                                  <span className="muted">[{edge.source_entities.join(", ")}]</span>
                                )}
                                <span className="order-arrow">→</span>
                                <button className="btn btn-ghost" onClick={() => onSelectTable({ view: "table_info", table: edge.target }, "home")}>
                                  {edge.target}
                                </button>
                                {edge.target_entities && edge.target_entities.length > 0 && (
                                  <span className="muted">[{edge.target_entities.join(", ")}]</span>
                                )}
                              </span>
                            ))}
                            {!details?.edges_ba?.length && !pair.edges_ba_sample?.length && (
                              <span className="muted">Нет примеров для {pair.b} → {pair.a}</span>
                            )}
                          </div>
                          <div className="order-row-actions" style={{ marginTop: 8 }}>
                            <button className="btn btn-secondary" onClick={() => loadEntityLinkDetails(pair, key)}>
                              Обновить список
                            </button>
                            {details?.state === "loading" && <span className="muted">Загрузка...</span>}
                            {details?.state === "error" && <span className="muted">Ошибка</span>}
                          </div>
                        </div>
                      )}
                    </article>
                  );
                })}
                {!demoEntityMutual.length && <div className="muted">Взаимных связей не найдено.</div>}
              </div>
            </div>

            <div className="home-architecture-panel">
              <div className="section-subtitle">Циклы сущностей</div>
              <div className="muted">Замкнутые контуры, которые требуют проверки логики и ручного разрыва порядка расчета.</div>
              <div className="order-list" style={{ marginTop: 12 }}>
                {entityCycles.slice(0, 4).map((cycle, idx) => (
                  <article key={`cycle-${idx}`} className="order-row">
                    <header className="order-row-header">
                      <div>
                        <div className="order-row-target mono">Цикл сущностей</div>
                        <div className="order-row-meta">Сущностей: {cycle.size}</div>
                      </div>
                      <div className="order-pill order-pill-warning">ЦИКЛ</div>
                    </header>
                    <div className="order-row-chain">
                      {cycle.nodes.slice(0, 6).map((node, i) => (
                        <span key={`${node}-${i}`} className="order-node mono">{node}</span>
                      ))}
                      {cycle.nodes.length > 6 && <span className="order-node">…</span>}
                    </div>
                    <div className="order-row-actions">
                      <button className="btn btn-ghost" onClick={() => toggleCycleDetails(cycle, `cycle-${idx}`)}>
                        {cycleOpen[`cycle-${idx}`] ? "Скрыть таблицы цикла" : "Показать таблицы цикла"}
                      </button>
                      {cycleDetails[`cycle-${idx}`]?.state === "loading" && <span className="muted">Загрузка...</span>}
                      {cycleDetails[`cycle-${idx}`]?.state === "error" && <span className="muted">Ошибка</span>}
                    </div>
                    {cycleOpen[`cycle-${idx}`] && cycleDetails[`cycle-${idx}`]?.state === "ready" && (
                      <div className="order-impact">
                        <div className="order-impact-title">Таблицы в цикле</div>
                        {cycleDetails[`cycle-${idx}`]?.entities?.map((entity) => (
                          <div key={entity.name} className="order-impact-group">
                            <div className="order-impact-group-title">
                              <span>{entity.name}</span>
                              <span className="order-impact-badge">{entity.tables.length}</span>
                            </div>
                            <div className="order-impact-list">
                              {(entity.tables || []).slice(0, 10).map((fqn) => (
                                <button key={fqn} className="btn btn-ghost" onClick={() => onSelectTable({ view: "table_info", table: fqn }, "home")}>
                                  {fqn}
                                </button>
                              ))}
                              {(entity.tables || []).length > 10 && <span className="muted">… ещё {entity.tables.length - 10}</span>}
                            </div>
                          </div>
                        ))}
                        {cycleDetails[`cycle-${idx}`]?.hiddenCount > 0 && (
                          <div className="muted" style={{ marginTop: 8 }}>
                            Ещё сущностей: {cycleDetails[`cycle-${idx}`].hiddenCount}
                          </div>
                        )}
                      </div>
                    )}
                  </article>
                ))}
                {!entityCycles.length && <div className="muted">Циклов не найдено.</div>}
              </div>
            </div>
          </div>
        </section>
      )}
    </div>
  );
}
  const formatTime = (value) => {
    if (!value) return "—";
    return formatRuDateTime(value, {
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
        return "Серьезно";
      default:
        return "Внимание";
    }
  };
