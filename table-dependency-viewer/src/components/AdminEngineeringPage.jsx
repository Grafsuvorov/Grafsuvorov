import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ComposedChart,
  Legend,
  Line,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { adminApi } from "../api/admin.js";
import { formatLocalDateTime } from "../utils/datetime.js";

const DAY_OPTIONS = [30, 60, 90, 180, 365];
const REPORT_TABS = [
  { id: "releases", label: "Релизы" },
  { id: "team", label: "Команда" },
];
const RELEASE_SUBTABS = [
  { id: "overview", label: "Обзор" },
  { id: "exceptions", label: "Хотфиксы / Внерелизы" },
];
const RELEASE_BUCKET_LABELS = {
  release: "Релизы",
  hotfix: "Хотфиксы",
  outside_release: "Внерелизы",
};
const RELEASE_BUCKET_CLASSES = {
  release: "release",
  hotfix: "hotfix",
  outside_release: "outside",
};
const GENERIC_ENTITY_NAMES = new Set([
  "clickhouse",
  "greenplum",
  "gp",
  "click",
  "без сущности",
  "unknown",
  "null",
]);
const STATUS_CLASS = {
  Перегружен: "overloaded",
  Недогружен: "underloaded",
  Эффективен: "efficient",
  Стабильно: "stable",
};

function formatHours(value) {
  return `${Number(value || 0).toFixed(1)} ч`;
}

function formatMinutes(value) {
  const numeric = Number(value || 0);
  if (!numeric) return "0 мин";
  if (numeric >= 60) {
    return `${(numeric / 60).toFixed(1)} ч`;
  }
  return `${Math.round(numeric)} мин`;
}

function shortLabel(value, limit = 18) {
  if (!value) return "—";
  if (value.length <= limit) return value;
  return `${value.slice(0, limit - 1)}…`;
}

function formatDateTime(value) {
  if (!value) return "—";
  return formatLocalDateTime(value, { withSeconds: false });
}

function formatShortDate(value) {
  if (!value) return "—";
  return formatLocalDateTime(value, { dateStyle: "short", timeStyle: undefined });
}

function releaseBucketLabel(value) {
  return RELEASE_BUCKET_LABELS[value] || "Релизы";
}

function releaseBucketClass(value) {
  return RELEASE_BUCKET_CLASSES[value] || "release";
}

function normalizeEntityName(value) {
  return String(value || "")
    .trim()
    .toLowerCase();
}

function isMeaningfulEntityName(value) {
  const normalized = normalizeEntityName(value);
  if (!normalized) return false;
  return !GENERIC_ENTITY_NAMES.has(normalized);
}

function formatReleaseHeadline(row) {
  const type = String(row?.release_type || "").trim();
  if (type && type.length > 2 && !/^release$/i.test(type)) {
    return type;
  }
  return `${releaseBucketLabel(row?.release_bucket)} от ${formatShortDate(row?.started_at)}`;
}

function formatSystemLabel(value) {
  const normalized = String(value || "").trim().toLowerCase();
  if (normalized === "clickhouse") return "ClickHouse";
  if (normalized === "greenplum") return "Greenplum";
  return value || "Система";
}

export default function AdminEngineeringPage() {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState("releases");
  const [days, setDays] = useState(180);

  const [releaseData, setReleaseData] = useState(null);
  const [releaseLoading, setReleaseLoading] = useState(false);
  const [releaseError, setReleaseError] = useState(null);

  const [teamData, setTeamData] = useState(null);
  const [teamLoading, setTeamLoading] = useState(false);
  const [teamError, setTeamError] = useState(null);
  const [selectedEngineer, setSelectedEngineer] = useState(null);

  useEffect(() => {
    setReleaseLoading(true);
    setReleaseError(null);
    adminApi.releaseReports(days)
      .then((payload) => setReleaseData(payload || null))
      .catch((err) => setReleaseError(err.message || "Не удалось загрузить релизную аналитику"))
      .finally(() => setReleaseLoading(false));
  }, [days]);

  useEffect(() => {
    if (activeTab !== "team") return;
    setTeamLoading(true);
    setTeamError(null);
    adminApi.engineeringEfficiency(days)
      .then((payload) => setTeamData(payload || null))
      .catch((err) => setTeamError(err.message || "Не удалось загрузить аналитику команды"))
      .finally(() => setTeamLoading(false));
  }, [activeTab, days]);

  const engineers = teamData?.engineers || [];
  const selectedEngineerRow = useMemo(() => {
    if (!engineers.length) return null;
    return engineers.find((row) => row.engineer === selectedEngineer) || engineers[0];
  }, [engineers, selectedEngineer]);

  useEffect(() => {
    if (!engineers.length) {
      setSelectedEngineer(null);
      return;
    }
    if (!selectedEngineer || !engineers.some((row) => row.engineer === selectedEngineer)) {
      setSelectedEngineer(engineers[0].engineer);
    }
  }, [engineers, selectedEngineer]);

  const topEngineers = useMemo(
    () => engineers.slice(0, 8).map((row) => row.engineer),
    [engineers]
  );

  const dailyChart = useMemo(() => {
    const daysMap = new Map();
    (teamData?.daily_engineers || []).forEach((row) => {
      if (!topEngineers.includes(row.engineer)) return;
      const bucket = daysMap.get(row.day) || { day: row.day, totalHours: 0, totalTasks: 0 };
      bucket[row.engineer] = row.hours;
      bucket.totalHours += Number(row.hours || 0);
      bucket.totalTasks += Number(row.tasks_count || 0);
      daysMap.set(row.day, bucket);
    });
    return [...daysMap.values()];
  }, [teamData?.daily_engineers, topEngineers]);

  const schemaChart = useMemo(
    () => (teamData?.schema_breakdown || []).slice(0, 8),
    [teamData?.schema_breakdown]
  );

  const dashboardChart = useMemo(
    () => (teamData?.dashboard_report || []).slice(0, 8),
    [teamData?.dashboard_report]
  );

  return (
    <div className="container cc-page">
      <section className="card engineering-page reports-page">
        <div className="page-header engineering-header reports-header">
          <div>
            <h1>Репорты</h1>
            <div className="muted">Операционная аналитика по релизам, трудозатратам и изменяемости объектов.</div>
          </div>
          <div className="engineering-toolbar reports-toolbar">
            <span className="muted">Окно анализа</span>
            {DAY_OPTIONS.map((option) => (
              <button
                key={option}
                className={`btn ${days === option ? "btn-primary" : "btn-secondary"}`}
                onClick={() => setDays(option)}
              >
                {option} дн
              </button>
            ))}
          </div>
        </div>

        <div className="reports-tabs">
          {REPORT_TABS.map((tab) => (
            <button
              key={tab.id}
              type="button"
              className={`reports-tab ${activeTab === tab.id ? "active" : ""}`}
              onClick={() => setActiveTab(tab.id)}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {activeTab === "releases" ? (
          <ReleaseReportsTab
            data={releaseData}
            loading={releaseLoading}
            error={releaseError}
            onOpenTable={(schema, table) => navigate(`/table/${encodeURIComponent(schema)}/${encodeURIComponent(table)}`)}
            onOpenRelease={(releaseId) => navigate("/releases", { state: { releaseId } })}
          />
        ) : (
          <TeamEfficiencyTab
            data={teamData}
            loading={teamLoading}
            error={teamError}
            selectedEngineer={selectedEngineer}
            setSelectedEngineer={setSelectedEngineer}
            selectedEngineerRow={selectedEngineerRow}
            topEngineers={topEngineers}
            dailyChart={dailyChart}
            schemaChart={schemaChart}
            dashboardChart={dashboardChart}
          />
        )}
      </section>
    </div>
  );
}

function ReleaseReportsTab({ data, loading, error, onOpenTable, onOpenRelease }) {
  const [activeSubtab, setActiveSubtab] = useState("overview");
  const [selectedEntity, setSelectedEntity] = useState(null);
  const cadence = data?.cadence || [];
  const summary = data?.summary || {};
  const topEntities = data?.top_entities || [];
  const topTables = data?.top_tables || [];
  const topUsers = data?.top_users || [];
  const topCreators = data?.top_creators || [];
  const topInitiators = data?.top_initiators || [];
  const recentReleases = data?.recent_releases || [];
  const exceptionReleases = data?.exception_releases || [];
  const weekdayHeatmap = data?.weekday_heatmap || [];
  const typeBreakdown = data?.type_breakdown || [];
  const systemBreakdown = data?.system_breakdown || [];
  const entityTimeline = data?.entity_timeline || [];
  const focus = data?.focus || {};

  const displayTopEntities = useMemo(() => {
    const filtered = topEntities.filter((row) => isMeaningfulEntityName(row.entity_name));
    return filtered.length ? filtered : topEntities;
  }, [topEntities]);

  useEffect(() => {
    if (!displayTopEntities.length) {
      setSelectedEntity(null);
      return;
    }
    if (selectedEntity && displayTopEntities.some((row) => row.entity_name === selectedEntity)) {
      return;
    }
    setSelectedEntity(displayTopEntities[0].entity_name);
  }, [displayTopEntities, selectedEntity]);

  const peakWeek = useMemo(() => {
    if (!cadence.length) return null;
    return [...cadence].sort((a, b) => Number(b.releases_count || 0) - Number(a.releases_count || 0))[0] || null;
  }, [cadence]);

  const cadenceChart = useMemo(() => cadence.slice(-16), [cadence]);

  const entityOptions = useMemo(
    () => ["Все сущности", ...displayTopEntities.map((row) => row.entity_name)],
    [displayTopEntities]
  );

  const selectedEntityValue = selectedEntity || "Все сущности";
  const normalizedSelectedEntity = selectedEntityValue === "Все сущности" ? null : selectedEntityValue;

  const filteredTables = useMemo(() => {
    if (!normalizedSelectedEntity) return topTables;
    return topTables.filter((row) => (row.entity_names || []).includes(normalizedSelectedEntity));
  }, [topTables, normalizedSelectedEntity]);

  const filteredRecentReleases = useMemo(() => {
    if (!normalizedSelectedEntity) return recentReleases;
    return recentReleases.filter((row) => (row.entity_names || []).includes(normalizedSelectedEntity));
  }, [recentReleases, normalizedSelectedEntity]);

  const filteredExceptions = useMemo(() => {
    if (!normalizedSelectedEntity) return exceptionReleases;
    return exceptionReleases.filter((row) => (row.entity_names || []).includes(normalizedSelectedEntity));
  }, [exceptionReleases, normalizedSelectedEntity]);

  const selectedEntitySummary = useMemo(() => {
    if (!normalizedSelectedEntity) return null;
    return displayTopEntities.find((row) => row.entity_name === normalizedSelectedEntity) || null;
  }, [displayTopEntities, normalizedSelectedEntity]);

  const weekdayGrid = useMemo(() => {
    const labels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];
    const maxCount = Math.max(...weekdayHeatmap.map((row) => Number(row.releases_count || 0)), 0);
    return labels.map((label, index) => {
      const weekdayNo = index + 1;
      const rows = [];
      for (let hour = 0; hour < 24; hour += 1) {
        const hit = weekdayHeatmap.find((row) => Number(row.weekday_no) === weekdayNo && Number(row.hour_of_day) === hour);
        const count = Number(hit?.releases_count || 0);
        rows.push({
          hour,
          count,
          intensity: maxCount ? count / maxCount : 0,
          objects: Number(hit?.objects_count || 0),
          tasks: Number(hit?.tasks_count || 0),
        });
      }
      return { label, hours: rows };
    });
  }, [weekdayHeatmap]);

  const selectedEntityActivity = useMemo(() => {
    if (!normalizedSelectedEntity) return [];
    return entityTimeline.filter((row) => row.entity_name === normalizedSelectedEntity).slice(-6);
  }, [entityTimeline, normalizedSelectedEntity]);

  return (
    <>
      {error ? <div className="dev-meta-feedback error">{error}</div> : null}
      {loading ? <div className="muted">Загрузка релизной аналитики...</div> : null}

      {!loading && data && (
        <>
          <div className="reports-subtabs">
            {RELEASE_SUBTABS.map((tab) => (
              <button
                key={tab.id}
                type="button"
                className={`reports-subtab ${activeSubtab === tab.id ? "active" : ""}`}
                onClick={() => setActiveSubtab(tab.id)}
              >
                {tab.label}
              </button>
            ))}
          </div>

          <div className="release-report-kpis">
            <div className="release-report-kpi cube-release">
              <div className="label">Релизы</div>
              <div className="value">{summary.releases_count ?? 0}</div>
              <div className="hint">{summary.release_days_count ?? 0} дней с релизами</div>
            </div>
            <div className="release-report-kpi cube-objects">
              <div className="label">Объекты</div>
              <div className="value">{summary.objects_count ?? 0}</div>
              <div className="hint">{Number(summary.avg_objects_per_release || 0).toFixed(1)} на релиз</div>
            </div>
            <div className="release-report-kpi cube-hotfix">
              <div className="label">Хотфиксы</div>
              <div className="value">{summary.hotfix_count ?? 0}</div>
              <div className="hint">оперативные поставки</div>
            </div>
            <div className="release-report-kpi cube-outside">
              <div className="label">Внерелизы</div>
              <div className="value">{summary.outside_release_count ?? 0}</div>
              <div className="hint">отдельный поток</div>
            </div>
            <div className="release-report-kpi cube-hours">
              <div className="label">Трудозатраты</div>
              <div className="value">{formatHours(summary.hours_total)}</div>
              <div className="hint">{summary.tasks_count ?? 0} задач в поставках</div>
            </div>
            <div className="release-report-kpi cube-users">
              <div className="label">Люди</div>
              <div className="value">{summary.initiators_count ?? 0}</div>
              <div className="hint">{formatMinutes(summary.avg_duration_minutes)} средний цикл релиза</div>
            </div>
          </div>

          <div className="release-report-focus">
            <div className="release-report-focus-card">
              <div className="section-subtitle">Пик частоты</div>
              {peakWeek ? (
                <>
                  <div className="release-report-focus-title">{peakWeek.week_label}</div>
                  <div className="release-report-focus-meta">
                    <span>{peakWeek.releases_count} релизов</span>
                    <span>{peakWeek.objects_count} объектов</span>
                  </div>
                </>
              ) : (
                <div className="muted">Нет данных.</div>
              )}
            </div>
            <div className="release-report-focus-card">
              <div className="section-subtitle">Самая изменяемая сущность</div>
              {focus.top_entity ? (
                <>
                  <div className="release-report-focus-title">{focus.top_entity.entity_name}</div>
                  <div className="release-report-focus-meta">
                    <span>{focus.top_entity.objects_count} объектов</span>
                    <span>{focus.top_entity.releases_count} релизов</span>
                  </div>
                </>
              ) : (
                <div className="muted">Нет данных.</div>
              )}
            </div>
            <div className="release-report-focus-card">
              <div className="section-subtitle">Лидер по трудозатратам</div>
              {focus.top_user ? (
                <>
                  <div className="release-report-focus-title">{focus.top_user.engineer}</div>
                  <div className="release-report-focus-meta">
                    <span>{formatHours(focus.top_user.hours_total)}</span>
                    <span>{focus.top_user.releases_count} релизов</span>
                  </div>
                </>
              ) : (
                <div className="muted">Нет данных.</div>
              )}
            </div>
          </div>

          <div className="engineering-grid reports-grid-primary">
            <section className="engineering-block release-report-block">
              <div className="engineering-block-head">
                <div>
                  <div className="section-subtitle">Частота релизов по неделям</div>
                  <div className="muted">Последние недели: ритм поставок, хотфиксов и внерелизов без перегруженного масштаба.</div>
                </div>
              </div>
              <div className="engineering-chart release-report-chart-wide">
                <div className="release-report-chart-scroll">
                  <ResponsiveContainer width="100%" height="100%">
                    <ComposedChart data={cadenceChart} margin={{ top: 10, right: 12, left: 0, bottom: 10 }}>
                      <CartesianGrid strokeDasharray="3 3" stroke="rgba(148,163,184,0.14)" />
                      <XAxis dataKey="week_label" stroke="#94a3b8" />
                      <YAxis yAxisId="count" stroke="#94a3b8" />
                      <YAxis yAxisId="objects" orientation="right" stroke="#94a3b8" />
                      <Tooltip content={<CadenceTooltip />} />
                      <Legend />
                      <Bar yAxisId="count" dataKey="regular_release_count" stackId="releases" name="Релизы" fill="#38bdf8" radius={[5, 5, 0, 0]} />
                      <Bar yAxisId="count" dataKey="hotfix_count" stackId="releases" name="Хотфиксы" fill="#f59e0b" radius={[5, 5, 0, 0]} />
                      <Bar yAxisId="count" dataKey="outside_release_count" stackId="releases" name="Внерелизы" fill="#fb7185" radius={[5, 5, 0, 0]} />
                      <Line yAxisId="objects" type="monotone" dataKey="objects_count" name="Объекты" stroke="#0f766e" strokeWidth={2.5} dot={false} />
                    </ComposedChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </section>

            <section className="engineering-block release-report-block">
              <div className="engineering-block-head">
                <div>
                  <div className="section-subtitle">Срез по типам поставок</div>
                  <div className="muted">Где больше объема и сколько часов съедает каждый поток.</div>
                </div>
              </div>
              <div className="release-report-type-grid">
                {typeBreakdown.map((row) => (
                  <div key={row.release_bucket} className={`release-type-card bucket-${releaseBucketClass(row.release_bucket)}`}>
                    <div className="release-type-head">
                      <span>{releaseBucketLabel(row.release_bucket)}</span>
                      <span>{row.releases_count}</span>
                    </div>
                    <div className="release-type-metrics">
                      <strong>{row.objects_count}</strong>
                      <span>объектов</span>
                    </div>
                    <div className="release-type-foot">
                      <span>{row.tasks_count} задач</span>
                      <span>{formatHours(row.hours_total)}</span>
                    </div>
                  </div>
                ))}
              </div>

              <div className="release-system-strip">
                {systemBreakdown.map((row) => (
                  <div key={row.system_name} className="release-system-card">
                    <span className="label">{formatSystemLabel(row.system_name)}</span>
                    <strong>{row.objects_count}</strong>
                    <span className="hint">объектов в поставках</span>
                  </div>
                ))}
              </div>

              <div className="section-subtitle">Последние поставки</div>
              <div className="release-report-stream">
                {recentReleases.map((row) => (
                  <div key={row.release_id} className="release-report-stream-row">
                    <div className="release-report-stream-main">
                      <div className="release-report-stream-title">{formatReleaseHeadline(row)}</div>
                      <div className="release-report-stream-subline">
                        <span className="mono">{row.release_id}</span>
                        <span>{formatDateTime(row.started_at)}</span>
                      </div>
                    </div>
                    <div className="release-report-stream-meta">
                      <span className={`release-report-badge bucket-${releaseBucketClass(row.release_bucket)}`}>
                        {releaseBucketLabel(row.release_bucket)}
                      </span>
                      <span>{row.objects_count} объектов</span>
                      <span>{formatHours(row.hours_total)}</span>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          </div>

          {activeSubtab === "overview" ? (
            <>
              <div className="engineering-grid reports-grid-secondary">
                <section className="engineering-block release-report-block">
                  <div className="engineering-block-head">
                    <div>
                      <div className="section-subtitle">Сущности, которые меняются чаще всего</div>
                      <div className="muted">Выбор сущности ниже фильтрует таблицы и релизы справа.</div>
                    </div>
                  </div>
                  <div className="engineering-chart">
                    <ResponsiveContainer width="100%" height={300}>
                      <BarChart data={displayTopEntities} layout="vertical" margin={{ top: 10, right: 18, left: 18, bottom: 10 }}>
                        <CartesianGrid strokeDasharray="3 3" stroke="rgba(148,163,184,0.14)" />
                        <XAxis type="number" stroke="#94a3b8" />
                        <YAxis type="category" dataKey="entity_name" width={180} stroke="#94a3b8" tickFormatter={(value) => shortLabel(value, 24)} />
                        <Tooltip formatter={(value, key) => [value, key === "releases_count" ? "Релизы" : "Объекты"]} />
                        <Bar dataKey="releases_count" name="Релизы" fill="#0f766e" radius={[0, 8, 8, 0]} />
                      </BarChart>
                    </ResponsiveContainer>
                  </div>
                  <div className="reports-entity-chips">
                    {entityOptions.map((entityName) => (
                      <button
                        key={entityName}
                        type="button"
                        className={`reports-entity-chip ${selectedEntityValue === entityName ? "active" : ""}`}
                        onClick={() => setSelectedEntity(entityName === "Все сущности" ? null : entityName)}
                      >
                        {entityName}
                      </button>
                    ))}
                  </div>
                </section>

                <section className="engineering-block release-report-block">
                  <div className="section-subtitle">Heatmap по дням и часам релизов</div>
                  <div className="reports-heatmap">
                    <div className="reports-heatmap-head">
                      <span></span>
                      {Array.from({ length: 24 }).map((_, idx) => (
                        <span key={`hour-${idx}`}>{idx}</span>
                      ))}
                    </div>
                    {weekdayGrid.map((day) => (
                      <div key={day.label} className="reports-heatmap-row">
                        <span className="reports-heatmap-label">{day.label}</span>
                        {day.hours.map((cell) => (
                          <div
                            key={`${day.label}-${cell.hour}`}
                            className="reports-heatmap-cell"
                            title={`${day.label} ${String(cell.hour).padStart(2, "0")}:00 — ${cell.count} релизов, ${cell.objects} объектов, ${cell.tasks} задач`}
                            style={{
                              opacity: cell.count > 0 ? 0.18 + cell.intensity * 0.82 : 0.08,
                              background: cell.count > 0 ? "linear-gradient(180deg, #38bdf8, #2563eb)" : "rgba(148,163,184,0.12)",
                            }}
                          >
                            {cell.count > 0 ? cell.count : ""}
                          </div>
                        ))}
                      </div>
                    ))}
                  </div>
                </section>
              </div>

              <div className="engineering-grid reports-grid-secondary">
                <section className="engineering-block release-report-block">
                  <div className="engineering-block-head">
                    <div>
                      <div className="section-subtitle">Топ таблиц по числу изменений</div>
                      <div className="muted">
                        {normalizedSelectedEntity ? `Фокус: ${normalizedSelectedEntity}` : "Все сущности"}
                      </div>
                    </div>
                  </div>
                  <div className="engineering-table">
                    <div className="engineering-table-head release-report-table-row">
                      <span>Таблица</span>
                      <span>Релизы</span>
                      <span>Объекты</span>
                      <span>Задачи</span>
                      <span>Последнее изменение</span>
                    </div>
                    {filteredTables.map((row) => (
                      <button
                        key={`${row.schema_name}.${row.table_name}`}
                        type="button"
                        className="engineering-table-row release-report-table-row release-report-table-link"
                        onClick={() => onOpenTable(row.schema_name, row.table_name)}
                      >
                        <span className="mono engineering-cell-ellipsis" title={`${row.schema_name}.${row.table_name}`}>
                          {row.schema_name}.{row.table_name}
                        </span>
                        <span>{row.releases_count}</span>
                        <span>{row.objects_count}</span>
                        <span>{row.tasks_count}</span>
                        <span>{formatShortDate(row.last_change_at)}</span>
                      </button>
                    ))}
                    {filteredTables.length === 0 ? <div className="muted">Для этой сущности пока нет таблиц в топе.</div> : null}
                  </div>
                </section>

                <section className="engineering-block release-report-block">
                  <div className="engineering-block-head">
                    <div>
                      <div className="section-subtitle">Релизы по выбранной сущности</div>
                      <div className="muted">
                        {normalizedSelectedEntity ? `Фокус: ${normalizedSelectedEntity}` : "Последние релизы по всем сущностям"}
                      </div>
                    </div>
                  </div>
                  <div className="release-report-stream">
                    {filteredRecentReleases.map((row) => (
                      <button
                        key={row.release_id}
                        type="button"
                        className="release-report-stream-row release-report-stream-button"
                        onClick={() => onOpenRelease(row.release_id)}
                      >
                        <div className="release-report-stream-main">
                          <div className="release-report-stream-title">{formatReleaseHeadline(row)}</div>
                          <div className="release-report-stream-subline">
                            <span className="mono">{row.release_id}</span>
                            <span>{formatDateTime(row.started_at)}</span>
                          </div>
                        </div>
                        <div className="release-report-stream-meta">
                          <span className={`release-report-badge bucket-${releaseBucketClass(row.release_bucket)}`}>
                            {releaseBucketLabel(row.release_bucket)}
                          </span>
                          <span>{row.tasks_count} задач</span>
                          <span>{row.objects_count} объектов</span>
                          <span>{formatHours(row.hours_total)}</span>
                        </div>
                      </button>
                    ))}
                    {filteredRecentReleases.length === 0 ? <div className="muted">Нет релизов для выбранной сущности.</div> : null}
                  </div>
                </section>
              </div>

              <div className="engineering-grid reports-grid-secondary">
                <section className="engineering-block release-report-block">
                  <div className="section-subtitle">Исполнители</div>
                  <div className="engineering-table">
                    <div className="engineering-table-head release-report-users-row">
                      <span>Исполнитель</span>
                      <span>Часы</span>
                      <span>Релизы</span>
                      <span>Хотфиксы</span>
                      <span>Внерелизы</span>
                      <span>Задачи</span>
                    </div>
                    {topUsers.map((row) => (
                      <div key={row.engineer} className="engineering-table-row release-report-users-row">
                        <span className="engineering-primary" title={row.engineer}>{row.engineer}</span>
                        <span>{formatHours(row.hours_total)}</span>
                        <span>{row.releases_count}</span>
                        <span>{row.hotfix_count}</span>
                        <span>{row.outside_release_count}</span>
                        <span>{row.tasks_count}</span>
                      </div>
                    ))}
                  </div>
                </section>

                <section className="engineering-block release-report-block">
                  <div className="section-subtitle">Инициаторы релизов</div>
                  <div className="engineering-table">
                    <div className="engineering-table-head release-report-initiators-row">
                      <span>Инициатор</span>
                      <span>Релизы</span>
                      <span>Хотфиксы</span>
                      <span>Внерелизы</span>
                      <span>Объекты</span>
                      <span>Часы</span>
                    </div>
                    {topInitiators.map((row) => (
                      <div key={row.initiated_by} className="engineering-table-row release-report-initiators-row">
                        <span className="engineering-primary" title={row.initiated_by}>{row.initiated_by}</span>
                        <span>{row.releases_count}</span>
                        <span>{row.hotfix_count}</span>
                        <span>{row.outside_release_count}</span>
                        <span>{row.objects_count}</span>
                        <span>{formatHours(row.hours_total)}</span>
                      </div>
                    ))}
                  </div>
                </section>
              </div>

              <div className="engineering-grid reports-grid-secondary">
                <section className="engineering-block release-report-block">
                  <div className="engineering-block-head">
                    <div>
                      <div className="section-subtitle">Фокус по выбранной сущности</div>
                      <div className="muted">
                        {normalizedSelectedEntity ? normalizedSelectedEntity : "Выберите сущность из списка выше, чтобы увидеть концентрированный срез."}
                      </div>
                    </div>
                  </div>
                  {selectedEntitySummary ? (
                    <div className="release-entity-focus">
                      <div className="release-entity-focus-grid">
                        <div className="release-entity-focus-card">
                          <span className="label">Релизы</span>
                          <strong>{selectedEntitySummary.releases_count}</strong>
                        </div>
                        <div className="release-entity-focus-card">
                          <span className="label">Объекты</span>
                          <strong>{selectedEntitySummary.objects_count}</strong>
                        </div>
                        <div className="release-entity-focus-card">
                          <span className="label">Задачи</span>
                          <strong>{selectedEntitySummary.tasks_count}</strong>
                        </div>
                        <div className="release-entity-focus-card">
                          <span className="label">Последняя активность</span>
                          <strong>{formatShortDate(selectedEntitySummary.last_release_at)}</strong>
                        </div>
                      </div>
                      <div className="release-entity-focus-detail">
                        <div className="release-entity-focus-line">
                          <span>Хотфиксы</span>
                          <strong>{selectedEntitySummary.hotfix_count || 0}</strong>
                        </div>
                        <div className="release-entity-focus-line">
                          <span>Внерелизы</span>
                          <strong>{selectedEntitySummary.outside_release_count || 0}</strong>
                        </div>
                        <div className="release-entity-focus-line">
                          <span>Ключевые таблицы</span>
                          <strong>{filteredTables.length}</strong>
                        </div>
                      </div>
                      {selectedEntityActivity.length ? (
                        <div className="release-entity-activity">
                          {selectedEntityActivity.map((row) => (
                            <div key={`${row.entity_name}-${row.month_start}`} className="release-entity-activity-row">
                              <span>{row.month_label}</span>
                              <span>{row.releases_count} релизов</span>
                              <strong>{row.objects_count} объектов</strong>
                            </div>
                          ))}
                        </div>
                      ) : null}
                    </div>
                  ) : (
                    <div className="muted">Нет выбранной сущности для детального среза.</div>
                  )}
                </section>

                <section className="engineering-block release-report-block">
                  <div className="section-subtitle">Авторы задач</div>
                  <div className="engineering-table">
                    <div className="engineering-table-head release-report-users-row">
                      <span>Автор</span>
                      <span>Часы</span>
                      <span>Релизы</span>
                      <span>Хотфиксы</span>
                      <span>Внерелизы</span>
                      <span>Задачи</span>
                    </div>
                    {topCreators.map((row) => (
                      <div key={row.creator} className="engineering-table-row release-report-users-row">
                        <span className="engineering-primary" title={row.creator}>{row.creator}</span>
                        <span>{formatHours(row.hours_total)}</span>
                        <span>{row.releases_count}</span>
                        <span>{row.hotfix_count}</span>
                        <span>{row.outside_release_count}</span>
                        <span>{row.tasks_count}</span>
                      </div>
                    ))}
                  </div>
                </section>
              </div>
            </>
          ) : (
            <div className="engineering-grid reports-grid-secondary">
              <section className="engineering-block release-report-block">
                <div className="engineering-block-head">
                  <div>
                    <div className="section-subtitle">Хотфиксы и внерелизы</div>
                    <div className="muted">Исключения из штатного релизного контура.</div>
                  </div>
                </div>
                <div className="release-report-stream">
                  {filteredExceptions.map((row) => (
                    <button
                      key={`${row.release_id}-${row.release_bucket}`}
                      type="button"
                      className="release-report-stream-row release-report-stream-button"
                      onClick={() => onOpenRelease(row.release_id)}
                    >
                        <div className="release-report-stream-main">
                        <div className="release-report-stream-title">{formatReleaseHeadline(row)}</div>
                        <div className="release-report-stream-subline">
                          <span className="mono">{row.release_id}</span>
                          <span>{formatDateTime(row.started_at)}</span>
                        </div>
                      </div>
                      <div className="release-report-stream-meta">
                        <span className={`release-report-badge bucket-${releaseBucketClass(row.release_bucket)}`}>
                          {releaseBucketLabel(row.release_bucket)}
                        </span>
                        <span>{row.tasks_count} задач</span>
                        <span>{row.objects_count} объектов</span>
                        <span>{formatHours(row.hours_total)}</span>
                      </div>
                    </button>
                  ))}
                  {filteredExceptions.length === 0 ? <div className="muted">Исключений в выбранном срезе нет.</div> : null}
                </div>
              </section>

              <section className="engineering-block release-report-block">
                <div className="section-subtitle">Сущности в исключениях</div>
                <div className="engineering-table">
                  <div className="engineering-table-head release-report-exception-row">
                    <span>Сущность</span>
                    <span>Релизы</span>
                    <span>Хотфиксы</span>
                    <span>Внерелизы</span>
                  </div>
                  {topEntities
                    .filter((row) => Number(row.hotfix_count || 0) > 0 || Number(row.outside_release_count || 0) > 0)
                    .map((row) => (
                      <div key={row.entity_name} className="engineering-table-row release-report-exception-row">
                        <span className="engineering-primary" title={row.entity_name}>{row.entity_name}</span>
                        <span>{row.releases_count}</span>
                        <span>{row.hotfix_count}</span>
                        <span>{row.outside_release_count}</span>
                      </div>
                    ))}
                </div>
              </section>
            </div>
          )}
        </>
      )}
    </>
  );
}

function TeamEfficiencyTab({
  data,
  loading,
  error,
  selectedEngineer,
  setSelectedEngineer,
  selectedEngineerRow,
  topEngineers,
  dailyChart,
  schemaChart,
  dashboardChart,
}) {
  const engineers = data?.engineers || [];

  return (
    <>
      {error ? <div className="dev-meta-feedback error">{error}</div> : null}
      {loading ? <div className="muted">Загрузка аналитики команды...</div> : null}

      {!loading && data && (
        <>
          <div className="engineering-kpis">
            <div className="engineering-kpi">
              <div className="label">Задачи</div>
              <div className="value">{data.summary?.tasks_count ?? 0}</div>
              <div className="hint">в анализируемом окне</div>
            </div>
            <div className="engineering-kpi">
              <div className="label">Объекты</div>
              <div className="value">{data.summary?.objects_count ?? 0}</div>
              <div className="hint">release objects</div>
            </div>
            <div className="engineering-kpi">
              <div className="label">Часы</div>
              <div className="value">{formatHours(data.summary?.hours)}</div>
              <div className="hint">распределено по объектам</div>
            </div>
            <div className="engineering-kpi">
              <div className="label">Инженеры</div>
              <div className="value">{data.summary?.engineers_count ?? 0}</div>
              <div className="hint">с активностью в окне</div>
            </div>
          </div>

          <div className="engineering-focus-grid">
            <div className="engineering-focus-card focus-overloaded">
              <div className="section-subtitle">Риск перегруза</div>
              {(data.focus?.overloaded || []).length ? (
                (data.focus?.overloaded || []).map((row) => (
                  <button
                    key={`over-${row.engineer}`}
                    className="engineering-focus-row"
                    onClick={() => setSelectedEngineer(row.engineer)}
                  >
                    <span>{row.engineer}</span>
                    <span>{formatHours(row.hours)}</span>
                  </button>
                ))
              ) : (
                <div className="muted">Явного перегруза не видно.</div>
              )}
            </div>

            <div className="engineering-focus-card focus-efficient">
              <div className="section-subtitle">Высокая отдача</div>
              {(data.focus?.efficient || []).length ? (
                (data.focus?.efficient || []).map((row) => (
                  <button
                    key={`eff-${row.engineer}`}
                    className="engineering-focus-row"
                    onClick={() => setSelectedEngineer(row.engineer)}
                  >
                    <span>{row.engineer}</span>
                    <span>{row.tasks_count} задач</span>
                  </button>
                ))
              ) : (
                <div className="muted">Пока нет ярко выраженного лидера.</div>
              )}
            </div>

            <div className="engineering-focus-card focus-underloaded">
              <div className="section-subtitle">Низкая загрузка</div>
              {(data.focus?.underloaded || []).length ? (
                (data.focus?.underloaded || []).map((row) => (
                  <button
                    key={`under-${row.engineer}`}
                    className="engineering-focus-row"
                    onClick={() => setSelectedEngineer(row.engineer)}
                  >
                    <span>{row.engineer}</span>
                    <span>{formatHours(row.hours)}</span>
                  </button>
                ))
              ) : (
                <div className="muted">Сильной недогрузки не видно.</div>
              )}
            </div>
          </div>

          <div className="engineering-grid">
            <section className="engineering-block">
              <div className="section-subtitle">Нагрузка по дням</div>
              <div className="muted">Топ-8 инженеров по часам за период и общий ритм задач.</div>
              <div className="engineering-chart">
                <ComposedDailyChart data={dailyChart} topEngineers={topEngineers} />
              </div>
            </section>

            <section className="engineering-block">
              <div className="section-subtitle">Инженеры</div>
              <div className="engineering-table">
                <div className="engineering-table-head engineering-engineers-row">
                  <span>Инженер</span>
                  <span>Статус</span>
                  <span>Задачи</span>
                  <span>Объекты</span>
                  <span>Часы</span>
                  <span>Ч / задача</span>
                </div>
                {engineers.map((row) => (
                  <button
                    key={row.engineer}
                    className={`engineering-table-row engineering-engineers-row ${selectedEngineerRow?.engineer === row.engineer ? "active" : ""}`}
                    onClick={() => setSelectedEngineer(row.engineer)}
                  >
                    <span className="engineering-primary" title={row.engineer}>{row.engineer}</span>
                    <span className={`engineering-status status-${STATUS_CLASS[row.load_status] || "stable"}`}>
                      {row.load_status}
                    </span>
                    <span>{row.tasks_count}</span>
                    <span>{row.objects_count}</span>
                    <span>{formatHours(row.hours)}</span>
                    <span>{formatHours(row.avg_hours_per_task)}</span>
                  </button>
                ))}
              </div>
            </section>
          </div>

          <div className="engineering-grid engineering-grid-secondary">
            <section className="engineering-block">
              <div className="engineering-block-head">
                <div>
                  <div className="section-subtitle">Разбивка по схемам</div>
                  <div className="muted">
                    {selectedEngineerRow ? `Фокус: ${selectedEngineerRow.engineer}` : "Общая картина по схемам"}
                  </div>
                </div>
              </div>
              <div className="engineering-chart">
                <ResponsiveContainer width="100%" height={290}>
                  <BarChart
                    data={selectedEngineerRow?.schemas?.length ? selectedEngineerRow.schemas : schemaChart}
                    layout="vertical"
                    margin={{ top: 10, right: 16, left: 18, bottom: 10 }}
                  >
                    <CartesianGrid strokeDasharray="3 3" stroke="rgba(148,163,184,0.14)" />
                    <XAxis type="number" stroke="#94a3b8" />
                    <YAxis
                      type="category"
                      dataKey="schema_name"
                      width={90}
                      stroke="#94a3b8"
                      tickFormatter={(value) => shortLabel(value, 12)}
                    />
                    <Tooltip formatter={(value) => [formatHours(value), "Часы"]} />
                    <Bar dataKey="hours" radius={[0, 8, 8, 0]} fill="#38bdf8" />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </section>

            <section className="engineering-block">
              <div className="section-subtitle">По дашбордам КХД</div>
              <div className="engineering-chart">
                <ResponsiveContainer width="100%" height={290}>
                  <BarChart data={dashboardChart} margin={{ top: 10, right: 10, left: 0, bottom: 24 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="rgba(148,163,184,0.14)" />
                    <XAxis
                      dataKey="dashboard_direction"
                      stroke="#94a3b8"
                      angle={-18}
                      textAnchor="end"
                      interval={0}
                      height={70}
                      tickFormatter={(value) => shortLabel(value, 14)}
                    />
                    <YAxis stroke="#94a3b8" />
                    <Tooltip formatter={(value) => [formatHours(value), "Часы"]} />
                    <Bar dataKey="hours" radius={[8, 8, 0, 0]}>
                      {dashboardChart.map((row, index) => (
                        <Cell key={`dash-${row.dashboard_direction}`} fill={CHART_COLORS[index % CHART_COLORS.length]} />
                      ))}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </section>
          </div>

          <div className="engineering-grid engineering-grid-secondary">
            <section className="engineering-block">
              <div className="section-subtitle">Топ-30 объектов по времени</div>
              <div className="engineering-table">
                <div className="engineering-table-head engineering-object-row">
                  <span>Объект</span>
                  <span>Часы</span>
                  <span>Задачи</span>
                  <span>Изменения</span>
                  <span>Ведущий</span>
                </div>
                {(data.top_objects || []).map((row) => (
                  <div key={`${row.schema_name}.${row.table_name}`} className="engineering-table-row engineering-object-row">
                    <span className="mono engineering-cell-ellipsis" title={`${row.schema_name}.${row.table_name}`}>
                      {row.schema_name}.{row.table_name}
                    </span>
                    <span>{formatHours(row.hours)}</span>
                    <span>{row.tasks_count}</span>
                    <span>{row.changes_count}</span>
                    <span>{row.top_engineer}</span>
                  </div>
                ))}
              </div>
            </section>

            <section className="engineering-block">
              <div className="section-subtitle">Отчет по дашбордам</div>
              <div className="engineering-table">
                <div className="engineering-table-head engineering-dashboard-row">
                  <span>Дашборд</span>
                  <span>Часы</span>
                  <span>Задачи</span>
                  <span>Объекты</span>
                  <span>Ведущий</span>
                </div>
                {(data.dashboard_report || []).map((row) => (
                  <div key={row.dashboard_direction} className="engineering-table-row engineering-dashboard-row">
                    <span className="engineering-cell-ellipsis" title={row.dashboard_direction}>{row.dashboard_direction}</span>
                    <span>{formatHours(row.hours)}</span>
                    <span>{row.tasks_count}</span>
                    <span>{row.objects_count}</span>
                    <span>{row.top_engineer}</span>
                  </div>
                ))}
              </div>
            </section>
          </div>
        </>
      )}
    </>
  );
}

function CadenceTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  const row = payload[0]?.payload || {};
  return (
    <div className="yt-workload-tooltip">
      <div className="yt-workload-tooltip-title">Неделя {label}</div>
      <div className="yt-workload-tooltip-row"><span>Релизы</span><strong>{row.regular_release_count || 0}</strong></div>
      <div className="yt-workload-tooltip-row"><span>Хотфиксы</span><strong>{row.hotfix_count || 0}</strong></div>
      <div className="yt-workload-tooltip-row"><span>Внерелизы</span><strong>{row.outside_release_count || 0}</strong></div>
      <div className="yt-workload-tooltip-row"><span>Объекты</span><strong>{row.objects_count || 0}</strong></div>
      <div className="yt-workload-tooltip-row"><span>Задачи</span><strong>{row.tasks_count || 0}</strong></div>
    </div>
  );
}

function ComposedDailyChart({ data, topEngineers }) {
  return (
    <ResponsiveContainer width="100%" height="100%">
      <ComposedChart data={data} margin={{ top: 10, right: 14, left: 0, bottom: 10 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="rgba(148,163,184,0.14)" />
        <XAxis dataKey="day" stroke="#94a3b8" tickFormatter={(value) => value?.slice(5) || value} />
        <YAxis yAxisId="hours" stroke="#94a3b8" />
        <YAxis yAxisId="tasks" orientation="right" stroke="#94a3b8" />
        <Tooltip />
        <Legend />
        {topEngineers.map((engineer, idx) => (
          <Bar
            key={engineer}
            yAxisId="hours"
            dataKey={engineer}
            stackId="hours"
            fill={CHART_COLORS[idx % CHART_COLORS.length]}
          />
        ))}
        <Line yAxisId="tasks" type="monotone" dataKey="totalTasks" stroke="#f8fafc" strokeWidth={2} dot={false} />
      </ComposedChart>
    </ResponsiveContainer>
  );
}
