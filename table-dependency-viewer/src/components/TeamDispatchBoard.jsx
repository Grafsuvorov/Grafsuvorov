import { useEffect, useMemo, useState } from "react";
import { currentEmployees, parseObjects, recommendEngineers, STAGES } from "../utils/teamDispatch.js";
import { formatLocalDateTime } from "../utils/datetime.js";
import "../style/team-workload.css";
import "../style/team-dispatch.css";

const hours = (n) => `${Number(n || 0).toLocaleString("ru-RU", { maximumFractionDigits: 1 })} ч`;
const date = (v) => v ? formatLocalDateTime(v, { withSeconds: false }) : "не загружена";
const url = (v) => /^https?:\/\//i.test(v || "") ? v : undefined;

function TaskCard({ task, onSelect, selected }) {
  return <button className={`td-task ${selected ? "selected" : ""}`} onClick={() => onSelect(task.issue_id)}>
    <div className="td-task-top"><strong>{task.issue_id}</strong><span>{task.priority || task.state}</span></div>
    <div className="td-task-name">{task.summary === task.issue_id ? "Описание пока не загружено" : task.summary}</div>
    <div className="td-task-state">{task.state}</div>
    {task.objects?.length > 0 && <div className="td-task-object" title={task.objects.join(", ")}>{task.objects[0]}{task.objects.length > 1 ? ` +${task.objects.length - 1}` : ""}</div>}
    <div className="td-task-bottom">{task.stale_days >= 14 && <span className="tw-stale">Без обновлений {Math.floor(task.stale_days)} дн</span>}<span>{task.remaining_hours == null ? "Без оценки" : task.estimate_exhausted ? "Оценка исчерпана" : `Остаток ≈ ${hours(task.remaining_hours)}`}</span>{task.release_date && <span title="Плановая дата релиза">Релиз {task.release_date}</span>}</div>
  </button>;
}

export default function TeamDispatchBoard({ data, loading, error, onRefresh }) {
  const [query, setQuery] = useState("");
  const [taskId, setTaskId] = useState("");
  const [objectInput, setObjectInput] = useState("");
  const [strategy, setStrategy] = useState("balanced");
  const [auto, setAuto] = useState(true);
  const [category, setCategory] = useState("all");
  const [sort, setSort] = useState("capacity");
  const [selectedEmployee, setSelectedEmployee] = useState(null);
  useEffect(() => {
    if (!auto) return;
    const timer = setInterval(() => { if (document.visibilityState === "visible") onRefresh(); }, 60000);
    return () => clearInterval(timer);
  }, [auto, onRefresh]);
  const active = useMemo(() => (data?.tasks || []).filter((t) => t.is_open), [data]);
  const employees = useMemo(() => currentEmployees(data), [data]);
  const visible = employees.filter((e) => `${e.engineer} ${e.email}`.toLowerCase().includes(query.toLowerCase()))
    .sort((a, b) => sort === "capacity" ? a.load - b.load : b.stages.active.length - a.stages.active.length);
  const incoming = active.filter((t) => t.owner_id == null);
  const chosen = (data?.tasks || []).find((t) => t.issue_id === taskId);
  const candidates = useMemo(() => recommendEngineers(data, { taskId, objects: parseObjects(objectInput), strategy }), [data, taskId, objectInput, strategy]);
  const pickTask = (id) => { setTaskId(id); setObjectInput(""); document.getElementById("td-planner")?.scrollIntoView({ behavior: "smooth", block: "start" }); };
  const totalActive = employees.reduce((n, e) => n + e.stages.active.length, 0);
  const totalQueue = employees.reduce((n, e) => n + e.stages.queue.length, 0);
  const totalRelease = employees.reduce((n, e) => n + e.stages.release.length, 0);
  const totalUnknown = employees.reduce((n, e) => n + e.unknown, 0);
  if (!data) return <div className="tw-report"><div className={error ? "tw-error" : "tw-loading"}>{error || "Собираем текущую загрузку…"}<button className="btn btn-secondary" onClick={onRefresh}>Обновить</button></div></div>;
  return <div className="tw-report td-report">
    <div className="tw-heading"><div><div className="tw-eyebrow">РАСПРЕДЕЛЕНИЕ РАБОТЫ</div><h2>Кому передать следующую задачу</h2><p>Текущий портфель по загруженному срезу. Исторические часы не влияют на рекомендации.</p></div><div className="td-refresh"><button className="btn btn-primary" onClick={() => document.getElementById("td-planner")?.scrollIntoView({ behavior: "smooth", block: "start" })}>Подобрать исполнителя ↓</button><label><input type="checkbox" checked={auto} onChange={(e) => setAuto(e.target.checked)} /> Обновлять каждую минуту</label><button className="btn btn-secondary" disabled={loading} onClick={onRefresh}>{loading ? "Обновляем…" : "Обновить"}</button></div></div>
    {error && <div className="tw-error" role="alert">{error}</div>}
    <div className="td-pulse"><span><i className="td-live" /> Срез: <b>{date(data.snapshot_loaded_at)}</b></span><span>Самая ранняя загрузка: {date(data.oldest_snapshot_at)}</span><span>Обновляется экран; актуальность задач зависит от ETL</span></div>
    <div className="tw-kpis">{[["В работе сейчас", totalActive, "Разработка, анализ, интеграция и проверки", "blue"], ["В очереди", totalQueue, "Назначены, но ещё не в рабочих статусах", "purple"], ["Ждут релиза", totalRelease, "Отдельно от активной разработки", "green"], ["Нужно распределить", incoming.length, "Без назначенного или сопоставленного сотрудника", "amber"]].map(([label, value, hint, color]) => <article className={`tw-kpi ${color}`} key={label}><span>{label}</span><strong>{value}</strong><small>{hint}</small></article>)}</div>

    <section className="td-board-section" id="td-board"><div className="tw-panel-title"><div><h3>Доска сотрудников · сейчас</h3><p>Каждая колонка — сотрудник. Нажмите задачу для подбора исполнителя.</p></div><div className="td-board-controls"><input placeholder="Найти сотрудника…" aria-label="Найти сотрудника" value={query} onChange={(e) => setQuery(e.target.value)} /><select aria-label="Категория задач на доске" value={category} onChange={(e) => setCategory(e.target.value)}><option value="all">Все задачи</option><option value="tech_etl">Витрины Tech ETL</option><option value="other">Другие задачи</option><option value="unknown">Без описания</option></select><select aria-label="Сортировка доски" value={sort} onChange={(e) => setSort(e.target.value)}><option value="capacity">Сначала меньше работы</option><option value="active">Сначала больше задач в работе</option></select></div></div>
      <div className="td-board" role="region" aria-label="Доска текущей загрузки" tabIndex={0}>
        <section className="td-column td-inbox"><header><div><span className="td-avatar">＋</span><strong>Нужно разобрать</strong></div><b>{incoming.length}</b></header><p className="td-column-sub">Без исполнителя или без совпадения с пользователем приложения</p>{incoming.length ? <div className="td-lane"><details open><summary>Входящие · {incoming.length}</summary>{incoming.filter((t) => category === "all" || t.category === category).map((t) => <TaskCard key={t.issue_id} task={t} onSelect={pickTask} selected={taskId === t.issue_id} />)}</details></div> : <div className="td-column-empty">Все открытые задачи сопоставлены</div>}</section>
        {visible.map((e) => <section id={`td-person-${e.user_id}`} key={e.user_id} className={`td-column ${selectedEmployee === e.user_id ? "focused" : ""}`}><header><div><span className="td-avatar">{e.engineer.slice(0, 2).toUpperCase()}</span><strong>{e.engineer}</strong></div><b>{e.open.length}</b></header><p className="td-column-sub" title={e.email}>{e.email}</p><div className="td-column-stats"><strong>{e.stages.active.length} в работе</strong><span>{e.estimatedCount ? `≈ ${hours(e.remaining)} остатка` : "Без оценки остатка"}</span></div>{e.unknown > 0 && <div className="td-column-uncertainty">{e.unknown} задач без надёжной оценки остатка</div>}{STAGES.map((stage) => {
          const stageTasks = e.stages[stage.id].filter((t) => category === "all" || t.category === category);
          return <div className="td-lane" key={stage.id} style={{ "--stage-color": stage.color }}><details open={stage.id === "active" || stage.id === "queue"}><summary><span>{stage.label}</span><b>{stageTasks.length}</b></summary>{stageTasks.length ? stageTasks.map((t) => <TaskCard key={t.issue_id} task={t} onSelect={pickTask} selected={taskId === t.issue_id} />) : <div className="td-column-empty">Нет задач</div>}</details></div>;
        })}</section>)}
      </div>{!visible.length && <div className="tw-empty">Сотрудники по запросу не найдены.</div>}
    </section>

    <section className="td-planner tw-panel" id="td-planner">
      <div className="tw-panel-title"><div><div className="tw-eyebrow">ПОДБОР ИСПОЛНИТЕЛЯ</div><h3>Новая задача → подходящие сотрудники</h3><p>Выберите задачу с доски или укажите объекты новой задачи. Рекомендации пересчитаются автоматически.</p></div></div>
      <div className="td-plan-grid"><div className="td-inputs">
        <label>Задача из загруженного среза<input list="td-task-options" placeholder="Например, DWH-12407" value={taskId} onChange={(e) => setTaskId(e.target.value.trim().toUpperCase())} /><datalist id="td-task-options">{active.map((t) => <option key={t.issue_id} value={t.issue_id}>{t.summary}</option>)}</datalist></label>
        <label>Объекты новой задачи<textarea rows={3} placeholder={"dm.sales_report\ndds.sales"} value={objectInput} onChange={(e) => setObjectInput(e.target.value)} /></label>
        <label>Что важнее<select value={strategy} onChange={(e) => setStrategy(e.target.value)}><option value="balanced">Баланс загрузки и связанных объектов</option><option value="capacity">Меньше текущей работы</option><option value="context">Уже работает с этими объектами</option></select></label>
        {chosen && <div className="td-selected"><div><strong>{chosen.issue_id}</strong> · {chosen.state}<button aria-label="Сбросить выбранную задачу" onClick={() => setTaskId("")}>×</button></div><p>{chosen.summary === chosen.issue_id ? "Описание пока не загружено" : chosen.summary}</p><small>Сейчас: {chosen.owner_name || chosen.assignee || "не назначена"}</small><div className="tw-objects">{chosen.objects.map((o) => <span key={o}>{o}</span>)}</div><div className="td-selected-meta">{chosen.estimate_hours ? `Оценка ${hours(chosen.estimate_hours)} · ` : "Без оценки · "}{chosen.direction || chosen.dashboard || "Направление не указано"}</div><a href={url(chosen.url)} target="_blank" rel="noreferrer">Открыть в YouTrack ↗</a></div>}
        {taskId && !chosen && <div className="td-note">Этой задачи нет в загруженном срезе. Можно указать её объекты вручную.</div>}
        {!chosen?.objects.length && !parseObjects(objectInput).length && <div className="td-note">Пока сравниваем только текущую загрузку. Добавьте объекты для поиска совпадений и связей.</div>}
      </div><div className="td-recommendations">
        {candidates.slice(0, 4).map((e, index) => <article className={`td-candidate ${index === 0 ? "first" : ""}`} key={e.user_id}>
          <div className="td-candidate-head"><span className="td-rank">{index + 1}</span><div><strong>{e.engineer}</strong><small>{e.email}</small></div><button className="td-text-btn" onClick={() => { setSelectedEmployee(e.user_id); setQuery(""); requestAnimationFrame(() => document.getElementById(`td-person-${e.user_id}`)?.scrollIntoView({ behavior: "smooth", block: "center", inline: "center" })); }}>На доску ↑</button></div>
          <div className="td-candidate-metrics"><span><b>{e.stages.active.length}</b> в работе</span><span><b>{e.stages.queue.length}</b> в очереди</span><span><b>{e.stages.release.length}</b> ждут релиза</span><span>{e.estimatedCount ? `≈ ${hours(e.remaining)} по оценкам` : "Нет оценок остатка"}</span></div>
          <div className="td-reasons">{e.exactCount > 0 && <span className="good">{e.exactCount} задач с теми же объектами</span>}{e.relatedCount > 0 && <span className="good">{e.relatedCount} задач со связанными объектами</span>}{e.stages.active.length === 0 && <span>Нет задач в рабочих статусах</span>}{e.unknown > 0 && <span>{e.unknown} задач без оценки остатка</span>}{e.stages.active.length >= 5 && <span className="risk">Много параллельных задач</span>}</div>
          {e.matches.length > 0 && <details><summary>Почему подходит по объектам</summary>{e.matches.map((m) => <div className="td-match" key={m.task.issue_id}><a href={url(m.task.url)} target="_blank" rel="noreferrer">{m.task.issue_id}</a><span>{m.task.state}</span>{m.exact.map((o) => <code key={o}>{o}</code>)}{m.related.map((l) => <code key={`${l.source}:${l.target}`}>{l.source} → {l.target}</code>)}</div>)}</details>}
        </article>)}
        {!candidates.length && <div className="tw-empty">Нет активных сотрудников с ролями engineer/admin.</div>}
        <div className="td-note">Это рекомендация для решения о назначении. Изменить исполнителя можно в YouTrack.{chosen ? " Выбранная задача исключена из нагрузки кандидатов при сравнении." : ""}</div>
      </div></div>
    </section>

    <details className="tw-method"><summary>Как выбираются рекомендации</summary><p>Сравниваем все открытые задачи активных инженеров и администраторов по загруженному срезу, независимо от выбранного периода аналитики. Задача в работе даёт 3 балла нагрузки, в очереди — 1, в ожидании релиза — 0,25, на уточнении — 0,5. Остаток известных оценок разработки и очереди добавляет по 1 баллу за 8 часов. Это сравнительный показатель, а не процент занятости.</p><p>Совпадение объекта даёт 4 балла контекста, прямая зависимость из каталога — 2, максимум 8. В режиме баланса контекст уменьшает показатель нагрузки; в режиме связанных объектов его вес утраивается. Учитываются только реальные связи каталога, а не совпадение схемы. Каталог связей: {data.object_links_available ? "загружен" : "недоступен; сравниваем только одинаковые объекты"}.</p><p>Остаток — оценка минус все загруженные списания по задаче. Нулевая оценка, отсутствие оценки или её исчерпание не означают, что сотрудник свободен. Сейчас таких задач без надёжного остатка: {totalUnknown}. Отпуска, внеплановые работы и полнота учёта времени в данных не видны.</p></details>
  </div>;
}
