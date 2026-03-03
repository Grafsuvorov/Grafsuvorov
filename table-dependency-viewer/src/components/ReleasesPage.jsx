import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function ReleasesPage() {
  const navigate = useNavigate();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [selectedId, setSelectedId] = useState(null);
  const [details, setDetails] = useState(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [detailsError, setDetailsError] = useState(null);

  useEffect(() => {
    setLoading(true);
    setError(null);
    fetch(`${API_BASE}/api/releases?days=60&limit=80`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить релизы")))
      .then((data) => setItems(Array.isArray(data?.items) ? data.items : []))
      .catch((err) => setError(typeof err === "string" ? err : "Не удалось загрузить релизы"))
      .finally(() => setLoading(false));
  }, []);

  const openDetails = (releaseId) => {
    if (!releaseId) return;
    if (selectedId === releaseId && details) {
      setSelectedId(null);
      setDetails(null);
      return;
    }
    setSelectedId(releaseId);
    setDetails(null);
    setDetailsLoading(true);
    setDetailsError(null);
    fetch(`${API_BASE}/api/releases/${encodeURIComponent(releaseId)}?limit=400`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить детали релиза")))
      .then((data) => setDetails(data))
      .catch((err) => setDetailsError(typeof err === "string" ? err : "Не удалось загрузить детали релиза"))
      .finally(() => setDetailsLoading(false));
  };

  const stats = useMemo(() => {
    const total = items.length;
    const failed = items.filter((i) => i.failed_count > 0 || i.failed_any).length;
    const running = items.filter((i) => String(i.status || "").toLowerCase().includes("run")).length;
    return { total, failed, running };
  }, [items]);

  const formatDateTime = (value) => {
    if (!value) return "—";
    const str = String(value);
    const normalized = str.replace("T", " ").replace("Z", "");
    const match = normalized.match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})/);
    if (match) return `${match[1]} ${match[2]}`;
    return normalized;
  };

  const openTable = (schema, table) => {
    if (!schema || !table) return;
    navigate(`/table/${encodeURIComponent(schema)}/${encodeURIComponent(table)}`);
  };

  return (
    <div className="page releases-page">
      <div className="page-header">
        <div>
          <h1>Релизы</h1>
          <div className="muted">Реестр изменений и статус внедрения.</div>
        </div>
      </div>

      <div className="release-summary">
        <div className="release-summary-card">
          <div className="label">Всего релизов</div>
          <div className="value">{stats.total}</div>
        </div>
        <div className="release-summary-card warn">
          <div className="label">С ошибками</div>
          <div className="value">{stats.failed}</div>
        </div>
        <div className="release-summary-card">
          <div className="label">В процессе</div>
          <div className="value">{stats.running}</div>
        </div>
      </div>

      <section className="card release-list">
        {loading && <div className="muted">Загрузка релизов...</div>}
        {error && <div className="dep-error-title">{error}</div>}
        {!loading && !error && items.length === 0 && <div className="muted">Релизы не найдены.</div>}
        {!loading && !error && items.length > 0 && (
          <div className="release-list-table">
            <div className="release-list-head">
              <span>Релиз</span>
              <span>Статус</span>
              <span>Старт</span>
              <span>Длительность</span>
              <span>Объектов</span>
              <span>Автор</span>
              <span>Задачи</span>
              <span></span>
            </div>
            {items.map((row) => (
              <div key={row.release_id} className="release-list-row">
                <span className="mono">{row.release_id}</span>
                <span className={`status-pill ${row.failed_count ? "status-failed" : "status-success"}`}>
                  {row.status || "—"}
                </span>
                <span>{formatDateTime(row.started_at)}</span>
                <span>{row.duration_minutes ? `${Math.round(row.duration_minutes)} мин` : "—"}</span>
                <span>{row.objects_count ?? "—"}</span>
                <span>{row.initiated_by || "—"}</span>
                <span className="release-task-links">
                  {Array.isArray(row.task_ids) && row.task_ids.length > 0
                    ? row.task_ids.slice(0, 3).map((task, idx) => (
                        <span key={`${row.release_id}-${task}-${idx}`} className="mono">
                          {task}
                        </span>
                      ))
                    : "—"}
                </span>
                <button className="btn btn-secondary" onClick={() => openDetails(row.release_id)}>
                  {selectedId === row.release_id ? "Скрыть" : "Детали"}
                </button>
              </div>
            ))}
          </div>
        )}
      </section>

      {selectedId && (
        <section className="card release-details">
          <div className="section-title">Детали релиза</div>
          {detailsLoading && <div className="muted">Загрузка деталей...</div>}
          {detailsError && <div className="dep-error-title">{detailsError}</div>}
          {!detailsLoading && !detailsError && details?.objects?.length === 0 && (
            <div className="muted">Объектов не найдено.</div>
          )}
          {!detailsLoading && !detailsError && details?.objects?.length > 0 && (
            <div className="release-objects-table">
              <div className="release-objects-head">
                <span>Объект</span>
                <span>БД</span>
                <span>Статус</span>
                <span>Изменения</span>
                <span>Задача</span>
                <span>Дата</span>
              </div>
              {details.objects.map((obj, idx) => (
                <div key={`${obj.release_id}-${idx}`} className="release-objects-row">
                  <span className="mono">{obj.schema_name}.{obj.table_name}</span>
                  <button
                    className="release-object-link"
                    onClick={() => openTable(obj.schema_name, obj.table_name)}
                    title={`${obj.schema_name}.${obj.table_name}`}
                  >
                    {obj.schema_name}.{obj.table_name}
                  </button>
                  <span>{obj.target_system || "—"}</span>
                  <span className={`status-pill ${obj.final_status?.toLowerCase().includes("success") ? "status-success" : "status-unknown"}`}>
                    {obj.final_status || "—"}
                  </span>
                  <span className="muted" title={obj.change_type || ""}>
                    {obj.change_type || "—"}
                  </span>
                  {obj.task_link ? (
                    <a className="yt-link" href={obj.task_link} target="_blank" rel="noreferrer">
                      {obj.task_id || "—"}
                    </a>
                  ) : (
                    <span className="mono">{obj.task_id || "—"}</span>
                  )}
                  <span>{formatDateTime(obj.created_at)}</span>
                </div>
              ))}
            </div>
          )}
        </section>
      )}
    </div>
  );
}
