import { useEffect, useMemo, useState } from "react";
import "../style/app.css";
import { formatDateInputValue, formatLocalDateTime, parseLocalDateTime } from "../utils/datetime.js";
import { formatPercent } from "../utils/format.js";
import { entitiesApi } from "../api/entities.js";
import { performanceApi } from "../api/performance.js";
const SLA_MINUTES = 10;
const SLOW_P95_MINUTES = 10;
const UNSTABLE_WARN = 0.3;
const UNSTABLE_CRIT = 0.6;

const formatMinutes = (value) =>
  Number.isFinite(value) ? value.toFixed(1) : "—";

export default function SlowestTables({ onSelectTable }) {
  const [viewMode, setViewMode] = useState("risk");
  const [tables, setTables] = useState([]);
  const [meta, setMeta] = useState(null);
  const [windowDays, setWindowDays] = useState(30);
  const [limit, setLimit] = useState(20);
  const [loadProfile, setLoadProfile] = useState([]);
  const [loadingProfile, setLoadingProfile] = useState(true);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [nightSummary, setNightSummary] = useState(null);
  const [nightLoading, setNightLoading] = useState(true);
  const [nightError, setNightError] = useState(null);
  const [entities, setEntities] = useState([]);
  const [entityId, setEntityId] = useState("");
  const [entityLoads, setEntityLoads] = useState([]);
  const [entitySchema, setEntitySchema] = useState("all");
  const [entityLimit, setEntityLimit] = useState(30);
  const [entityLoading, setEntityLoading] = useState(false);
  const [entitySchemaOptions, setEntitySchemaOptions] = useState(["all"]);
  const [windowDate, setWindowDate] = useState(() => formatDateInputValue());
  const [timeFrom, setTimeFrom] = useState("04:30");
  const [timeTo, setTimeTo] = useState("05:00");
  const [windowSource, setWindowSource] = useState("both");
  const [windowEntityFilter, setWindowEntityFilter] = useState("all");
  const [windowRows, setWindowRows] = useState([]);
  const [windowLoading, setWindowLoading] = useState(false);
  const [windowError, setWindowError] = useState(null);
  const [showAllWindowBars, setShowAllWindowBars] = useState(false);
  const [compareDateA, setCompareDateA] = useState(() => formatDateInputValue());
  const [compareDateB, setCompareDateB] = useState(() => {
    const value = new Date();
    value.setDate(value.getDate() - 1);
    return formatDateInputValue(value);
  });
  const [compareEntityId, setCompareEntityId] = useState("");
  const [compareRows, setCompareRows] = useState([]);
  const [compareLoading, setCompareLoading] = useState(false);
  const [compareError, setCompareError] = useState(null);
  const [compareSchemaSelection, setCompareSchemaSelection] = useState([]);

  useEffect(() => {
    setLoading(true);
    performanceApi.slowestTables(windowDays, limit)
      .then((data) => {
        if (Array.isArray(data)) {
          setTables(data);
          setMeta(null);
        } else {
          setTables(Array.isArray(data?.rows) ? data.rows : []);
          setMeta(data?.meta || null);
        }
      })
      .catch(() => setError("Не удалось загрузить данные"))
      .finally(() => setLoading(false));
  }, [windowDays, limit]);

  useEffect(() => {
    setLoadingProfile(true);
    performanceApi.loadProfile(windowDays)
      .then((data) => {
        setLoadProfile(Array.isArray(data?.profile) ? data.profile : []);
      })
      .catch(() => setLoadProfile([]))
      .finally(() => setLoadingProfile(false));
  }, [windowDays]);

  useEffect(() => {
    setNightLoading(true);
    setNightError(null);
    performanceApi.nightSummary(windowDays, 50)
      .then((data) => setNightSummary(data))
      .catch(() => setNightError("Не удалось загрузить ночное окно"))
      .finally(() => setNightLoading(false));
  }, [windowDays]);

  useEffect(() => {
    entitiesApi.list()
      .then((data) => {
        const list = Array.isArray(data) ? data : [];
        const seen = new Set();
        const uniq = list.filter((item) => {
          const key = String(item?.entity_id ?? "");
          if (!key || seen.has(key)) return false;
          seen.add(key);
          return true;
        });
        uniq.sort((a, b) =>
          String(a.entity_name || "").localeCompare(String(b.entity_name || ""), "en")
        );
        setEntities(uniq);
        if (!entityId && uniq.length > 0) {
          setEntityId(String(uniq[0].entity_id));
        }
        if (!compareEntityId && uniq.length > 0) {
          setCompareEntityId(String(uniq[0].entity_id));
        }
      })
      .catch(() => setEntities([]));
  }, [compareEntityId, entityId]);

  useEffect(() => {
    if (!entityId) {
      setEntityLoads([]);
      return;
    }
    setEntityLoading(true);
    performanceApi.entityLoads(entityId, windowDays, entityLimit, entitySchema)
      .then((data) => {
        const list = Array.isArray(data) ? data : [];
        setEntityLoads(list);
        if (entitySchema === "all") {
          const set = new Set();
          list.forEach((row) => {
            const schema = String(row.table_fqn || "").split(".")[0];
            if (schema) set.add(schema);
          });
          setEntitySchemaOptions(["all", ...Array.from(set).sort((a, b) => a.localeCompare(b, "en"))]);
        }
      })
      .catch(() => setEntityLoads([]))
      .finally(() => setEntityLoading(false));
  }, [entityId, windowDays, entityLimit, entitySchema]);

  useEffect(() => {
    loadWindowRuns();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const sorted = useMemo(() => tables, [tables]);

  const shortenName = (value, max = 38) => {
    if (!value) return "—";
    if (value.length <= max) return value;
    const head = value.slice(0, Math.max(12, Math.floor(max * 0.6)));
    const tail = value.slice(-Math.max(8, Math.floor(max * 0.3)));
    return `${head}…${tail}`;
  };

  const formatDateTime = (value) => {
    if (!value) return "—";
    return formatLocalDateTime(value, { withSeconds: false });
  };

  const loadWindowRuns = () => {
    setWindowLoading(true);
    setWindowError(null);
    performanceApi.windowRuns(
      { date: windowDate, from: timeFrom, to: timeTo, source: windowSource },
      true,
    )
      .then((data) => {
        const merged = [];
        (data.gp || []).forEach((row) => merged.push({ ...row, source: "GP" }));
        (data.click || []).forEach((row) => merged.push({ ...row, source: "ClickHouse" }));
        merged.sort((a, b) => (a.start_dttm || "").localeCompare(b.start_dttm || ""));
        setWindowRows(merged);
        setWindowEntityFilter("all");
        setShowAllWindowBars(false);
      })
      .catch((err) => setWindowError(typeof err === "string" ? err : "Не удалось загрузить окно"))
      .finally(() => setWindowLoading(false));
  };

  const loadCompare = () => {
    setCompareLoading(true);
    setCompareError(null);
    performanceApi.loadCompare(
      { dateA: compareDateA, dateB: compareDateB, entityId: compareEntityId },
      true,
    )
      .then((data) => {
        setCompareRows(Array.isArray(data?.rows) ? data.rows : []);
        setCompareSchemaSelection([]);
      })
      .catch((err) =>
        setCompareError(err instanceof Error ? err.message : "Не удалось сравнить загрузки"),
      )
      .finally(() => setCompareLoading(false));
  };

  const periodLabel = useMemo(() => {
    if (meta?.period_from && meta?.period_to) {
      const fmt = (value) =>
        parseLocalDateTime(value)?.toLocaleDateString("en-GB", {
          day: "2-digit",
          month: "2-digit",
        }) || "—";
      return `${fmt(meta.period_from)} — ${fmt(meta.period_to)}`;
    }
    return null;
  }, [meta]);

  const summary = useMemo(() => {
    const total = sorted.length;
    const slowCount = sorted.filter((t) => t.slow).length;
    const unstableCount = sorted.filter((t) => t.unstable).length;
    const avgRuns =
      total > 0
        ? Math.round(
            sorted.reduce((sum, t) => sum + (t.runs_count || 0), 0) / total,
          )
        : 0;
    return { total, slowCount, unstableCount, avgRuns };
  }, [sorted]);

  const windowRowsByDuration = useMemo(() => {
    return [...windowRows].sort(
      (a, b) =>
        Number(b.actual_duration_min ?? b.duration_min ?? 0) -
        Number(a.actual_duration_min ?? a.duration_min ?? 0),
    );
  }, [windowRows]);

  const windowEntityOptions = useMemo(() => {
    const set = new Set();
    windowRows.forEach((row) => {
      if (row.entity_name) set.add(row.entity_name);
    });
    return Array.from(set).sort((a, b) => a.localeCompare(b, "ru"));
  }, [windowRows]);

  const filteredWindowRows = useMemo(() => {
    if (!windowRows.length) return [];
    if (windowEntityFilter === "all") return windowRowsByDuration;
    return windowRowsByDuration.filter((row) => row.entity_name === windowEntityFilter);
  }, [windowRowsByDuration, windowEntityFilter, windowRows]);

  const visibleWindowBars = useMemo(
    () => (showAllWindowBars ? filteredWindowRows : filteredWindowRows.slice(0, 20)),
    [filteredWindowRows, showAllWindowBars],
  );

  const windowMaxDuration = useMemo(() => {
    if (!filteredWindowRows.length) return 0;
    return Math.max(
      ...filteredWindowRows.map(
        (r) => Number(r.actual_duration_min ?? r.duration_min ?? 0) + Number(r.lag_duration_min || 0),
      ),
    );
  }, [filteredWindowRows]);

  const windowEntitySummary = useMemo(() => {
    const map = new Map();
    filteredWindowRows.forEach((row) => {
      const key = row.entity_name || "—";
      const item = map.get(key) || { entity: key, tables: new Set(), runs: 0, minutes: 0, lagMinutes: 0 };
      item.runs += 1;
      item.minutes += Number(row.actual_duration_min ?? row.duration_min ?? 0);
      item.lagMinutes += Number(row.lag_duration_min || 0);
      item.tables.add(formatObjectFqn(row.schema_name, row.table_name));
      map.set(key, item);
    });
    return Array.from(map.values())
      .map((item) => ({
        entity: item.entity,
        tables_count: item.tables.size,
        runs_count: item.runs,
        minutes: Math.round(item.minutes * 100) / 100,
        lag_minutes: Math.round(item.lagMinutes * 100) / 100,
      }))
      .sort((a, b) => (b.tables_count - a.tables_count) || (b.minutes - a.minutes));
  }, [filteredWindowRows]);

  const maxProfileDuration = useMemo(() => {
    if (!loadProfile.length) return 0;
    return Math.max(...loadProfile.map((p) => p.total_duration_minutes || 0));
  }, [loadProfile]);

  const nightHours = useMemo(() => [21, 22, 23, 0, 1, 2, 3, 4, 5, 6, 7, 8], []);
  const nightProfileMap = useMemo(() => {
    const map = new Map();
    (nightSummary?.hourly || []).forEach((slot) => {
      map.set(Number(slot.hour), slot);
    });
    return map;
  }, [nightSummary]);
  const nightMaxDuration = useMemo(() => {
    const values = (nightSummary?.hourly || []).map((slot) => slot.total_duration_minutes || 0);
    return values.length ? Math.max(...values) : 0;
  }, [nightSummary]);

  const entitySchemas = useMemo(() => entitySchemaOptions, [entitySchemaOptions]);

  const filteredEntityLoads = useMemo(() => {
    if (entitySchema === "all") return entityLoads;
    return entityLoads.filter((row) => row.table_fqn?.startsWith(`${entitySchema}.`));
  }, [entityLoads, entitySchema]);

  const compareSchemaOptions = useMemo(() => {
    const schemas = new Set();
    compareRows.forEach((row) => {
      const [schemaName] = String(row.table_fqn || "").split(".");
      if (schemaName) schemas.add(schemaName);
    });
    return Array.from(schemas).sort((a, b) => a.localeCompare(b, "ru"));
  }, [compareRows]);

  const filteredCompareRows = useMemo(() => {
    if (!compareSchemaSelection.length) return compareRows;
    return compareRows.filter((row) => {
      const [schemaName] = String(row.table_fqn || "").split(".");
      return compareSchemaSelection.includes(schemaName);
    });
  }, [compareRows, compareSchemaSelection]);

  const compareMaxDelta = useMemo(() => {
    if (!filteredCompareRows.length) return 0;
    return Math.max(...filteredCompareRows.map((row) => Math.abs(Number(row.delta_minutes || 0))));
  }, [filteredCompareRows]);

  const compareSummary = useMemo(() => {
    const stats = { faster: 0, slower: 0, onlyOneDay: 0 };
    filteredCompareRows.forEach((row) => {
      if (row.duration_a === null || row.duration_b === null) {
        stats.onlyOneDay += 1;
      } else if ((row.delta_minutes || 0) > 0) {
        stats.slower += 1;
      } else if ((row.delta_minutes || 0) < 0) {
        stats.faster += 1;
      }
    });
    return stats;
  }, [filteredCompareRows]);

  const compareOverview = useMemo(() => {
    if (!filteredCompareRows.length) return null;
    const aggregate = (suffix) => {
      const startValues = filteredCompareRows
        .map((row) => row[`start_${suffix}`])
        .filter(Boolean)
        .sort((a, b) => String(a).localeCompare(String(b)));
      const endValues = filteredCompareRows
        .map((row) => row[`end_${suffix}`])
        .filter(Boolean)
        .sort((a, b) => String(a).localeCompare(String(b)));
      const start = startValues.length ? startValues[0] : null;
      const end = endValues.length ? endValues[endValues.length - 1] : null;
      const startDt = parseLocalDateTime(start);
      const endDt = parseLocalDateTime(end);
      return {
        start,
        end,
        spanMinutes:
          startDt && endDt ? Math.round(((endDt.getTime() - startDt.getTime()) / 60000) * 10) / 10 : null,
      };
    };
    const base = aggregate("a");
    const compare = aggregate("b");
    const deltaMinutes =
      base.spanMinutes !== null && compare.spanMinutes !== null
        ? compare.spanMinutes - base.spanMinutes
        : null;
    return { base, compare, deltaMinutes };
  }, [filteredCompareRows]);

  const compareOverviewMaxSpan = useMemo(() => {
    if (!compareOverview) return 0;
    return Math.max(compareOverview.base.spanMinutes || 0, compareOverview.compare.spanMinutes || 0, 0);
  }, [compareOverview]);

  function formatObjectFqn(schema, table) {
    const schemaText = String(schema || "").trim();
    const tableText = String(table || "").trim();
    if (!tableText) return schemaText || "";
    if (tableText.includes(".")) return tableText;
    return schemaText ? `${schemaText}.${tableText}` : tableText;
  }

  const openTable = (schema, table, context) => {
    const fqn = formatObjectFqn(schema, table);
    if (!fqn || !fqn.includes(".")) return;
    onSelectTable?.({ view: "table_info", table: fqn, context }, "slowest_tables");
  };

  const openTableFqn = (fqn, context) => {
    if (!fqn || typeof fqn !== "string") return;
    const [schema, ...rest] = fqn.split(".");
    const table = rest.join(".");
    openTable(schema, table, context);
  };

  const toggleCompareSchema = (schemaName) => {
    setCompareSchemaSelection((current) =>
      current.includes(schemaName)
        ? current.filter((value) => value !== schemaName)
        : [...current, schemaName],
    );
  };

  const statusLabel = (status) => {
    const value = String(status || "").toUpperCase();
    if (value === "SUCCESS") return "Успешно";
    if (value === "FAILED") return "Ошибка";
    if (value === "RUNNING") return "В работе";
    if (value === "UP_FOR_RETRY") return "Повтор";
    return value || "—";
  };

  const compareDeltaClass = (delta) => {
    if (delta === null || delta === undefined) return "neutral";
    if (delta > 0) return "worse";
    if (delta < 0) return "better";
    return "neutral";
  };

  return (
    <div className="container cc-page slow-page">
      <section className="cc-header-zone">
        <h1>Производительность загрузок</h1>
        <div className="cc-subtitle">
          Исторические узкие места, ночные пики и анализ конкретного окна загрузок в одном разделе.
        </div>
      </section>

      <section className="slow-controls">
        <div className="section-title">Режим страницы</div>
        <div className="slow-controls-row">
          <div className="slow-select-group">
            <button
              className={viewMode === "risk" ? "active" : ""}
              onClick={() => setViewMode("risk")}
            >
              Исторический риск
            </button>
            <button
              className={viewMode === "window" ? "active" : ""}
              onClick={() => setViewMode("window")}
            >
              Анализ окна
            </button>
            <button
              className={viewMode === "compare" ? "active" : ""}
              onClick={() => setViewMode("compare")}
            >
              Сравнение дней
            </button>
          </div>
        </div>
      </section>

      {viewMode === "compare" && (
        <>
          <section className="analytics-block analytics-compare-block">
            <div className="section-title">Сравнение загрузок по дням</div>
            <div className="muted analytics-subtitle">
              Сравнение последнего успешного запуска по двум датам. Сначала выберите базовый день, потом день сравнения.
            </div>
            <div className="analytics-toolbar compact">
              <div className="analytics-range">
                <div className="analytics-custom compact">
                  <label className="muted">Базовый день</label>
                  <input
                    type="date"
                    className="input"
                    value={compareDateA}
                    onChange={(e) => setCompareDateA(e.target.value)}
                  />
                </div>
                <div className="analytics-custom compact">
                  <label className="muted">Сравниваемый день</label>
                  <input
                    type="date"
                    className="input"
                    value={compareDateB}
                    onChange={(e) => setCompareDateB(e.target.value)}
                  />
                </div>
                <div className="analytics-custom compact">
                  <label className="muted">Сущность</label>
                  <select
                    className="input"
                    value={compareEntityId}
                    onChange={(e) => setCompareEntityId(e.target.value)}
                  >
                    <option value="">Все сущности</option>
                    {entities.map((entity) => (
                      <option key={entity.entity_id} value={entity.entity_id}>
                        {entity.entity_name || `Сущность ${entity.entity_id}`}
                      </option>
                    ))}
                  </select>
                </div>
                <button className="btn btn-primary analytics-action" onClick={loadCompare}>
                  Сравнить
                </button>
              </div>
            </div>
            {!!compareSchemaOptions.length && (
              <div className="analytics-chip-row">
                <button
                  className={`analytics-chip ${compareSchemaSelection.length === 0 ? "active" : ""}`}
                  onClick={() => setCompareSchemaSelection([])}
                >
                  Все схемы
                </button>
                {compareSchemaOptions.map((schemaName) => (
                  <button
                    key={schemaName}
                    className={`analytics-chip ${compareSchemaSelection.includes(schemaName) ? "active" : ""}`}
                    onClick={() => toggleCompareSchema(schemaName)}
                  >
                    {schemaName}
                  </button>
                ))}
              </div>
            )}
            {compareLoading && <div className="muted">Сравниваем загрузки...</div>}
          {compareError && <div className="dep-error-title">{compareError}</div>}
            {!compareLoading && !compareError && !!filteredCompareRows.length && (
              <>
                {compareOverview && (
                  <div className="entity-compare-overview">
                    <div className="entity-compare-card">
                      <div className="entity-compare-label">Старт окна сущности</div>
                      <div className="entity-compare-values">
                        <span>{compareDateA}: {formatDateTime(compareOverview.base.start)}</span>
                        <span>{compareDateB}: {formatDateTime(compareOverview.compare.start)}</span>
                      </div>
                    </div>
                    <div className="entity-compare-card">
                      <div className="entity-compare-label">Финиш последней таблицы</div>
                      <div className="entity-compare-values">
                        <span>{compareDateA}: {formatDateTime(compareOverview.base.end)}</span>
                        <span>{compareDateB}: {formatDateTime(compareOverview.compare.end)}</span>
                      </div>
                    </div>
                    <div className={`entity-compare-card ${compareDeltaClass(compareOverview.deltaMinutes)}`}>
                      <div className="entity-compare-label">Длительность окна сущности</div>
                      <div className="entity-compare-values">
                        <span>{compareDateA}: {compareOverview.base.spanMinutes ?? "—"} мин</span>
                        <span>{compareDateB}: {compareOverview.compare.spanMinutes ?? "—"} мин</span>
                        <span>
                          {compareOverview.deltaMinutes === null
                            ? "не хватает данных"
                            : compareOverview.deltaMinutes > 0
                            ? `стало дольше на ${compareOverview.deltaMinutes.toFixed(1)} мин`
                            : compareOverview.deltaMinutes < 0
                              ? `стало быстрее на ${Math.abs(compareOverview.deltaMinutes).toFixed(1)} мин`
                              : "без изменений"}
                        </span>
                      </div>
                      {compareOverviewMaxSpan > 0 && (
                        <div className="entity-compare-bars">
                          <div className="entity-compare-bar-row">
                            <span>{compareDateA}</span>
                            <div className="entity-compare-bar-track">
                              <div
                                className="entity-compare-bar-fill"
                                style={{ width: `${Math.max(10, ((compareOverview.base.spanMinutes || 0) / compareOverviewMaxSpan) * 100)}%` }}
                              />
                            </div>
                            <span>{compareOverview.base.spanMinutes ?? "—"} мин</span>
                          </div>
                          <div className="entity-compare-bar-row">
                            <span>{compareDateB}</span>
                            <div className="entity-compare-bar-track">
                              <div
                                className="entity-compare-bar-fill"
                                style={{ width: `${Math.max(10, ((compareOverview.compare.spanMinutes || 0) / compareOverviewMaxSpan) * 100)}%` }}
                              />
                            </div>
                            <span>{compareOverview.compare.spanMinutes ?? "—"} мин</span>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                )}
                <div className="slow-summary compare-summary">
                  <div className="slow-summary-card">
                    <div className="label">Объектов</div>
                    <div className="value">{filteredCompareRows.length}</div>
                  </div>
                  <div className="slow-summary-card success">
                    <div className="label">Ускорились</div>
                    <div className="value">{compareSummary.faster}</div>
                  </div>
                  <div className="slow-summary-card danger">
                    <div className="label">Замедлились</div>
                    <div className="value">{compareSummary.slower}</div>
                  </div>
                  <div className="slow-summary-card">
                    <div className="label">Только в одном дне</div>
                    <div className="value">{compareSummary.onlyOneDay}</div>
                  </div>
                </div>
                <div className="analytics-compare-list">
                  {filteredCompareRows.map((row) => {
                    const delta = Number(row.delta_minutes || 0);
                    const width = compareMaxDelta
                      ? Math.max(8, (Math.abs(delta) / compareMaxDelta) * 100)
                      : 0;
                    return (
                      <div key={row.table_fqn} className="analytics-compare-row">
                        <button
                          className="btn btn-ghost analytics-compare-name mono"
                          title={row.table_fqn}
                          onClick={() => openTable(row.table_schema, row.table_name, { compare: true })}
                        >
                          {shortenName(row.table_fqn, 42)}
                        </button>
                        <div className="analytics-compare-meta">
                          <span>{row.entity_name || "—"}</span>
                          <span>{`${row.duration_a ?? "—"} мин -> ${row.duration_b ?? "—"} мин`}</span>
                        </div>
                        <div className="analytics-compare-track">
                          <div
                            className={`analytics-compare-bar ${compareDeltaClass(delta)}`}
                            style={{ width: `${width}%` }}
                          />
                        </div>
                        <div className={`analytics-compare-delta ${compareDeltaClass(delta)}`}>
                          {row.delta_minutes === null
                            ? "только один день"
                            : delta > 0
                              ? `дольше на ${delta.toFixed(1)} мин`
                              : delta < 0
                                ? `быстрее на ${Math.abs(delta).toFixed(1)} мин`
                                : "без изменений"}
                          {row.delta_pct !== null ? ` · ${formatPercent(row.delta_pct)}` : ""}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </>
            )}
          </section>
        </>
      )}

      {viewMode === "window" && (
        <>
          <section className="analytics-block">
            <div className="section-title">Окно загрузок</div>
            <div className="muted analytics-subtitle">
              GP и ClickHouse в одном окне времени. Для ClickHouse отдельно показываются работа и ожидание.
            </div>
            <div className="analytics-toolbar compact">
              <div className="analytics-range">
                <div className="analytics-custom compact">
                  <label className="muted">Дата</label>
                  <input
                    type="date"
                    className="input"
                    value={windowDate}
                    onChange={(e) => setWindowDate(e.target.value)}
                  />
                </div>
                <div className="analytics-custom compact">
                  <label className="muted">С</label>
                  <input
                    type="time"
                    className="input"
                    value={timeFrom}
                    onChange={(e) => setTimeFrom(e.target.value)}
                  />
                </div>
                <div className="analytics-custom compact">
                  <label className="muted">По</label>
                  <input
                    type="time"
                    className="input"
                    value={timeTo}
                    onChange={(e) => setTimeTo(e.target.value)}
                  />
                </div>
                <div className="analytics-custom compact">
                  <label className="muted">Источник</label>
                  <select
                    className="input"
                    value={windowSource}
                    onChange={(e) => setWindowSource(e.target.value)}
                  >
                    <option value="both">GP + Click</option>
                    <option value="gp">Только GP</option>
                    <option value="click">Только Click</option>
                  </select>
                </div>
                <div className="analytics-custom compact">
                  <label className="muted">Сущность</label>
                  <select
                    className="input"
                    value={windowEntityFilter}
                    onChange={(e) => setWindowEntityFilter(e.target.value)}
                  >
                    <option value="all">Все сущности</option>
                    {windowEntityOptions.map((entity) => (
                      <option key={entity} value={entity}>
                        {entity}
                      </option>
                    ))}
                  </select>
                </div>
                <button className="btn btn-primary analytics-action" onClick={loadWindowRuns}>
                  Найти
                </button>
              </div>
            </div>
          </section>

          {windowLoading && <div className="muted">Загрузка аналитики...</div>}
          {windowError && <div className="dep-error-title">{windowError}</div>}

          {!windowLoading && !windowError && (
            <div className="analytics-grid">
              <section className="analytics-block">
                <div className="section-title">Работа и ожидание</div>
                {filteredWindowRows.length === 0 && <div className="muted">Нет запусков в окне.</div>}
                {filteredWindowRows.length > 0 && (
                  <>
                    <div className="analytics-block-actions">
                      <span className="muted">Показано {visibleWindowBars.length} из {filteredWindowRows.length}</span>
                      {filteredWindowRows.length > 20 && (
                        <button className="btn btn-ghost" onClick={() => setShowAllWindowBars((v) => !v)}>
                          {showAllWindowBars ? "Свернуть" : "Показать все"}
                        </button>
                      )}
                    </div>
                    <div className="analytics-bars">
                      {visibleWindowBars.map((row, idx) => {
                        const actual = Number(row.actual_duration_min ?? row.duration_min ?? 0);
                        const lag = Number(row.lag_duration_min || 0);
                        const total = actual + lag;
                        const actualWidth = windowMaxDuration
                          ? Math.max(actual > 0 ? 8 : 0, (actual / windowMaxDuration) * 100)
                          : 0;
                        const lagWidth = windowMaxDuration ? (lag / windowMaxDuration) * 100 : 0;
                        const label = formatObjectFqn(row.schema_name, row.table_name);
                        return (
                          <div key={`${label}-${row.run_uuid || idx}`} className="analytics-bar-row">
                            <div className="analytics-bar-label mono">
                              <button
                                className="btn btn-ghost analytics-bar-link"
                                title={label}
                                onClick={() => openTable(row.schema_name, row.table_name)}
                              >
                                {shortenName(label, 44)}
                              </button>
                              <span className="analytics-pill analytics-pill-inline">{row.source}</span>
                            </div>
                            <div
                              className="analytics-bar-track"
                              title={
                                row.source === "ClickHouse"
                                  ? `Работа ${actual} мин, ожидание ${lag} мин, окно ${total} мин`
                                  : `Работа ${actual} мин`
                              }
                            >
                              <div className="analytics-bar-fill" style={{ width: `${actualWidth}%` }} />
                              {row.source === "ClickHouse" && lag > 0 && (
                                <div
                                  className="analytics-bar-lag"
                                  style={{ left: `${actualWidth}%`, width: `${lagWidth}%` }}
                                />
                              )}
                            </div>
                            <div className="analytics-bar-value">
                              {row.source === "ClickHouse"
                                ? `${actual} работа / ${lag} ожидание`
                                : `${actual} мин`}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </>
                )}
              </section>

              <section className="analytics-block">
                <div className="section-title">Сущности в окне</div>
                {windowEntitySummary.length === 0 && <div className="muted">Нет данных.</div>}
                {windowEntitySummary.length > 0 && (
                  <div className="analytics-table analytics-plain-table">
                    <div className="analytics-head analytics-entity">
                      <span>Сущность</span>
                      <span>Таблиц</span>
                      <span>Запусков</span>
                      <span>Работа</span>
                      <span>Ожидание</span>
                    </div>
                    {windowEntitySummary.slice(0, 20).map((item) => (
                      <div key={item.entity} className="analytics-row analytics-entity">
                        <span className="mono analytics-cell-entity" title={item.entity}>
                          {shortenName(item.entity, 28)}
                        </span>
                        <span>{item.tables_count}</span>
                        <span>{item.runs_count}</span>
                        <span>{item.minutes}</span>
                        <span>{item.lag_minutes}</span>
                      </div>
                    ))}
                  </div>
                )}
              </section>

              <section className="analytics-block">
                <div className="section-title">Список запусков в окне</div>
                {filteredWindowRows.length === 0 && <div className="muted">Нет запусков в окне.</div>}
                {filteredWindowRows.length > 0 && (
                  <div className="analytics-run-list analytics-run-list-plain">
                    {filteredWindowRows.map((row, idx) => {
                      const fullName = formatObjectFqn(row.schema_name, row.table_name);
                      return (
                        <div key={`${fullName}-${row.run_uuid || idx}`} className="analytics-run-row">
                          <div className="analytics-run-main">
                            <button
                              className="mono analytics-cell-name btn btn-ghost"
                              title={fullName}
                              onClick={() => openTable(row.schema_name, row.table_name)}
                            >
                              {shortenName(fullName, 40)}
                            </button>
                            <span className="muted analytics-cell-entity" title={row.entity_name || ""}>
                              {shortenName(row.entity_name || "—", 28)}
                            </span>
                          </div>
                          <div className="analytics-run-badges">
                            <span className="analytics-pill">{row.source}</span>
                            <span className={`analytics-pill analytics-pill-status status-${String(row.status || "").toLowerCase()}`}>
                              {statusLabel(row.status)}
                            </span>
                          </div>
                          <div className="analytics-run-time">
                            <span className="muted">Старт</span>
                            <span>{formatDateTime(row.start_dttm)}</span>
                          </div>
                          <div className="analytics-run-time">
                            <span className="muted">Финиш</span>
                            <span>{formatDateTime(row.end_dttm)}</span>
                          </div>
                          <div className="analytics-run-metric">
                            <span className="muted">Работа</span>
                            <strong>{formatMinutes(Number(row.actual_duration_min ?? row.duration_min ?? 0))}</strong>
                          </div>
                          <div className="analytics-run-metric">
                            <span className="muted">Ожидание</span>
                            <strong>{formatMinutes(Number(row.lag_duration_min || 0))}</strong>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </section>
            </div>
          )}
        </>
      )}

      {viewMode === "risk" && periodLabel && (
        <div className="cc-header-meta">
          <span className="period-pill">Период: {periodLabel}</span>
          <span className="period-note">по логам</span>
        </div>
      )}

      {viewMode === "risk" && <section className="slow-summary">
        <div className="slow-summary-card">
          <div className="label">Таблиц в выборке</div>
          <div className="value">{summary.total}</div>
          {meta?.candidates !== undefined && (
            <div className="hint muted">{meta.candidates} кандидатов</div>
          )}
        </div>
        <div className="slow-summary-card danger">
          <div className="label">Медленные (p95)</div>
          <div className="value">{summary.slowCount}</div>
        </div>
        <div className="slow-summary-card warn">
          <div className="label">Нестабильные (CV)</div>
          <div className="value">{summary.unstableCount}</div>
        </div>
        <div className="slow-summary-card">
          <div className="label">Среднее запусков</div>
          <div className="value">{summary.avgRuns}</div>
        </div>
      </section>}

      {viewMode === "risk" && <section className="slow-controls">
        <div className="section-title">Параметры окна</div>
        <div className="slow-controls-row">
          <div className="slow-select-group">
            <span className="slow-select-label">Окно</span>
            {[7, 14, 30].map((d) => (
              <button
                key={d}
                className={d === windowDays ? "active" : ""}
                onClick={() => setWindowDays(d)}
              >
                {d} дней
              </button>
            ))}
          </div>
          <div className="slow-select-group">
            <span className="slow-select-label">TOP</span>
            {[10, 20, 50].map((n) => (
              <button
                key={n}
                className={n === limit ? "active" : ""}
                onClick={() => setLimit(n)}
              >
                {n}
              </button>
            ))}
          </div>
        </div>
      </section>}

      {viewMode === "risk" && <section className="slow-criteria">
        <div className="section-title">Критерии</div>
        <div className="slow-criteria-grid">
          <div className="slow-criteria-card">
            <div className="slow-criteria-title">Медленная загрузка</div>
            <div className="muted">
              p95 &gt; {SLA_MINUTES} мин или p95 &gt; {SLOW_P95_MINUTES} мин
            </div>
          </div>
          <div className="slow-criteria-card">
            <div className="slow-criteria-title">Нестабильность</div>
            <div className="muted">
              CV &lt; {UNSTABLE_WARN} — стабильно · {UNSTABLE_WARN}–{UNSTABLE_CRIT} — нестабильно · &gt; {UNSTABLE_CRIT} — критично
            </div>
          </div>
          <div className="slow-criteria-card">
            <div className="slow-criteria-title">Красный флаг</div>
            <div className="muted">p95 / avg &gt; 2</div>
          </div>
        </div>
      </section>}

      {viewMode === "risk" && <section className="slow-profile">
        <div className="section-title">
          Суммарная нагрузка по часам (SUCCESS)
          <span
            className="load-info"
            title="Aggregated across all SUCCESS loads for the selected period. Used to find peak system hours."
          >
            ℹ️
          </span>
        </div>
        <div className="slow-profile-sub muted">
          Цвет — суммарная длительность по окну, а не за день.
        </div>
        {loadingProfile && <div className="muted">Загрузка профиля...</div>}
        {!loadingProfile && loadProfile.length === 0 && (
          <div className="card muted">Нет данных профиля нагрузки.</div>
        )}
        {!loadingProfile && loadProfile.length > 0 && (
          <div className="load-heatmap">
            <div className="load-heatmap-grid">
              {loadProfile.map((slot) => {
                const ratio = maxProfileDuration
                  ? slot.total_duration_minutes / maxProfileDuration
                  : 0;
                const alpha = Math.min(0.75, 0.12 + ratio * 0.63);
                const bg = `rgba(96, 165, 250, ${alpha.toFixed(3)})`;
                const hourLabel = `${String(slot.hour).padStart(2, "0")}:00–${String(slot.hour).padStart(2, "0")}:59`;
                const totalMinutes = slot.total_duration_minutes || 0;
                const hours = Math.floor(totalMinutes / 60);
                const minutes = Math.round(totalMinutes % 60);
                const durationLabel = hours > 0 ? `${hours} ч ${minutes} мин` : `${minutes} мин`;
                const title = `Час: ${hourLabel}\nЗапуски: ${slot.runs_count}\nСуммарно: ${durationLabel}\nОкно: ${windowDays} дней`;
                return (
                  <div
                    key={slot.hour}
                    className="load-heatmap-cell"
                    style={{ background: bg }}
                    title={title}
                  >
                    <span>{slot.hour}</span>
                  </div>
                );
              })}
            </div>
            <div className="load-heatmap-axis">
              <span>00</span>
              <span>04</span>
              <span>08</span>
              <span>12</span>
              <span>16</span>
              <span>20</span>
              <span>23</span>
            </div>
          </div>
        )}
      </section>}

      {viewMode === "risk" && <section className="slow-night">
        <div className="section-title">Ночное окно (21:00–08:00)</div>
        {nightLoading && <div className="muted">Загрузка ночного окна...</div>}
        {nightError && <div className="card muted">{nightError}</div>}
        {!nightLoading && !nightError && (
          <>
            <div className="slow-summary slow-night-summary">
              <div className="slow-summary-card">
                <div className="label">Запусков</div>
                <div className="value">{nightSummary?.summary?.runs_count ?? 0}</div>
              </div>
              <div className="slow-summary-card">
                <div className="label">Таблиц</div>
                <div className="value">{nightSummary?.summary?.tables_count ?? 0}</div>
              </div>
              <div className="slow-summary-card">
                <div className="label">Сущностей</div>
                <div className="value">{nightSummary?.summary?.entities_count ?? 0}</div>
              </div>
              <div className="slow-summary-card">
                <div className="label">Сумма</div>
                <div className="value">{formatMinutes(nightSummary?.summary?.total_duration_minutes)}</div>
                <div className="hint muted">минут загрузки</div>
              </div>
              <div className="slow-summary-card danger">
                <div className="label">Макс</div>
                <div className="value">{formatMinutes(nightSummary?.summary?.max_duration_minutes)}</div>
              </div>
            </div>

            <div className="slow-night-grid">
              <div className="slow-night-panel">
                <div className="slow-night-title">Пики по часам</div>
                <div className="slow-night-sub muted">
                  Наведите на час — до 50 таблиц.
                </div>
                <div className="load-heatmap">
                  <div className="load-heatmap-grid load-heatmap-night">
                    {nightHours.map((hour) => {
                      const slot = nightProfileMap.get(hour);
                      const ratio = nightMaxDuration
                        ? (slot?.total_duration_minutes || 0) / nightMaxDuration
                        : 0;
                      const alpha = Math.min(0.75, 0.12 + ratio * 0.63);
                      const bg = `rgba(56, 189, 248, ${alpha.toFixed(3)})`;
                      const totalMinutes = slot?.total_duration_minutes || 0;
                      const hours = Math.floor(totalMinutes / 60);
                      const minutes = Math.round(totalMinutes % 60);
                      const durationLabel = hours > 0 ? `${hours} ч ${minutes} мин` : `${minutes} мин`;
                      const tables = (slot?.top_tables || []).map((t) => `${t.table_fqn} (${formatMinutes(t.duration_minutes)} min)`);
                      const title = [
                        `Час: ${String(hour).padStart(2, "0")}:00`,
                        `Запуски: ${slot?.runs_count || 0}`,
                        `Суммарно: ${durationLabel}`,
                        tables.length ? "Топ таблиц:" : "Топ таблиц: нет",
                        ...tables,
                      ].join("\n");
                      return (
                        <div
                          key={hour}
                          className="load-heatmap-cell"
                          style={{ background: bg }}
                          title={title}
                        >
                          <span>{String(hour).padStart(2, "0")}</span>
                        </div>
                      );
                    })}
                  </div>
                  <div className="load-heatmap-axis">
                    <span>21</span>
                    <span>00</span>
                    <span>03</span>
                    <span>06</span>
                    <span>08</span>
                  </div>
                </div>
              </div>

              <div className="slow-night-panel">
                <div className="slow-night-title">Самые долгие за ночь</div>
                {nightSummary?.top_runs?.length ? (
                  <div className="slow-night-list">
                    {nightSummary.top_runs.map((row, idx) => (
                      <div key={`${row.table_fqn}-${idx}`} className="slow-night-item">
                        <button
                          className="mono slow-night-table btn btn-ghost"
                          title={row.table_fqn}
                          onClick={() => openTableFqn(row.table_fqn)}
                        >
                          {row.table_fqn}
                        </button>
                        <div className="slow-night-meta">
                          <span>{row.entity_name || "—"}</span>
                          <span>{formatMinutes(row.duration_minutes)} мин</span>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="card muted">Нет данных ночной загрузки.</div>
                )}
              </div>

              <div className="slow-night-panel">
                <div className="slow-night-title">Аномалии vs p95</div>
                <div className="slow-night-sub muted">
                  Показывает превышения p95 более чем в 1.5×.
                </div>
                {nightSummary?.anomalies?.length ? (
                  <div className="slow-night-list">
                    {nightSummary.anomalies.map((row, idx) => (
                      <div key={`${row.table_fqn}-${idx}`} className="slow-night-item">
                        <button
                          className="mono slow-night-table btn btn-ghost"
                          title={row.table_fqn}
                          onClick={() => openTableFqn(row.table_fqn)}
                        >
                          {row.table_fqn}
                        </button>
                        <div className="slow-night-meta">
                          <span>{row.entity_name || "—"}</span>
                          <span>
                            {formatMinutes(row.duration_minutes)} мин / p95 {formatMinutes(row.p95_minutes)} ({row.ratio ?? "—"}x)
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="card muted">Аномалий нет.</div>
                )}
              </div>
            </div>
          </>
        )}
      </section>}

      {viewMode === "risk" && <section className="slow-entity">
        <div className="section-title">Анализ по сущности</div>
        <div className="slow-controls-row slow-entity-controls">
          <div className="slow-select-group">
            <span className="slow-select-label">Сущность</span>
            <select
              className="slow-entity-select"
              value={entityId}
              onChange={(event) => setEntityId(event.target.value)}
            >
              {!entities.length && <option value="">Нет сущностей</option>}
              {entities.map((e) => (
                <option key={e.entity_id} value={e.entity_id}>
                  {e.entity_name || `Сущность ${e.entity_id}`}
                </option>
              ))}
            </select>
          </div>
          <div className="slow-select-group">
            <span className="slow-select-label">Схема</span>
            <select
              className="slow-entity-select"
              value={entitySchema}
              onChange={(event) => setEntitySchema(event.target.value)}
            >
              {entitySchemas.map((schema) => (
                <option key={schema} value={schema}>
                  {schema === "all" ? "Все" : schema}
                </option>
              ))}
            </select>
          </div>
          <div className="slow-select-group">
            <span className="slow-select-label">TOP</span>
            {[10, 30, 50].map((size) => (
              <button
                key={size}
                className={size === entityLimit ? "active" : ""}
                onClick={() => setEntityLimit(size)}
              >
                {size}
              </button>
            ))}
          </div>
        </div>
        {entityLoading && <div className="muted">Загрузка данных сущности...</div>}
        {!entityLoading && filteredEntityLoads.length === 0 && (
          <div className="card muted">Нет данных для выбранной сущности.</div>
        )}
        {!entityLoading && filteredEntityLoads.length > 0 && (
          <div className="table-wrapper">
            <table className="incidents-table slow-table">
              <thead>
                <tr>
                  <th>Table</th>
                  <th>AVG</th>
                  <th>P95</th>
                  <th>MAX</th>
                  <th>RUNS</th>
                  <th>Последний</th>
                </tr>
              </thead>
              <tbody>
                {filteredEntityLoads.map((row, idx) => (
                  <tr
                    key={`${row.table_fqn}-${idx}`}
                    className="slow-row-click"
                    onClick={() => openTableFqn(row.table_fqn)}
                  >
                    <td className="mono slow-table-name" title={row.table_fqn}>
                      {row.table_fqn}
                    </td>
                    <td>{formatMinutes(row.avg_duration)}</td>
                    <td>{formatMinutes(row.p95_duration)}</td>
                    <td>{formatMinutes(row.max_duration)}</td>
                    <td>{row.runs_count ?? "—"}</td>
                    <td>{row.last_finish || "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>}

      {viewMode === "risk" && loading && <div className="page-loading">Загрузка метрик...</div>}
      {viewMode === "risk" && error && <div className="page-error">{error}</div>}

      {viewMode === "risk" && !loading && !error && sorted.length === 0 && (
        <div className="card muted">Нет данных по успешным загрузкам.</div>
      )}

      {viewMode === "risk" && !loading && !error && sorted.length > 0 && (
        <section className="cc-surface">
          <div className="section-title">
            Таблицы по риску
            <span className="section-meta">{sorted.length}</span>
          </div>
          <div className="table-wrapper">
            <table className="incidents-table slow-table">
              <thead>
                <tr>
                  <th>Table</th>
                  <th>Сущность</th>
                  <th>AVG</th>
                  <th>P95</th>
                  <th>MAX</th>
                  <th title="Используется для CV">RUNS</th>
                  <th>CV</th>
                  <th>P95/AVG</th>
                  <th>Статус</th>
                </tr>
              </thead>
              <tbody>
                {sorted.map((row, index) => (
                  <tr
                    key={`${row.table_schema}.${row.table_name}.${row.entity_name || "no-entity"}.${row.runs_count || 0}.${index}`}
                    className="slow-row-click"
                    onClick={() =>
                      openTable(row.table_schema, row.table_name, {
                        status: row.status,
                        slow: row.slow,
                        unstable: row.unstable,
                        low_sample: row.low_sample,
                        runs_count: row.runs_count,
                        avg_duration: row.avg_duration,
                        p95_duration: row.p95_duration,
                        max_duration: row.max_duration,
                        stddev_duration: row.stddev_duration,
                        cv: row.cv,
                        p95_avg_ratio: row.p95_avg_ratio,
                      })
                    }
                  >
                    <td className="mono slow-table-name" title={`${row.table_schema}.${row.table_name}`}>
                      {row.table_schema}.{row.table_name}
                    </td>
                    <td>{row.entity_name || "—"}</td>
                    <td>{formatMinutes(row.avg_duration)}</td>
                    <td>{formatMinutes(row.p95_duration)}</td>
                    <td>{formatMinutes(row.max_duration)}</td>
                    <td>{row.runs_count}</td>
                    <td>{Number.isFinite(row.cv) ? Number(row.cv).toFixed(2) : "—"}</td>
                    <td>{Number.isFinite(row.p95_avg_ratio) ? Number(row.p95_avg_ratio).toFixed(2) : "—"}</td>
                    <td>
                      <div className="slow-status">
                        {row.low_sample && (
                          <span
                            className="slow-pill low-sample"
                            title="Not enough runs to assess stability"
                          >
                            Мало запусков <span className="slow-pill-info">ℹ️</span>
                          </span>
                        )}
                        {row.status === "slow_unstable" && <span className="slow-pill danger">Медленно и нестабильно</span>}
                        {row.status === "slow" && <span className="slow-pill danger">Медленно</span>}
                        {row.status === "unstable" && (
                          <span className={`slow-pill ${row.critical_unstable ? "danger" : "warn"}`}>
                            Нестабильно
                          </span>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </div>
  );
}
