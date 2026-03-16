import { useEffect, useMemo, useState } from "react";
import "../style/app.css";
import { formatDateInputValue, formatLocalDateTime } from "../utils/datetime.js";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function AnalyticsPage() {
  const [windowDate, setWindowDate] = useState(() => formatDateInputValue());
  const [timeFrom, setTimeFrom] = useState("04:30");
  const [timeTo, setTimeTo] = useState("05:00");
  const [source, setSource] = useState("both");
  const [entityFilter, setEntityFilter] = useState("all");
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const shortenName = (value, max = 38) => {
    if (!value) return "—";
    if (value.length <= max) return value;
    const head = value.slice(0, Math.max(12, Math.floor(max * 0.6)));
    const tail = value.slice(-Math.max(8, Math.floor(max * 0.3)));
    return `${head}…${tail}`;
  };

  useEffect(() => {
    loadWindowRuns();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const formatDateTime = (value) => {
    if (!value) return "—";
    return formatLocalDateTime(value, { withSeconds: false });
  };

  const formatMinutes = (value) => {
    if (value === null || value === undefined) return "—";
    return `${value} мин`;
  };

  const loadWindowRuns = () => {
    setLoading(true);
    setError(null);
    const params = new URLSearchParams({
      date: windowDate,
      from: timeFrom,
      to: timeTo,
      source,
    });
    fetch(`${API_BASE}/api/window-runs?${params.toString()}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить окно")))
      .then((data) => {
        const merged = [];
        (data.gp || []).forEach((row) => merged.push({ ...row, source: "GP" }));
        (data.click || []).forEach((row) => merged.push({ ...row, source: "ClickHouse" }));
        merged.sort((a, b) => (a.start_dttm || "").localeCompare(b.start_dttm || ""));
        setRows(merged);
        setEntityFilter("all");
      })
      .catch((err) => setError(typeof err === "string" ? err : "Не удалось загрузить окно"))
      .finally(() => setLoading(false));
  };

  const rowsByDuration = useMemo(() => {
    return [...rows].sort((a, b) => (Number(b.actual_duration_min ?? b.duration_min ?? 0) - Number(a.actual_duration_min ?? a.duration_min ?? 0)));
  }, [rows]);

  const entityOptions = useMemo(() => {
    const set = new Set();
    rows.forEach((row) => {
      if (row.entity_name) set.add(row.entity_name);
    });
    return Array.from(set).sort((a, b) => a.localeCompare(b, "ru"));
  }, [rows]);

  const rowsFiltered = useMemo(() => {
    if (!rows.length) return [];
    if (entityFilter === "all") return rowsByDuration;
    return rowsByDuration.filter((row) => row.entity_name === entityFilter);
  }, [rowsByDuration, entityFilter]);

  const maxDuration = useMemo(() => {
    if (!rowsFiltered.length) return 0;
    return Math.max(...rowsFiltered.map((r) => Number(r.actual_duration_min ?? r.duration_min ?? 0) + Number(r.lag_duration_min || 0)));
  }, [rowsFiltered]);

  const entitySummary = useMemo(() => {
    const map = new Map();
    rowsFiltered.forEach((row) => {
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
  }, [rowsFiltered]);

  return (
    <div className="page analytics-page compact">
      <div className="page-header analytics-header">
        <div>
          <h1>Загрузки</h1>
          <div className="muted analytics-subtitle">Окно загрузок по времени (GP + Click).</div>
        </div>
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
              value={source}
              onChange={(e) => setSource(e.target.value)}
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
              value={entityFilter}
              onChange={(e) => setEntityFilter(e.target.value)}
            >
              <option value="all">Все сущности</option>
              {entityOptions.map((entity) => (
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

      {loading && <div className="muted">Загрузка аналитики...</div>}
      {error && <div className="dep-error-title">{error}</div>}

      {!loading && !error && (
        <div className="analytics-grid">
          <section className="card analytics-block">
            <div className="section-title">Работа и ожидание</div>
            {rowsFiltered.length === 0 && <div className="muted">Нет запусков в окне.</div>}
            {rowsFiltered.length > 0 && (
              <div className="analytics-bars">
                {rowsFiltered.slice(0, 30).map((row, idx) => {
                  const actual = Number(row.actual_duration_min ?? row.duration_min ?? 0);
                  const lag = Number(row.lag_duration_min || 0);
                  const total = actual + lag;
                  const actualWidth = maxDuration ? Math.max(actual > 0 ? 8 : 0, (actual / maxDuration) * 100) : 0;
                  const lagWidth = maxDuration ? (lag / maxDuration) * 100 : 0;
                  const label = `${row.schema_name}.${row.table_name}`;
                  return (
                    <div key={`${label}-${idx}`} className="analytics-bar-row">
                      <div className="analytics-bar-label mono" title={label}>
                        <span>{shortenName(label, 44)}</span>
                        <span className="analytics-pill analytics-pill-inline">{row.source}</span>
                      </div>
                      <div className="analytics-bar-track" title={row.source === "ClickHouse" ? `Работа ${actual} мин, ожидание ${lag} мин, окно ${total} мин` : `Работа ${actual} мин`}>
                        <div className="analytics-bar-fill" style={{ width: `${actualWidth}%` }} />
                        {row.source === "ClickHouse" && lag > 0 && (
                          <div className="analytics-bar-lag" style={{ left: `${actualWidth}%`, width: `${lagWidth}%` }} />
                        )}
                      </div>
                      <div className="analytics-bar-value">
                        {row.source === "ClickHouse" ? `${actual} работа / ${lag} ожидание` : formatMinutes(actual)}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </section>

          <section className="card analytics-block">
            <div className="section-title">Сущности в окне</div>
            {entitySummary.length === 0 && <div className="muted">Нет данных.</div>}
            {entitySummary.length > 0 && (
              <div className="analytics-table">
                <div className="analytics-head analytics-entity">
                  <span>Сущность</span>
                  <span>Таблиц</span>
                  <span>Запусков</span>
                  <span>Работа</span>
                  <span>Ожидание</span>
                </div>
                {entitySummary.slice(0, 20).map((item) => (
                  <div key={item.entity} className="analytics-row analytics-entity">
                    <span className="mono analytics-cell-entity" title={item.entity}>{shortenName(item.entity, 28)}</span>
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
            <div className="section-title">Список загрузок</div>
            {rowsFiltered.length === 0 && <div className="muted">Нет запусков в окне.</div>}
            {rowsFiltered.length > 0 && (
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
                {rowsFiltered.map((row, idx) => {
                  const fullName = `${row.schema_name}.${row.table_name}`;
                  return (
                  <div key={`${row.schema_name}.${row.table_name}-${row.run_uuid || idx}`} className="analytics-row analytics-window">
                    <span className="mono analytics-cell-name" title={fullName}>
                      {shortenName(fullName)}
                    </span>
                    <span className="mono" title={row.run_uuid || ""}>
                      {shortenName(row.run_uuid || "—", 18)}
                    </span>
                    <span className="muted analytics-cell-entity" title={row.entity_name || ""}>
                      {shortenName(row.entity_name || "—", 28)}
                    </span>
                    <span className="analytics-pill">{row.source}</span>
                    <span>{formatDateTime(row.start_dttm)}</span>
                    <span>{formatDateTime(row.end_dttm)}</span>
                    <span>{formatMinutes(row.actual_duration_min ?? row.duration_min ?? 0)}</span>
                    <span>{row.source === "ClickHouse" ? formatMinutes(row.lag_duration_min ?? 0) : "—"}</span>
                    <span className={`status-pill status-${String(row.status || "").toLowerCase()}`}>
                      {row.status || "—"}
                    </span>
                  </div>
                  );
                })}
              </div>
            )}
          </section>
        </div>
      )}
    </div>
  );
}
