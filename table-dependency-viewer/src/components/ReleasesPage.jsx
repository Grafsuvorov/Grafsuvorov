import { useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import {
  ResponsiveContainer,
  ComposedChart,
  Bar,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ReferenceLine,
} from "recharts";
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
  const [ytTasksLoading, setYtTasksLoading] = useState(false);
  const [ytTasksError, setYtTasksError] = useState(null);
  const [ytWorkload, setYtWorkload] = useState([]);
  const [ytWorkloadLoading, setYtWorkloadLoading] = useState(false);
  const [ytWorkloadError, setYtWorkloadError] = useState(null);
  const analyticsDays = 30;

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
    setYtWorkloadLoading(true);
    setYtWorkloadError(null);
    fetch(`${API_BASE}/api/ytrek/workload?days=${analyticsDays}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить нагрузку по задачам")))
      .then((data) => setYtWorkload(Array.isArray(data) ? data : []))
      .catch((err) => setYtWorkloadError(typeof err === "string" ? err : "Не удалось загрузить нагрузку по задачам"))
      .finally(() => setYtWorkloadLoading(false));
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
  const visibleReleases = useMemo(() => items.slice(0, 5), [items]);
  const workloadChartWidth = useMemo(() => Math.max(900, ytWorkload.length * 56), [ytWorkload.length]);
  const formatDateTime = (value) => {
    if (!value) return "—";
    return formatLocalDateTime(value, { withSeconds: false });
  };

  const formatShortDay = (value) => {
    if (!value) return "—";
    const [year, month, day] = String(value).split("-");
    if (!year || !month || !day) return value;
    return `${day}.${month}`;
  };
  const releaseStatusClass = (status) => {
    const value = String(status || "").toLowerCase();
    if (!value) return "status-unknown";
    if (value.includes("success") || value.includes("loaded")) return "status-success";
    if (value.includes("fail") || value.includes("error")) return "status-failed";
    if (value.includes("run") || value.includes("queue") || value.includes("retry")) return "status-running";
    return "status-unknown";
  };

  const workloadSummary = useMemo(() => {
    if (!ytWorkload.length) return null;
    const peakActivity = [...ytWorkload].sort((a, b) => (b.total_activity || 0) - (a.total_activity || 0))[0] || null;
    const peakCreated = [...ytWorkload].sort((a, b) => (b.created_count || 0) - (a.created_count || 0))[0] || null;
    const releaseDays = ytWorkload.filter((row) => Number(row.release_count || 0) > 0);
    return {
      peakActivity,
      peakCreated,
      releaseDays: releaseDays.length,
    };
  }, [ytWorkload]);

  const releaseReferenceDays = useMemo(
    () => ytWorkload.filter((row) => Number(row.release_count || 0) > 0).map((row) => row.day),
    [ytWorkload],
  );

  const workloadTooltip = ({ active, payload, label }) => {
    if (!active || !payload?.length) return null;
    const data = payload[0]?.payload || {};
    return (
      <div className="yt-workload-tooltip">
        <div className="yt-workload-tooltip-title">{formatShortDay(label)}</div>
        <div className="yt-workload-tooltip-row">
          <span>Создано</span>
          <strong>{data.created_count || 0}</strong>
        </div>
        <div className="yt-workload-tooltip-row">
          <span>Назначено</span>
          <strong>{data.assigned_count || 0}</strong>
        </div>
        <div className="yt-workload-tooltip-row">
          <span>Взято в работу</span>
          <strong>{data.in_work_count || 0}</strong>
        </div>
        <div className="yt-workload-tooltip-row">
          <span>Ожидание релиза</span>
          <strong>{data.release_ready_count || 0}</strong>
        </div>
        <div className="yt-workload-tooltip-row">
          <span>Суммарная активность</span>
          <strong>{data.total_activity || 0}</strong>
        </div>
        {data.release_count ? (
          <div className="yt-workload-tooltip-row highlight">
            <span>Релизов в день</span>
            <strong>{data.release_count}</strong>
          </div>
        ) : null}
      </div>
    );
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
            {visibleReleases.map((row) => (
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
        {!loading && !error && items.length > 5 && (
          <div className="muted release-limit-note">Показаны 5 последних релизов из {items.length}.</div>
        )}
      </section>

      <section className="card release-analytics">
        <div className="section-title">Трудозатраты и частота изменений</div>
          <div className="yt-workload-shell">
            <div className="yt-workload-head">
              <div>
                <div className="section-subtitle">Нагрузка по задачам по дням</div>
                <div className="muted">
                  Видно, когда задачи создавались, назначались, брались в работу и доходили до ожидания релиза.
                </div>
              </div>
              <div className="yt-workload-note muted">
                Вертикальные маркеры показывают дни релизов.
              </div>
            </div>
            {(ytWorkloadLoading || ytWorkloadError) && (
              <div className={ytWorkloadError ? "dep-error-title" : "muted"}>
                {ytWorkloadError || "Загрузка графика..."}
              </div>
            )}
            {!ytWorkloadLoading && !ytWorkloadError && workloadSummary && (
              <div className="yt-workload-kpis">
                <div className="yt-workload-kpi">
                  <div className="label">Пик активности</div>
                  <div className="value">{workloadSummary.peakActivity?.total_activity || 0}</div>
                  <div className="hint">{formatShortDay(workloadSummary.peakActivity?.day)}</div>
                </div>
                <div className="yt-workload-kpi">
                  <div className="label">Пик новых задач</div>
                  <div className="value">{workloadSummary.peakCreated?.created_count || 0}</div>
                  <div className="hint">{formatShortDay(workloadSummary.peakCreated?.day)}</div>
                </div>
                <div className="yt-workload-kpi">
                  <div className="label">Дней с релизами</div>
                  <div className="value">{workloadSummary.releaseDays}</div>
                  <div className="hint">в окне {analyticsDays} дней</div>
                </div>
              </div>
            )}
            {!ytWorkloadLoading && !ytWorkloadError && ytWorkload.length > 0 && (
              <div className="yt-workload-chart-scroll">
                <div className="yt-workload-chart" style={{ minWidth: `${workloadChartWidth}px` }}>
                <ResponsiveContainer width="100%" height={340}>
                  <ComposedChart data={ytWorkload} margin={{ top: 16, right: 18, left: -8, bottom: 8 }}>
                    <CartesianGrid stroke="rgba(148,163,184,0.12)" vertical={false} />
                    <XAxis
                      dataKey="day"
                      tickFormatter={formatShortDay}
                      fontSize={12}
                      minTickGap={20}
                    />
                    <YAxis allowDecimals={false} fontSize={12} width={28} />
                    <Tooltip content={workloadTooltip} />
                    <Legend wrapperStyle={{ fontSize: 12 }} />
                    {releaseReferenceDays.map((day) => (
                      <ReferenceLine
                        key={day}
                        x={day}
                        stroke="rgba(251,191,36,0.78)"
                        strokeDasharray="4 4"
                      />
                    ))}
                    <Area
                      type="monotone"
                      dataKey="total_activity"
                      name="Общая активность"
                      stroke="#f59e0b"
                      fill="rgba(245,158,11,0.16)"
                      strokeWidth={2.2}
                    />
                    <Bar dataKey="created_count" name="Создано" fill="#60a5fa" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="assigned_count" name="Назначено" fill="#34d399" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="in_work_count" name="Взято в работу" fill="#f97316" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="release_ready_count" name="Ожидание релиза" fill="#a78bfa" radius={[4, 4, 0, 0]} />
                  </ComposedChart>
                </ResponsiveContainer>
                </div>
              </div>
            )}
          </div>
        {(ytTasksLoading || ytTasksError) && null}
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
                  <span className={`status-pill ${releaseStatusClass(obj.final_status)}`}>
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
