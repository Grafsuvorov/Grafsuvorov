import { useEffect, useMemo, useRef, useState } from "react";
import "../style/app.css";
import GraphViewer from "./GraphViewer.jsx";
import GanttChart from "./GanttChart.jsx";
import { sendAuditEvent } from "../utils/audit.js";
import { formatLocalDateTime } from "../utils/datetime.js";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function TableCard({
  schema,
  tableName,
  source = "current",
  onBack,
  onNavigateTable,
  onOpenImpact,
  onOpenLogicAudit,
  autoShowGraph = false,
  tableContext = null,
}) {
  const formatMinutes = (value) => (value !== null && value !== undefined ? `${value} мин` : "—");
  const formatDurationMmSs = (value) => {
    const minutes = Number(value);
    if (!Number.isFinite(minutes)) return "—";
    const totalSeconds = Math.max(0, Math.round(minutes * 60));
    const mm = Math.floor(totalSeconds / 60);
    const ss = totalSeconds % 60;
    return `${String(mm).padStart(2, "0")}:${String(ss).padStart(2, "0")}`;
  };
  const formatDurationDelta = (currentValue, previousValue) => {
    const current = Number(currentValue);
    const previous = Number(previousValue);
    if (!Number.isFinite(current) || !Number.isFinite(previous)) return "—";
    const deltaSeconds = Math.round((current - previous) * 60);
    const sign = deltaSeconds > 0 ? "+" : deltaSeconds < 0 ? "-" : "±";
    const absSeconds = Math.abs(deltaSeconds);
    const mm = Math.floor(absSeconds / 60);
    const ss = absSeconds % 60;
    return `${sign}${String(mm).padStart(2, "0")}:${String(ss).padStart(2, "0")}`;
  };
  const isCurrentSource = source === "current";
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
  const [dbtHistory, setDbtHistory] = useState([]);
  const [dbtHistoryLoading, setDbtHistoryLoading] = useState(false);
  const [dbtHistoryError, setDbtHistoryError] = useState(null);
  const [dbtHistoryConfigured, setDbtHistoryConfigured] = useState(true);
  const [dbtHistoryAvailable, setDbtHistoryAvailable] = useState(true);
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
  const [clickHistory, setClickHistory] = useState([]);
  const [clickHistoryLoading, setClickHistoryLoading] = useState(false);
  const [clickHistoryError, setClickHistoryError] = useState(null);
  const [historyMode, setHistoryMode] = useState("gp");
  const [viewMatches, setViewMatches] = useState([]);
  const [viewSearchLoading, setViewSearchLoading] = useState(false);
  const [viewSearchError, setViewSearchError] = useState(null);
  const [releaseItems, setReleaseItems] = useState([]);
  const [releaseLoading, setReleaseLoading] = useState(false);
  const [releaseError, setReleaseError] = useState(null);
  const [ytData, setYtData] = useState(null);
  const [ytLoading, setYtLoading] = useState(false);
  const [ytError, setYtError] = useState(null);
  const [showAllReleases, setShowAllReleases] = useState(false);
  const [showAllTasks, setShowAllTasks] = useState(false);
  const [showAllTimeline, setShowAllTimeline] = useState(false);
  const [analyticsSummary, setAnalyticsSummary] = useState(null);
  const [analyticsLoading, setAnalyticsLoading] = useState(false);
  const [analyticsError, setAnalyticsError] = useState(null);
  const [isFavorite, setIsFavorite] = useState(false);
  const [favoriteLoading, setFavoriteLoading] = useState(false);
  const [expandedGpErrors, setExpandedGpErrors] = useState({});
  const [expandedClickErrors, setExpandedClickErrors] = useState({});
  const [expandedDbtErrors, setExpandedDbtErrors] = useState({});
  const [showAllDbtUpstream, setShowAllDbtUpstream] = useState(false);
  const [showAllDbtColumns, setShowAllDbtColumns] = useState(false);
  const [showAllDbtConfig, setShowAllDbtConfig] = useState(false);
  const [showAllDbtMeta, setShowAllDbtMeta] = useState(false);
  const graphSectionRef = useRef(null);
  const historyRequestRef = useRef(0);
  const clickRunsRequestRef = useRef(0);
  const clickHistoryRequestRef = useRef(0);
  const dbtHistoryRequestRef = useRef(0);
  const gpHistoryWithDelta = useMemo(
    () =>
      (historyRows || []).map((row, idx, arr) => ({
        ...row,
        previous_duration_minutes:
          idx + 1 < arr.length ? arr[idx + 1]?.duration_minutes ?? null : null,
      })),
    [historyRows],
  );
  const clickHistoryWithDelta = useMemo(
    () =>
      (clickHistory || []).map((row, idx, arr) => ({
        ...row,
        current_duration_minutes: row.actual_duration_min ?? row.duration_min ?? null,
        previous_duration_minutes:
          idx + 1 < arr.length
            ? arr[idx + 1]?.actual_duration_min ?? arr[idx + 1]?.duration_min ?? null
            : null,
      })),
    [clickHistory],
  );

  useEffect(() => {
    if (!schema || !tableName) {
      return;
    }

    setLoadingMeta(true);
    setError(null);
    const params = new URLSearchParams();
    if (source && source !== "current") {
      params.set("source", source);
    }
    const suffix = params.toString() ? `?${params.toString()}` : "";
    fetch(`${API_BASE}/api/card/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}${suffix}`)
      .then((res) => {
        if (!res.ok) throw new Error("Не удалось загрузить карточку таблицы");
        return res.json();
      })
      .then(setMeta)
      .catch((err) => setError(err.message || String(err)))
      .finally(() => setLoadingMeta(false));
  }, [schema, tableName, source]);

  useEffect(() => {
    if (!isCurrentSource || !meta?.table_id) {
      setIsFavorite(false);
      return;
    }
    fetch(`${API_BASE}/auth/favorites/tables/${encodeURIComponent(meta.table_id)}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить статус избранного")))
      .then((data) => setIsFavorite(!!data?.is_favorite))
      .catch(() => setIsFavorite(false));
  }, [isCurrentSource, meta?.table_id]);

  useEffect(() => {
    if (!schema || !tableName || !isCurrentSource) {
      setHistoryRows([]);
      setHistoryError(null);
      setHistoryLoading(false);
      return;
    }
    setHistoryLoading(true);
    setHistoryError(null);
    const requestId = ++historyRequestRef.current;
    const params = new URLSearchParams({ limit: "10" });
    if (meta?.table_id) params.set("table_id", String(meta.table_id));
    fetch(`${API_BASE}/api/table-history/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}?${params.toString()}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить историю запусков")))
      .then((data) => {
        if (requestId !== historyRequestRef.current) return;
        setHistoryRows(Array.isArray(data) ? data : []);
      })
      .catch((err) => {
        if (requestId !== historyRequestRef.current) return;
        console.error(err);
        setHistoryError(typeof err === "string" ? err : "Не удалось загрузить историю запусков");
      })
      .finally(() => {
        if (requestId !== historyRequestRef.current) return;
        setHistoryLoading(false);
      });
  }, [schema, tableName, meta?.table_id, isCurrentSource]);

  useEffect(() => {
    if (!schema || !tableName || isCurrentSource) {
      setDbtHistory([]);
      setDbtHistoryError(null);
      setDbtHistoryLoading(false);
      setDbtHistoryConfigured(true);
      setDbtHistoryAvailable(true);
      return;
    }
    setDbtHistoryLoading(true);
    setDbtHistoryError(null);
    const requestId = ++dbtHistoryRequestRef.current;
    const params = new URLSearchParams({ limit: "12" });
    if (source) params.set("source", source);
    fetch(`${API_BASE}/api/dbt/history/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}?${params.toString()}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить dbt-логи")))
      .then((data) => {
        if (requestId !== dbtHistoryRequestRef.current) return;
        setDbtHistory(Array.isArray(data?.runs) ? data.runs : []);
        setDbtHistoryConfigured(Boolean(data?.configured ?? true));
        setDbtHistoryAvailable(Boolean(data?.available ?? true));
        setDbtHistoryError(data?.available === false ? null : null);
      })
      .catch((err) => {
        if (requestId !== dbtHistoryRequestRef.current) return;
        console.error(err);
        setDbtHistoryError(typeof err === "string" ? err : "Не удалось загрузить dbt-логи");
      })
      .finally(() => {
        if (requestId !== dbtHistoryRequestRef.current) return;
        setDbtHistoryLoading(false);
      });
  }, [schema, tableName, source, isCurrentSource]);

  useEffect(() => {
    if (!schema || !tableName || !isCurrentSource) {
      setVariants([]);
      setVariantsError(null);
      setVariantsLoading(false);
      return;
    }
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
  }, [schema, tableName, isCurrentSource]);

  useEffect(() => {
    if (!schema || !tableName || !isCurrentSource) {
      setDqData(null);
      setDqError(null);
      setDqLoading(false);
      return;
    }
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
  }, [schema, tableName, isCurrentSource]);

  useEffect(() => {
    if (!schema || !tableName || !isCurrentSource) {
      setDqHistory([]);
      setDqHistoryError(null);
      setDqHistoryLoading(false);
      return;
    }
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
  }, [schema, tableName, isCurrentSource]);

  useEffect(() => {
    if (!schema || !tableName || !isCurrentSource) {
      setClickRuns([]);
      setClickStages([]);
      setClickError(null);
      setClickLoading(false);
      return;
    }
    setClickLoading(true);
    setClickError(null);
    const requestId = ++clickRunsRequestRef.current;
    const params = new URLSearchParams({ limit: "6" });
    if (meta?.table_id) params.set("table_id", String(meta.table_id));
    fetch(`${API_BASE}/api/click/table/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}?${params.toString()}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить ClickHouse-логи")))
      .then((data) => {
        if (requestId !== clickRunsRequestRef.current) return;
        setClickRuns(Array.isArray(data?.runs) ? data.runs : []);
        setClickStages(Array.isArray(data?.stages) ? data.stages : []);
      })
      .catch((err) => {
        if (requestId !== clickRunsRequestRef.current) return;
        console.error(err);
        setClickError(typeof err === "string" ? err : "Не удалось загрузить ClickHouse-логи");
      })
      .finally(() => {
        if (requestId !== clickRunsRequestRef.current) return;
        setClickLoading(false);
      });
  }, [schema, tableName, meta?.table_id, isCurrentSource]);

  useEffect(() => {
    if (!schema || !tableName || !isCurrentSource) {
      setClickMeta(null);
      setClickMetaError(null);
      setClickMetaLoading(false);
      return;
    }
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
  }, [schema, tableName, isCurrentSource]);

  useEffect(() => {
    if (!schema || !tableName || !isCurrentSource) {
      setClickHistory([]);
      setClickHistoryError(null);
      setClickHistoryLoading(false);
      return;
    }
    setClickHistoryLoading(true);
    setClickHistoryError(null);
    const requestId = ++clickHistoryRequestRef.current;
    const params = new URLSearchParams({ limit: "20" });
    if (meta?.table_id) params.set("table_id", String(meta.table_id));
    fetch(`${API_BASE}/api/click/history/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}?${params.toString()}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить историю ClickHouse")))
      .then((data) => {
        if (requestId !== clickHistoryRequestRef.current) return;
        setClickHistory(Array.isArray(data) ? data : []);
      })
      .catch((err) => {
        if (requestId !== clickHistoryRequestRef.current) return;
        console.error(err);
        setClickHistoryError(typeof err === "string" ? err : "Не удалось загрузить историю ClickHouse");
      })
      .finally(() => {
        if (requestId !== clickHistoryRequestRef.current) return;
        setClickHistoryLoading(false);
      });
  }, [schema, tableName, meta?.table_id, isCurrentSource]);

  useEffect(() => {
    if (!schema || !tableName || !isCurrentSource) {
      setAnalyticsSummary(null);
      setAnalyticsError(null);
      setAnalyticsLoading(false);
      return;
    }
    setAnalyticsLoading(true);
    setAnalyticsError(null);
    fetch(`${API_BASE}/api/analytics/table/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}?days=90`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить аналитику таблицы")))
      .then((data) => setAnalyticsSummary(data?.summary || null))
      .catch((err) => {
        console.error(err);
        setAnalyticsError(typeof err === "string" ? err : "Не удалось загрузить аналитику таблицы");
      })
      .finally(() => setAnalyticsLoading(false));
  }, [schema, tableName, isCurrentSource]);

  const handleViewSearch = () => {
    if (!isCurrentSource) {
      setViewMatches([]);
      setViewSearchError(null);
      setViewSearchLoading(false);
      return;
    }
    setViewSearchLoading(true);
    setViewSearchError(null);
    fetch(`${API_BASE}/api/click/view/search?schema=${encodeURIComponent(schema)}&table=${encodeURIComponent(tableName)}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось найти view-скрипты")))
      .then((data) => setViewMatches(Array.isArray(data?.matches) ? data.matches : []))
      .catch((err) => {
        console.error(err);
        setViewSearchError(typeof err === "string" ? err : "Не удалось найти view-скрипты");
      })
      .finally(() => setViewSearchLoading(false));
  };

  useEffect(() => {
    if (!schema || !tableName || !isCurrentSource) return;
    handleViewSearch();
  }, [schema, tableName, isCurrentSource]);

  useEffect(() => {
    if (!schema || !tableName || !isCurrentSource) {
      setReleaseItems([]);
      setReleaseError(null);
      setReleaseLoading(false);
      return;
    }
    setReleaseLoading(true);
    setReleaseError(null);
    fetch(`${API_BASE}/api/releases/table/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}?limit=12`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить релизы по объекту")))
      .then((data) => setReleaseItems(Array.isArray(data?.items) ? data.items : []))
      .catch((err) => {
        console.error(err);
        setReleaseError(typeof err === "string" ? err : "Не удалось загрузить релизы по объекту");
      })
      .finally(() => setReleaseLoading(false));
  }, [schema, tableName, isCurrentSource]);

  useEffect(() => {
    if (!schema || !tableName || !isCurrentSource) {
      setYtData(null);
      setYtError(null);
      setYtLoading(false);
      return;
    }
    setYtLoading(true);
    setYtError(null);
    fetch(`${API_BASE}/api/ytrek/table/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить данные YouTrack")))
      .then((data) => setYtData(data || null))
      .catch((err) => {
        console.error(err);
        setYtError(typeof err === "string" ? err : "Не удалось загрузить данные YouTrack");
      })
      .finally(() => setYtLoading(false));
  }, [schema, tableName, isCurrentSource]);

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
  const formatDateTime = (value) => {
    if (!value) return "—";
    return formatLocalDateTime(value, { withSeconds: false });
  };
  const ytLink = (id) => (id ? `https://yt.rusal.ru/issue/${id}` : "#");
  const topGpTooltip = (() => {
    if (!historyRows?.length) return "Нет успешных GP-запусков.";
    const top = [...historyRows]
      .filter((row) => row.duration_minutes !== null && row.duration_minutes !== undefined)
      .sort((a, b) => Number(b.duration_minutes || 0) - Number(a.duration_minutes || 0))
      .slice(0, 6);
    if (!top.length) return "Нет успешных GP-запусков.";
    return top
      .map((row, idx) => `${idx + 1}. ${formatDateTime(row.finish || row.start)} · ${row.duration_minutes} мин`)
      .join("\n");
  })();
  const topClickTooltip = (() => {
    if (!clickHistory?.length) return "Нет ClickHouse-запусков.";
    const top = [...clickHistory]
      .filter(
        (row) =>
          (row.actual_duration_min ?? row.duration_min) !== null &&
          (row.actual_duration_min ?? row.duration_min) !== undefined,
      )
      .sort(
        (a, b) =>
          Number(b.actual_duration_min ?? b.duration_min ?? 0) -
          Number(a.actual_duration_min ?? a.duration_min ?? 0),
      )
      .slice(0, 6);
    if (!top.length) return "Нет ClickHouse-запусков.";
    return top
      .map(
        (row, idx) =>
          `${idx + 1}. ${formatDateTime(row.end_dttm || row.start_dttm)} · ${row.actual_duration_min ?? row.duration_min} мин`,
      )
      .join("\n");
  })();
  const ytTaskMap = new Map();
  (ytData?.tasks || []).forEach((task) => {
    ytTaskMap.set(task.issue_id, task);
  });
  const visibleReleases = showAllReleases ? releaseItems : releaseItems.slice(0, 3);
  const visibleTasks = showAllTasks ? (ytData?.tasks || []) : (ytData?.tasks || []).slice(0, 3);
  const visibleTimeline = showAllTimeline ? (ytData?.timeline || []) : (ytData?.timeline || []).slice(0, 3);

  const metrics = !meta || !isCurrentSource
    ? []
    : [
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
          hint: "только успешные · top-6 GP в tooltip",
          title: topGpTooltip,
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
        ...(analyticsSummary
          ? [
              {
                label: "Изменений за 90 дней",
                value: analyticsSummary.changes ?? "—",
                hint: "release_objects",
              },
              {
                label: "Часы за 90 дней",
                value: analyticsSummary.hours ?? "—",
                hint: "YouTrack worklog",
              },
            ]
          : []),
      ];

  const sqlSections = useMemo(() => {
    if (!meta) return [];
    return [
      { title: "SQL: insert", sql: meta.sql_query_insert_init_sql },
      { title: "SQL: recreate", sql: meta.sql_query_recreate_init_sql },
      { title: "SQL: truncate", sql: meta.sql_query_truncate_sql },
    ];
  }, [meta]);

  const clickLastRun = clickRuns[0] || null;
  const dbtLastRun = dbtHistory[0] || null;
  const dbtHistoryHasErrors = dbtHistory.some((row) => Boolean(row?.error_message));
  const dbtManifest = meta?.dbt_manifest || null;
  const dbtMetadata = dbtManifest?.metadata || null;
  const dbtArtifactPaths = dbtManifest
    ? [
        ["Model file", dbtManifest.original_file_path || dbtManifest.path],
        ["Patch", dbtManifest.patch_path],
        ["Build", dbtManifest.build_path],
        ["Compiled", dbtManifest.compiled_path],
      ].filter(([, value]) => value)
    : [];
  const hiddenDbtFields = new Set(["checksum", "user_id", "manifest_path", "unique_id"]);
  const dbtConfigEntries = dbtManifest?.config
    ? Object.entries(dbtManifest.config).filter(
        ([key, value]) => !hiddenDbtFields.has(String(key || "").toLowerCase()) && value !== null && value !== undefined && value !== "",
      )
    : [];
  const dbtMetaEntries = dbtManifest?.meta
    ? Object.entries(dbtManifest.meta).filter(
        ([key, value]) => !hiddenDbtFields.has(String(key || "").toLowerCase()) && value !== null && value !== undefined && value !== "",
      )
    : [];
  const dbtUpstreamModels = useMemo(() => {
    const seen = new Set();
    return (dbtManifest?.upstream_models || []).filter((item) => {
      const key = `${item?.schema || ""}.${item?.table_name || ""}.${item?.model_name || ""}.${item?.unique_id || ""}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }, [dbtManifest?.upstream_models]);
  const dbtVisibleUpstreamModels = showAllDbtUpstream ? dbtUpstreamModels : dbtUpstreamModels.slice(0, 8);
  const dbtVisibleColumns = showAllDbtColumns ? dbtManifest?.columns || [] : (dbtManifest?.columns || []).slice(0, 60);
  const dbtVisibleConfigEntries = showAllDbtConfig ? dbtConfigEntries : dbtConfigEntries.slice(0, 12);
  const dbtVisibleMetaEntries = showAllDbtMeta ? dbtMetaEntries : dbtMetaEntries.slice(0, 12);
  const normalizeDescription = (value, fallback = "—") => {
    const raw = String(value || "").trim();
    if (!raw) return fallback;
    const parts = raw.split("|").map((part) => part.trim()).filter(Boolean);
    if (!parts.length) return raw;
    const filtered = parts.filter((part) => !/[A-Za-z0-9_]+\.[A-Za-z0-9_]+/.test(part));
    const normalized = [];
    filtered.forEach((part) => {
      const key = part.toLowerCase();
      if (!normalized.some((item) => item.toLowerCase() === key)) {
        normalized.push(part);
      }
    });
    return normalized[0] || filtered[0] || parts[0] || fallback;
  };
  const formatDbtTimestamp = (value) => {
    if (!value) return "—";
    const normalized = typeof value === "number" ? new Date(value * 1000).toISOString() : value;
    const parsed = formatLocalDateTime(normalized, { withSeconds: false });
    if (!parsed || parsed === normalized) {
      return String(normalized).replace("T", " ").replace(/\.\d+/, "").replace(/Z$/, "");
    }
    return parsed;
  };
  const renderCompactValue = (value, key = "") => {
    if (value === null || value === undefined || value === "") return "—";
    const normalizedKey = String(key || "").toLowerCase();
    const textValue = typeof value === "string" ? value.trim() : value;
    const looksLikeDate =
      typeof textValue === "string" &&
      (/^\d{4}-\d{2}-\d{2}(?:[ T]\d{2}:\d{2}(?::\d{2})?)?/.test(textValue) ||
        /(?:^|_)(created_at|generated_at|updated_at|patch_created_at|start_at|end_at|dttm|timestamp)$/i.test(normalizedKey));
    if (
      looksLikeDate ||
      (typeof value === "number" &&
        /(?:^|_)(created_at|generated_at|updated_at|patch_created_at|timestamp)$/i.test(normalizedKey))
    ) {
      return formatDbtTimestamp(value);
    }
    if (typeof value === "string") return value;
    return JSON.stringify(value);
  };
  const attributeTypeMap = useMemo(() => {
    const entries = Array.isArray(meta?.attributes)
      ? meta.attributes
      : Array.isArray(meta?.columns)
      ? meta.columns
      : Array.isArray(meta?.fields)
      ? meta.fields
      : [];
    const out = new Map();
    entries.forEach((item) => {
      if (!item || typeof item !== "object") return;
      const name = String(item.column_name_click || item.column_name_gp || item.name || item.column || item.field || "").trim();
      if (!name) return;
      const type = item.data_type_gp || item.data_type_click || item.data_type || item.type || "";
      if (type) out.set(name.toLowerCase(), String(type));
    });
    return out;
  }, [meta]);
  const parsedKeyAttributes = useMemo(() => {
    return (Array.isArray(meta?.key_attributes) ? meta.key_attributes : []).map((item, idx) => {
      const raw = String(item || "").trim();
      const parts = raw.split("|").map((part) => part.trim()).filter(Boolean);
      const sourceRef = parts.find((part) => part.includes("."));
      const fieldName = sourceRef ? sourceRef.split(".").slice(-1)[0] : raw;
      const description = normalizeDescription(raw, fieldName || raw || `field_${idx + 1}`);
      const dataType = attributeTypeMap.get(String(fieldName || "").toLowerCase()) || null;
      return { raw, fieldName, description, dataType };
    });
  }, [attributeTypeMap, meta?.key_attributes]);
  const normalizedDbtVisibleColumns = useMemo(() => {
    return dbtVisibleColumns.map((column) => {
      const name = String(column?.name || "").trim();
      const dataType = column?.data_type || attributeTypeMap.get(name.toLowerCase()) || null;
      return {
        ...column,
        dataType,
        normalizedDescription: normalizeDescription(column?.description, "Без описания"),
      };
    });
  }, [attributeTypeMap, dbtVisibleColumns]);
  const clickStatusLabel = (status) => {
    const value = String(status || "").toUpperCase();
    switch (value) {
      case "SUCCESS":
      case "LOADED":
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
  const releaseStatusClass = (status) => {
    const value = String(status || "").toLowerCase();
    if (!value) return "status-unknown";
    if (value.includes("success") || value.includes("loaded")) return "status-success";
    if (value.includes("fail") || value.includes("error")) return "status-failed";
    if (value.includes("run") || value.includes("queue") || value.includes("retry")) return "status-running";
    return "status-unknown";
  };
  const copySql = (sql) => {
    if (!sql) return;
    navigator.clipboard.writeText(sql).catch(() => {});
  };
  const toggleGpError = (key) => {
    setExpandedGpErrors((prev) => ({ ...prev, [key]: !prev[key] }));
  };
  const toggleClickError = (key) => {
    setExpandedClickErrors((prev) => ({ ...prev, [key]: !prev[key] }));
  };
  const toggleDbtError = (key) => {
    setExpandedDbtErrors((prev) => ({ ...prev, [key]: !prev[key] }));
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

    const params = new URLSearchParams({ depth: "3" });
    if (source && source !== "current") {
      params.set("source", source);
    }
    fetch(`${API_BASE}/api/graph/table/${encodeURIComponent(schema)}/${encodeURIComponent(tableName)}?${params.toString()}`)
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
        requestAnimationFrame(() => {
          graphSectionRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
        });
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
  }, [schema, tableName, autoShowGraph, source]);

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

  const handleDbtUpstreamOpen = (item) => {
    if (!item?.schema || !item?.table_name) return;
    if (onNavigateTable) {
      onNavigateTable(item.schema, item.table_name);
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
            <span>Источник {source === "current" ? "current" : source}</span>
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

      <div className="table-action-bar">
        {isCurrentSource ? (
          <button
            className="btn btn-secondary"
            onClick={() => {
              if (!meta?.table_id || favoriteLoading) return;
              setFavoriteLoading(true);
              const method = isFavorite ? "DELETE" : "POST";
              const url = isFavorite
                ? `${API_BASE}/auth/favorites/tables/${encodeURIComponent(meta.table_id)}`
                : `${API_BASE}/auth/favorites/tables`;
              const init = isFavorite
                ? { method }
                : {
                    method,
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                      table_id: meta.table_id,
                      table_schema: schema,
                      table_name: tableName,
                      entity_name: meta.entity_name || null,
                    }),
                  };
              fetch(url, init)
                .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось обновить избранное")))
                .then(() => {
                  setIsFavorite(!isFavorite);
                  sendAuditEvent({
                    event_type: isFavorite ? "remove_favorite_table" : "add_favorite_table",
                    page: `/table/${schema}/${tableName}`,
                    object_type: "table",
                    object_id: String(meta.table_id),
                    object_name: tableFqn,
                  });
                })
                .catch(() => {})
                .finally(() => setFavoriteLoading(false));
            }}
          >
            {favoriteLoading
              ? "Сохраняем..."
              : isFavorite
                ? "Убрать из избранного"
                : "В избранное"}
          </button>
        ) : null}
        <button
          className="btn btn-secondary"
          onClick={() => {
            sendAuditEvent({
              event_type: "open_dependency_graph",
              page: `/table/${schema}/${tableName}`,
              object_type: "table",
              object_name: tableFqn,
            });
            loadDependencies();
          }}
        >
          Граф зависимостей
        </button>
        <button
          className="btn btn-secondary"
          onClick={() => {
            sendAuditEvent({
              event_type: "open_impact_graph",
              page: `/table/${schema}/${tableName}`,
              object_type: "table",
              object_name: tableFqn,
            });
            onOpenImpact?.(schema, tableName);
          }}
        >
          Граф влияния
        </button>
        {isCurrentSource ? (
          <button
            className="btn btn-secondary"
            onClick={() => {
              sendAuditEvent({
                event_type: showGantt ? "hide_timeline" : "show_timeline",
                page: `/table/${schema}/${tableName}`,
                object_type: "table",
                object_name: tableFqn,
              });
              setShowGantt(!showGantt);
            }}
          >
            {showGantt ? "Скрыть таймлайн" : "Показать таймлайн"}
          </button>
        ) : null}
        {isCurrentSource ? (
          <button
            className="btn btn-secondary"
            onClick={() => {
              sendAuditEvent({
                event_type: "open_logic_audit",
                page: `/table/${schema}/${tableName}`,
                object_type: "table",
                object_name: tableFqn,
              });
              onOpenLogicAudit?.(tableFqn);
            }}
          >
            Аудит логики
          </button>
        ) : null}
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

      {isCurrentSource ? <div className="table-grid">
        {metrics.map((metric) => (
          <div key={metric.label} className="table-info-card" title={metric.title || ""}>
            <div className="table-card-label">{metric.label}</div>
            <div className="table-card-value">{metric.value}</div>
            <div className="table-card-hint muted">{metric.hint}</div>
          </div>
        ))}
      </div> : null}

      {isCurrentSource ? <div className="table-section">
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
      </div> : null}

      {!isCurrentSource ? <div className="table-section">
        <div className="section-title">Последние dbt-запуски</div>
        <div className="card">
          {dbtHistoryLoading && <div className="muted">Загрузка dbt-логов...</div>}
          {dbtHistoryError && <div className="dep-error-title">{dbtHistoryError}</div>}
          {!dbtHistoryLoading && !dbtHistoryError && !dbtHistoryConfigured && (
            <div className="muted">Подключение к dbt logs не настроено.</div>
          )}
          {!dbtHistoryLoading && !dbtHistoryError && dbtHistoryConfigured && !dbtHistoryAvailable && (
            <div className="muted">База dbt logs сейчас недоступна.</div>
          )}
          {!dbtHistoryLoading && !dbtHistoryError && dbtHistoryConfigured && dbtHistoryAvailable && dbtHistory.length === 0 && (
            <div className="muted">dbt-запусков не найдено.</div>
          )}
          {!dbtHistoryLoading && !dbtHistoryError && dbtHistoryConfigured && dbtHistoryAvailable && dbtHistory.length > 0 && (
            <>
              {dbtLastRun ? (
                <div className="section-subtitle muted" style={{ marginBottom: 12 }}>
                  Последний запуск: {dbtLastRun.model_status || "—"} / {dbtLastRun.dbt_run_status || "—"}
                </div>
              ) : null}
              <div className={`history-table dbt ${dbtHistoryHasErrors ? "with-errors" : ""}`}>
                <div className="history-table-head">
                  <span>Статус модели</span>
                  <span>Запуск dbt</span>
                  <span>Старт</span>
                  <span>Финиш</span>
                  <span>Длит.</span>
                  {dbtHistoryHasErrors ? <span>Ошибка</span> : null}
                </div>
                {dbtHistory.map((row, idx) => (
                  <div key={`${row.execution_guid || "dbt"}-${idx}`} className="history-row-block">
                    <div className="history-table-row">
                      <span className={`history-state history-${String(row.model_status || "unknown").toLowerCase()}`}>
                        {row.model_status || "UNKNOWN"}
                      </span>
                      <span className="history-message">
                        {row.dbt_run_status || "—"}
                        {row.dag_run_id ? <span className="muted"> · {row.dag_run_id}</span> : null}
                      </span>
                      <span className="history-time">{formatLocalDateTime(row.start_dttm, { withSeconds: false }) || row.start_dttm || "—"}</span>
                      <span className="history-time">{formatLocalDateTime(row.finish_dttm, { withSeconds: false }) || row.finish_dttm || "—"}</span>
                      <span>{row.duration_minutes ?? "—"} мин</span>
                      {dbtHistoryHasErrors ? (
                        <span className="history-message">
                          {row.error_message ? (
                          <button
                            className="history-error-toggle compact"
                            onClick={() => toggleDbtError(`dbt-${idx}`)}
                          >
                            {expandedDbtErrors[`dbt-${idx}`] ? "Скрыть" : "Показать"}
                          </button>
                          ) : "—"}
                        </span>
                      ) : null}
                    </div>
                    {row.error_message && expandedDbtErrors[`dbt-${idx}`] && (
                      <pre className="history-error-body">{row.error_message}</pre>
                    )}
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
      </div> : null}

      {isCurrentSource ? <div className="table-section">
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
              <div className="click-summary-grid">
                <div>
                  <div className="click-label">Старт</div>
                  <div className="click-value">{clickLastRun?.start_dttm || "—"}</div>
                </div>
                <div>
                  <div className="click-label">Финиш</div>
                  <div className="click-value">{clickLastRun?.end_dttm || "—"}</div>
                </div>
                <div>
                  <div className="click-label">Работа</div>
                  <div className="click-value" title={topClickTooltip}>
                    {formatMinutes(clickLastRun?.actual_duration_min ?? clickLastRun?.duration_min)}
                  </div>
                </div>
                <div>
                  <div className="click-label">Ожидание / пауза</div>
                  <div className="click-value">
                    {formatMinutes(clickLastRun?.lag_duration_min ?? 0)}
                  </div>
                </div>
              </div>
              {clickLastRun?.error_text && (
                <div className="history-error-block">
                  <button
                    className="history-error-toggle"
                    onClick={() => toggleClickError("click-last-run")}
                  >
                    {expandedClickErrors["click-last-run"] ? "Скрыть ошибку" : "Показать ошибку"}
                  </button>
                  {expandedClickErrors["click-last-run"] && (
                    <pre className="history-error-body">{clickLastRun.error_text}</pre>
                  )}
                </div>
              )}

              <div className="click-section-block">
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
                    {viewSearchLoading && <div className="muted">Ищем view-скрипты...</div>}
                    {viewSearchError && <div className="dep-error-title">{viewSearchError}</div>}
                    {!viewSearchLoading && !viewSearchError && (
                      <>
                        {viewMatches.length > 0 ? (
                          <div className="click-view-list">
                            {viewMatches.map((item, idx) => (
                              <div key={`${item.view_name}-${idx}`} className="click-view-row">
                                <div className="mono">{item.view_schema}.{item.view_name}</div>
                                <div className="muted">Используется в view</div>
                                <button
                                  className="btn btn-secondary"
                                  onClick={() =>
                                    fetch(`${API_BASE}/api/click/meta/${encodeURIComponent(item.view_schema)}/${encodeURIComponent(item.view_name)}`)
                                      .then((res) => (res.ok ? res.json() : Promise.reject()))
                                      .then((data) => {
                                        if (data?.view_sql) {
                                          openSqlModal({ title: `ClickHouse VIEW: ${item.view_name}`, sql: data.view_sql });
                                        }
                                      })
                                      .catch(() => {})
                                  }
                                >
                                  Открыть
                                </button>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <div className="muted">View-скрипты не найдены.</div>
                        )}
                      </>
                    )}
                  </>
                )}
              </div>

              {clickStages.length > 0 && (
                <div className="click-section-block">
                  <div className="section-subtitle">Последние этапы</div>
                  <div className="click-stage-list">
                    {clickStages.slice(0, 6).map((stage, idx) => (
                      <div key={`${stage.stage_name || "stage"}-${idx}`} className="click-stage-card">
                        <div className="click-stage-name">{stage.stage_name || "—"}</div>
                        <div className="click-stage-meta">
                          <span>{stage.status || "—"}</span>
                          <span>{formatMinutes(stage.duration_min)}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div> : null}

      {isCurrentSource ? <div className="table-section">
        <div className="section-title">Релизы объекта</div>
        <div className="card">
          {releaseLoading && <div className="muted">Загрузка релизов...</div>}
          {releaseError && <div className="dep-error-title">{releaseError}</div>}
          {!releaseLoading && !releaseError && releaseItems.length === 0 && (
            <div className="muted">Релизы по объекту не найдены.</div>
          )}
          {!releaseLoading && !releaseError && releaseItems.length > 0 && (
            <>
            <div className="release-table release-table-card">
              <div className="release-head">
                <span>Релиз</span>
                <span>Задача</span>
                <span>БД</span>
                <span>Кто релизил</span>
                <span>Исполнитель задачи</span>
                <span>Статус</span>
                <span>Изменения</span>
                <span>Дата</span>
              </div>
              {visibleReleases.map((item, idx) => (
                <div key={`${item.release_id}-${idx}`} className="release-row">
                  <span className="mono">{item.release_id}</span>
                  <span>
                    {item.task_link ? (
                      <a className="yt-link" href={item.task_link} target="_blank" rel="noreferrer">
                        {item.task_id || "—"}
                      </a>
                    ) : (
                      <span className="mono">{item.task_id || "—"}</span>
                    )}
                    {ytTaskMap.get(item.task_id)?.summary ? (
                      <span className="release-sub muted">{ytTaskMap.get(item.task_id)?.summary}</span>
                    ) : null}
                  </span>
                  <span>{item.target_system || "—"}</span>
                  <span>{item.initiated_by || "—"}</span>
                  <span>{item.task_executor || "—"}</span>
                  <span className={`status-pill ${releaseStatusClass(item.final_status)}`}>
                    {item.final_status || "—"}
                  </span>
                  <span className="muted" title={item.change_type || ""}>
                    {item.change_type || "—"}
                  </span>
                  <span>{formatDateTime(item.created_at)}</span>
                </div>
              ))}
            </div>
            {releaseItems.length > 3 && (
              <button className="btn btn-ghost table-expand-btn" onClick={() => setShowAllReleases((v) => !v)}>
                {showAllReleases ? "Свернуть релизы" : `Показать ещё релизы (${releaseItems.length - 3})`}
              </button>
            )}
            </>
          )}
        </div>
      </div> : null}

      {isCurrentSource ? <div className="table-section">
        <div className="section-title">YouTrack: задачи по таблице</div>
        <div className="card">
          {ytLoading && <div className="muted">Загрузка задач...</div>}
          {ytError && <div className="dep-error-title">{ytError}</div>}
          {!ytLoading && !ytError && (!ytData || !ytData.tasks || ytData.tasks.length === 0) && (
            <div className="muted">Задачи не найдены.</div>
          )}
          {!ytLoading && !ytError && ytData?.tasks?.length > 0 && (
            <>
              <div className="yt-summary">
                <div>
                  <div className="yt-label">Задач</div>
                  <div className="yt-value">{ytData.stats?.tasks_count ?? ytData.tasks.length}</div>
                </div>
                <div>
                  <div className="yt-label">Трудозатраты</div>
                  <div className="yt-value">
                    {ytData.stats?.work_minutes_total
                      ? `${Math.round(ytData.stats.work_minutes_total / 60)} ч`
                      : "—"}
                  </div>
                </div>
              </div>

              <div className="yt-section-block">
                <div className="section-subtitle">Текущие задачи</div>
                <div className="yt-task-table">
                <div className="yt-task-head">
                  <span>Задача</span>
                  <span>Постановщик</span>
                  <span>Исполнитель</span>
                  <span>Статус</span>
                  <span>Команда</span>
                  <span>Дашборд КХД/Направление</span>
                  <span>Трудозатраты</span>
                  <span>Последняя смена исполнителя</span>
                  <span>Последняя смена статуса</span>
                </div>
                {visibleTasks.map((t) => (
                  <div key={t.issue_id} className="yt-task-row">
                    <span>
                      <a className="yt-link" href={ytLink(t.issue_id)} target="_blank" rel="noreferrer">
                        {t.issue_id}
                      </a>
                      {t.summary ? <span className="release-sub muted">{t.summary}</span> : null}
                    </span>
                    <span>{t.created_by || "—"}</span>
                    <span>
                      {t.effective_assignee || "—"}
                      {t.effective_assignee_reason ? (
                        <span className="muted"> · {t.effective_assignee_reason}</span>
                      ) : null}
                    </span>
                    <span>{t.current_state || "—"}</span>
                    <span>{t.custom?.Subsystem || "—"}</span>
                    <span>{t.custom?.["Дашборд КХД/Направление"] || "—"}</span>
                    <span>
                      {t.work_minutes ? `${Math.round(t.work_minutes / 60)} ч` : "—"}
                    </span>
                    <span className="muted">
                      {t.last_assignee_change?.author
                        ? `${t.last_assignee_change.author} → ${t.last_assignee_change.value_to || "—"}`
                        : "—"}
                    </span>
                    <span className="muted">
                      {t.last_state_change?.author
                        ? `${t.last_state_change.author} → ${t.last_state_change.value_to || "—"}`
                        : "—"}
                    </span>
                  </div>
                ))}
                </div>
              </div>
              {ytData.tasks.length > 3 && (
                <button className="btn btn-ghost table-expand-btn" onClick={() => setShowAllTasks((v) => !v)}>
                  {showAllTasks ? "Свернуть задачи" : `Показать ещё задачи (${ytData.tasks.length - 3})`}
                </button>
              )}

              {ytData.timeline?.length > 0 && (
                <div className="yt-section-block yt-timeline">
                  <div className="section-subtitle">Последние изменения</div>
                  <div className="yt-timeline-head">
                    <span>Задача</span>
                    <span>Дата</span>
                    <span>Автор</span>
                    <span>Событие</span>
                    <span>Поле</span>
                    <span>Было</span>
                    <span>Стало</span>
                  </div>
                  {visibleTimeline.map((row, idx) => (
                    <div key={`${row.issue_id}-${idx}`} className="yt-timeline-row">
                      <span>
                        <a className="yt-link" href={ytLink(row.issue_id)} target="_blank" rel="noreferrer">
                          {row.issue_id || "—"}
                        </a>
                        {ytTaskMap.get(row.issue_id)?.summary ? (
                          <span className="release-sub muted">{ytTaskMap.get(row.issue_id)?.summary}</span>
                        ) : null}
                      </span>
                      <span>{row.ts || "—"}</span>
                      <span>{row.author || "—"}</span>
                      <span>{row.event_type || "—"}</span>
                      <span>{row.field_name || "—"}</span>
                      <span>{row.value_from || "—"}</span>
                      <span>{row.value_to || "—"}</span>
                    </div>
                  ))}
                  {ytData.timeline.length > 3 && (
                    <button className="btn btn-ghost table-expand-btn" onClick={() => setShowAllTimeline((v) => !v)}>
                      {showAllTimeline ? "Свернуть изменения" : `Показать ещё изменения (${ytData.timeline.length - 3})`}
                    </button>
                  )}
                </div>
              )}
            </>
          )}
        </div>
      </div> : null}

      {isCurrentSource ? <div className="table-section">
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
      </div> : null}

      {dbtManifest && (
        <div className="table-section">
          <div className="section-title">DBT Model</div>
          <div className="card">
            <div className="click-meta-grid">
              <div>
                <div className="click-label">Модель</div>
                <div className="click-value mono dbt-manifest-wrap">{dbtManifest.model_name || "—"}</div>
              </div>
              <div>
                <div className="click-label">Таблица</div>
                <div className="click-value mono dbt-manifest-wrap">{dbtManifest.schema}.{dbtManifest.table_name}</div>
              </div>
              <div>
                <div className="click-label">Materialized</div>
                <div className="click-value">{dbtManifest.materialized || "—"}</div>
              </div>
              <div>
                <div className="click-label">Package</div>
                <div className="click-value">{dbtManifest.package_name || "—"}</div>
              </div>
              <div>
                <div className="click-label">Database</div>
                <div className="click-value">{dbtManifest.database || "—"}</div>
              </div>
              <div>
                <div className="click-label">Колонки</div>
                <div className="click-value">{dbtManifest.columns?.length ?? 0}</div>
              </div>
              <div>
                <div className="click-label">Upstream refs</div>
                <div className="click-value">{dbtUpstreamModels.length}</div>
              </div>
              <div>
                <div className="click-label">Sources</div>
                <div className="click-value">{dbtManifest.sources?.length ?? 0}</div>
              </div>
              <div>
                <div className="click-label">Metrics</div>
                <div className="click-value">{dbtManifest.metrics?.length ?? 0}</div>
              </div>
            </div>

            {dbtManifest.description ? (
              <div className="dbt-manifest-block">
                <div className="section-subtitle">Описание</div>
                <div>{dbtManifest.description}</div>
              </div>
            ) : null}

            {Array.isArray(dbtManifest.tags) && dbtManifest.tags.length > 0 ? (
              <div className="dbt-manifest-block">
                <div className="section-subtitle">Теги</div>
                <div className="table-key-list">
                  {dbtManifest.tags.map((tag) => (
                    <span key={tag} className="table-key-pill mono">
                      {tag}
                    </span>
                  ))}
                </div>
              </div>
            ) : null}

            <div className="dbt-manifest-block">
              <div className="section-subtitle">Файлы модели</div>
              <div className="dbt-manifest-paths">
                {dbtArtifactPaths.map(([label, value]) => (
                  <div key={label}>
                    <div className="click-label">{label}</div>
                    <div className="mono dbt-manifest-wrap">{value}</div>
                  </div>
                ))}
              </div>
            </div>

            <div className="dbt-manifest-block">
              <div className="section-subtitle">Детали модели</div>
              <div className="dbt-manifest-paths">
                <div>
                  <div className="click-label">Relation name</div>
                  <div className="mono dbt-manifest-wrap">{dbtManifest.relation_name || "—"}</div>
                </div>
                <div>
                  <div className="click-label">Language</div>
                  <div>{dbtManifest.language || "—"}</div>
                </div>
                <div>
                  <div className="click-label">dbt version</div>
                  <div>{dbtMetadata?.dbt_version || "—"}</div>
                </div>
                <div>
                  <div className="click-label">Generated</div>
                  <div>{formatDbtTimestamp(dbtMetadata?.generated_at)}</div>
                </div>
                <div>
                  <div className="click-label">Adapter</div>
                  <div>{dbtMetadata?.adapter_type || "—"}</div>
                </div>
                <div>
                  <div className="click-label">Created</div>
                  <div>{formatDbtTimestamp(dbtManifest.created_at)}</div>
                </div>
              </div>
            </div>

            <div className="dbt-manifest-block">
              <div className="section-subtitle">Upstream зависимости</div>
              {dbtUpstreamModels.length ? (
                <div className="dbt-manifest-list">
                  {dbtVisibleUpstreamModels.map((item) => {
                    const label = item.schema && item.table_name
                      ? `${item.schema}.${item.table_name}`
                      : item.model_name || item.unique_id?.split(".").slice(-1)[0] || "DBT model";
                    return (
                      <button
                        key={item.unique_id}
                        className="dbt-manifest-item"
                        onClick={() => handleDbtUpstreamOpen(item)}
                        disabled={!item.schema || !item.table_name}
                      >
                        <span className="mono">{label}</span>
                        <span className="muted">{item.schema && item.table_name ? "Открыть таблицу" : "DBT model без физической таблицы"}</span>
                      </button>
                    );
                  })}
                </div>
              ) : (
                <div className="muted">Upstream зависимости не найдены.</div>
              )}
              {dbtUpstreamModels.length > 8 ? (
                <div className="dbt-manifest-actions">
                  <button className="btn btn-ghost" onClick={() => setShowAllDbtUpstream((value) => !value)}>
                    {showAllDbtUpstream ? "Свернуть upstream" : `Показать все ${dbtUpstreamModels.length} upstream`}
                  </button>
                </div>
              ) : null}
            </div>

            {dbtManifest.sources?.length ? (
              <div className="dbt-manifest-block">
                <div className="section-subtitle">Sources</div>
                <div className="dbt-manifest-list">
                  {dbtManifest.sources.map((item, idx) => (
                    <div key={`source-${idx}`} className="dbt-manifest-item static">
                      <span className="mono">{typeof item === "string" ? item : JSON.stringify(item)}</span>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}

            {dbtManifest.metrics?.length ? (
              <div className="dbt-manifest-block">
                <div className="section-subtitle">Metrics</div>
                <div className="dbt-manifest-list">
                  {dbtManifest.metrics.map((item, idx) => (
                    <div key={`metric-${idx}`} className="dbt-manifest-item static">
                      <span className="mono">{typeof item === "string" ? item : JSON.stringify(item)}</span>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}

            {dbtManifest.columns?.length ? (
              <div className="dbt-manifest-block">
                <div className="section-subtitle">Колонки</div>
                <div className="dbt-manifest-list">
                  {normalizedDbtVisibleColumns.map((column) => (
                    <div key={column.name} className="dbt-manifest-item static">
                      <span className="mono">
                        {column.name}
                        {column.dataType ? <span className="muted"> · {column.dataType}</span> : null}
                      </span>
                      <span className="muted">{column.normalizedDescription}</span>
                    </div>
                  ))}
                </div>
                {dbtManifest.columns.length > 60 ? (
                  <div className="dbt-manifest-actions">
                    <button className="btn btn-ghost" onClick={() => setShowAllDbtColumns((value) => !value)}>
                      {showAllDbtColumns ? "Свернуть колонки" : `Показать все ${dbtManifest.columns.length} колонок`}
                    </button>
                  </div>
                ) : null}
              </div>
            ) : null}

            {dbtConfigEntries.length ? (
              <div className="dbt-manifest-block">
                <div className="section-subtitle">Config</div>
                <div className="dbt-manifest-list">
                  {dbtVisibleConfigEntries.map(([key, value]) => (
                    <div key={key} className="dbt-manifest-item static">
                      <span className="mono">{key}</span>
                      <span className="muted mono dbt-manifest-wrap dbt-manifest-value">{renderCompactValue(value, key)}</span>
                    </div>
                  ))}
                </div>
                {dbtConfigEntries.length > 12 ? (
                  <div className="dbt-manifest-actions">
                    <button className="btn btn-ghost" onClick={() => setShowAllDbtConfig((value) => !value)}>
                      {showAllDbtConfig ? "Свернуть config" : `Показать весь config (${dbtConfigEntries.length})`}
                    </button>
                  </div>
                ) : null}
              </div>
            ) : null}

            {dbtMetaEntries.length ? (
              <div className="dbt-manifest-block">
                <div className="section-subtitle">Meta</div>
                <div className="dbt-manifest-list">
                  {dbtVisibleMetaEntries.map(([key, value]) => (
                    <div key={key} className="dbt-manifest-item static">
                      <span className="mono">{key}</span>
                      <span className="muted mono dbt-manifest-wrap dbt-manifest-value">{renderCompactValue(value, key)}</span>
                    </div>
                  ))}
                </div>
                {dbtMetaEntries.length > 12 ? (
                  <div className="dbt-manifest-actions">
                    <button className="btn btn-ghost" onClick={() => setShowAllDbtMeta((value) => !value)}>
                      {showAllDbtMeta ? "Свернуть meta" : `Показать весь meta (${dbtMetaEntries.length})`}
                    </button>
                  </div>
                ) : null}
              </div>
            ) : null}

            <div className="dbt-manifest-block">
              <div className="section-subtitle">SQL модели</div>
              <div className="table-sql-actions">
                <button
                  className="btn btn-secondary"
                  onClick={() => openSqlModal({ title: `dbt model: ${dbtManifest.table_name}`, sql: dbtManifest.raw_code })}
                  disabled={!dbtManifest.raw_code}
                >
                  Открыть raw_code
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {isCurrentSource ? <div className="table-section">
        <div className="section-title">Последние запуски</div>
        <div className="card">
          <div className="history-toggle">
            <button
              className={`btn btn-ghost ${historyMode === "gp" ? "active" : ""}`}
              onClick={() => setHistoryMode("gp")}
            >
              GP (основная загрузка)
            </button>
            <button
              className={`btn btn-ghost ${historyMode === "click" ? "active" : ""}`}
              onClick={() => setHistoryMode("click")}
            >
              ClickHouse (S3/CH)
            </button>
          </div>

          {historyMode === "gp" && (
            <>
              {historyLoading && <div className="muted">Загрузка запусков...</div>}
              {historyError && <div className="dep-error-title">{historyError}</div>}
              {!historyLoading && !historyError && historyRows.length === 0 && (
                <div className="muted">Запусков не найдено.</div>
              )}
              {!historyLoading && !historyError && historyRows.length > 0 && (
                <div className="history-table gp">
                  <div className="history-table-head">
                    <span>Статус</span>
                    <span>Старт</span>
                    <span>Финиш</span>
                    <span>Длит.</span>
                    <span>Комментарий</span>
                  </div>
                  {gpHistoryWithDelta.map((row, idx) => (
                    <div key={`${row.finish || "row"}-${idx}`} className="history-row-block">
                      <div className="history-table-row">
                        <span className={`history-state history-${String(row.state || "unknown").toLowerCase()}`}>
                          {row.state || "UNKNOWN"}
                        </span>
                        <span>{row.start || "—"}</span>
                        <span>{row.finish || "—"}</span>
                        <span className="history-duration-cell">
                          <strong>{formatDurationMmSs(row.duration_minutes)}</strong>
                          <span className="history-duration-detail">
                            prev {formatDurationMmSs(row.previous_duration_minutes)} · Δ {formatDurationDelta(row.duration_minutes, row.previous_duration_minutes)}
                          </span>
                        </span>
                        <span className="history-message">
                          {row.message ? (
                            <button
                              className="history-error-toggle compact"
                              onClick={() => toggleGpError(`gp-${idx}`)}
                            >
                              {expandedGpErrors[`gp-${idx}`] ? "Скрыть статус" : "Статус"}
                            </button>
                          ) : "—"}
                        </span>
                      </div>
                      {row.message && expandedGpErrors[`gp-${idx}`] && (
                        <pre className="history-error-body">{row.message}</pre>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </>
          )}

          {historyMode === "click" && (
            <>
              {clickHistoryLoading && <div className="muted">Загрузка ClickHouse...</div>}
              {clickHistoryError && <div className="dep-error-title">{clickHistoryError}</div>}
              {!clickHistoryLoading && !clickHistoryError && clickHistory.length === 0 && (
                <div className="muted">Запусков ClickHouse не найдено.</div>
              )}
              {!clickHistoryLoading && !clickHistoryError && clickHistory.length > 0 && (
                <div className="history-table click">
                  <div className="history-table-head">
                    <span>Этап</span>
                    <span>Старт</span>
                    <span>Финиш</span>
                    <span>Работа</span>
                    <span>Ожидание</span>
                    <span>Статус</span>
                  </div>
                  {clickHistoryWithDelta.map((row, idx) => (
                    <div key={`${row.run_uuid}-${idx}`} className="history-row-block">
                      <div className={`history-table-row status-${String(row.status || "").toLowerCase()}`}>
                        <span>{row.stage_name}</span>
                        <span>{row.start_dttm || "—"}</span>
                        <span>{row.end_dttm || "—"}</span>
                        <span className="history-duration-cell">
                          <strong>{formatDurationMmSs(row.current_duration_minutes)}</strong>
                          <span className="history-duration-detail">
                            prev {formatDurationMmSs(row.previous_duration_minutes)} · Δ {formatDurationDelta(row.current_duration_minutes, row.previous_duration_minutes)}
                          </span>
                        </span>
                        <span>{formatMinutes(row.lag_duration_min ?? 0)}</span>
                        <span className="history-click-status">
                          {clickStatusLabel(row.status)}
                          {row.error_text ? (
                            <button
                              className="history-error-toggle compact"
                              onClick={() => toggleClickError(`click-${idx}`)}
                            >
                              {expandedClickErrors[`click-${idx}`] ? "Скрыть статус" : "Статус"}
                            </button>
                          ) : null}
                        </span>
                      </div>
                      {row.error_text && expandedClickErrors[`click-${idx}`] && (
                        <pre className="history-error-body">{row.error_text}</pre>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </>
          )}
        </div>
      </div> : null}

      {isCurrentSource ? <div className="table-section">
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
      </div> : null}

      {parsedKeyAttributes.length > 0 && (
        <div className="table-section">
          <div className="section-title">Ключевые поля</div>
          <div className="card">
            <div className="table-key-list">
              {parsedKeyAttributes.map((key) => (
                <span key={key.raw} className="table-key-pill">
                  {key.description}
                  {key.dataType ? <span className="muted"> · {key.dataType}</span> : null}
                </span>
              ))}
            </div>
          </div>
        </div>
      )}

      <div className="table-section" ref={graphSectionRef}>
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
