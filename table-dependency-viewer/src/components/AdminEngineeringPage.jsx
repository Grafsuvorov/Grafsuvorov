import { useEffect, useMemo, useState } from "react";
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
const DAY_OPTIONS = [30, 60, 90, 180, 365];
const CHART_COLORS = ["#38bdf8", "#f59e0b", "#34d399", "#f97316", "#a78bfa", "#fb7185"];
const STATUS_CLASS = {
  "Перегружен": "overloaded",
  "Недогружен": "underloaded",
  "Эффективен": "efficient",
  "Стабильно": "stable",
};

function formatHours(value) {
  return `${Number(value || 0).toFixed(1)} ч`;
}

function shortLabel(value, limit = 18) {
  if (!value) return "—";
  if (value.length <= limit) return value;
  return `${value.slice(0, limit - 1)}…`;
}

export default function AdminEngineeringPage({ userProfile }) {
  const [days, setDays] = useState(90);
  const [data, setData] = useState(null);
  const [selectedEngineer, setSelectedEngineer] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (userProfile?.role !== "admin") return;
    setLoading(true);
    setError(null);
    adminApi.engineeringEfficiency(days)
      .then((payload) => {
        setData(payload || null);
      })
      .catch((err) => {
        setError(err.message || "Не удалось загрузить аналитику");
      })
      .finally(() => setLoading(false));
  }, [days, userProfile?.role]);

  const engineers = data?.engineers || [];
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
    () => engineers.slice(0, 6).map((row) => row.engineer),
    [engineers]
  );

  const dailyChart = useMemo(() => {
    const daysMap = new Map();
    (data?.daily_engineers || []).forEach((row) => {
      if (!topEngineers.includes(row.engineer)) return;
      const bucket = daysMap.get(row.day) || { day: row.day, totalHours: 0, totalTasks: 0 };
      bucket[row.engineer] = row.hours;
      bucket.totalHours += Number(row.hours || 0);
      bucket.totalTasks += Number(row.tasks_count || 0);
      daysMap.set(row.day, bucket);
    });
    return [...daysMap.values()];
  }, [data?.daily_engineers, topEngineers]);

  const schemaChart = useMemo(
    () => (data?.schema_breakdown || []).slice(0, 8),
    [data?.schema_breakdown]
  );

  const dashboardChart = useMemo(
    () => (data?.dashboard_report || []).slice(0, 8),
    [data?.dashboard_report]
  );

  if (userProfile?.role !== "admin") {
    return (
      <div className="container cc-page">
        <div className="cc-surface">
          <div className="section-title">Доступ запрещён</div>
          <div className="muted">Требуется роль администратора.</div>
        </div>
      </div>
    );
  }

  return (
    <div className="container cc-page">
      <section className="card engineering-page">
        <div className="page-header engineering-header">
          <div>
            <h1>Эффективность команды</h1>
            <div className="muted">Нагрузка, выпуск и перекосы по инженерам, схемам, объектам и дашбордам.</div>
          </div>
          <div className="engineering-toolbar">
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

        {error ? <div className="dev-meta-feedback error">{error}</div> : null}
        {loading ? <div className="muted">Загрузка аналитики...</div> : null}

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
                <div className="section-subtitle">Перегружены</div>
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
                <div className="section-subtitle">Молодцы</div>
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
                <div className="section-subtitle">Недогружены</div>
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
                <div className="muted">Топ инженеров по часам и общий ритм задач.</div>
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
                <div className="section-subtitle">Дашборды</div>
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
                      <span className="mono" title={`${row.schema_name}.${row.table_name}`}>
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
                      <span title={row.dashboard_direction}>{row.dashboard_direction}</span>
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
      </section>
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
