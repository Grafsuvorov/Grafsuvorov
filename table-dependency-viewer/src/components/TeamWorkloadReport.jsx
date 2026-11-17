import { useEffect, useMemo, useState } from "react";
import { Bar, BarChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { formatLocalDateTime } from "../utils/datetime.js";
import "../style/team-workload.css";

const CATEGORIES = [{ id: "all", label: "Все задачи" }, { id: "tech_etl", label: "Витрины · Tech ETL" }, { id: "other", label: "Разработка и текучка" }];
const hours = (n) => n == null ? "—" : `${Number(n).toLocaleString("ru-RU", { maximumFractionDigits: 1 })} ч`;
const duration = (n) => n == null ? "—" : `${Number(n).toLocaleString("ru-RU", { maximumFractionDigits: 1 })} дн`;
const date = (v) => v ? formatLocalDateTime(v, { withSeconds: false }) : "—";
const average = (values) => values.length ? values.reduce((a, b) => a + b, 0) / values.length : null;
const safeUrl = (value) => /^https?:\/\//i.test(value || "") ? value : undefined;
const CHART_TOOLTIP = { contentStyle: { background: "var(--tw-surface)", color: "var(--tw-text)", border: "1px solid var(--tw-border)", borderRadius: 12 } };

function exportTasks(tasks) {
  const columns = ["Задача", "Название", "Исполнитель", "Категория", "Статус", "Создана", "Завершена", "Часы за период", "Часы всего", "Возраст, дни", "Объекты"];
  const cell = (v) => {
    let value = String(v ?? "");
    if (/^[=+@-]/.test(value)) value = `'${value}`;
    return `"${value.replaceAll('"', '""')}"`;
  };
  const lines = tasks.map((t) => [t.issue_id, t.summary, t.owner_name || t.assignee, t.category === "tech_etl" ? "Tech ETL" : "Другие", t.state, t.created_at, t.resolved_at, t.hours, t.lifetime_hours, t.age_days, t.objects.join(", ")]);
  const url = URL.createObjectURL(new Blob(["\uFEFF", [columns, ...lines].map((r) => r.map(cell).join(";")).join("\r\n")], { type: "text/csv;charset=utf-8" }));
  const link = document.createElement("a"); link.href = url; link.download = "team-workload.csv"; link.click(); URL.revokeObjectURL(url);
}

export default function TeamWorkloadReport({ data, loading, error, onRefresh }) {
  const [category, setCategory] = useState("all");
  const [selectedId, setSelectedId] = useState(null);
  const [status, setStatus] = useState("open");
  const [search, setSearch] = useState("");
  const [includeInactive, setIncludeInactive] = useState(false);
  const [sort, setSort] = useState("open_count");
  const [hoursPerDay, setHoursPerDay] = useState(8);
  const [page, setPage] = useState(1);
  const tasks = useMemo(() => (data?.tasks || []).filter((t) => category === "all" || t.category === category), [data, category]);
  const employees = useMemo(() => (data?.engineers || []).filter((e) => includeInactive || e.is_active).map((employee) => {
    const owned = tasks.filter((t) => t.owner_id === employee.user_id);
    const open = owned.filter((t) => t.is_open);
    const closed = owned.filter((t) => t.closed_in_period);
    const completed = closed.filter((t) => t.status_group === "completed");
    const tracked = completed.filter((t) => t.lifetime_hours > 0);
    return { ...employee,
      open_count: open.length, tech_etl_open: open.filter((t) => t.category === "tech_etl").length,
      other_open: open.filter((t) => t.category === "other").length, closed_count: closed.length,
      closed_total: owned.filter((t) => !t.is_open).length,
      closed_without_date: owned.filter((t) => !t.is_open && !t.resolved_at).length,
      cancelled_total: owned.filter((t) => t.status_group === "cancelled").length,
      hours: category === "all" ? employee.hours : category === "tech_etl" ? employee.tech_etl_hours : employee.other_hours,
      avg_task_hours: average(tracked.map((t) => t.lifetime_hours)), tracked_closed_count: tracked.length,
      avg_cycle_days: average(completed.map((t) => t.cycle_days).filter((v) => v != null)),
      stale_count: open.filter((t) => t.stale_days >= 14).length,
      oldest_days: open.length ? Math.max(...open.map((t) => t.age_days || 0)) : null,
    };
  }).sort((a, b) => (b[sort] || 0) - (a[sort] || 0) || a.engineer.localeCompare(b.engineer)), [data, tasks, category, includeInactive, sort]);
  useEffect(() => {
    if (selectedId !== "unmatched" && !employees.some((e) => e.user_id === selectedId)) setSelectedId(employees[0]?.user_id ?? null);
  }, [employees, selectedId]);
  useEffect(() => { setPage(1); }, [selectedId, status, category, search, data]);
  const selected = employees.find((e) => e.user_id === selectedId);
  const unmatched = tasks.filter((t) => t.owner_id == null && t.is_open);
  const employeeIds = new Set(employees.map((e) => e.user_id));
  const completed = tasks.filter((t) => employeeIds.has(t.owner_id) && t.closed_in_period);
  const measured = completed.filter((t) => t.status_group === "completed" && t.lifetime_hours > 0);
  const allClosed = tasks.filter((t) => employeeIds.has(t.owner_id) && !t.is_open);
  const undatedClosed = allClosed.filter((t) => !t.resolved_at);
  const filteredTasks = tasks.filter((t) => {
    const contribution = t.contributions.find((c) => c.user_id === selectedId);
    const ownerMatch = selectedId === "unmatched" ? t.owner_id == null : t.owner_id === selectedId;
    const matches = status === "worked" ? (selectedId !== "unmatched" && contribution?.hours > 0) : ownerMatch && (status === "open" ? t.is_open : status === "closed" ? t.closed_in_period : status === "closed_all" ? !t.is_open : true);
    return matches && `${t.issue_id} ${t.summary} ${t.state} ${t.objects.join(" ")} ${t.initiator_email || ""}`.toLowerCase().includes(search.toLowerCase());
  }).sort((a, b) => status === "open" ? (b.age_days || 0) - (a.age_days || 0) : String(b.resolved_at || b.updated_at || "").localeCompare(String(a.resolved_at || a.updated_at || "")));
  const daily = useMemo(() => {
    const rows = new Map();
    for (const row of data?.daily || []) {
      if (selectedId !== null && row.user_id !== selectedId) continue;
      const day = rows.get(row.day) || { day: row.day, tech_etl: 0, other: 0 };
      if (category !== "other") day.tech_etl += row.tech_etl;
      if (category !== "tech_etl") day.other += row.other;
      rows.set(row.day, day);
    }
    return [...rows.values()].sort((a, b) => a.day.localeCompare(b.day));
  }, [data, selectedId, category]);
  if (loading) return <div className="tw-loading" role="status">Собираем портфель задач и трудозатраты команды…</div>;
  if (error) return <div className="tw-error" role="alert"><p>{error}</p><button className="btn btn-secondary" onClick={onRefresh}>Повторить загрузку</button></div>;
  if (!data) return null;
  const totalHours = employees.reduce((sum, e) => sum + e.hours, 0);
  const capacity = data.working_days * hoursPerDay;
  const kpis = [
    ["Открытый портфель", employees.reduce((n, e) => n + e.open_count, 0), "Все незавершённые, независимо от даты создания", "blue"],
    ["Закрыто в срезе", allClosed.length, `${completed.length} за период · ${undatedClosed.length} без даты · ${allClosed.filter((t) => t.status_group === "cancelled").length} отменено / дубли`, "green"],
    ["Списано за период", hours(totalHours), "Личные трудозатраты по дате worklog", "purple"],
    ["В среднем на задачу", hours(average(measured.map((t) => t.lifetime_hours))), `Полные трудозатраты · ${measured.length} завершённых с учётом времени (без отмен и дублей)`, "amber"],
  ];
  return <div className="tw-report">
    <div className="tw-heading"><div><div className="tw-eyebrow">КОМАНДА / ОПЕРАЦИОННЫЙ ОБЗОР</div><h2>Кто чем занят</h2><p>Открытые задачи сейчас, результат и трудозатраты за {data.days} дней.</p></div><button className="btn btn-secondary" onClick={onRefresh}>Обновить</button></div>
    <div className="tw-controls"><div className="tw-segments" aria-label="Категория задач">{CATEGORIES.map((c) => <button key={c.id} aria-pressed={category === c.id} className={category === c.id ? "active" : ""} onClick={() => setCategory(c.id)}>{c.label}</button>)}</div><label className="tw-checkbox"><input type="checkbox" checked={includeInactive} onChange={(e) => setIncludeInactive(e.target.checked)} /> Включить отключённых пользователей</label></div>
    <div className="tw-kpis">{kpis.map(([label, value, hint, color]) => <article className={`tw-kpi ${color}`} key={label}><span>{label}</span><strong>{value}</strong><small>{hint}</small></article>)}</div>
    <div className="tw-context"><span>Срез: <b>{date(data.snapshot_loaded_at)}</b></span><span>Самая ранняя загрузка: {date(data.oldest_snapshot_at)}</span><button onClick={() => { setSelectedId("unmatched"); setStatus("open"); }}>Без сопоставленного исполнителя: <b>{unmatched.length}</b> ↗</button></div>
    {!data.tasks.length && <div className="tw-empty">В срезе пока нет задач. Загрузите задачи YouTrack, включая задачи вне релизов, и обновите отчёт.</div>}
    <section className="tw-panel"><div className="tw-panel-title"><div><h3>Портфель сотрудников</h3><p>Выберите сотрудника, чтобы посмотреть его задачи. Часы учитываются один раз по автору worklog.</p></div><label>Сортировка <select value={sort} onChange={(e) => setSort(e.target.value)}><option value="open_count">По открытым задачам</option><option value="hours">По списанным часам</option><option value="closed_total">По закрытым в срезе</option><option value="oldest_days">По возрасту задач</option></select></label></div>
      <div className="tw-table-scroll"><table className="tw-people"><thead><tr><th>Сотрудник</th><th>Портфель сейчас</th><th>Закрыто в срезе</th><th>Списано</th><th>Учёт времени / фонд</th><th>Часы / задача</th><th>До закрытия</th><th>Без обновлений ≥14 дн</th></tr></thead><tbody>{employees.map((e) => {
        const ratio = capacity ? e.hours / capacity * 100 : null;
        return <tr key={e.user_id} className={selectedId === e.user_id ? "selected" : ""}><td><button className="tw-person" aria-pressed={selectedId === e.user_id} onClick={() => { setSelectedId(e.user_id); setStatus("open"); }}><span className="tw-avatar">{e.engineer.slice(0, 2).toUpperCase()}</span><span><strong>{e.engineer}</strong><small>{e.role === "admin" ? "Администратор" : "Инженер"}{!e.is_active ? " · отключён" : ""}</small><small>{e.email}</small></span></button></td><td><strong className="tw-count">{e.open_count}</strong><div className="tw-split"><span className="tw-dot blue" />{e.tech_etl_open} витрины <span className="tw-dot purple" />{e.other_open} другие</div></td><td><strong>{e.closed_total}</strong><small>{e.closed_count} за период</small>{e.closed_without_date > 0 && <small>{e.closed_without_date} без даты</small>}{e.cancelled_total > 0 && <small>{e.cancelled_total} отменено / дубли</small>}</td><td><strong>{hours(e.hours)}</strong></td><td><div className="tw-meter"><i style={{ width: `${Math.min(ratio || 0, 100)}%` }} /></div><small>{ratio == null ? "—" : `${Math.round(ratio)}%`} из {hours(capacity)}</small></td><td>{hours(e.avg_task_hours)}<small>{e.tracked_closed_count} закрытых с учётом</small></td><td>{duration(e.avg_cycle_days)}<small>календарных, в среднем</small></td><td><span className={e.stale_count ? "tw-alert-count" : ""}>{e.stale_count}</span></td></tr>;
      })}</tbody></table></div>{!employees.length && <div className="tw-empty">Нет пользователей с ролями engineer и admin в выбранном составе.</div>}
      <div className="tw-method-inline"><label>Рабочий день <select value={hoursPerDay} onChange={(e) => setHoursPerDay(Number(e.target.value))}>{[4, 6, 8].map((v) => <option key={v} value={v}>{v} ч</option>)}</select></label><span>Фонд: {data.working_days} будних дней, без праздников и отпусков. Доля списанных часов показывает полноту учёта времени, а не свободную ёмкость сотрудника.</span></div>
    </section>
    <div className="tw-charts"><section className="tw-panel"><div className="tw-panel-title"><div><h3>Как распределён портфель</h3><p>До 12 сотрудников с наибольшим количеством открытых задач.</p></div></div>{employees.some((e) => e.open_count) ? <ResponsiveContainer width="100%" height={Math.max(220, Math.min(employees.length, 12) * 42)}><BarChart data={[...employees].sort((a, b) => b.open_count - a.open_count).slice(0, 12)} layout="vertical" margin={{ left: 0, right: 24 }}><CartesianGrid strokeDasharray="3 3" horizontal={false} opacity={0.15} /><XAxis type="number" allowDecimals={false} /><YAxis type="category" dataKey="engineer" width={120} tick={{ fontSize: 11 }} /><Tooltip {...CHART_TOOLTIP} /><Legend /><Bar isAnimationActive={false} dataKey="tech_etl_open" name="Витрины · Tech ETL" stackId="tasks" fill="#38bdf8" /><Bar isAnimationActive={false} dataKey="other_open" name="Другие задачи" stackId="tasks" fill="#a78bfa" radius={[0, 4, 4, 0]} /></BarChart></ResponsiveContainer> : <div className="tw-empty">Открытых задач в выбранном срезе нет.</div>}</section>
    <section className="tw-panel"><div className="tw-panel-title"><div><h3>Ритм работы · {selected?.engineer || "выберите сотрудника"}</h3><p>Часы по фактической дате списания.</p></div></div>{daily.length ? <ResponsiveContainer width="100%" height={260}><BarChart data={daily} margin={{ right: 16 }}><CartesianGrid strokeDasharray="3 3" vertical={false} opacity={0.15} /><XAxis dataKey="day" tickFormatter={(v) => v.slice(5).split("-").reverse().join(".")} tick={{ fontSize: 11 }} /><YAxis /><Tooltip {...CHART_TOOLTIP} formatter={(v, name) => [hours(v), name]} /><Legend /><Bar isAnimationActive={false} dataKey="tech_etl" name="Витрины · Tech ETL" stackId="hours" fill="#38bdf8" /><Bar isAnimationActive={false} dataKey="other" name="Другие задачи" stackId="hours" fill="#a78bfa" radius={[4, 4, 0, 0]} /></BarChart></ResponsiveContainer> : <div className="tw-empty">За период нет списанных часов в выбранной категории.</div>}</section></div>
    <section className="tw-panel"><div className="tw-panel-title"><div><div className="tw-eyebrow">ДЕТАЛИ ПОРТФЕЛЯ</div><h3>{selectedId === "unmatched" ? "Без сопоставленного исполнителя" : selected?.engineer || "Выберите сотрудника"}</h3><p>{selectedId === "unmatched" ? "Исполнитель отсутствует, не найден среди engineer/admin или совпадение неоднозначно." : `${selected?.email || ""} · Самая старая открытая задача: ${duration(selected?.oldest_days)}`}</p></div><button className="btn btn-secondary" disabled={!filteredTasks.length} onClick={() => exportTasks(filteredTasks)}>Скачать CSV</button></div>
      <div className="tw-controls"><div className="tw-segments">{[["open", "Открытые"], ["closed", "Закрытые за период"], ["closed_all", "Все закрытые"], ["worked", "Списывал время"]].filter(([id]) => selectedId !== "unmatched" || id !== "worked").map(([id, label]) => <button key={id} aria-pressed={status === id} className={status === id ? "active" : ""} onClick={() => setStatus(id)}>{label}</button>)}</div><input className="tw-search" aria-label="Поиск задач" placeholder="Задача, витрина, инициатор…" value={search} onChange={(e) => setSearch(e.target.value)} /></div>
      <div className="tw-task-list">{filteredTasks.slice((page - 1) * 25, page * 25).map((t) => <article className="tw-task" key={t.issue_id}><div className="tw-task-main"><div className="tw-task-meta"><a href={safeUrl(t.url)} target="_blank" rel="noreferrer">{t.issue_id} ↗</a><span className={`tw-badge ${t.category === "tech_etl" ? "blue" : "purple"}`}>{t.category === "tech_etl" ? "Tech ETL · витрины" : "Другие задачи"}</span><span className="tw-badge">{t.state}</span></div><h4>{t.summary}</h4><div className="tw-task-detail">Исполнитель: {t.owner_name || t.assignee || "не назначен"}{t.initiator_email ? ` · Инициатор: ${t.initiator_email}` : ""}</div>{t.objects.length > 0 && <div className="tw-objects">{t.objects.map((fqn) => <span key={fqn}>{fqn}</span>)}</div>}<div className="tw-task-links"><span title={t.origin_evidence}>{t.origin_evidence}</span>{t.assignment_source === "state_author" && <span>Исполнитель по автору перехода статуса</span>}{t.assignment_source === "assignee_history" && <span>Исполнитель из истории назначений</span>}{t.mr_url && <a href={safeUrl(t.mr_url)} target="_blank" rel="noreferrer">Merge request ↗</a>}{t.parent_issue && <span>Родитель: {t.parent_issue}</span>}</div></div><div className="tw-task-stats"><div><small>{t.is_open ? "Возраст" : "До закрытия"}</small><strong>{duration(t.is_open ? t.age_days : t.cycle_days)}</strong></div><div><small>Часы за период / всего</small><strong>{hours(t.hours)} / {hours(t.lifetime_hours)}</strong></div>{status === "worked" && <div><small>Лично за период</small><strong>{hours(t.contributions.find((c) => c.user_id === selectedId)?.hours)}</strong></div>}<small>{t.is_open ? `Обновлена: ${date(t.updated_at)}` : t.resolved_at ? `Закрыта: ${date(t.resolved_at)}${t.closed_at_source === "state_history" ? " · из истории статуса" : ""}` : "Дата закрытия не загружена"}</small>{t.is_open && t.stale_days >= 14 && <span className="tw-stale">Без обновлений {Math.floor(t.stale_days)} дн</span>}</div></article>)}</div>
      {!filteredTasks.length && <div className="tw-empty">Задач по выбранным условиям нет.</div>}
      <div className="tw-pagination"><span>{filteredTasks.length} задач · страница {page} из {Math.max(1, Math.ceil(filteredTasks.length / 25))}</span><div><button className="btn btn-secondary" disabled={page <= 1} onClick={() => setPage(page - 1)}>←</button><button className="btn btn-secondary" disabled={page * 25 >= filteredTasks.length} onClick={() => setPage(page + 1)}>→</button></div></div>
    </section>
    <details className="tw-method"><summary>Как читать этот отчёт и что покрывают данные</summary><p>Портфель закрепляется за текущим исполнителем задачи. Email автора трудозатрат сопоставляется с email приложения отдельным INNER JOIN по всем worklog, без issue_id. Задача может вообще не иметь списаний. Если assignee пуст, используем поле «Исполнитель», историю назначений, затем автора перехода в «В работе» / «Ожидание релиза», как в отчёте по релизам; источник указан в карточке. Неоднозначные совпадения не распределяются. Инициатор MR — заказчик, а не исполнитель.</p><p>Витрины Tech ETL определяются по автору tech_etl либо шаблону описания: email инициатора + MR + витрина. Остальные задачи показаны общей категорией «Разработка и текучка». Время выполнения SQL из описания не является трудозатратами сотрудника.</p><p>«Часы / задача» — полное списанное время всех участников по завершённым за период задачам текущего исполнителя (Done, Fixed, Завершена), без отмен и дублей; задачи без трудозатрат исключаются из среднего. «До закрытия» — календарное время от создания до закрытия, включая ожидание. Исторический исполнитель на момент закрытия может отличаться. Duplicate и Отклонено закрывают задачу, но не входят в средние выполнения. Статусы подготовки к релизу, ожидания релиза и проверок остаются открытыми. Дата закрытия берётся из resolved_at или истории перехода в текущий закрытый статус; если даты нет, задача видна во «Все закрытые», но не приписывается выбранному периоду.</p><p>Отчёт показывает только загруженные задачи. Даты загрузки помогают оценить свежесть, но не подтверждают полноту. Для разработки и текучки нужен срез вне релизов. Пользователей со связью через email worklog: {data.summary.users_matched_by_email ?? 0}. Задач с исполнителем по автору перехода статуса: {data.summary.state_author_tasks ?? 0}. Не сопоставлено часов за период: {hours(data.summary.unknown_author_hours)}. Часы по задачам без среза: {hours(data.summary.orphan_hours)}.</p></details>
  </div>;
}
