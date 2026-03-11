import { useEffect, useMemo, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";
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
  const [windowDate, setWindowDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [timeFrom, setTimeFrom] = useState("04:30");
  const [timeTo, setTimeTo] = useState("05:00");
  const [windowSource, setWindowSource] = useState("both");
  const [windowEntityFilter, setWindowEntityFilter] = useState("all");
  const [windowRows, setWindowRows] = useState([]);
  const [windowLoading, setWindowLoading] = useState(false);
  const [windowError, setWindowError] = useState(null);

  useEffect(() => {
    setLoading(true);
    fetch(`${API_BASE}/api/slowest-tables?days=${windowDays}&limit=${limit}`)
      .then((res) => (res.ok ? res.json() : Promise.reject(res.status)))
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
    fetch(`${API_BASE}/api/load-profile?days=${windowDays}`)
      .then((res) => {
        if (res.status === 404) {
          return { profile: [] };
        }
        return res.ok ? res.json() : Promise.reject(res.status);
      })
      .then((data) => {
        setLoadProfile(Array.isArray(data?.profile) ? data.profile : []);
      })
      .catch(() => setLoadProfile([]))
      .finally(() => setLoadingProfile(false));
  }, [windowDays]);

  useEffect(() => {
    setNightLoading(true);
    setNightError(null);
    fetch(`${API_BASE}/api/night-summary?days=${windowDays}&limit=50`)
      .then((res) => (res.ok ? res.json() : Promise.reject(res.status)))
      .then((data) => setNightSummary(data))
      .catch(() => setNightError("Не удалось загрузить ночное окно"))
      .finally(() => setNightLoading(false));
  }, [windowDays]);

  useEffect(() => {
    fetch(`${API_BASE}/api/entities`)
      .then((res) => (res.ok ? res.json() : Promise.reject(res.status)))
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
      })
      .catch(() => setEntities([]));
  }, []);

  useEffect(() => {
    if (!entityId) {
      setEntityLoads([]);
      return;
    }
    setEntityLoading(true);
    const schemaParam = entitySchema !== "all" ? `&schema=${encodeURIComponent(entitySchema)}` : "";
    fetch(`${API_BASE}/api/entity-loads?entity_id=${encodeURIComponent(entityId)}&days=${windowDays}&limit=${entityLimit}${schemaParam}`)
      .then((res) => (res.ok ? res.json() : Promise.reject(res.status)))
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
    const str = String(value).replace("T", " ").replace("Z", "");
    const match = str.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})/);
    if (match) return `${match[1]} ${match[2]}`;
    return str;
  };

  const loadWindowRuns = () => {
    setWindowLoading(true);
    setWindowError(null);
    const params = new URLSearchParams({
      date: windowDate,
      from: timeFrom,
      to: timeTo,
      source: windowSource,
    });
    fetch(`${API_BASE}/api/window-runs?${params.toString()}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить окно")))
      .then((data) => {
        const merged = [];
        (data.gp || []).forEach((row) => merged.push({ ...row, source: "GP" }));
        (data.click || []).forEach((row) => merged.push({ ...row, source: "ClickHouse" }));
        merged.sort((a, b) => (a.start_dttm || "").localeCompare(b.start_dttm || ""));
        setWindowRows(merged);
        setWindowEntityFilter("all");
      })
      .catch((err) => setWindowError(typeof err === "string" ? err : "Не удалось загрузить окно"))
      .finally(() => setWindowLoading(false));
  };

  const periodLabel = useMemo(() => {
    if (meta?.period_from && meta?.period_to) {
      const fmt = (value) =>
        new Date(value).toLocaleDateString("en-GB", {
          day: "2-digit",
          month: "2-digit",
        });
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
      item.tables.add(`${row.schema_name}.${row.table_name}`);
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

  const openTable = (schema, table, context) => {
    if (!schema || !table) return;
    onSelectTable?.({ view: "table_info", table: `${schema}.${table}`, context }, "slowest_tables");
  };

  const openTableFqn = (fqn, context) => {
    if (!fqn || typeof fqn !== "string") return;
    const [schema, ...rest] = fqn.split(".");
    const table = rest.join(".");
    openTable(schema, table, context);
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
          </div>
        </div>
      </section>

      {viewMode === "window" && (
        <>
          <section className="card analytics-block">
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
              <section className="card analytics-block">
                <div className="section-title">Работа и ожидание</div>
                {filteredWindowRows.length === 0 && <div className="muted">Нет запусков в окне.</div>}
                {filteredWindowRows.length > 0 && (
                  <div className="analytics-bars">
                    {filteredWindowRows.slice(0, 30).map((row, idx) => {
                      const actual = Number(row.actual_duration_min ?? row.duration_min ?? 0);
                      const lag = Number(row.lag_duration_min || 0);
                      const total = actual + lag;
                      const actualWidth = windowMaxDuration
                        ? Math.max(actual > 0 ? 8 : 0, (actual / windowMaxDuration) * 100)
                        : 0;
                      const lagWidth = windowMaxDuration ? (lag / windowMaxDuration) * 100 : 0;
                      const label = `${row.schema_name}.${row.table_name}`;
                      return (
                        <div key={`${label}-${row.run_uuid || idx}`} className="analytics-bar-row">
                          <div className="analytics-bar-label mono" title={label}>
                            <span>{shortenName(label, 44)}</span>
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
                )}
              </section>

              <section className="card analytics-block">
                <div className="section-title">Сущности в окне</div>
                {windowEntitySummary.length === 0 && <div className="muted">Нет данных.</div>}
                {windowEntitySummary.length > 0 && (
                  <div className="analytics-table">
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

              <section className="card analytics-block">
                <div className="section-title">Список запусков в окне</div>
                {filteredWindowRows.length === 0 && <div className="muted">Нет запусков в окне.</div>}
                {filteredWindowRows.length > 0 && (
                  <div className="analytics-table">
                    <div className="analytics-head analytics-window">
                      <span>Таблица</span>
                      <span>Run UUID</span>
                      <span>Сущность</span>
                      <span>Источник</span>
                      <span>Старт</span>
                      <span>Финиш</span>
                      <span>Работа</span>
                      <span>Ожидание</span>
                      <span>Статус</span>
                    </div>
                    {filteredWindowRows.map((row, idx) => {
                      const fullName = `${row.schema_name}.${row.table_name}`;
                      return (
                        <div
                          key={`${fullName}-${row.run_uuid || idx}`}
                          className="analytics-row analytics-window"
                        >
                          <button
                            className="mono analytics-cell-name btn btn-ghost"
                            title={fullName}
                            onClick={() => openTable(row.schema_name, row.table_name)}
                          >
                            {shortenName(fullName, 36)}
                          </button>
                          <span className="mono" title={row.run_uuid || "—"}>
                            {shortenName(row.run_uuid || "—", 18)}
                          </span>
                          <span className="muted analytics-cell-entity" title={row.entity_name || ""}>
                            {shortenName(row.entity_name || "—", 24)}
                          </span>
                          <span className="analytics-pill">{row.source}</span>
                          <span>{formatDateTime(row.start_dttm)}</span>
                          <span>{formatDateTime(row.end_dttm)}</span>
                          <span>{formatMinutes(Number(row.actual_duration_min ?? row.duration_min ?? 0))}</span>
                          <span>{formatMinutes(Number(row.lag_duration_min || 0))}</span>
                          <span>{row.status || "—"}</span>
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
                        <div className="mono slow-night-table" title={row.table_fqn}>{row.table_fqn}</div>
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
                        <div className="mono slow-night-table" title={row.table_fqn}>{row.table_fqn}</div>
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
