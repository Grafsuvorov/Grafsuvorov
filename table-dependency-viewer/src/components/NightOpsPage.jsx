import { useCallback, useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import "../style/app.css";
import { nightOpsApi } from "../api/nightOps.js";

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

function TableLinkRow({ children, fqn, onOpen }) {
  return (
    <button className="night-row" onClick={() => onOpen(fqn)}>
      {children}
    </button>
  );
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
  const [extrasReady, setExtrasReady] = useState(false);

  const openTable = useCallback((fqn) => {
    const path = toTablePath(fqn);
    if (path) navigate(path);
  }, [navigate]);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    Promise.all([
      nightOpsApi.summary(30, 50, 0),
      nightOpsApi.summary(30, 50, 1),
    ])
      .then(([currJson, prevJson]) => {
        if (!cancelled) {
          setData(currJson);
          setPrevData(prevJson);
          setExtrasReady(true);
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
    if (!extrasReady) return () => {
      cancelled = true;
    };

    setClickSlowLoading(true);
    setClickSlowError(null);
    setClickFailuresLoading(true);
    setClickFailuresError(null);

    const timer = window.setTimeout(() => {
      Promise.all([nightOpsApi.clickSlowStages(7, 20), nightOpsApi.clickSummary(7, 10)])
        .then(([slowJson, failuresJson]) => {
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
    }, 150);

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [extrasReady]);

  const peakHour = useMemo(() => {
    if (!data?.hourly?.length) return null;
    return [...data.hourly].sort(
      (a, b) => (b.total_duration_minutes || 0) - (a.total_duration_minutes || 0),
    )[0];
  }, [data]);

  const peakTables = useMemo(() => peakHour?.top_tables || [], [peakHour]);

  const loadHeavyTables = useCallback(async (options = {}) => {
    const start = options.start ?? heavyWindowStart;
    const end = options.end ?? heavyWindowEnd;
    const limit = options.limit ?? heavyLimit;
    const startMinutes = parseMinutes(start);
    const endMinutes = parseMinutes(end);
    if (startMinutes === null || endMinutes === null) {
      setHeavyError("Введите окно в формате HH:MM, например 04:30-05:20");
      return;
    }

    setHeavyLoading(true);
    setHeavyError(null);

    try {
      const payload = await nightOpsApi.heavyTables({
        days: 30,
        limit,
        windowStart: start,
        windowEnd: end,
      });
      setHeavyData(payload);
    } catch (err) {
      setHeavyError(typeof err === "string" ? err : "Не удалось загрузить тяжелые таблицы");
    } finally {
      setHeavyLoading(false);
    }
  }, [heavyWindowStart, heavyWindowEnd, heavyLimit]);

  useEffect(() => {
    if (!extrasReady) return;
    const timer = window.setTimeout(() => {
      loadHeavyTables();
    }, 250);
    return () => window.clearTimeout(timer);
  }, [loadHeavyTables, extrasReady]);

  const applyWindow = () => {
    const match = heavyWindowRange.trim().match(RANGE_RE);
    if (match) {
      const start = `${match[1].padStart(2, "0")}:${match[2]}`;
      const end = `${match[3].padStart(2, "0")}:${match[4]}`;
      setHeavyWindowStart(start);
      setHeavyWindowEnd(end);
      loadHeavyTables({ start, end });
      return;
    }
    loadHeavyTables();
  };

  const applyPeakPreset = () => {
    if (!peakHour) return;
    const hour = String(peakHour.hour).padStart(2, "0");
    const start = `${hour}:00`;
    const end = `${hour}:59`;
    setHeavyWindowStart(start);
    setHeavyWindowEnd(end);
    setHeavyWindowRange(`${start}-${end}`);
    loadHeavyTables({ start, end });
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
        <h1>Мониторинг ночного окна</h1>
        <div className="cc-subtitle">GP и ClickHouse в одном рабочем экране: пик, ошибки и самые тяжелые загрузки.</div>
      </section>

      {loading && <div className="muted">Загрузка ночного окна...</div>}
      {error && <div className="dep-error-title">{error}</div>}

      {!loading && !error && data && (
        <>
          <section className="cc-surface">
            <div className="section-title">Сводка ночи</div>
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
                {prevData && <div className="night-kpi-delta">Вчера: {prevData.summary?.total_duration_minutes ?? 0} мин</div>}
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Пиковый час</div>
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
            <div className="section-title">Рабочее окно анализа</div>
            <div className="muted" style={{ marginBottom: 12 }}>
              Выбери интервал, в котором нужно понять, что заняло окно и какие таблицы стали узким местом.
            </div>
            <div className="night-window-controls">
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
                    loadHeavyTables({ start: DEFAULT_WINDOW_START, end: DEFAULT_WINDOW_END });
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

            <div className="night-monitor-grid" style={{ marginTop: 16 }}>
              <div className="night-panel">
                <div className="night-panel-title">Тяжелые таблицы в окне</div>
                <div className="night-panel-sub muted">
                  {heavyData ? `${heavyData.window?.start}–${heavyData.window?.end}` : "Окно не загружено"}
                </div>
                <div className="night-list">
                  {heavyRows.map((row) => (
                    <TableLinkRow
                      key={`${row.table_fqn}-${row.total_duration_minutes}-${row.runs_count}`}
                      fqn={row.table_fqn}
                      onOpen={openTable}
                    >
                      <span className="mono">{row.table_fqn}</span>
                      <span className="muted">
                        {row.entity_name || "—"} · ID {row.table_id ?? "—"} · Σ {row.total_duration_minutes ?? "—"} мин · max {row.max_duration_minutes ?? "—"} мин · запусков {row.runs_count ?? 0}
                      </span>
                    </TableLinkRow>
                  ))}
                  {!heavyLoading && !heavyRows.length && <div className="muted">Тяжелых таблиц нет.</div>}
                </div>
              </div>

              <div className="night-panel">
                <div className="night-panel-title">Пиковый час</div>
                <div className="night-panel-sub muted">
                  {peakHour ? `Пик в ${String(peakHour.hour).padStart(2, "0")}:00` : "Нет данных по пику"}
                </div>
                <div className="night-focus-cards">
                  <div className="night-focus-card">
                    <span className="night-focus-label">Запусков</span>
                    <strong>{peakHour?.runs_count ?? 0}</strong>
                  </div>
                  <div className="night-focus-card">
                    <span className="night-focus-label">Длительность</span>
                    <strong>{peakHour?.total_duration_minutes ?? 0} мин</strong>
                  </div>
                </div>
                <div className="night-list">
                  {peakTables.slice(0, peakLimit).map((row) => (
                    <TableLinkRow
                      key={`${row.table_fqn}-${row.duration_minutes}-${row.entity_name}`}
                      fqn={row.table_fqn}
                      onOpen={openTable}
                    >
                      <span className="mono">{row.table_fqn}</span>
                      <span className="muted">
                        {row.entity_name || "—"} · ID {row.table_id ?? "—"} · {row.duration_minutes ?? "—"} мин
                      </span>
                    </TableLinkRow>
                  ))}
                  {!peakTables.length && <div className="muted">Таблиц в пике нет.</div>}
                </div>
                {peakTables.length > 0 && (
                  <div className="night-panel-actions">
                    <button className="btn btn-secondary" onClick={() => setShowPeakDetails(true)}>
                      Детали пика
                    </button>
                  </div>
                )}
              </div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title night-controls">
              <span>Проблемные зоны</span>
              <label className="night-toggle">
                <input
                  type="checkbox"
                  checked={showFailuresOnly}
                  onChange={(e) => setShowFailuresOnly(e.target.checked)}
                />
                Только ошибки
              </label>
            </div>
            <div className="night-monitor-grid">
              {!showFailuresOnly && (
                <div className="night-panel">
                  <div className="night-panel-title">Самые долгие GP-загрузки</div>
                  <div className="night-panel-sub muted">Топ за последние 30 дней</div>
                  <div className="night-list">
                    {(data.top_runs || []).slice(0, longestLimit).map((row) => (
                      <TableLinkRow key={`${row.table_fqn}-${row.start}`} fqn={row.table_fqn} onOpen={openTable}>
                        <span className="mono">{row.table_fqn}</span>
                        <span className="muted">
                          {row.entity_name || "—"} · ID {row.table_id ?? "—"} · {row.duration_minutes ?? "—"} мин
                        </span>
                      </TableLinkRow>
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
                  <div className="night-panel-title">Аномалии относительно p95</div>
                  <div className="night-panel-sub muted">Запуски выше 1.5× исторического p95</div>
                  <div className="night-list">
                    {(data.anomalies || []).slice(0, anomalyLimit).map((row) => (
                      <TableLinkRow key={`${row.table_fqn}-${row.start}`} fqn={row.table_fqn} onOpen={openTable}>
                        <span className="mono">{row.table_fqn}</span>
                        <span className="muted">
                          {row.entity_name || "—"} · ID {row.table_id ?? "—"} · {row.duration_minutes ?? "—"} мин · {row.ratio ?? "—"}x
                        </span>
                      </TableLinkRow>
                    ))}
                    {!(data.anomalies || []).length && <div className="muted">Аномалий не найдено.</div>}
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

              <div className="night-panel">
                <div className="night-panel-title">Ошибки GP</div>
                <div className="night-panel-sub muted">Последние неуспешные загрузки</div>
                <div className="night-list">
                  {(data.failed_runs || []).slice(0, failedLimit).map((row) => (
                    <TableLinkRow key={`${row.table_fqn}-${row.start}`} fqn={row.table_fqn} onOpen={openTable}>
                      <span className="mono">{row.table_fqn}</span>
                      <span className="muted">
                        {row.entity_name || "—"} · ID {row.table_id ?? "—"} · {row.message || "FAILED"}
                      </span>
                    </TableLinkRow>
                  ))}
                  {!(data.failed_runs || []).length && <div className="muted">Ошибок GP нет.</div>}
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

              <div className="night-panel">
                <div className="night-panel-title">Ошибки ClickHouse</div>
                <div className="night-panel-sub muted">Последние неуспешные запуски</div>
                {clickFailuresLoading && <div className="muted">Загрузка...</div>}
                {clickFailuresError && <div className="dep-error-title">{clickFailuresError}</div>}
                {!clickFailuresLoading && !clickFailuresError && (
                  <div className="night-list">
                    {clickFailures.map((row, idx) => (
                      <TableLinkRow key={`${row.schema_name}.${row.table_name}-${idx}`} fqn={`${row.schema_name}.${row.table_name}`} onOpen={openTable}>
                        <span className="mono">{row.schema_name}.{row.table_name}</span>
                        <span className="muted">
                          {row.problem_area ? `Проблема: ${row.problem_area}` : "Проблема: —"} · {row.status || "—"}
                        </span>
                      </TableLinkRow>
                    ))}
                    {!clickFailures.length && <div className="muted">Ошибок ClickHouse нет.</div>}
                  </div>
                )}
              </div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">ClickHouse: долгие этапы (7 дней)</div>
            <div className="muted" style={{ marginBottom: 12 }}>
              Этот блок нужен для разбора внутренних задержек в S3/ClickHouse, когда сама загрузка не упала, но окно все равно расползлось.
            </div>
            <div className="night-panel">
              {clickSlowLoading && <div className="muted">Загрузка...</div>}
              {clickSlowError && <div className="dep-error-title">{clickSlowError}</div>}
              {!clickSlowLoading && !clickSlowError && (
                <div className="night-list">
                  {clickSlow.map((row, idx) => (
                    <TableLinkRow key={`${row.schema_name}.${row.table_name}-${idx}`} fqn={`${row.schema_name}.${row.table_name}`} onOpen={openTable}>
                      <span className="mono">{row.schema_name}.{row.table_name}</span>
                      <span className="muted">
                        {row.stage_name} · {row.duration_min ?? "—"} мин · {row.status || "—"}
                      </span>
                    </TableLinkRow>
                  ))}
                  {!clickSlow.length && <div className="muted">Долгих этапов нет.</div>}
                </div>
              )}
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
