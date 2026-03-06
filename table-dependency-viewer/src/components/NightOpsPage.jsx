import { useCallback, useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

const DEFAULT_WINDOW_START = "04:30";
const DEFAULT_WINDOW_END = "05:20";
const TIME_RE = /^([01]?\d|2[0-3]):([0-5]\d)$/;
const RANGE_RE = /([01]?\d|2[0-3]):([0-5]\d)\s*[-–—]\s*([01]?\d|2[0-3]):([0-5]\d)/;

function toTablePath(fqn) {
  if (!fqn || !fqn.includes(".")) return null;
  const [schema, ...rest] = fqn.split(".");
  const table = rest.join(".");
  return `/table/${encodeURIComponent(schema)}/${encodeURIComponent(table)}`;
}

function parseMinutes(value) {
  if (!TIME_RE.test(value || "")) return null;
  const [hour, minute] = value.split(":").map(Number);
  return hour * 60 + minute;
}

export default function NightOpsPage() {
  const navigate = useNavigate();

  const [data, setData] = useState(null);
  const [prevData, setPrevData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const [showFailuresOnly, setShowFailuresOnly] = useState(false);
  const [showPeakDetails, setShowPeakDetails] = useState(false);

  const [longestLimit, setLongestLimit] = useState(10);
  const [anomalyLimit, setAnomalyLimit] = useState(10);
  const [failedLimit, setFailedLimit] = useState(10);
  const [peakLimit, setPeakLimit] = useState(10);

  const [heavyWindowStart, setHeavyWindowStart] = useState(DEFAULT_WINDOW_START);
  const [heavyWindowEnd, setHeavyWindowEnd] = useState(DEFAULT_WINDOW_END);
  const [heavyWindowRange, setHeavyWindowRange] = useState(`${DEFAULT_WINDOW_START}-${DEFAULT_WINDOW_END}`);
  const [heavyLimit, setHeavyLimit] = useState(20);
  const [heavySortMode, setHeavySortMode] = useState("heavy_total");
  const [heavyData, setHeavyData] = useState(null);
  const [heavyLoading, setHeavyLoading] = useState(false);
  const [heavyError, setHeavyError] = useState(null);
  const [clickSlow, setClickSlow] = useState([]);
  const [clickSlowLoading, setClickSlowLoading] = useState(false);
  const [clickSlowError, setClickSlowError] = useState(null);
  const [clickFailures, setClickFailures] = useState([]);
  const [clickFailuresLoading, setClickFailuresLoading] = useState(false);
  const [clickFailuresError, setClickFailuresError] = useState(null);
  const [windowDate, setWindowDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [windowSource, setWindowSource] = useState("both");
  const [windowRows, setWindowRows] = useState([]);
  const [windowLoading, setWindowLoading] = useState(false);
  const [windowError, setWindowError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    Promise.all([
      fetch(`${API_BASE}/api/night-summary?days=30&limit=50`),
      fetch(`${API_BASE}/api/night-summary?days=30&limit=50&shift_days=1`),
    ])
      .then(async ([curr, prev]) => {
        if (!curr.ok) throw new Error("Не удалось загрузить ночное окно");
        const currJson = await curr.json();
        const prevJson = prev.ok ? await prev.json() : null;
        if (!cancelled) {
          setData(currJson);
          setPrevData(prevJson);
        }
      })
      .catch((err) => {
        if (!cancelled) setError(typeof err === "string" ? err : "Не удалось загрузить ночное окно");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    setClickSlowLoading(true);
    setClickSlowError(null);
    setClickFailuresLoading(true);
    setClickFailuresError(null);

    Promise.all([
      fetch(`${API_BASE}/api/click/slow-stages?days=7&limit=20`),
      fetch(`${API_BASE}/api/click/summary?days=7&limit=10`),
    ])
      .then(async ([slowResp, failuresResp]) => {
        const slowJson = slowResp.ok ? await slowResp.json() : [];
        const failuresJson = failuresResp.ok ? await failuresResp.json() : {};
        if (!cancelled) {
          setClickSlow(Array.isArray(slowJson) ? slowJson : []);
          setClickFailures(Array.isArray(failuresJson?.failures) ? failuresJson.failures : []);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setClickSlowError("Не удалось загрузить ClickHouse");
          setClickFailuresError("Не удалось загрузить ClickHouse");
        }
      })
      .finally(() => {
        if (!cancelled) {
          setClickSlowLoading(false);
          setClickFailuresLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, []);

  const peakHour = useMemo(() => {
    if (!data?.hourly?.length) return null;
    const sorted = [...data.hourly].sort(
      (a, b) => (b.total_duration_minutes || 0) - (a.total_duration_minutes || 0)
    );
    return sorted[0];
  }, [data]);

  const peakTables = useMemo(() => peakHour?.top_tables || [], [peakHour]);

  const loadHeavyTables = useCallback(async (options = {}) => {
    const start = options.start ?? heavyWindowStart;
    const end = options.end ?? heavyWindowEnd;
    const limit = options.limit ?? heavyLimit;
    const startMinutes = parseMinutes(start);
    const endMinutes = parseMinutes(end);
    if (startMinutes === null || endMinutes === null) {
      setHeavyError("Введите окно в формате HH:MM (например, 04:30)");
      return;
    }

    setHeavyLoading(true);
    setHeavyError(null);

    try {
      const params = new URLSearchParams({
        days: "30",
        limit: String(limit),
        window_start: start,
        window_end: end,
      });
      const resp = await fetch(`${API_BASE}/api/night/heavy-tables?${params.toString()}`);
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const payload = await resp.json();
      setHeavyData(payload);
    } catch (err) {
    setHeavyError(typeof err === "string" ? err : "Не удалось загрузить тяжелые таблицы");
    } finally {
      setHeavyLoading(false);
    }
  }, [heavyWindowStart, heavyWindowEnd, heavyLimit]);

  const loadWindowRuns = useCallback(async () => {
    setWindowLoading(true);
    setWindowError(null);
    try {
      const params = new URLSearchParams({
        date: windowDate,
        from: heavyWindowStart,
        to: heavyWindowEnd,
        source: windowSource,
      });
      const resp = await fetch(`${API_BASE}/api/window-runs?${params.toString()}`);
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const payload = await resp.json();
      const rows = [];
      (payload.gp || []).forEach((row) => rows.push({ ...row, source: "GP" }));
      (payload.click || []).forEach((row) => rows.push({ ...row, source: "ClickHouse" }));
      rows.sort((a, b) => (a.start_dttm || "").localeCompare(b.start_dttm || ""));
      setWindowRows(rows);
    } catch (err) {
      setWindowError(typeof err === "string" ? err : "Не удалось загрузить окно");
    } finally {
      setWindowLoading(false);
    }
  }, [windowDate, heavyWindowStart, heavyWindowEnd, windowSource]);

  useEffect(() => {
    loadHeavyTables();
  }, [loadHeavyTables]);

  useEffect(() => {
    loadWindowRuns();
  }, [loadWindowRuns]);

  const applyWindow = () => {
    const match = heavyWindowRange.trim().match(RANGE_RE);
    if (match) {
      const start = `${match[1].padStart(2, "0")}:${match[2]}`;
      const end = `${match[3].padStart(2, "0")}:${match[4]}`;
      setHeavyWindowStart(start);
      setHeavyWindowEnd(end);
      loadHeavyTables({ start, end });
      loadWindowRuns();
      return;
    }
    loadHeavyTables();
    loadWindowRuns();
  };

  const applyPeakPreset = () => {
    if (!peakHour) return;
    const hour = String(peakHour.hour).padStart(2, "0");
    setHeavyWindowStart(`${hour}:00`);
    setHeavyWindowEnd(`${hour}:59`);
    setHeavyWindowRange(`${hour}:00-${hour}:59`);
  };

  const heavyRows = useMemo(() => {
    const rows = Array.isArray(heavyData?.rows) ? [...heavyData.rows] : [];
    if (heavySortMode === "long_max") {
      rows.sort((a, b) => (b.max_duration_minutes || 0) - (a.max_duration_minutes || 0));
      return rows;
    }
    rows.sort((a, b) => (b.total_duration_minutes || 0) - (a.total_duration_minutes || 0));
    return rows;
  }, [heavyData, heavySortMode]);

  return (
    <div className="container cc-page">
      <section className="cc-header-zone">
        <button className="btn" onClick={() => navigate("/")}>← Назад</button>
        <h1>Ночное окно</h1>
        <div className="cc-subtitle">Источник: GP · Сводка за последнее ночное окно (21:00–08:00)</div>
      </section>

      {loading && <div className="muted">Загрузка ночного окна...</div>}
      {error && <div className="dep-error-title">{error}</div>}

      {!loading && !error && data && (
        <>
          <section className="cc-surface">
            <div className="section-title">Ключевые показатели</div>
            <div className="night-kpis">
              <div className="night-kpi-card">
                <div className="night-kpi-label">Запусков</div>
                <div className="night-kpi-value">{data.summary?.runs_count ?? 0}</div>
                {prevData && <div className="night-kpi-delta">Вчера: {prevData.summary?.runs_count ?? 0}</div>}
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Таблиц</div>
                <div className="night-kpi-value">{data.summary?.tables_count ?? 0}</div>
                {prevData && <div className="night-kpi-delta">Вчера: {prevData.summary?.tables_count ?? 0}</div>}
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Сущностей</div>
                <div className="night-kpi-value">{data.summary?.entities_count ?? 0}</div>
                {prevData && <div className="night-kpi-delta">Вчера: {prevData.summary?.entities_count ?? 0}</div>}
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Суммарно</div>
                <div className="night-kpi-value">{data.summary?.total_duration_minutes ?? 0} мин</div>
                {prevData && (
                  <div className="night-kpi-delta">Вчера: {prevData.summary?.total_duration_minutes ?? 0} мин</div>
                )}
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Пик</div>
                <div className="night-kpi-value">
                  {peakHour ? `${String(peakHour.hour).padStart(2, "0")}:00` : "—"}
                </div>
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Падения</div>
                <div className="night-kpi-value">{data.failed_summary?.runs_count ?? 0}</div>
                {prevData && <div className="night-kpi-delta">Вчера: {prevData.failed_summary?.runs_count ?? 0}</div>}
              </div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Фокус на пиковое окно</div>
            <div className="night-window-controls">
              <label className="night-window-label">
                Дата
                <input
                  className="night-window-input"
                  type="date"
                  value={windowDate}
                  onChange={(e) => setWindowDate(e.target.value)}
                />
              </label>
              <label className="night-window-label">
                Начало
                <input
                  className="night-window-input"
                  value={heavyWindowStart}
                  onChange={(e) => {
                    setHeavyWindowStart(e.target.value);
                    setHeavyWindowRange(`${e.target.value}-${heavyWindowEnd}`);
                  }}
                  placeholder="04:30"
                />
              </label>
              <label className="night-window-label">
                Конец
                <input
                  className="night-window-input"
                  value={heavyWindowEnd}
                  onChange={(e) => {
                    setHeavyWindowEnd(e.target.value);
                    setHeavyWindowRange(`${heavyWindowStart}-${e.target.value}`);
                  }}
                  placeholder="05:20"
                />
              </label>
              <label className="night-window-label">
                Интервал
                <input
                  className="night-window-input night-window-input-wide"
                  value={heavyWindowRange}
                  onChange={(e) => setHeavyWindowRange(e.target.value)}
                  placeholder="04:30-05:20"
                />
              </label>
              <label className="night-window-label">
                Источник
                <select
                  className="night-window-select"
                  value={windowSource}
                  onChange={(e) => setWindowSource(e.target.value)}
                >
                  <option value="both">GP + Click</option>
                  <option value="gp">Только GP</option>
                  <option value="click">Только Click</option>
                </select>
              </label>
              <label className="night-window-label">
                TOP
                <select
                  className="night-window-select"
                  value={heavyLimit}
                  onChange={(e) => setHeavyLimit(Number(e.target.value))}
                >
                  {[10, 20, 30, 50].map((n) => (
                    <option key={n} value={n}>{n}</option>
                  ))}
                </select>
              </label>
              <label className="night-window-label">
                Сортировка
                <select
                  className="night-window-select"
                  value={heavySortMode}
                  onChange={(e) => setHeavySortMode(e.target.value)}
                >
                  <option value="heavy_total">Тяжелые (сумма)</option>
                  <option value="long_max">Долгие (макс)</option>
                </select>
              </label>
              <div className="night-window-actions">
                <button className="btn btn-secondary" onClick={applyWindow} disabled={heavyLoading}>
                  {heavyLoading ? "Загрузка..." : "Применить"}
                </button>
                <button
                  className="btn btn-ghost"
                  onClick={() => {
                    setHeavyWindowStart(DEFAULT_WINDOW_START);
                    setHeavyWindowEnd(DEFAULT_WINDOW_END);
                    setHeavyWindowRange(`${DEFAULT_WINDOW_START}-${DEFAULT_WINDOW_END}`);
                  }}
                >
                  04:30–05:20
                </button>
                <button className="btn btn-ghost" onClick={applyPeakPreset} disabled={!peakHour}>
                  Использовать пик
                </button>
              </div>
            </div>

            {heavyError && <div className="dep-error-title" style={{ marginTop: 10 }}>{heavyError}</div>}

            {heavyData && (
              <div className="night-window-summary">
                <span>Запусков: <strong>{heavyData.summary?.runs_count ?? 0}</strong></span>
                <span>Таблиц: <strong>{heavyData.summary?.tables_count ?? 0}</strong></span>
                <span>Сумма: <strong>{heavyData.summary?.total_duration_minutes ?? 0} мин</strong></span>
                <span>Макс: <strong>{heavyData.summary?.max_duration_minutes ?? 0} мин</strong></span>
              </div>
            )}
          </section>

          <section className="cc-surface">
            <div className="section-title night-controls">
              <span>Детализация</span>
              <label className="night-toggle">
                <input
                  type="checkbox"
                  checked={showFailuresOnly}
                  onChange={(e) => setShowFailuresOnly(e.target.checked)}
                />
                Только ошибки
              </label>
            </div>

            <div className="night-columns">
              {!showFailuresOnly && (
                <div className="night-panel">
                  <div className="night-panel-title">Окно загрузок (GP/Click)</div>
                  <div className="night-panel-sub muted">
                    {windowDate} · {heavyWindowStart}–{heavyWindowEnd} · {windowSource}
                  </div>
                  <div className="night-window-table">
                    <div className="night-window-head">
                      <span>Таблица</span>
                      <span>Сущность</span>
                      <span>Источник</span>
                      <span>Старт</span>
                      <span>Финиш</span>
                      <span>Длит.</span>
                      <span>Статус</span>
                    </div>
                    {windowLoading && <div className="muted">Загрузка...</div>}
                    {windowError && <div className="dep-error-title">{windowError}</div>}
                    {!windowLoading && !windowError && windowRows.length === 0 && (
                      <div className="muted">Таблиц нет.</div>
                    )}
                    {!windowLoading && !windowError && windowRows.map((row, idx) => (
                      <button
                        key={`${row.schema_name}.${row.table_name}-${row.start_dttm}-${idx}`}
                        className="night-window-row"
                        onClick={() => {
                          const fqn = `${row.schema_name}.${row.table_name}`;
                          const path = toTablePath(fqn);
                          if (path) navigate(path);
                        }}
                      >
                        <span className="mono">{row.schema_name}.{row.table_name}</span>
                        <span className="muted">{row.entity_name || "—"}</span>
                        <span className="night-pill">{row.source}</span>
                        <span>{row.start_dttm || "—"}</span>
                        <span>{row.end_dttm || "—"}</span>
                        <span>{row.duration_min ?? 0} мин</span>
                        <span className={`status-pill status-${String(row.status || "").toLowerCase()}`}>
                          {row.status || "—"}
                        </span>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {!showFailuresOnly && (
                <div className="night-panel">
                  <div className="night-panel-title">Самые долгие</div>
                  <div className="night-panel-sub muted">Топ-10 по длительности</div>
                  <div className="night-list">
                    {(data.top_runs || []).slice(0, longestLimit).map((row) => (
                      <button
                        key={`${row.table_fqn}-${row.start}`}
                        className="night-row"
                        onClick={() => {
                          const path = toTablePath(row.table_fqn);
                          if (path) navigate(path);
                        }}
                      >
                        <span className="mono">{row.table_fqn}</span>
                        <span className="muted">
                          {row.entity_name || "—"} · ID {row.table_id ?? "—"} · {row.duration_minutes ?? "—"} мин
                        </span>
                      </button>
                    ))}
                  </div>
                  {(data.top_runs || []).length > 10 && (
                    <div className="night-panel-actions">
                      <button className="btn btn-ghost" onClick={() => setLongestLimit((n) => Math.min(n + 10, (data.top_runs || []).length))}>
                        Показать +10
                      </button>
                      <button className="btn btn-ghost" onClick={() => setLongestLimit(10)}>
                        Сброс
                      </button>
                    </div>
                  )}
                </div>
              )}

              {!showFailuresOnly && (
                <div className="night-panel">
                  <div className="night-panel-title">Аномалии vs p95</div>
                  <div className="night-panel-sub muted">Запуски &gt; 1.5× p95</div>
                  <div className="night-list">
                    {(data.anomalies || []).slice(0, anomalyLimit).map((row) => (
                      <button
                        key={`${row.table_fqn}-${row.start}`}
                        className="night-row"
                        onClick={() => {
                          const path = toTablePath(row.table_fqn);
                          if (path) navigate(path);
                        }}
                      >
                        <span className="mono">{row.table_fqn}</span>
                        <span className="muted">
                          {row.entity_name || "—"} · ID {row.table_id ?? "—"} · {row.duration_minutes ?? "—"} мин · {row.ratio ?? "—"}x
                        </span>
                      </button>
                    ))}
                  </div>
                  {(data.anomalies || []).length > 10 && (
                    <div className="night-panel-actions">
                      <button className="btn btn-ghost" onClick={() => setAnomalyLimit((n) => Math.min(n + 10, (data.anomalies || []).length))}>
                        Показать +10
                      </button>
                      <button className="btn btn-ghost" onClick={() => setAnomalyLimit(10)}>
                        Сброс
                      </button>
                    </div>
                  )}
                </div>
              )}

              {!showFailuresOnly && (
                <div className="night-panel">
                  <div className="night-panel-title">Таблицы пикового часа</div>
                  <div className="night-panel-sub muted">
                    {peakHour ? `Пик в ${String(peakHour.hour).padStart(2, "0")}:00` : "Нет данных по пику"}
                  </div>
                  <div className="night-list">
                    {peakTables.slice(0, peakLimit).map((row) => (
                      <button
                        key={`${row.table_fqn}-${row.duration_minutes}-${row.entity_name}`}
                        className="night-row"
                        onClick={() => {
                          const path = toTablePath(row.table_fqn);
                          if (path) navigate(path);
                        }}
                      >
                        <span className="mono">{row.table_fqn}</span>
                        <span className="muted">
                          {row.entity_name || "—"} · ID {row.table_id ?? "—"} · {row.duration_minutes ?? "—"} мин
                        </span>
                      </button>
                    ))}
                    {!peakTables.length && <div className="muted">Таблиц в пике нет.</div>}
                  </div>
                  {peakTables.length > 10 && (
                    <div className="night-panel-actions">
                      <button className="btn btn-ghost" onClick={() => setPeakLimit((n) => Math.min(n + 10, peakTables.length))}>
                        Показать +10
                      </button>
                      <button className="btn btn-ghost" onClick={() => setPeakLimit(10)}>
                        Сброс
                      </button>
                    </div>
                  )}
                  {peakTables.length > 0 && (
                    <div className="night-panel-actions">
                      <button className="btn btn-secondary" onClick={() => setShowPeakDetails(true)}>
                        Почему пик?
                      </button>
                    </div>
                  )}
                </div>
              )}

              <div className="night-panel">
                <div className="night-panel-title">Ошибки</div>
                <div className="night-panel-sub muted">Последние ошибки в окне</div>
                <div className="night-list">
                  {(data.failed_runs || []).slice(0, failedLimit).map((row) => (
                    <button
                      key={`${row.table_fqn}-${row.start}`}
                      className="night-row"
                      onClick={() => {
                        const path = toTablePath(row.table_fqn);
                        if (path) navigate(path);
                      }}
                    >
                      <span className="mono">{row.table_fqn}</span>
                      <span className="muted">
                        {row.entity_name || "—"} · ID {row.table_id ?? "—"} · {row.message || "FAILED"}
                      </span>
                    </button>
                  ))}
                </div>
                {(data.failed_runs || []).length > 10 && (
                  <div className="night-panel-actions">
                    <button className="btn btn-ghost" onClick={() => setFailedLimit((n) => Math.min(n + 10, (data.failed_runs || []).length))}>
                      Показать +10
                    </button>
                    <button className="btn btn-ghost" onClick={() => setFailedLimit(10)}>
                      Сброс
                    </button>
                  </div>
                )}
              </div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">ClickHouse (S3/Click) — 7 дней</div>
            <div className="night-columns">
              <div className="night-panel">
                <div className="night-panel-title">Долгие этапы</div>
                <div className="night-panel-sub muted">Топ-20 по длительности</div>
                {clickSlowLoading && <div className="muted">Загрузка...</div>}
                {clickSlowError && <div className="dep-error-title">{clickSlowError}</div>}
                {!clickSlowLoading && !clickSlowError && (
                  <div className="night-list">
                    {clickSlow.map((row, idx) => (
                      <button
                        key={`${row.schema_name}.${row.table_name}-${idx}`}
                        className="night-row"
                        onClick={() => {
                          const path = toTablePath(`${row.schema_name}.${row.table_name}`);
                          if (path) navigate(path);
                        }}
                      >
                        <span className="mono">{row.schema_name}.{row.table_name}</span>
                        <span className="muted">
                          {row.stage_name} · {row.duration_min ?? "—"} мин · {row.status || "—"}
                        </span>
                      </button>
                    ))}
                    {!clickSlow.length && <div className="muted">Долгих этапов нет.</div>}
                  </div>
                )}
              </div>

              <div className="night-panel">
                <div className="night-panel-title">Ошибки ClickHouse</div>
                <div className="night-panel-sub muted">Последние неуспешные запуски</div>
                {clickFailuresLoading && <div className="muted">Загрузка...</div>}
                {clickFailuresError && <div className="dep-error-title">{clickFailuresError}</div>}
                {!clickFailuresLoading && !clickFailuresError && (
                  <div className="night-list">
                    {clickFailures.map((row, idx) => (
                      <button
                        key={`${row.schema_name}.${row.table_name}-${idx}`}
                        className="night-row"
                        onClick={() => {
                          const path = toTablePath(`${row.schema_name}.${row.table_name}`);
                          if (path) navigate(path);
                        }}
                      >
                        <span className="mono">{row.schema_name}.{row.table_name}</span>
                        <span className="muted">
                          {row.problem_area ? `Проблема: ${row.problem_area}` : "Проблема: —"} · {row.status || "—"}
                        </span>
                      </button>
                    ))}
                    {!clickFailures.length && <div className="muted">Ошибок нет.</div>}
                  </div>
                )}
              </div>
            </div>
          </section>
        </>
      )}

      {showPeakDetails && peakHour && (
        <div className="night-modal" onClick={() => setShowPeakDetails(false)}>
          <div className="night-modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="night-modal-head">
              <div>
                <div className="night-panel-title">Детали пикового часа</div>
                <div className="night-panel-sub muted">
                  {String(peakHour.hour).padStart(2, "0")}:00 · {peakHour.runs_count ?? 0} запусков · {peakHour.total_duration_minutes ?? 0} мин
                </div>
              </div>
              <button className="btn btn-ghost" onClick={() => setShowPeakDetails(false)}>
                Закрыть
              </button>
            </div>
            <div className="night-list">
              {peakTables.map((row) => (
                <div key={`${row.table_fqn}-${row.duration_minutes}-${row.entity_name}`} className="night-row">
                  <span className="mono">{row.table_fqn}</span>
                  <span className="muted">
                    {row.entity_name || "—"} · ID {row.table_id ?? "—"} · {row.duration_minutes ?? "—"} мин
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
