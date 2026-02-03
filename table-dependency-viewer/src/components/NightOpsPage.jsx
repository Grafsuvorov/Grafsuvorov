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

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    Promise.all([
      fetch(`${API_BASE}/api/night-summary?days=30&limit=50`),
      fetch(`${API_BASE}/api/night-summary?days=30&limit=50&shift_days=1`),
    ])
      .then(async ([curr, prev]) => {
        if (!curr.ok) throw new Error("Failed to load night summary");
        const currJson = await curr.json();
        const prevJson = prev.ok ? await prev.json() : null;
        if (!cancelled) {
          setData(currJson);
          setPrevData(prevJson);
        }
      })
      .catch((err) => {
        if (!cancelled) setError(typeof err === "string" ? err : "Failed to load night summary");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
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

  useEffect(() => {
    loadHeavyTables();
  }, [loadHeavyTables]);

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
        <button className="btn" onClick={() => navigate("/")}>← Back</button>
        <h1>Night operations</h1>
        <div className="cc-subtitle">Summary for the last night window (21:00–08:00)</div>
      </section>

      {loading && <div className="muted">Loading night summary...</div>}
      {error && <div className="dep-error-title">{error}</div>}

      {!loading && !error && data && (
        <>
          <section className="cc-surface">
            <div className="section-title">Night KPIs</div>
            <div className="night-kpis">
              <div className="night-kpi-card">
                <div className="night-kpi-label">Runs</div>
                <div className="night-kpi-value">{data.summary?.runs_count ?? 0}</div>
                {prevData && <div className="night-kpi-delta">Prev: {prevData.summary?.runs_count ?? 0}</div>}
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Tables</div>
                <div className="night-kpi-value">{data.summary?.tables_count ?? 0}</div>
                {prevData && <div className="night-kpi-delta">Prev: {prevData.summary?.tables_count ?? 0}</div>}
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Entities</div>
                <div className="night-kpi-value">{data.summary?.entities_count ?? 0}</div>
                {prevData && <div className="night-kpi-delta">Prev: {prevData.summary?.entities_count ?? 0}</div>}
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Total duration</div>
                <div className="night-kpi-value">{data.summary?.total_duration_minutes ?? 0} min</div>
                {prevData && (
                  <div className="night-kpi-delta">Prev: {prevData.summary?.total_duration_minutes ?? 0} min</div>
                )}
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Peak hour</div>
                <div className="night-kpi-value">
                  {peakHour ? `${String(peakHour.hour).padStart(2, "0")}:00` : "—"}
                </div>
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Failed runs</div>
                <div className="night-kpi-value">{data.failed_summary?.runs_count ?? 0}</div>
                {prevData && <div className="night-kpi-delta">Prev: {prevData.failed_summary?.runs_count ?? 0}</div>}
              </div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Peak window focus</div>
            <div className="night-window-controls">
              <label className="night-window-label">
                Start
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
                End
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
                Interval
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
                Sort
                <select
                  className="night-window-select"
                  value={heavySortMode}
                  onChange={(e) => setHeavySortMode(e.target.value)}
                >
                  <option value="heavy_total">Heavy (sum)</option>
                  <option value="long_max">Long (max run)</option>
                </select>
              </label>
              <div className="night-window-actions">
                <button className="btn btn-secondary" onClick={applyWindow} disabled={heavyLoading}>
                  {heavyLoading ? "Loading..." : "Apply"}
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
                  Use peak hour
                </button>
              </div>
            </div>

            {heavyError && <div className="dep-error-title" style={{ marginTop: 10 }}>{heavyError}</div>}

            {heavyData && (
              <div className="night-window-summary">
                <span>Runs: <strong>{heavyData.summary?.runs_count ?? 0}</strong></span>
                <span>Tables: <strong>{heavyData.summary?.tables_count ?? 0}</strong></span>
                <span>Total: <strong>{heavyData.summary?.total_duration_minutes ?? 0} min</strong></span>
                <span>Max run: <strong>{heavyData.summary?.max_duration_minutes ?? 0} min</strong></span>
              </div>
            )}
          </section>

          <section className="cc-surface">
            <div className="section-title night-controls">
              <span>Night details</span>
              <label className="night-toggle">
                <input
                  type="checkbox"
                  checked={showFailuresOnly}
                  onChange={(e) => setShowFailuresOnly(e.target.checked)}
                />
                Show failures only
              </label>
            </div>

            <div className="night-columns">
              {!showFailuresOnly && (
                <div className="night-panel">
                  <div className="night-panel-title">Heavy tables in selected window</div>
                  <div className="night-panel-sub muted">
                    {heavyData ? `${heavyData.window?.start}–${heavyData.window?.end}` : "Window not loaded"}
                  </div>
                  <div className="night-list">
                    {heavyRows.map((row) => (
                      <button
                        key={`${row.table_fqn}-${row.total_duration_minutes}-${row.runs_count}`}
                        className="night-row"
                        onClick={() => {
                          const path = toTablePath(row.table_fqn);
                          if (path) navigate(path);
                        }}
                      >
                        <span className="mono">{row.table_fqn}</span>
                        <span className="muted">
                          {row.entity_name || "—"} · ID {row.table_id ?? "—"} · Σ {row.total_duration_minutes ?? "—"} min · max {row.max_duration_minutes ?? "—"} min · runs {row.runs_count ?? 0}
                        </span>
                        {row.table_size_mb !== null && row.table_size_mb !== undefined && (
                          <span className="night-row-badge">{row.table_size_mb} MB</span>
                        )}
                      </button>
                    ))}
                    {!heavyLoading && !heavyRows.length && <div className="muted">No heavy tables in this window.</div>}
                  </div>
                </div>
              )}

              {!showFailuresOnly && (
                <div className="night-panel">
                  <div className="night-panel-title">Longest runs</div>
                  <div className="night-panel-sub muted">Top 10 by duration</div>
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
                          {row.entity_name || "—"} · ID {row.table_id ?? "—"} · {row.duration_minutes ?? "—"} min
                        </span>
                      </button>
                    ))}
                  </div>
                  {(data.top_runs || []).length > 10 && (
                    <div className="night-panel-actions">
                      <button className="btn btn-ghost" onClick={() => setLongestLimit((n) => Math.min(n + 10, (data.top_runs || []).length))}>
                        Show +10
                      </button>
                      <button className="btn btn-ghost" onClick={() => setLongestLimit(10)}>
                        Reset
                      </button>
                    </div>
                  )}
                </div>
              )}

              {!showFailuresOnly && (
                <div className="night-panel">
                  <div className="night-panel-title">Anomalies vs p95</div>
                  <div className="night-panel-sub muted">Runs &gt; 1.5x p95</div>
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
                          {row.entity_name || "—"} · ID {row.table_id ?? "—"} · {row.duration_minutes ?? "—"} min · {row.ratio ?? "—"}x
                        </span>
                      </button>
                    ))}
                  </div>
                  {(data.anomalies || []).length > 10 && (
                    <div className="night-panel-actions">
                      <button className="btn btn-ghost" onClick={() => setAnomalyLimit((n) => Math.min(n + 10, (data.anomalies || []).length))}>
                        Show +10
                      </button>
                      <button className="btn btn-ghost" onClick={() => setAnomalyLimit(10)}>
                        Reset
                      </button>
                    </div>
                  )}
                </div>
              )}

              {!showFailuresOnly && (
                <div className="night-panel">
                  <div className="night-panel-title">Peak hour tables</div>
                  <div className="night-panel-sub muted">
                    {peakHour ? `Peak at ${String(peakHour.hour).padStart(2, "0")}:00` : "No peak data"}
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
                          {row.entity_name || "—"} · ID {row.table_id ?? "—"} · {row.duration_minutes ?? "—"} min
                        </span>
                      </button>
                    ))}
                    {!peakTables.length && <div className="muted">No peak tables.</div>}
                  </div>
                  {peakTables.length > 10 && (
                    <div className="night-panel-actions">
                      <button className="btn btn-ghost" onClick={() => setPeakLimit((n) => Math.min(n + 10, peakTables.length))}>
                        Show +10
                      </button>
                      <button className="btn btn-ghost" onClick={() => setPeakLimit(10)}>
                        Reset
                      </button>
                    </div>
                  )}
                  {peakTables.length > 0 && (
                    <div className="night-panel-actions">
                      <button className="btn btn-secondary" onClick={() => setShowPeakDetails(true)}>
                        Why peak?
                      </button>
                    </div>
                  )}
                </div>
              )}

              <div className="night-panel">
                <div className="night-panel-title">Failed runs</div>
                <div className="night-panel-sub muted">Last failures in the window</div>
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
                      Show +10
                    </button>
                    <button className="btn btn-ghost" onClick={() => setFailedLimit(10)}>
                      Reset
                    </button>
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
                <div className="night-panel-title">Peak hour details</div>
                <div className="night-panel-sub muted">
                  {String(peakHour.hour).padStart(2, "0")}:00 · {peakHour.runs_count ?? 0} runs · {peakHour.total_duration_minutes ?? 0} min
                </div>
              </div>
              <button className="btn btn-ghost" onClick={() => setShowPeakDetails(false)}>
                Close
              </button>
            </div>
            <div className="night-list">
              {peakTables.map((row) => (
                <div key={`${row.table_fqn}-${row.duration_minutes}-${row.entity_name}`} className="night-row">
                  <span className="mono">{row.table_fqn}</span>
                  <span className="muted">
                    {row.entity_name || "—"} · ID {row.table_id ?? "—"} · {row.duration_minutes ?? "—"} min
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
