import { useEffect, useMemo, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function AnalyticsPage() {
  const [windowDate, setWindowDate] = useState(() => new Date().toISOString().slice(0, 10));
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
    const str = String(value).replace("T", " ").replace("Z", "");
    const match = str.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})/);
    if (match) return `${match[1]} ${match[2]}`;
    return str;
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

  const maxDuration = useMemo(() => {
    if (!rowsFiltered.length) return 0;
    return Math.max(...rowsFiltered.map((r) => Number(r.duration_min || 0)));
  }, [rowsFiltered]);

  const rowsByDuration = useMemo(() => {
    return [...rows].sort((a, b) => (Number(b.duration_min || 0) - Number(a.duration_min || 0)));
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

  const entitySummary = useMemo(() => {
    const map = new Map();
    rowsFiltered.forEach((row) => {
      const key = row.entity_name || "—";
      const item = map.get(key) || { entity: key, tables: new Set(), runs: 0, minutes: 0 };
      item.runs += 1;
      item.minutes += Number(row.duration_min || 0);
      item.tables.add(`${row.schema_name}.${row.table_name}`);
      map.set(key, item);
    });
    return Array.from(map.values())
      .map((item) => ({
        entity: item.entity,
        tables_count: item.tables.size,
        runs_count: item.runs,
        minutes: Math.round(item.minutes * 100) / 100,
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
            <div className="section-title">График длительности</div>
            {rowsFiltered.length === 0 && <div className="muted">Нет запусков в окне.</div>}
            {rowsFiltered.length > 0 && (
              <div className="analytics-bars">
                {rowsFiltered.slice(0, 30).map((row, idx) => {
                  const width = maxDuration ? Math.max(8, (Number(row.duration_min || 0) / maxDuration) * 100) : 0;
                  const label = `${row.schema_name}.${row.table_name}`;
                  return (
                    <div key={`${label}-${idx}`} className="analytics-bar-row">
                      <div className="analytics-bar-label mono" title={label}>
                        <span>{shortenName(label, 44)}</span>
                        <span className="analytics-pill analytics-pill-inline">{row.source}</span>
                      </div>
                      <div className="analytics-bar-track">
                        <div className="analytics-bar-fill" style={{ width: `${width}%` }} />
                      </div>
                      <div className="analytics-bar-value">{row.duration_min ?? 0} мин</div>
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
                  <span>Минут</span>
                </div>
                {entitySummary.slice(0, 20).map((item) => (
                  <div key={item.entity} className="analytics-row analytics-entity">
                    <span className="mono analytics-cell-entity" title={item.entity}>{shortenName(item.entity, 28)}</span>
                    <span>{item.tables_count}</span>
                    <span>{item.runs_count}</span>
                    <span>{item.minutes}</span>
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
                  <span>Сущность</span>
                  <span>Источник</span>
                  <span>Старт</span>
                  <span>Финиш</span>
                  <span>Длит.</span>
                  <span>Статус</span>
                </div>
                {rowsFiltered.map((row, idx) => {
                  const fullName = `${row.schema_name}.${row.table_name}`;
                  return (
                  <div key={`${row.schema_name}.${row.table_name}-${idx}`} className="analytics-row analytics-window">
                    <span className="mono analytics-cell-name" title={fullName}>
                      {shortenName(fullName)}
                    </span>
                    <span className="muted analytics-cell-entity" title={row.entity_name || ""}>
                      {shortenName(row.entity_name || "—", 28)}
                    </span>
                    <span className="analytics-pill">{row.source}</span>
                    <span>{formatDateTime(row.start_dttm)}</span>
                    <span>{formatDateTime(row.end_dttm)}</span>
                    <span>{row.duration_min ?? 0} мин</span>
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
