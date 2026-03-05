import { useEffect, useMemo, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function AnalyticsPage() {
  const [days, setDays] = useState(30);
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [byExecutor, setByExecutor] = useState([]);
  const [byCreator, setByCreator] = useState([]);
  const [byDirection, setByDirection] = useState([]);

  const hasCustomRange = Boolean(dateFrom || dateTo);

  const buildParams = (groupBy) => {
    const params = new URLSearchParams();
    params.set("group_by", groupBy);
    if (hasCustomRange) {
      if (dateFrom) params.set("date_from", dateFrom);
      if (dateTo) params.set("date_to", dateTo);
    } else {
      params.set("days", String(days));
    }
    return params.toString();
  };

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    Promise.all([
      fetch(`${API_BASE}/api/analytics/workload?${buildParams("executor")}`),
      fetch(`${API_BASE}/api/analytics/workload?${buildParams("creator")}`),
      fetch(`${API_BASE}/api/analytics/workload?${buildParams("direction")}`),
    ])
      .then(async ([execRes, creatorRes, dirRes]) => {
        if (!execRes.ok || !creatorRes.ok || !dirRes.ok) {
          throw new Error("Не удалось загрузить аналитику");
        }
        const execJson = await execRes.json();
        const creatorJson = await creatorRes.json();
        const dirJson = await dirRes.json();
        if (!cancelled) {
          setByExecutor(Array.isArray(execJson?.items) ? execJson.items : []);
          setByCreator(Array.isArray(creatorJson?.items) ? creatorJson.items : []);
          setByDirection(Array.isArray(dirJson?.items) ? dirJson.items : []);
        }
      })
      .catch((err) => {
        if (!cancelled) setError(err.message || "Не удалось загрузить аналитику");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [days, dateFrom, dateTo]);

  const formatHours = (minutes) => {
    const value = Number(minutes || 0);
    return `${(value / 60).toFixed(1)} ч`;
  };

  const formatDateTime = (value) => {
    if (!value) return "—";
    const str = String(value).replace("T", " ").replace("Z", "");
    const match = str.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})/);
    if (match) return `${match[1]} ${match[2]}`;
    return str;
  };

  const rangeLabel = useMemo(() => {
    if (hasCustomRange) {
      const from = dateFrom || "…";
      const to = dateTo || "…";
      return `${from} — ${to}`;
    }
    return `Последние ${days} дней`;
  }, [days, dateFrom, dateTo, hasCustomRange]);

  return (
    <div className="page analytics-page">
      <div className="page-header">
        <div>
          <h1>Аналитика</h1>
          <div className="muted">Нагрузка команды и структура задач.</div>
        </div>
      </div>

      <div className="analytics-toolbar">
        <div className="analytics-range">
          {[30, 90].map((d) => (
            <button
              key={d}
              className={`btn btn-ghost ${!hasCustomRange && days === d ? "active" : ""}`}
              onClick={() => {
                setDays(d);
                setDateFrom("");
                setDateTo("");
              }}
            >
              {d} дней
            </button>
          ))}
          <div className="analytics-custom">
            <label className="muted">С даты</label>
            <input
              type="date"
              className="input"
              value={dateFrom}
              onChange={(e) => setDateFrom(e.target.value)}
            />
          </div>
          <div className="analytics-custom">
            <label className="muted">По дату</label>
            <input
              type="date"
              className="input"
              value={dateTo}
              onChange={(e) => setDateTo(e.target.value)}
            />
          </div>
          {hasCustomRange && (
            <button
              className="btn btn-secondary"
              onClick={() => {
                setDateFrom("");
                setDateTo("");
              }}
            >
              Сбросить
            </button>
          )}
        </div>
        <div className="analytics-range-label muted">{rangeLabel}</div>
      </div>

      {loading && <div className="muted">Загрузка аналитики...</div>}
      {error && <div className="dep-error-title">{error}</div>}

      {!loading && !error && (
        <div className="analytics-grid">
          <section className="card analytics-block">
            <div className="section-title">Нагрузка команды</div>
            <div className="analytics-table">
              <div className="analytics-head">
                <span>Инженер</span>
                <span>Задач</span>
                <span>Таблиц</span>
                <span>Часы</span>
                <span>Последняя активность</span>
              </div>
              {byExecutor.map((row, idx) => (
                <div key={`exec-${idx}`} className="analytics-row">
                  <span>{row.executor || "—"}</span>
                  <span>{row.tasks_count || 0}</span>
                  <span>{row.tables_count || 0}</span>
                  <span>{formatHours(row.minutes)}</span>
                  <span>{formatDateTime(row.last_activity)}</span>
                </div>
              ))}
              {byExecutor.length === 0 && <div className="muted">Данных нет.</div>}
            </div>
          </section>

          <section className="card analytics-block">
            <div className="section-title">Постановщики</div>
            <div className="analytics-table">
              <div className="analytics-head">
                <span>Постановщик</span>
                <span>Задач</span>
                <span>Таблиц</span>
                <span>Часы</span>
                <span>Последняя активность</span>
              </div>
              {byCreator.map((row, idx) => (
                <div key={`creator-${idx}`} className="analytics-row">
                  <span>{row.creator || "—"}</span>
                  <span>{row.tasks_count || 0}</span>
                  <span>{row.tables_count || 0}</span>
                  <span>{formatHours(row.minutes)}</span>
                  <span>{formatDateTime(row.last_activity)}</span>
                </div>
              ))}
              {byCreator.length === 0 && <div className="muted">Данных нет.</div>}
            </div>
          </section>

          <section className="card analytics-block">
            <div className="section-title">Направления</div>
            <div className="analytics-table">
              <div className="analytics-head">
                <span>Направление</span>
                <span>Задач</span>
                <span>Таблиц</span>
                <span>Часы</span>
                <span>Последняя активность</span>
              </div>
              {byDirection.map((row, idx) => (
                <div key={`direction-${idx}`} className="analytics-row">
                  <span>{row.direction || "—"}</span>
                  <span>{row.tasks_count || 0}</span>
                  <span>{row.tables_count || 0}</span>
                  <span>{formatHours(row.minutes)}</span>
                  <span>{formatDateTime(row.last_activity)}</span>
                </div>
              ))}
              {byDirection.length === 0 && <div className="muted">Данных нет.</div>}
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
