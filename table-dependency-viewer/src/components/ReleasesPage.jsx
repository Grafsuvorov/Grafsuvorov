import { useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import "../style/app.css";
import { formatLocalDateTime } from "../utils/datetime.js";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";
const YT_BASE = "https://yt.rusal.ru/issue/";

export default function ReleasesPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [selectedId, setSelectedId] = useState(null);
  const [details, setDetails] = useState(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [detailsError, setDetailsError] = useState(null);
  const [ytStats, setYtStats] = useState(null);
  const [ytStatsLoading, setYtStatsLoading] = useState(false);
  const [ytStatsError, setYtStatsError] = useState(null);
  const [ytTasks, setYtTasks] = useState([]);
  const [ytTasksLoading, setYtTasksLoading] = useState(false);
  const [ytTasksError, setYtTasksError] = useState(null);
  const analyticsDays = 30;
  const [selectedDirection, setSelectedDirection] = useState(null);
  const [selectedCreator, setSelectedCreator] = useState(null);
  const [selectedAssignee, setSelectedAssignee] = useState(null);

  useEffect(() => {
    setLoading(true);
    setError(null);
    fetch(`${API_BASE}/api/releases?days=60&limit=80`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить релизы")))
      .then((data) => setItems(Array.isArray(data?.items) ? data.items : []))
      .catch((err) => setError(typeof err === "string" ? err : "Не удалось загрузить релизы"))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    const releaseId = location.state?.releaseId;
    if (releaseId) {
      openDetails(releaseId);
    }
  }, [location.state]);


  useEffect(() => {
    setYtStatsLoading(true);
    setYtStatsError(null);
    fetch(`${API_BASE}/api/ytrek/analytics?days=${analyticsDays}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить аналитику YouTrack")))
      .then((data) => setYtStats(data || null))
      .catch((err) => setYtStatsError(typeof err === "string" ? err : "Не удалось загрузить аналитику YouTrack"))
      .finally(() => setYtStatsLoading(false));

    setYtTasksLoading(true);
    setYtTasksError(null);
    fetch(`${API_BASE}/api/ytrek/tasks?days=${analyticsDays}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить задачи YouTrack")))
      .then((data) => setYtTasks(Array.isArray(data) ? data : []))
      .catch((err) => setYtTasksError(typeof err === "string" ? err : "Не удалось загрузить задачи YouTrack"))
      .finally(() => setYtTasksLoading(false));
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
    return formatLocalDateTime(value, { withSeconds: false });
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
                        <a
                          key={`${row.release_id}-${task}-${idx}`}
                          className="yt-link mono"
                          href={`${YT_BASE}${task}`}
                          target="_blank"
                          rel="noreferrer"
                        >
                          {task}
                        </a>
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

      <section className="card release-analytics">
        <div className="section-title">Трудозатраты и частота изменений</div>
        {(ytStatsLoading || ytTasksLoading) && <div className="muted">Загрузка аналитики...</div>}
        {(ytStatsError || ytTasksError) && (
          <div className="dep-error-title">{ytStatsError || ytTasksError}</div>
        )}
        {!ytStatsLoading && !ytStatsError && ytStats && (
          <div className="yt-analytics-grid">
            <div className="yt-analytics-block">
              <div className="section-subtitle">По направлениям</div>
              <div className="yt-analytics-table">
                <div className="yt-analytics-head">
                  <span>Направление</span>
                  <span>Задач</span>
                  <span>Часы</span>
                  <span></span>
                </div>
                {(ytStats.by_direction || []).map((row, idx) => (
                  <div key={`dir-${idx}`} className="yt-analytics-row">
                    <span>{row.direction || "—"}</span>
                    <span>{row.tasks_count || 0}</span>
                    <span>{row.minutes ? Math.round(row.minutes / 60) : 0}</span>
                    <button
                      className="btn btn-secondary"
                      onClick={() =>
                        setSelectedDirection((prev) => (prev === row.direction ? null : row.direction))
                      }
                    >
                      {selectedDirection === row.direction ? "Скрыть" : "Задачи"}
                    </button>
                  </div>
                ))}
              </div>
              {selectedDirection && (
                <div className="yt-analytics-tasks">
                  <div className="yt-analytics-task-head">
                    <span>Задача</span>
                    <span>Направление</span>
                    <span>Постановщик</span>
                    <span>Исполнитель</span>
                    <span>Часы</span>
                  </div>
                  {(ytTasks || [])
                    .filter((t) => (t.direction || "Не указан") === selectedDirection)
                    .map((t, idx) => (
                    <div key={`dir-task-${idx}`} className="yt-analytics-task-row">
                      <a className="yt-link mono" href={`${YT_BASE}${t.issue_id}`} target="_blank" rel="noreferrer">
                        {t.issue_id}
                      </a>
                      <span>{t.direction || "—"}</span>
                      <span>{t.created_by || "—"}</span>
                      <span>{t.assignee || "—"}</span>
                      <span>{t.minutes ? Math.round(t.minutes / 60) : 0} ч</span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="yt-analytics-block">
              <div className="section-subtitle">По постановщикам</div>
              <div className="yt-analytics-table">
                <div className="yt-analytics-head">
                  <span>Постановщик</span>
                  <span>Задач</span>
                  <span>Часы</span>
                  <span></span>
                </div>
                {(ytStats.by_creator || []).map((row, idx) => (
                  <div key={`creator-${idx}`} className="yt-analytics-row">
                    <span>{row.creator || "—"}</span>
                    <span>{row.tasks_count || 0}</span>
                    <span>{row.minutes ? Math.round(row.minutes / 60) : 0}</span>
                    <button
                      className="btn btn-secondary"
                      onClick={() =>
                        setSelectedCreator((prev) => (prev === row.creator ? null : row.creator))
                      }
                    >
                      {selectedCreator === row.creator ? "Скрыть" : "Задачи"}
                    </button>
                  </div>
                ))}
              </div>
              {selectedCreator && (
                <div className="yt-analytics-tasks">
                  <div className="yt-analytics-task-head">
                    <span>Задача</span>
                    <span>Направление</span>
                    <span>Постановщик</span>
                    <span>Исполнитель</span>
                    <span>Часы</span>
                  </div>
                  {(ytTasks || [])
                    .filter((t) => (t.created_by || "Не указан") === selectedCreator)
                    .map((t, idx) => (
                    <div key={`creator-task-${idx}`} className="yt-analytics-task-row">
                      <a className="yt-link mono" href={`${YT_BASE}${t.issue_id}`} target="_blank" rel="noreferrer">
                        {t.issue_id}
                      </a>
                      <span>{t.direction || "—"}</span>
                      <span>{t.created_by || "—"}</span>
                      <span>{t.assignee || "—"}</span>
                      <span>{t.minutes ? Math.round(t.minutes / 60) : 0} ч</span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="yt-analytics-block">
              <div className="section-subtitle">По исполнителям</div>
              <div className="yt-analytics-table">
                <div className="yt-analytics-head">
                  <span>Исполнитель</span>
                  <span>Задач</span>
                  <span>Часы</span>
                  <span></span>
                </div>
                {(ytStats.by_assignee || []).map((row, idx) => (
                  <div key={`assignee-${idx}`} className="yt-analytics-row">
                    <span>{row.assignee || "—"}</span>
                    <span>{row.tasks_count || 0}</span>
                    <span>{row.minutes ? Math.round(row.minutes / 60) : 0}</span>
                    <button
                      className="btn btn-secondary"
                      onClick={() =>
                        setSelectedAssignee((prev) => (prev === row.assignee ? null : row.assignee))
                      }
                    >
                      {selectedAssignee === row.assignee ? "Скрыть" : "Задачи"}
                    </button>
                  </div>
                ))}
              </div>
              {selectedAssignee && (
                <div className="yt-analytics-tasks">
                  <div className="yt-analytics-task-head">
                    <span>Задача</span>
                    <span>Направление</span>
                    <span>Постановщик</span>
                    <span>Исполнитель</span>
                    <span>Часы</span>
                  </div>
                  {(ytTasks || [])
                    .filter((t) => (t.assignee || "Не указан") === selectedAssignee)
                    .map((t, idx) => (
                    <div key={`assignee-task-${idx}`} className="yt-analytics-task-row">
                      <a className="yt-link mono" href={`${YT_BASE}${t.issue_id}`} target="_blank" rel="noreferrer">
                        {t.issue_id}
                      </a>
                      <span>{t.direction || "—"}</span>
                      <span>{t.created_by || "—"}</span>
                      <span>{t.assignee || "—"}</span>
                      <span>{t.minutes ? Math.round(t.minutes / 60) : 0} ч</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}
      </section>

      <section className="card release-analytics">
        <div className="section-title">Трудозатраты и частота изменений</div>
        {(ytStatsLoading || ytTasksLoading) && <div className="muted">Загрузка аналитики...</div>}
        {(ytStatsError || ytTasksError) && (
          <div className="dep-error-title">{ytStatsError || ytTasksError}</div>
        )}
        {!ytStatsLoading && !ytStatsError && ytStats && (
          <div className="yt-analytics-grid">
            <div className="yt-analytics-block">
              <div className="section-subtitle">По направлениям</div>
              <div className="yt-analytics-table">
                <div className="yt-analytics-head">
                  <span>Направление</span>
                  <span>Задач</span>
                  <span>Часы</span>
                  <span></span>
                </div>
                {(ytStats.by_direction || []).map((row, idx) => (
                  <div key={`dir-${idx}`} className="yt-analytics-row">
                    <span>{row.direction || "—"}</span>
                    <span>{row.tasks_count || 0}</span>
                    <span>{row.minutes ? Math.round(row.minutes / 60) : 0}</span>
                    <button
                      className="btn btn-secondary"
                      onClick={() =>
                        setSelectedDirection((prev) => (prev === row.direction ? null : row.direction))
                      }
                    >
                      {selectedDirection === row.direction ? "Скрыть" : "Задачи"}
                    </button>
                  </div>
                ))}
              </div>
              {selectedDirection && (
                <div className="yt-analytics-tasks">
                  <div className="yt-analytics-task-head">
                    <span>Задача</span>
                    <span>Направление</span>
                    <span>Постановщик</span>
                    <span>Исполнитель</span>
                    <span>Часы</span>
                  </div>
                  {(ytTasks || [])
                    .filter((t) => (t.direction || "Не указан") === selectedDirection)
                    .map((t, idx) => (
                    <div key={`dir-task-${idx}`} className="yt-analytics-task-row">
                      <a className="yt-link mono" href={`${YT_BASE}${t.issue_id}`} target="_blank" rel="noreferrer">
                        {t.issue_id}
                      </a>
                      <span>{t.direction || "—"}</span>
                      <span>{t.created_by || "—"}</span>
                      <span>{t.assignee || "—"}</span>
                      <span>{t.minutes ? Math.round(t.minutes / 60) : 0} ч</span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="yt-analytics-block">
              <div className="section-subtitle">По постановщикам</div>
              <div className="yt-analytics-table">
                <div className="yt-analytics-head">
                  <span>Постановщик</span>
                  <span>Задач</span>
                  <span>Часы</span>
                  <span></span>
                </div>
                {(ytStats.by_creator || []).map((row, idx) => (
                  <div key={`creator-${idx}`} className="yt-analytics-row">
                    <span>{row.creator || "—"}</span>
                    <span>{row.tasks_count || 0}</span>
                    <span>{row.minutes ? Math.round(row.minutes / 60) : 0}</span>
                    <button
                      className="btn btn-secondary"
                      onClick={() =>
                        setSelectedCreator((prev) => (prev === row.creator ? null : row.creator))
                      }
                    >
                      {selectedCreator === row.creator ? "Скрыть" : "Задачи"}
                    </button>
                  </div>
                ))}
              </div>
              {selectedCreator && (
                <div className="yt-analytics-tasks">
                  <div className="yt-analytics-task-head">
                    <span>Задача</span>
                    <span>Постановщик</span>
                    <span>Исполнитель</span>
                    <span>Направление</span>
                    <span>Часы</span>
                  </div>
                  {(ytTasks || [])
                    .filter((t) => (t.created_by || "Не указан") === selectedCreator)
                    .map((t, idx) => (
                    <div key={`creator-task-${idx}`} className="yt-analytics-task-row">
                      <a className="yt-link mono" href={`${YT_BASE}${t.issue_id}`} target="_blank" rel="noreferrer">
                        {t.issue_id}
                      </a>
                      <span>{t.created_by || "—"}</span>
                      <span>{t.assignee || "—"}</span>
                      <span>{t.direction || "—"}</span>
                      <span>{t.minutes ? Math.round(t.minutes / 60) : 0} ч</span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="yt-analytics-block">
              <div className="section-subtitle">По исполнителям</div>
              <div className="yt-analytics-table">
                <div className="yt-analytics-head">
                  <span>Исполнитель</span>
                  <span>Задач</span>
                  <span>Часы</span>
                  <span></span>
                </div>
                {(ytStats.by_assignee || []).map((row, idx) => (
                  <div key={`assignee-${idx}`} className="yt-analytics-row">
                    <span>{row.assignee || "—"}</span>
                    <span>{row.tasks_count || 0}</span>
                    <span>{row.minutes ? Math.round(row.minutes / 60) : 0}</span>
                    <button
                      className="btn btn-secondary"
                      onClick={() =>
                        setSelectedAssignee((prev) => (prev === row.assignee ? null : row.assignee))
                      }
                    >
                      {selectedAssignee === row.assignee ? "Скрыть" : "Задачи"}
                    </button>
                  </div>
                ))}
              </div>
              {selectedAssignee && (
                <div className="yt-analytics-tasks">
                  <div className="yt-analytics-task-head">
                    <span>Задача</span>
                    <span>Исполнитель</span>
                    <span>Постановщик</span>
                    <span>Направление</span>
                    <span>Часы</span>
                  </div>
                  {(ytTasks || [])
                    .filter((t) => (t.assignee || "Не указан") === selectedAssignee)
                    .map((t, idx) => (
                    <div key={`assignee-task-${idx}`} className="yt-analytics-task-row">
                      <a className="yt-link mono" href={`${YT_BASE}${t.issue_id}`} target="_blank" rel="noreferrer">
                        {t.issue_id}
                      </a>
                      <span>{t.assignee || "—"}</span>
                      <span>{t.created_by || "—"}</span>
                      <span>{t.direction || "—"}</span>
                      <span>{t.minutes ? Math.round(t.minutes / 60) : 0} ч</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
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
