import { useMemo, useState } from "react";
import { adminApi } from "../api/admin.js";

const DEFAULT_LIMIT = "100000";

export default function BusinessDqPanel() {
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ mr_input: "", business_area: "TRANSPORTATION", direction: "", release_date: "" });
  const [checks, setChecks] = useState([]);
  const [clickViews, setClickViews] = useState([]);
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
      const data = await adminApi.businessDqPreview({ mr_input: form.mr_input, business_area: form.business_area });
      setChecks(data.checks.map((item) => ({ ...item, detail_store_limit: DEFAULT_LIMIT, comment: "" })));
      setClickViews(data.click_views || []);
      if (!form.direction) set("direction", form.business_area);
    } catch (err) { setError(err.message || "Не удалось загрузить MR"); }
    finally { setLoading(false); }
  };
  const validate = async () => {
    setValidating(true); setError(""); setValidation(null);
    try { setValidation(await adminApi.businessDqValidate({ mr_input: form.mr_input, business_area: form.business_area })); }
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

  return <>
    <section className="cc-surface" style={{ marginTop: 16, padding: 10 }}>
      <button type="button" className={`btn ${open ? "btn-primary" : "btn-ghost"}`} onClick={() => setOpen((value) => !value)}>Бизнесовые DQ</button>
    </section>
    {open ? <section className="cc-surface" style={{ marginTop: 16 }}>
      <div className="section-title">Бизнесовые DQ-проверки</div>
      <div className="muted" style={{ marginBottom: 18 }}>Загрузите MR аналитика, проверьте найденные DQ и заполните параметры задачи. Ссылки на созданные MR добавятся в задачу автоматически.</div>
      <div className="prototype-step-grid">
        <label className="prototype-step-field" style={{ margin: 0 }}><span className="slow-select-label">Ссылка на diff</span><input className="slow-entity-select" value={form.mr_input} onChange={(e) => set("mr_input", e.target.value)} placeholder="https://gitlab.../-/merge_requests/2099/diffs" /></label>
        <label className="prototype-step-field" style={{ margin: 0 }}><span className="slow-select-label">Предметная область</span><input className="slow-entity-select" value={form.business_area} onChange={(e) => set("business_area", e.target.value.toUpperCase())} /></label>
        <label className="prototype-step-field" style={{ margin: 0 }}><span className="slow-select-label">Дашборд КХД / Направление</span><input className="slow-entity-select" value={form.direction} onChange={(e) => set("direction", e.target.value)} placeholder="Транспортировка" /></label>
        <label className="prototype-step-field" style={{ margin: 0 }}><span className="slow-select-label">Дата релиза</span><input className="slow-entity-select" type="date" value={form.release_date} onChange={(e) => set("release_date", e.target.value)} /></label>
      </div>
      <div className="prototype-import-actions"><button type="button" className="btn btn-primary" onClick={preview} disabled={loading || !form.mr_input || !form.business_area}>{loading ? "Загружаем MR..." : "Загрузить проверки"}</button></div>
      {checks.length ? <>
        <div className="prototype-chip-row" style={{ margin: "20px 0 10px" }}><span className="prototype-badge">{checks.length} проверок</span><span className="muted">{taskTitle}</span></div>
        {checks.map((item, index) => <div key={item.error_code} className="card" style={{ marginTop: 10 }}>
          <div className="prototype-object-header"><div><div className="prototype-object-title mono">{item.error_code}</div><div className="muted mono">{item.source_path}</div></div><label className="prototype-step-field" style={{ margin: 0, minWidth: 180 }}><span className="slow-select-label">Лимит детализации</span><input className="slow-entity-select mono" value={item.detail_store_limit} onChange={(e) => setChecks((rows) => rows.map((row, i) => i === index ? { ...row, detail_store_limit: e.target.value } : row))} /></label></div>
          <label className="prototype-step-field" style={{ marginTop: 14 }}><span className="slow-select-label">Описание / комментарий аналитика</span><textarea className="slow-entity-select" value={item.comment || ""} onChange={(e) => setChecks((rows) => rows.map((row, i) => i === index ? { ...row, comment: e.target.value } : row))} placeholder="Что особенно важно проверить в этой DQ-проверке" style={{ minHeight: 100, resize: "vertical" }} /></label>
          <details style={{ marginTop: 12 }}><summary className="btn btn-primary" style={{ display: "inline-flex", cursor: "pointer" }}>Просмотреть SQL проверки</summary><pre className="mono" style={{ margin: "10px 0 0", padding: 14, maxHeight: 480, overflow: "auto", whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{item.sql}</pre></details>
        </div>)}
        {clickViews.length ? <div className="muted" style={{ marginTop: 14 }}>Найденные в diff ClickHouse view будут добавлены автоматически: {clickViews.map((view) => view.fqn).join(", ")}</div> : null}
        <div className="prototype-import-actions"><div className="muted">Сначала SQL безопасно выполняется в DEV Greenplum в режиме только для чтения.</div><button type="button" className="btn btn-ghost" onClick={validate} disabled={validating}>{validating ? "Проверяем SQL..." : "Проверить SQL"}</button><button type="button" className="btn btn-primary" onClick={create} disabled={creating || validation?.status !== "ok"}>{creating ? "Создаём задачу и MR..." : "Создать задачу и MR"}</button></div>
        {validation?.status === "ok" ? <div className="muted" style={{ marginTop: 10 }}>Проверка пройдена: {validation.checks.map((item) => `${item.error_code} · ${item.duration_sec} сек`).join("; ")}</div> : null}
      </> : null}
      {error ? <div className="page-error" style={{ marginTop: 12 }}>{error}</div> : null}
      {result ? <div className="card" style={{ marginTop: 16 }}><div className="section-title">Задача и MR созданы</div><div className="muted">Задача: <a href={result.issue?.link} target="_blank" rel="noreferrer">{result.issue?.issue_id}</a></div>{result.dbt?.mr_url ? <div className="muted">dbt MR: <a href={result.dbt.mr_url} target="_blank" rel="noreferrer">{result.dbt.mr_url}</a></div> : null}{result.etl?.mr_url ? <div className="muted">ETL MR: <a href={result.etl.mr_url} target="_blank" rel="noreferrer">{result.etl.mr_url}</a></div> : null}</div> : null}
    </section> : null}
  </>;
}
