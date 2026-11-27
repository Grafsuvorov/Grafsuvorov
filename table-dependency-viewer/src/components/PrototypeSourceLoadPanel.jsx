import { forwardRef, useEffect, useImperativeHandle, useMemo, useRef, useState } from "react";
import { adminApi } from "../api/admin.js";
import { summarizeSourceBatch, sourceTargetKey, sourceDetailsForm, sourceTaskWarning, combinedTaskLabel } from "../utils/prototypeSourceBatch.js";

const INITIAL = { target_schema: "stg", target_table: "", source_schema: "", source_table: "", server_id: "", fields: "ALL", distribution_field: "RN", primary_key: "", entity_name: "" };

const SourceLoadEditor = forwardRef(function SourceLoadEditor({ mode, rowId, onReady, onBusy, onLookupBusy }, ref) {
  const [form, setForm] = useState(INITIAL);
  const [servers, setServers] = useState([]);
  const [tables, setTables] = useState([]);
  const [tablesError, setTablesError] = useState("");
  const [lookup, setLookup] = useState(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const callbacks = useRef({ onReady, onLookupBusy }); callbacks.current = { onReady, onLookupBusy };
  const touched = useRef(new Set());
  const autoFields = useRef({});
  const loadedTarget = useRef("");
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const isOhd = mode === "ohd";
  useEffect(() => { let active = true;
    adminApi.prototypeReviewSourceServers(mode).then((v) => { if (active) setServers(v?.items || []); }).catch((e) => { if (active) setError(e.message); });
    return () => { active = false; };
  }, [mode]);
  useEffect(() => { let active = true;
    adminApi.prototypeReviewSourceTables(form.target_schema, mode).then((v) => { if (active) { setTables(v?.items || []); setTablesError(""); } }).catch((e) => { if (active) { setTables([]); setTablesError(e.message); } });
    return () => { active = false; };
  }, [form.target_schema, mode]);
  const change = (name, value) => {
    onReady(null); setResult(null); setError("");
    const identityChanged = name === "target_schema" || (name === "target_table" && sourceTargetKey(form.target_table) !== sourceTargetKey(value));
    const previousAutoFields = identityChanged ? autoFields.current : {};
    if (identityChanged) { touched.current = new Set(); loadedTarget.current = ""; }
    else touched.current.add(name);
    setForm((prev) => {
      const reset = {};
      if (identityChanged) for (const [field, oldValue] of Object.entries(previousAutoFields)) {
        if (prev[field] === oldValue) reset[field] = INITIAL[field];
      }
      return { ...prev, ...reset, [name]: value, ...(name === "target_schema" ? { target_table: "", fields: "ALL" } : {}) };
    });
    if (identityChanged) autoFields.current = {};
  };
  useEffect(() => {
    const target = form.target_table.trim();
    const key = `${mode}:${form.target_schema}:${sourceTargetKey(target)}`;
    if (!target || key === loadedTarget.current) { setDetailsLoading(false); return; }
    let active = true;
    setLookup({ status: "loading" }); setDetailsLoading(true); callbacks.current.onLookupBusy?.(true);
    const timer = setTimeout(async () => {
      try {
        const details = await adminApi.prototypeReviewSourceTableDetails(form.target_schema, target, mode);
        if (!active) return;
        loadedTarget.current = key;
        if (details.found === false) { setLookup({ status: "new" }); return; }
        callbacks.current.onReady(null);
        setForm((prev) => {
          const next = sourceDetailsForm(prev, details, touched.current);
          autoFields.current = Object.fromEntries(Object.keys(INITIAL).filter((field) => field !== "target_table" && next[field] !== prev[field]).map((field) => [field, next[field]]));
          return next;
        });
        setLookup({ status: "found" });
      } catch (e) { if (active) setLookup({ status: "error", message: e.message }); }
      finally { if (active) { setDetailsLoading(false); callbacks.current.onLookupBusy?.(false); } }
    }, 400);
    return () => { active = false; clearTimeout(timer); callbacks.current.onLookupBusy?.(false); };
  }, [form.target_schema, form.target_table, mode]);
  const complete = Boolean(form.target_table.trim() && form.source_schema.trim() && form.source_table.trim()
    && (isOhd || form.entity_name.trim()) && form.primary_key.trim() && form.server_id);
  const run = async () => {
    if (loading || detailsLoading) return false;
    onReady(null);
    if (!complete) { setError("Заполните источник, target, сервер, ключ и сущность (для КХД)"); return false; }
    setLoading(true); onBusy(true); setError(""); setResult(null);
    try {
      const response = await adminApi.prototypeReviewSourceLoadRun({ ...form, mode, server_id: Number(form.server_id) });
      setResult(response);
      if (response?.status !== "ok") throw new Error(response?.error || "Генерация не завершилась успешно");
      if (!response.recreate_sql || (!isOhd && !response.yaml_content)) throw new Error("Функция не вернула полный SQL/YAML. Проверьте результат генерации");
      if (form.fields.trim().toUpperCase() === "ALL" && response.fields) setForm((prev) => ({ ...prev, fields: response.fields }));
      onReady({ ...form, mode, server_id: Number(form.server_id), fields: response.fields || form.fields,
        load_status: response.status, yaml_content: response.yaml_content || "", yaml_contents: response.yaml_contents || {},
        recreate_sql: response.recreate_sql, insert_sql: response.insert_sql || "", truncate_sql: response.truncate_sql || "" });
      return true;
    } catch (e) { setError(e?.message || "Не удалось выполнить функцию загрузки"); return false; }
    finally { setLoading(false); onBusy(false); }
  };
  useImperativeHandle(ref, () => ({ run }), [form, loading, detailsLoading, mode]);
  const input = (name, label, placeholder = "") => <label className="prototype-step-field" key={name}>
    <span className="slow-select-label">{label}</span><input className="slow-entity-select" value={form[name]} placeholder={placeholder} onChange={(e) => change(name, e.target.value)} />
  </label>;
  return <>
    <p className="muted">Функция создаёт или пересоздаёт эту таблицу в DEV контура {mode.toUpperCase()} и формирует SQL загрузки.</p>
    <div className="prototype-step-grid">
      <label className="prototype-step-field"><span className="slow-select-label">Схема target</span><select className="slow-entity-select" value={form.target_schema} onChange={(e) => change("target_schema", e.target.value)}><option>stg</option><option>dict_stg</option></select></label>
      <label className="prototype-step-field"><span className="slow-select-label">Таблица target</span><input className="slow-entity-select" list={`source-tables-${rowId}`} value={form.target_table} onChange={(e) => change("target_table", e.target.value)} placeholder="Новая или существующая таблица" /><datalist id={`source-tables-${rowId}`}>{tables.map((t) => <option key={t.table_name} value={t.table_name} />)}</datalist>
        <span className="muted">{lookup?.status === "loading" ? "Проверяем target и подставляем параметры…" : lookup?.status === "found" ? "Таблица существует в DEV. Доступные параметры подставлены автоматически." : lookup?.status === "new" ? "Таблица не найдена в DEV — будет создана новая." : "Введите имя или выберите существующую таблицу из подсказок."}</span>
        {lookup?.status === "error" && <span className="page-error">Не удалось проверить target: {lookup.message}</span>}
      </label>
      {input("source_schema", "Схема источника", "SAPSR3")}
      {input("source_table", "Таблица источника", "/BIC/ATR_TO13000")}
      {!isOhd && <div>{input("entity_name", "Сущности / расписания", "TRANSPORTATION, TWO_HOURS")}<span className="muted">Несколько — через запятую. Для каждой будет свой YAML.</span></div>}
      <div>{input("primary_key", "Первичный ключ", "REQUEST, DATAPAKID, RECORD")}<span className="muted">Несколько полей — через запятую или ||.</span></div>
      {input("distribution_field", "Ключ распределения", "RN")}
      <label className="prototype-step-field"><span className="slow-select-label">Сервер источника</span><select className="slow-entity-select" value={form.server_id} onChange={(e) => change("server_id", e.target.value)}><option value="">Выберите сервер</option>{servers.map((s) => <option key={s.server_id} value={s.server_id}>{s.server_name} · ID {s.server_id}</option>)}</select></label>
      <label className="prototype-step-field prototype-source-fields"><span className="slow-select-label">Поля источника</span><textarea className="slow-entity-select" value={form.fields} onChange={(e) => change("fields", e.target.value)} /><span className="muted">ALL или список полей. Изменение параметров требует повторной генерации только этой таблицы.</span></label>
    </div>
    <button type="button" className="btn btn-primary" disabled={loading || detailsLoading || !complete} onClick={run}>{loading ? "Генерация…" : result?.status === "ok" ? "Перегенерировать эту таблицу" : "Сгенерировать в DEV"}</button>
    {tablesError && <p className="page-error">Не удалось загрузить подсказки таблиц: {tablesError}. Введённое имя проверяется отдельно.</p>}
    {error && <p className="page-error">{error}</p>}
    {result && <div className="card" style={{ marginTop: 14 }}>
      {[ ["recreate_sql", "SQL создания / пересоздания"], ["insert_sql", "SQL загрузки"], ["truncate_sql", "SQL очистки"] ].map(([key, label]) => result[key] && <details key={key}><summary>{label}</summary><pre style={{ whiteSpace: "pre-wrap" }}>{result[key]}</pre></details>)}
      {Object.entries(result.yaml_contents || {}).map(([name, content]) => <details key={name}><summary>YAML · {name}</summary><pre style={{ whiteSpace: "pre-wrap" }}>{content}</pre></details>)}
      {result.status === "error" && <details><summary>Сообщения функции</summary><pre style={{ whiteSpace: "pre-wrap" }}>{(result.notices || []).join("\n")}</pre></details>}
    </div>}
  </>;
});

let nextSourceRow = 1;
const PrototypeSourceLoadPanel = forwardRef(function PrototypeSourceLoadPanel({ mode = "khd", onSourceLoadsChange,
  hasDiff = false, disabled = false, combinedAction, onTaskDefaults }, ref) {
  const [rows, setRows] = useState([]);
  const [runningAll, setRunningAll] = useState(false);
  const [task, setTask] = useState({ summary: "", direction: "", release_date: "", parent_issue: "" });
  const [creating, setCreating] = useState(false);
  const [created, setCreated] = useState(null);
  const [error, setError] = useState("");
  const editors = useRef({});
  const onChange = useRef(onSourceLoadsChange); onChange.current = onSourceLoadsChange;
  const summary = useMemo(() => summarizeSourceBatch(rows), [rows]);
  useEffect(() => { onChange.current?.(summary); }, [summary]);
  useImperativeHandle(ref, () => ({ getSelection: () => summarizeSourceBatch(rows) }), [rows]);
  const update = (id, patch) => {
    if (!("expanded" in patch)) setCreated(null);
    setRows((prev) => prev.map((row) => row.id === id ? { ...row, ...patch } : row));
  };
  const runAll = async () => {
    setRunningAll(true);
    try { for (const row of rows.filter((r) => r.selected && !r.ready)) await editors.current[row.id]?.run(); }
    finally { setRunningAll(false); }
  };
  const createOnlyStg = async () => {
    if (!summary.valid || !summary.loads.length || !task.direction.trim()) return;
    setCreating(true); setError("");
    try { setCreated(await adminApi.prototypeReviewCreateIssue({ ...task, mode, mr_input: "", review_items: [],
      source_loads: summary.loads, expected_source_load_count: summary.loads.length, issue_summary: task.summary.trim() || "Загрузка таблиц в STG", linked_issues: [] })); }
    catch (e) { setError(e.message); } finally { setCreating(false); }
  };
  const busy = disabled || creating || runningAll || rows.some((row) => row.busy || row.lookupBusy);
  return <section className="cc-surface prototype-source-load">
    <div className="section-title">STG: таблицы из источников · {mode.toUpperCase()}</div>
    <p className="muted">Добавьте таблицы и сгенерируйте каждую в DEV. Готовые результаты сохраняются отдельно. Затем создайте одну задачу для STG или объедините их с проверенным diff.</p>
    <div className="prototype-import-actions">
      <button type="button" className="btn btn-primary" disabled={busy} onClick={() => { setCreated(null); setRows((prev) => [...prev, { id: nextSourceRow++, selected: true, ready: null, busy: false, expanded: true }]); }}>+ Добавить STG-таблицу</button>
      <button type="button" className="btn btn-ghost" disabled={busy || !rows.some((r) => r.selected && !r.ready)} onClick={runAll}>Сгенерировать непроверенные</button>
      <span className="muted">Готово {summary.ready} из {summary.selected} выбранных</span>
    </div>
    {rows.map((row, index) => <section key={row.id} className="cc-surface" style={{ marginTop: 14 }}>
      <div className="prototype-import-actions">
        <label><input type="checkbox" checked={row.selected} disabled={busy} onChange={(e) => update(row.id, { selected: e.target.checked })} /> Таблица {index + 1}</label>
        <span className="mono">{row.ready ? `${row.ready.target_schema}.${row.ready.target_table}` : "Настройте и выполните генерацию"}</span>
        <span className="prototype-badge">{row.busy ? "Генерация…" : row.lookupBusy ? "Подстановка…" : row.ready ? "Готова" : "Не готова"}</span>
        <button type="button" className="btn btn-ghost" disabled={busy} onClick={() => update(row.id, { expanded: !row.expanded })}>{row.expanded ? "Свернуть" : "Параметры и SQL"}</button>
        <button type="button" className="btn btn-ghost" disabled={busy} onClick={() => setRows((prev) => prev.filter((r) => r.id !== row.id))}>Убрать</button>
      </div>
      <fieldset hidden={!row.expanded} disabled={disabled || creating || runningAll || row.busy} style={{ border: 0, padding: 0, minWidth: 0 }}>
        <SourceLoadEditor ref={(ref) => { editors.current[row.id] = ref; }} rowId={row.id} mode={mode}
          onReady={(ready) => { update(row.id, { ready }); if (ready) update(row.id, { expanded: false }); }} onBusy={(value) => update(row.id, { busy: value })} onLookupBusy={(value) => update(row.id, { lookupBusy: value })} />
      </fieldset>
    </section>)}
    {summary.errors.map((message) => <p className="page-error" key={message}>{message}</p>)}
    {!!summary.selected && <div className="card" style={{ marginTop: 16 }}>
      <div className="section-title">Одна задача для выбранных STG-таблиц{hasDiff ? " и diff" : ""}</div>
      {hasDiff ? <>
        <p className="muted">Это одна задача, включающая выбранные STG-таблицы и объекты из MR.</p>
        {summary.loads.map((load) => <div className="mono" key={`${load.target_schema}.${load.target_table}`}>STG · {load.target_schema}.{load.target_table}</div>)}
        {(combinedAction?.diffTargets || []).map((target) => <div className="mono" key={target}>diff · {target}</div>)}
        <div className="prototype-source-task-actions">
          <button type="button" className="btn btn-primary prototype-combined-task-button"
            disabled={busy || !summary.valid || !summary.loads.length || !combinedAction?.canCreate}
            onClick={() => combinedAction?.onCreate()}>{combinedAction?.createdIssue ? `Общая задача ${combinedAction.createdIssue} создана` : combinedTaskLabel(summary.selected, combinedAction?.diffTargets?.length || 0)}</button>
          {combinedAction?.reviewReady && <a className="btn btn-ghost" href="#prototype-task-parameters">Общие параметры задачи</a>}
        </div>
        {!combinedAction?.reviewReady ? <p className="muted">Сначала запустите ревью указанного MR.</p> : !combinedAction?.canCreate && !combinedAction?.createdIssue ? <p className="muted">Заполните общие параметры задачи ниже и исправьте отмеченные ошибки ревью.</p> : null}
      </> : <>
        <p className="muted">Для общей задачи с diff укажите MR выше и запустите review. Для задачи только по STG заполните параметры здесь.</p>
        <div className="prototype-step-grid">
          {[ ["summary", "Название задачи"], ["direction", "Дашборд КХД/Направление *"], ["release_date", "Дата релиза"], ["parent_issue", "Родительская задача"] ].map(([name, label]) =>
            <label key={name} className="prototype-step-field"><span className="slow-select-label">{label}</span><input className="slow-entity-select" type={name === "release_date" ? "date" : "text"} value={task[name]} disabled={busy} onChange={(e) => { setTask((prev) => ({ ...prev, [name]: e.target.value })); onTaskDefaults?.(name, e.target.value); }} /></label>)}
        </div>
        <div className="prototype-source-task-actions">
        <button type="button" className="btn btn-primary" disabled={busy || Boolean(created?.issue?.issue_id) || !summary.valid || !summary.loads.length || !task.direction.trim()} onClick={createOnlyStg}>Создать отдельную STG-задачу ({summary.selected} таблицы)</button>
        </div>
      </>}
      {!summary.valid && <p className="muted">Сначала завершите генерацию всех выбранных таблиц или снимите выбор с ненужных.</p>}
    </div>}
    {error && <p className="page-error">{error}</p>}
    {created && <div className="card">{sourceTaskWarning(created, summary.loads) && <p className="page-error">{sourceTaskWarning(created, summary.loads)}</p>}<div>Задача: <a href={created.issue?.link} target="_blank" rel="noreferrer">{created.issue?.issue_id}</a></div>
      {[created.meta_mr, created.dbt_registry].filter(Boolean).map((mr, index) => mr.mr_url && <div key={index}><a href={mr.mr_url} target="_blank" rel="noreferrer">Открыть MR</a></div>)}
      {[created.meta_error, created.meta_mr_error, created.dbt_registry_error, created.attachment_error].filter(Boolean).map((message) => <p className="page-error" key={message}>{message}</p>)}
    </div>}
  </section>;
});

export default PrototypeSourceLoadPanel;
