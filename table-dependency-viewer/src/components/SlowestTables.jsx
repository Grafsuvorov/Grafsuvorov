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

  const sorted = useMemo(() => tables, [tables]);

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
        <h1>Медленные и нестабильные таблицы</h1>
        <div className="cc-subtitle">
          Мониторинг длительных и нестабильных запусков (успешные).
        </div>
      </section>

      {periodLabel && (
        <div className="cc-header-meta">
          <span className="period-pill">Период: {periodLabel}</span>
          <span className="period-note">по логам</span>
        </div>
      )}

      <section className="slow-summary">
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
      </section>

      <section className="slow-controls">
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
      </section>

      <section className="slow-criteria">
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
      </section>

      <section className="slow-profile">
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
      </section>

      <section className="slow-night">
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
      </section>

      <section className="slow-entity">
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
      </section>

      {loading && <div className="page-loading">Загрузка метрик...</div>}
      {error && <div className="page-error">{error}</div>}

      {!loading && !error && sorted.length === 0 && (
        <div className="card muted">Нет данных по успешным загрузкам.</div>
      )}

      {!loading && !error && sorted.length > 0 && (
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
