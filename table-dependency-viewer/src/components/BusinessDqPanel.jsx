import { useMemo, useState } from "react";
import { adminApi } from "../api/admin.js";

const DEFAULT_LIMIT = "100000";

export default function BusinessDqPanel() {
  const [form, setForm] = useState({ mr_input: "", business_area: "", business_area_code: "", direction: "", click_view_fqn: "", click_view_sql: "" });
  const [checks, setChecks] = useState([]);
  const [loading, setLoading] = useState(false);
  const [creating, setCreating] = useState(false);
  const [validating, setValidating] = useState(false);
  const [validation, setValidation] = useState(null);
  const [error, setError] = useState("");
  const [result, setResult] = useState(null);
  const set = (key, value) => setForm((prev) => ({ ...prev, [key]: value }));
  const taskTitle = useMemo(() => checks.length ? `[DQ] ${form.business_area || "Предметная область"}: ${checks.map((item) => item.error_code).join(", ")}` : "", [checks, form.business_area]);
  const preview = async () => {
    setLoading(true); setError(""); setResult(null); setValidation(null);
    try {
      const data = await adminApi.businessDqPreview({ mr_input: form.mr_input, business_area: form.business_area, business_area_code: form.business_area_code });
      setChecks(data.checks.map((item) => ({ ...item, detail_store_limit: DEFAULT_LIMIT })));
      if (!form.direction) set("direction", form.business_area);
    } catch (err) { setError(err.message || "Не удалось загрузить MR"); }
    finally { setLoading(false); }
  };
  const validate = async () => {
    setValidating(true); setError(""); setValidation(null);
    try { setValidation(await adminApi.businessDqValidate({ mr_input: form.mr_input, business_area: form.business_area, business_area_code: form.business_area_code })); }
    catch (err) { setError(err.message || "SQL-проверка не прошла"); }
    finally { setValidating(false); }
  };
  const create = async () => {
    setCreating(true); setError("");
    try {
      setResult(await adminApi.businessDqCreate({ ...form, issue_summary: taskTitle, checks, detail_store_limit: DEFAULT_LIMIT, stand_dev: true, stand_prod: true }));
    } catch (err) { setError(err.message || "Не удалось создать задачу и MR"); }
    finally { setCreating(false); }
  };
  return <section className="cc-surface" style={{ marginTop: 16 }}>
    <div className="section-title">Бизнесовые DQ</div>
    <div className="muted" style={{ marginBottom: 16 }}>Загрузите SQL нарушений из MR аналитика. Система подготовит dbt MR из <span className="mono">main</span> в <span className="mono">main</span>; Click-view, если она нужна, — ETL MR из <span className="mono">main</span> в <span className="mono">develop</span>.</div>
    <div className="prototype-step-grid">
      <label className="prototype-step-field" style={{ margin: 0 }}><span className="slow-select-label">Ссылка на MR аналитика</span><input className="slow-entity-select" value={form.mr_input} onChange={(e) => set("mr_input", e.target.value)} placeholder="https://gitlab.../-/merge_requests/2099" /></label>
      <label className="prototype-step-field" style={{ margin: 0 }}><span className="slow-select-label">Предметная область</span><input className="slow-entity-select" value={form.business_area} onChange={(e) => set("business_area", e.target.value)} placeholder="Транспортировка" /></label>
      <label className="prototype-step-field" style={{ margin: 0 }}><span className="slow-select-label">Код области</span><input className="slow-entity-select mono" value={form.business_area_code} onChange={(e) => set("business_area_code", e.target.value.toLowerCase())} placeholder="le" /></label>
      <label className="prototype-step-field" style={{ margin: 0 }}><span className="slow-select-label">Дашборд КХД / Направление</span><input className="slow-entity-select" value={form.direction} onChange={(e) => set("direction", e.target.value)} placeholder="Транспортировка" /></label>
    </div>
    <div className="prototype-import-actions"><button type="button" className="btn btn-primary" onClick={preview} disabled={loading || !form.mr_input || !form.business_area || !form.business_area_code}>{loading ? "Загружаем MR..." : "Загрузить DQ из MR"}</button></div>
    {checks.length ? <>
      <div className="prototype-chip-row" style={{ margin: "18px 0 10px" }}><span className="prototype-badge">{checks.length} проверок</span><span className="muted">Задача: {taskTitle}</span></div>
      {checks.map((item, index) => <div key={item.error_code} className="card" style={{ marginTop: 10 }}>
        <div className="prototype-object-header"><div><div className="prototype-object-title mono">{item.error_code}</div><div className="muted mono">{item.source_path}</div></div><label className="prototype-step-field" style={{ margin: 0, minWidth: 180 }}><span className="slow-select-label">Лимит детализации</span><input className="slow-entity-select mono" value={item.detail_store_limit} onChange={(e) => setChecks((rows) => rows.map((row, i) => i === index ? { ...row, detail_store_limit: e.target.value } : row))} /></label></div>
        <textarea className="slow-entity-select mono" readOnly value={item.sql} style={{ minHeight: 110, marginTop: 10, resize: "vertical" }} />
      </div>)}
      <details style={{ marginTop: 16 }}><summary className="section-title" style={{ cursor: "pointer" }}>Click-view — необязательно</summary><div className="prototype-step-grid" style={{ marginTop: 12 }}><label className="prototype-step-field" style={{ margin: 0 }}><span className="slow-select-label">Имя view</span><input className="slow-entity-select mono" value={form.click_view_fqn} onChange={(e) => set("click_view_fqn", e.target.value)} placeholder="dm_view.dq_transportation_vehicle_capacity_average_utilization" /></label></div><textarea className="slow-entity-select mono" value={form.click_view_sql} onChange={(e) => set("click_view_sql", e.target.value)} placeholder="SQL создания Click-view" style={{ minHeight: 180, marginTop: 12, resize: "vertical" }} /></details>
      <div className="prototype-import-actions"><div className="muted">Перед публикацией SQL выполняется в DEV Greenplum в режиме только для чтения.</div><button type="button" className="btn btn-ghost" onClick={validate} disabled={validating}>{validating ? "Проверяем SQL в DEV..." : "Проверить SQL в DEV"}</button><button type="button" className="btn btn-primary" onClick={create} disabled={creating || validation?.status !== "ok"}>{creating ? "Создаём задачу и MR..." : "Создать задачу и MR"}</button></div>
      {validation?.status === "ok" ? <div className="muted" style={{ marginTop: 10 }}>DEV-проверка пройдена: {validation.checks.map((item) => `${item.error_code} · ${item.duration_sec} сек`).join("; ")}</div> : null}
    </> : null}
    {error ? <div className="page-error" style={{ marginTop: 12 }}>{error}</div> : null}
    {result ? <div className="card" style={{ marginTop: 16 }}><div className="section-title">Готово</div><div className="muted">Задача: <a href={result.issue?.link} target="_blank" rel="noreferrer">{result.issue?.issue_id}</a></div>{result.dbt?.mr_url ? <div className="muted">dbt MR: <a href={result.dbt.mr_url} target="_blank" rel="noreferrer">{result.dbt.mr_url}</a></div> : null}{result.etl?.mr_url ? <div className="muted">ETL MR: <a href={result.etl.mr_url} target="_blank" rel="noreferrer">{result.etl.mr_url}</a></div> : null}</div> : null}
  </section>;
}
