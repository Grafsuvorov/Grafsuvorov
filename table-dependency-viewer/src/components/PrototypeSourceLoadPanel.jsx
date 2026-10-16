import { useEffect, useState } from "react";
import { adminApi } from "../api/admin.js";

const INITIAL = {
  target_schema: "stg", target_table: "", source_schema: "", source_table: "",
  server_id: "", fields: "ALL", distribution_field: "RN", primary_key: "",
  entity_name: "", issue_summary: "", direction: "", release_date: "",
};

export default function PrototypeSourceLoadPanel() {
  const [form, setForm] = useState(INITIAL);
  const [servers, setServers] = useState([]);
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    adminApi.prototypeReviewSourceServers().then((data) => setServers(data?.items || [])).catch((err) => setError(err?.message || "Не удалось загрузить серверы"));
  }, []);

  const change = (name, value) => setForm((prev) => ({ ...prev, [name]: value }));
  const run = async () => {
    setLoading(true); setError(""); setResult(null);
    try {
      const response = await adminApi.prototypeReviewSourceLoadRun({ ...form, server_id: Number(form.server_id) });
      setResult(response);
      if (String(form.fields || "").trim().toUpperCase() === "ALL" && response?.fields) {
        setForm((prev) => ({ ...prev, fields: response.fields }));
      }
    } catch (err) { setError(err?.message || "Не удалось выполнить функцию загрузки"); }
    finally { setLoading(false); }
  };
  const createIssue = async () => {
    if (!result?.yaml_content) return;
    setCreating(true); setError("");
    try {
      const created = await adminApi.prototypeReviewSourceLoadCreateIssue({
        ...form, server_id: Number(form.server_id), yaml_content: result.yaml_content,
        recreate_sql: result.recreate_sql || "", insert_sql: result.insert_sql || "",
        truncate_sql: result.truncate_sql || "", load_status: result.status,
      });
      setResult((prev) => ({ ...prev, created }));
    } catch (err) { setError(err?.message || "Не удалось создать задачу"); }
    finally { setCreating(false); }
  };

  return <section className="cc-surface" style={{ marginTop: 18 }}>
    <div className="section-title">Загрузка из источника в STG</div>
    <div className="muted" style={{ marginBottom: 14 }}>
      Новый сценарий без аналитического MR. Функция создаёт/пересоздаёт объект в DEV; после успешного запуска будут подготовлены YAML и SQL для инженерного MR.
    </div>
    <div className="prototype-step-grid">
      <label className="prototype-step-field"><span className="slow-select-label">Схема target</span><select className="slow-entity-select" value={form.target_schema} onChange={(e) => change("target_schema", e.target.value)}><option value="stg">stg</option><option value="dict_stg">dict_stg</option></select></label>
      <label className="prototype-step-field"><span className="slow-select-label">Таблица target</span><input className="slow-entity-select" value={form.target_table} onChange={(e) => change("target_table", e.target.value)} placeholder="SCRAPREMELTBP" /></label>
      <label className="prototype-step-field"><span className="slow-select-label">Схема источника</span><input className="slow-entity-select" value={form.source_schema} onChange={(e) => change("source_schema", e.target.value)} placeholder="MIGR_KHD" /></label>
      <label className="prototype-step-field"><span className="slow-select-label">Таблица источника</span><input className="slow-entity-select" value={form.source_table} onChange={(e) => change("source_table", e.target.value)} placeholder="V_SCRAPREMELTBP" /></label>
      <label className="prototype-step-field"><span className="slow-select-label">Сущность / расписание</span><input className="slow-entity-select" value={form.entity_name} onChange={(e) => change("entity_name", e.target.value)} placeholder="MANAGEMENT_REPORTING_1" /></label>
      <label className="prototype-step-field"><span className="slow-select-label">Первичный ключ</span><input className="slow-entity-select" value={form.primary_key} onChange={(e) => change("primary_key", e.target.value)} placeholder="ID_SCRAPREMELTBP" /></label>
      <label className="prototype-step-field"><span className="slow-select-label">Поля</span><input className="slow-entity-select" value={form.fields} onChange={(e) => change("fields", e.target.value)} placeholder="ALL или FIELD_A,FIELD_B" /><span className="muted">Для изменения таблицы: сначала запустите с ALL, затем добавьте или удалите поля и запустите повторно.</span></label>
      <label className="prototype-step-field"><span className="slow-select-label">Ключ распределения</span><input className="slow-entity-select" value={form.distribution_field} onChange={(e) => change("distribution_field", e.target.value)} placeholder="RN" /></label>
      <div className="prototype-step-field" style={{ gridColumn: "1 / -1" }}><span className="slow-select-label">Сервер источника</span><div className="prototype-control-list">{servers.map((server) => <label className="prototype-toggle-card" key={server.source_id}><input type="radio" name="source-server" checked={String(form.server_id) === String(server.source_id)} onChange={() => change("server_id", String(server.source_id))} /><span>{server.source_server_name} <small>#{server.source_id} · {server.source_type}</small></span></label>)}</div></div>
    </div>
    <div className="prototype-import-actions"><button className="btn btn-primary" disabled={loading || !form.target_table || !form.source_schema || !form.source_table || !form.entity_name || !form.server_id} onClick={run}>{loading ? "Запускаем функцию…" : "Сгенерировать в DEV"}</button></div>
    {error ? <div className="page-error" style={{ marginTop: 12 }}>{error}</div> : null}
    {result ? <div className={`card ${result.status === "error" ? "page-error" : ""}`} style={{ marginTop: 14 }}>
      <div className="section-title">{result.status === "ok" ? "DEV-генерация выполнена" : "Функция завершилась с ошибкой"}</div>
      {result.error ? <pre style={{ whiteSpace: "pre-wrap" }}>{result.error}</pre> : null}
      {result.fields ? <div className="muted">Поля из источника: <span className="mono">{result.fields}</span></div> : null}
      <details><summary>YAML</summary><pre style={{ whiteSpace: "pre-wrap" }}>{result.yaml_content}</pre></details>
      {result.status === "ok" ? <><details><summary>Recreate SQL</summary><pre style={{ whiteSpace: "pre-wrap" }}>{result.recreate_sql}</pre></details><details><summary>Insert SQL</summary><pre style={{ whiteSpace: "pre-wrap" }}>{result.insert_sql}</pre></details></> : null}
      <div className="prototype-step-grid" style={{ marginTop: 14 }}><label className="prototype-step-field"><span className="slow-select-label">Название задачи</span><input className="slow-entity-select" value={form.issue_summary} onChange={(e) => change("issue_summary", e.target.value)} placeholder="Загрузка stg..." /></label><label className="prototype-step-field"><span className="slow-select-label">Дашборд КХД/Направление</span><input className="slow-entity-select" value={form.direction} onChange={(e) => change("direction", e.target.value)} placeholder="Производство" /></label></div>
      <button className="btn btn-primary" disabled={creating || !form.direction} onClick={createIssue}>{creating ? "Создаём…" : result.status === "ok" ? "Создать задачу и инженерный MR" : "Создать задачу только с YAML"}</button>
      {result.created?.issue?.issue_id ? <div className="muted" style={{ marginTop: 12 }}>Создана задача: {result.created.issue.issue_id}{result.created.meta_mr?.mr_url ? <> · <a href={result.created.meta_mr.mr_url} target="_blank" rel="noreferrer">инженерный MR</a></> : null}</div> : null}
    </div> : null}
  </section>;
}
