import { useEffect, useMemo, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function AnalyticsPage() {
  const [windowDate, setWindowDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [timeFrom, setTimeFrom] = useState("04:30");
  const [timeTo, setTimeTo] = useState("05:00");
  const [source, setSource] = useState("both");
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

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
      })
      .catch((err) => setError(typeof err === "string" ? err : "Не удалось загрузить окно"))
      .finally(() => setLoading(false));
  };

  const maxDuration = useMemo(() => {
    if (!rows.length) return 0;
    return Math.max(...rows.map((r) => Number(r.duration_min || 0)));
  }, [rows]);

  return (
    <div className="page analytics-page compact">
      <div className="page-header">
        <div>
          <h1>Аналитика</h1>
          <div className="muted">Окно загрузок по времени (GP + Click).</div>
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
          <button className="btn btn-secondary" onClick={loadWindowRuns}>
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
            {rows.length === 0 && <div className="muted">Нет запусков в окне.</div>}
            {rows.length > 0 && (
              <div className="analytics-bars">
                {rows.slice(0, 30).map((row, idx) => {
                  const width = maxDuration ? Math.max(8, (Number(row.duration_min || 0) / maxDuration) * 100) : 0;
                  const label = `${row.schema_name}.${row.table_name}`;
                  return (
                    <div key={`${label}-${idx}`} className="analytics-bar-row">
                      <div className="analytics-bar-label mono">{label}</div>
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
            <div className="section-title">Список загрузок</div>
            {rows.length === 0 && <div className="muted">Нет запусков в окне.</div>}
            {rows.length > 0 && (
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
                {rows.map((row, idx) => (
                  <div key={`${row.schema_name}.${row.table_name}-${idx}`} className="analytics-row analytics-window">
                    <span className="mono">{row.schema_name}.{row.table_name}</span>
                    <span className="muted">{row.entity_name || "—"}</span>
                    <span className="analytics-pill">{row.source}</span>
                    <span>{formatDateTime(row.start_dttm)}</span>
                    <span>{formatDateTime(row.end_dttm)}</span>
                    <span>{row.duration_min ?? 0} мин</span>
                    <span className={`status-pill status-${String(row.status || "").toLowerCase()}`}>
                      {row.status || "—"}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </section>
        </div>
      )}
    </div>
  );
}
