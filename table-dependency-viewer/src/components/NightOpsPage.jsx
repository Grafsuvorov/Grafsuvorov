import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

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
                {prevData && (
                  <div className="night-kpi-delta">
                    Prev: {prevData.summary?.runs_count ?? 0}
                  </div>
                )}
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Tables</div>
                <div className="night-kpi-value">{data.summary?.tables_count ?? 0}</div>
                {prevData && (
                  <div className="night-kpi-delta">
                    Prev: {prevData.summary?.tables_count ?? 0}
                  </div>
                )}
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Entities</div>
                <div className="night-kpi-value">{data.summary?.entities_count ?? 0}</div>
                {prevData && (
                  <div className="night-kpi-delta">
                    Prev: {prevData.summary?.entities_count ?? 0}
                  </div>
                )}
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Total duration</div>
                <div className="night-kpi-value">{data.summary?.total_duration_minutes ?? 0} min</div>
                {prevData && (
                  <div className="night-kpi-delta">
                    Prev: {prevData.summary?.total_duration_minutes ?? 0} min
                  </div>
                )}
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Peak hour</div>
                <div className="night-kpi-value">
                  {peakHour ? String(peakHour.hour).padStart(2, "0") + ":00" : "—"}
                </div>
              </div>
              <div className="night-kpi-card">
                <div className="night-kpi-label">Failed runs</div>
                <div className="night-kpi-value">{data.failed_summary?.runs_count ?? 0}</div>
                {prevData && (
                  <div className="night-kpi-delta">
                    Prev: {prevData.failed_summary?.runs_count ?? 0}
                  </div>
                )}
              </div>
            </div>
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
  const toTablePath = (fqn) => {
    if (!fqn || !fqn.includes(".")) return null;
    const [schema, ...rest] = fqn.split(".");
    const table = rest.join(".");
    return `/table/${encodeURIComponent(schema)}/${encodeURIComponent(table)}`;
  };
