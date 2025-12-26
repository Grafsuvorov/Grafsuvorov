import { useEffect, useMemo, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

function formatDuration(sec) {
  if (sec == null) return "—";
  const s = Math.round(sec);
  const m = Math.floor(s / 60);
  const r = s % 60;
  if (m <= 0) return `${r}s`;
  return `${m}m ${r}s`;
}

function relTime(dtStr) {
  if (!dtStr) return "—";
  const dt = new Date(dtStr.replace(" ", "T"));
  const now = new Date();
  const diff = Math.floor((now - dt) / 1000);
  if (diff < 60) return `${diff}s назад`;
  const mins = Math.floor(diff / 60);
  if (mins < 60) return `${mins}м назад`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 48) return `${hrs}ч назад`;
  const days = Math.floor(hrs / 24);
  return `${days}д назад`;
}

export default function IncidentDetailsPage({ tableFqn, onBack, onOpenGraph }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState(true); // Blast radius block
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!tableFqn) return;

    let cancelled = false;
    async function load() {
      try {
        setLoading(true);
        setError(null);

        const res = await fetch(`${API_BASE}/api/incident?table_fqn=${encodeURIComponent(tableFqn)}`);
        const json = await res.json();

        if (!cancelled) setData(json);
      } catch (e) {
        if (!cancelled) setError(String(e));
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();

    return () => { cancelled = true; };
  }, [tableFqn]);

  const summary = data?.summary;
  const impact = data?.impact;
  const deps = data?.dependencies || [];
  const timeline = data?.timeline || [];

  const severityClass = useMemo(() => {
    const s = summary?.severity || "MEDIUM";
    if (s === "CRITICAL") return "pill-critical";
    if (s === "HIGH") return "pill-high";
    return "pill-medium";
  }, [summary?.severity]);

  const stateLabel = useMemo(() => {
    if (!summary?.state) return "UNKNOWN";
    return summary.state === "FAILING" ? "FAILING" : "RECOVERED";
  }, [summary?.state]);

  return (
    <div className="incident2-page">
      <div className="incident2-top">
        <button className="incident2-back" onClick={onBack}>← Инциденты</button>
        <div className="incident2-title">
          <div className="incident2-h1">Инцидент</div>
          <div className="incident2-sub">Повторяемость, таймлайн, риск и цепочки влияния</div>
        </div>
        <div className="incident2-badges">
          <span className={`incident2-pill ${severityClass}`}>{summary?.severity || "—"}</span>
          <span className={`incident2-pill ${stateLabel === "FAILING" ? "pill-state-bad" : "pill-state-ok"}`}>
            {stateLabel}
          </span>
        </div>
      </div>

      <div className="incident2-hero">
        <div className="incident2-hero-left">
          <div className="incident2-fqn mono">{summary?.table_fqn || tableFqn}</div>
          <div className="incident2-meta">
            <span className="incident2-meta-item">
              Последнее падение: <b>{summary?.last_failure_time || "—"}</b> <span className="muted">({relTime(summary?.last_failure_time)})</span>
            </span>
            <span className="incident2-meta-dot" />
            <span className="incident2-meta-item">
              Последний успех: <b>{summary?.last_success_time || "—"}</b> <span className="muted">({relTime(summary?.last_success_time)})</span>
            </span>
          </div>
        </div>

        <div className="incident2-hero-actions">
          <button className="btn btn-primary" onClick={() => onOpenGraph?.(summary?.table_fqn || tableFqn)}>
            Открыть граф
          </button>
          <button className="btn" onClick={() => setExpanded(v => !v)}>
            {expanded ? "Свернуть последствия" : "Показать последствия"}
          </button>
        </div>
      </div>

      {/* KPI */}
      <div className="incident2-kpis">
        <div className="incident2-kpi">
          <div className="incident2-kpi-value">{summary?.failures_24h ?? "—"}</div>
          <div className="incident2-kpi-label">Падений за 24ч</div>
        </div>

        <div className="incident2-kpi">
          <div className="incident2-kpi-value">{summary?.failures_7d ?? "—"}</div>
          <div className="incident2-kpi-label">Падений за 7д</div>
        </div>

        <div className="incident2-kpi">
          <div className="incident2-kpi-value">{summary?.consecutive_failures ?? "—"}</div>
          <div className="incident2-kpi-label">Подряд</div>
        </div>

        <div className="incident2-kpi">
          <div className="incident2-kpi-value">{impact?.blocked_tables_count ?? deps.length}</div>
          <div className="incident2-kpi-label">Затронуто таблиц</div>
        </div>

        <div className="incident2-kpi">
          <div className="incident2-kpi-value">{(impact?.reports_at_risk || []).length}</div>
          <div className="incident2-kpi-label">Отчётов под риском</div>
        </div>
      </div>

      {/* Timeline (главный смысл страницы) */}
      <div className="incident2-grid">
        <section className="incident2-card incident2-card-main">
          <div className="incident2-card-head">
            <div className="incident2-card-title">История падений</div>
            <div className="incident2-card-sub muted">Последние события по этой таблице</div>
          </div>

          {loading && <div className="incident2-skeleton">Загрузка таймлайна…</div>}
          {error && <div className="incident2-error">Ошибка: {error}</div>}

          {!loading && !error && timeline.length === 0 && (
            <div className="incident2-empty">Нет событий в истории</div>
          )}

          {!loading && !error && timeline.length > 0 && (
            <div className="incident2-timeline">
              {timeline.map((ev, idx) => {
                const isFail = ev.state === "FAILED";
                return (
                  <div key={idx} className="incident2-event">
                    <div className={`incident2-dot ${isFail ? "dot-fail" : "dot-ok"}`} />
                    <div className="incident2-event-body">
                      <div className="incident2-event-row">
                        <div className={`incident2-event-state ${isFail ? "state-fail" : "state-ok"}`}>
                          {ev.state}
                        </div>
                        <div className="incident2-event-time mono">{ev.finish || "—"}</div>
                        <div className="incident2-event-dur">{formatDuration(ev.duration_sec)}</div>
                      </div>
                      {ev.message && (
                        <div className="incident2-event-msg">{ev.message}</div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>

        {/* Side card: impact quick view */}
        <section className="incident2-card">
          <div className="incident2-card-head">
            <div className="incident2-card-title">Риск и влияние</div>
            <div className="incident2-card-sub muted">SLA / сущности / отчёты</div>
          </div>

          <div className="incident2-mini">
            <div className="incident2-mini-row">
              <span className="muted">SLA нарушений</span>
              <b>{impact?.sla_violations ?? 0}</b>
            </div>

            <div className="incident2-mini-row">
              <span className="muted">Сущностей</span>
              <b>{(impact?.affected_entities || []).length}</b>
            </div>

            <div className="incident2-mini-row">
              <span className="muted">Отчётов под риском</span>
              <b>{(impact?.reports_at_risk || []).length}</b>
            </div>
          </div>

          <div className="incident2-divider" />

          <div className="incident2-list-title">Сущности</div>
          <div className="incident2-chips">
            {(impact?.affected_entities || []).slice(0, 10).map(x => (
              <span key={x} className="chip">{x}</span>
            ))}
            {(impact?.affected_entities || []).length === 0 && (
              <div className="muted">—</div>
            )}
          </div>

          <div className="incident2-list-title" style={{ marginTop: 14 }}>Отчёты под риском</div>
          <ul className="incident2-ul">
            {(impact?.reports_at_risk || []).slice(0, 8).map(r => (
              <li key={r}>{r}</li>
            ))}
            {(impact?.reports_at_risk || []).length === 0 && (
              <li className="muted">—</li>
            )}
          </ul>
        </section>
      </div>

      {/* Blast radius */}
      {expanded && (
        <section className="incident2-card incident2-card-wide">
          <div className="incident2-card-head">
            <div className="incident2-card-title">Последствия (downstream)</div>
            <div className="incident2-card-sub muted">
              Таблицы, которые зависят от источника (клик — открыть граф по таблице)
            </div>
          </div>

          {deps.length === 0 ? (
            <div className="incident2-empty">Downstream зависимостей не найдено</div>
          ) : (
            <table className="table incident2-table">
              <thead>
                <tr>
                  <th>Таблица</th>
                  <th>Сущность</th>
                  <th>Среднее, мин</th>
                </tr>
              </thead>
              <tbody>
                {deps.map((t) => {
                  const fqn = `${t.schema}.${t.table_name || t.table || t.table_name}`;
                  const schema = t.schema;
                  const name = t.table_name || t.table;
                  const rowFqn = `${schema}.${name}`;

                  return (
                    <tr key={rowFqn} onClick={() => onOpenGraph?.(rowFqn)} title="Открыть граф зависимостей">
                      <td className="mono">{rowFqn}</td>
                      <td>{t.entity_name || t.entity || "—"}</td>
                      <td>{t.avg_duration_minutes ?? "—"}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </section>
      )}
    </div>
  );
}



                    import { useEffect, useState } from 'react';
import '../style/app.css';
const API_BASE = import.meta.env.VITE_API_BASE_URL;

export default function DependencyViewer({ table, onBack }) {
  const [results, setResults] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const fetchDependencies = async () => {
    if (!table) return;
    setLoading(true);
    setError(null);
    try {
      const response = await fetch(`${API_BASE}/api/dependencies?table=${table}`);
      if (!response.ok) throw new Error(`Ошибка: ${response.status}`);
      const data = await response.json();

      setResults(data);
    } catch (err) {
      setError(err.message);
      setResults([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (table) fetchDependencies();
  }, [table]);

  // Уникальные сущности
  const uniqueEntities = [];
  const entitySet = new Set();
  results.forEach((item) => {
    const key = `${item.entity_id}-${item.entity_name}`;
    if (!entitySet.has(key)) {
      entitySet.add(key);
      uniqueEntities.push(item);
    }
  });

  // Уникальные таблицы
  const uniqueTables = [];
  const tableSet = new Set();
  results.forEach((item) => {
    const key = `${item.schema}.${item.table_name}`;
    if (!tableSet.has(key)) {
      tableSet.add(key);
      uniqueTables.push(item);
    }
  });

  // Сортировка после фильтрации
  const parseTime = (t) => {
    if (!t) return 0;
    const timePart = t.split(' ')[1];
    const [h, m, s] = timePart.split(':').map(Number);
    return h * 3600 + m * 60 + s;
  };

  uniqueEntities.sort((a, b) => {
    const aSec = parseTime(a.start_time);
    const bSec = parseTime(b.start_time);
    const isALate = aSec >= 21 * 3600;
    const isBLate = bSec >= 21 * 3600;
    if (isALate && !isBLate) return -1;
    if (!isALate && isBLate) return 1;
    return aSec - bSec;
  });



  if (!table) return null;

  return (
    <div>
      <button onClick={onBack} style={{ marginBottom: 10 }}>← Назад</button>
      <h2 className="center">
        Зависимости для: <span className="monospace">{table.split('.')[1]}</span>
      </h2>

      {loading && (
        <div className="loading-bar-container">
          <div className="loading-bar" />
          <p className="center muted">Ищем зависимости... расслабься и ожидай 🙂</p>
        </div>
      )}

      {error && <p className="center error">Ошибка: {error}</p>}

      {uniqueEntities.length > 0 && (
        <>
          <h3>Сущности, которые надо перезапустить:</h3>
          <table>
            <thead>
              <tr>
                <th>Шаг</th>
                <th>Entity ID</th>
                <th>Entity Name</th>
                <th>Время запуска</th>
              </tr>
            </thead>
            <tbody>
              {uniqueEntities.map((item, i) => (
                <tr key={i}>
                  <td>{i + 1}</td>
                  <td>{item.entity_id}</td>
                  <td>{item.entity_name || '-'}</td>
                  <td>{item.start_time || '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}

      {uniqueTables.length > 0 && (
        <>
          <h3>Зависимые таблицы:</h3>
          <table>
            <thead>
              <tr>
                <th>Схема</th>
                <th>Таблица</th>
                <th>Entity ID</th>
                <th>Entity Name</th>
                <th>Время запуска</th>
                <th>⏱ Среднее время загрузки (мин)</th>
              </tr>
            </thead>
            <tbody>
              {uniqueTables.map((item, i) => (
                <tr key={`${item.schema}.${item.table_name}-${i}`}>
                  <td>{item.schema}</td>
                  <td className="monospace">{item.table_name}</td>
                  <td>{item.entity_id}</td>
                  <td>{item.entity_name || '-'}</td>
                  <td>{item.start_time || '-'}</td>
                  <td>
                    {typeof item.avg_duration_minutes === 'number'
                      ? item.avg_duration_minutes.toFixed(1)
                      : '-'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
    </div>
  );
}
