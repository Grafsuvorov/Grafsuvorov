import { useEffect, useMemo, useState } from "react";
import { ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip } from "recharts";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";
const TOP_FETCH_LIMIT = 10;

export default function IncidentsPage({ onSelectTable }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [search, setSearch] = useState("");
  const [showMappedOnly, setShowMappedOnly] = useState(false);
  const [showDbOnly, setShowDbOnly] = useState(false);
  const [showMissingTable, setShowMissingTable] = useState(false);
  const [topSize, setTopSize] = useState(5);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setLoading(true);
        setError(null);
        const resp = await fetch(`${API_BASE}/api/ytrek/incidents?top_limit=${TOP_FETCH_LIMIT}`);
        if (!resp.ok) {
          throw new Error(`HTTP ${resp.status}`);
        }
        const payload = await resp.json();
        if (!cancelled) {
          setData(payload);
        }
      } catch (err) {
        if (!cancelled) {
          setError(String(err));
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, []);

  const incidents = data?.incidents || [];
  const stats = data?.stats;
  const timeline = data?.timeline || [];
  const topTables = (data?.top_tables || []).slice(0, topSize);
  const topEntities = (data?.top_entities || []).slice(0, topSize);

  const periodLabel = useMemo(() => {
    if (!timeline.length) return null;
    const dates = timeline
      .map((row) => new Date(row.day))
      .filter((dt) => !Number.isNaN(dt.getTime()));
    if (!dates.length) return null;
    const min = new Date(Math.min(...dates));
    const max = new Date(Math.max(...dates));
    const fmt = (dt) =>
      dt.toLocaleDateString("ru-RU", { day: "2-digit", month: "2-digit" });
    return `${fmt(min)} — ${fmt(max)}`;
  }, [timeline]);

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase();
    return incidents.filter((incident) => {
      if (showMappedOnly && !incident.has_table) return false;
      if (showDbOnly && !incident.has_db_failures) return false;
      if (showMissingTable && incident.has_table) return false;
      if (!term) return true;
      return [
        incident.issue_id,
        incident.title,
        incident.table_fqn,
        incident.table_raw,
        incident.entity_name,
      ].some((field) => (field || "").toLowerCase().includes(term));
    });
  }, [incidents, search, showMappedOnly]);

  const formatDate = (value) => {
    if (!value) return "—";
    const dt = new Date(value.replace(" ", "T"));
    if (Number.isNaN(dt.getTime())) return value;
    return dt.toLocaleString("ru-RU", {
      day: "2-digit",
      month: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  const formatDayTitle = (dayStr) => {
    if (!dayStr) return "Без даты";
    const dt = new Date(dayStr);
    if (Number.isNaN(dt.getTime())) return dayStr;
    return dt.toLocaleDateString("ru-RU", { weekday: "short", day: "2-digit", month: "long" });
  };

  const chartTick = (value) => {
    const dt = new Date(value);
    if (Number.isNaN(dt.getTime())) return value;
    return dt.toLocaleDateString("ru-RU", { day: "2-digit", month: "2-digit" });
  };

  const openTable = (tableFqn) => {
    if (!tableFqn) return;
    onSelectTable?.({ view: "table_info", table: tableFqn }, "errors");
  };

  const topToggleOptions = [5, 10];

  const groupedIncidents = useMemo(() => {
    const groups = [];
    let currentTitle = null;
    let currentGroup = null;
    filtered.forEach((incident) => {
      const title = formatDayTitle(incident.incident_day);
      if (title !== currentTitle) {
        currentTitle = title;
        currentGroup = { title, items: [] };
        groups.push(currentGroup);
      }
      currentGroup.items.push(incident);
    });
    return groups;
  }, [filtered]);

  return (
    <div className="cc-page">
      <section className="cc-header-zone">
        <h1>Инциденты YouTrack</h1>
        <div className="cc-subtitle">
          Подборка задач из трекера + перекрёст с фактами из DWH.
        </div>
      </section>

      {stats && (
        <section className="incidents-overview">
          <div className="incidents-overview-card">
            <div className="label">Всего инцидентов</div>
            <div className="value">{stats.total}</div>
          </div>
          <div className="incidents-overview-card">
            <div className="label">Сопоставлено с таблицами</div>
            <div className="value">{stats.with_table}</div>
            <div className="hint">{stats.unique_tables} уникальных таблиц</div>
          </div>
          <div className="incidents-overview-card">
            <div className="label">Сущностей затронуто</div>
            <div className="value">{stats.unique_entities}</div>
          </div>
          <div className="incidents-overview-card danger">
            <div className="label">Ошибки в DWH</div>
            <div className="value">{stats.with_db_failures}</div>
            <div className="hint">по log history</div>
          </div>
        </section>
      )}

      {periodLabel && (
        <div className="cc-header-meta">
          <span className="period-pill">Период: {periodLabel}</span>
          <span className="period-note">по выборке YouTrack</span>
        </div>
      )}

      {timeline.length > 0 && (
        <section className="cc-surface incidents-chart">
          <div className="section-title">Динамика инцидентов по дням</div>
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={timeline} margin={{ top: 12, right: 16, left: -16, bottom: 0 }}>
              <XAxis dataKey="day" tickFormatter={chartTick} fontSize={12} interval={0} angle={-20} dy={10} dx={-8} height={60} />
              <YAxis allowDecimals={false} fontSize={12} width={24} />
              <Tooltip
                labelFormatter={(value) => formatDayTitle(value)}
                formatter={(value) => [`${value} инцид.`, ""]}
              />
              <Bar dataKey="count" fill="#f97316" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </section>
      )}

      <section className="incidents-top">
        <div className="incidents-top-head">
          <div>
            <div className="section-title">Топ сущностей и таблиц</div>
            <div className="incidents-top-desc">Сводка за весь период выгрузок YT, сортировка по числу инцидентов.</div>
          </div>
          <div className="incidents-top-toggle">
            {topToggleOptions.map((size) => (
              <button
                key={size}
                className={size === topSize ? "active" : ""}
                onClick={() => setTopSize(size)}
              >
                Top {size}
              </button>
            ))}
          </div>
        </div>

        <div className="incidents-top-columns">
          <div className="incidents-top-list">
            <div className="top-list-title">Сущности</div>
            {topEntities.length === 0 && <div className="muted">Нет данных</div>}
            {topEntities.map((item) => (
              <div key={item.label} className="incidents-top-row">
                <div>
                  <div className="top-label-type">Сущность</div>
                  <div className="top-label">{item.label}</div>
                  <div className="top-hint">Последний инцидент: {formatDate(item.last_incident)}</div>
                </div>
                <div className="top-count">{item.count}</div>
              </div>
            ))}
          </div>

          <div className="incidents-top-list">
            <div className="top-list-title">Таблицы</div>
            {topTables.length === 0 && <div className="muted">Нет данных</div>}
            {topTables.map((item) => (
              <div key={item.label} className="incidents-top-row">
                <div>
                  <div className="top-label-type">Таблица</div>
                  <div className="top-label mono">{item.label}</div>
                  <div className="top-hint">Последний инцидент: {formatDate(item.last_incident)}</div>
                </div>
                <div className="top-count">{item.count}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="cc-surface" style={{ marginBottom: 20 }}>
        <div className="incidents-controls">
          <input
            className="incidents-search"
            value={search}
            placeholder="Поиск по ID, названию, таблице"
            onChange={(e) => setSearch(e.target.value)}
          />

          <label className="incidents-toggle">
            <input
              type="checkbox"
              checked={showMappedOnly}
              onChange={(e) => {
                const next = e.target.checked;
                setShowMappedOnly(next);
                if (next) setShowMissingTable(false);
              }}
            />
            Только с найденной таблицей
          </label>

          <label className="incidents-toggle">
            <input
              type="checkbox"
              checked={showDbOnly}
              onChange={(e) => setShowDbOnly(e.target.checked)}
            />
            Только с ошибками в DWH
          </label>

          <label className="incidents-toggle">
            <input
              type="checkbox"
              checked={showMissingTable}
              disabled={showMappedOnly}
              onChange={(e) => {
                const next = e.target.checked;
                setShowMissingTable(next);
                if (next) setShowMappedOnly(false);
              }}
            />
            Без таблицы
          </label>
        </div>
      </section>

      {loading && <div className="page-loading">Загружаем инциденты…</div>}
      {error && !loading && (
        <div className="page-error">Не удалось загрузить инциденты: {error}</div>
      )}

      {!loading && !error && (
        <section className="cc-surface">
          <div className="section-title">
            Подробности
            <span className="section-meta">{filtered.length}</span>
          </div>

          {filtered.length === 0 ? (
            <div className="incident-empty">Ничего не найдено.</div>
          ) : (
            <div className="incident-groups">
              {groupedIncidents.map((group) => (
                <div key={group.title} className="incident-day-group">
                  <div className="incident-day-chip">{group.title}</div>
                  <div className="incident-card-list">
                    {group.items.map((incident) => {
                      const tableTitle = incident.table_fqn || incident.table_raw || "—";
                      return (
                        <article key={incident.issue_id} className="incident-card">
                          <header className="incident-card-header">
                            <div className="mono incident-card-id">{incident.issue_id}</div>
                            <div className="incident-actions">
                              {incident.link && (
                                <a
                                  className="incident-action-link"
                                  href={incident.link}
                                  target="_blank"
                                  rel="noreferrer"
                                >
                                  Открыть задачу
                                </a>
                              )}
                              <button
                                className="incident-action-button"
                                disabled={!incident.has_table}
                                onClick={() => openTable(incident.table_fqn)}
                              >
                                Карточка
                              </button>
                            </div>
                          </header>

                          <div className="incident-card-body">
                            <div className="incident-card-main">
                              <div className="incident-title">{incident.title}</div>
                              <div className="incident-entity muted">
                                {incident.entity_name || "—"}
                              </div>
                              {incident.has_db_failures && (
                                <div className="db-badge">Ошибки в DWH ({incident.db_failures_count})</div>
                              )}
                            </div>

                            <div className="incident-card-meta">
                              <div className="meta-label">Таблица</div>
                              <div className="mono" title={tableTitle}>
                                {incident.table_fqn || tableTitle}
                              </div>
                              {!incident.has_table && (
                                <div className="incident-badge warning">нет в БД</div>
                              )}
                            </div>
                          </div>

                          <div className="incident-card-times">
                            <div>
                              <div className="meta-label">Начало</div>
                              <div>{formatDate(incident.start_at)}</div>
                            </div>
                            <div>
                              <div className="meta-label">Обнаружено</div>
                              <div>{formatDate(incident.detected_at)}</div>
                            </div>
                            <div>
                              <div className="meta-label">Завершено</div>
                              <div>{formatDate(incident.resolved_at)}</div>
                            </div>
                          </div>
                        </article>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      )}
    </div>
  );
}
