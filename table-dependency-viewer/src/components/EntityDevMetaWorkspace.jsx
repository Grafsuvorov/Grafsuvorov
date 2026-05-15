import React, { useEffect, useMemo, useState } from "react";
import { entityMetaApi } from "../api/entityMeta.js";
import { formatRuDateTime } from "../utils/datetime.js";

function bundleFingerprint(bundle) {
  return JSON.stringify({
    yaml_content: bundle.yaml_content || "",
    recreate_sql: bundle.recreate_sql || "",
    insert_sql: bundle.insert_sql || "",
    truncate_sql: bundle.truncate_sql || "",
  });
}

export default function EntityDevMetaWorkspace({ userProfile }) {
  const [status, setStatus] = useState(null);
  const [catalog, setCatalog] = useState({ entities: [], dev_files: [] });
  const [entityOptions, setEntityOptions] = useState([]);
  const [selection, setSelection] = useState({
    entity_name: "",
    schema_name: "dm",
    table_name: "",
  });
  const [taskId, setTaskId] = useState("");
  const [bundle, setBundle] = useState(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [validating, setValidating] = useState(false);
  const [message, setMessage] = useState(null);
  const [messageType, setMessageType] = useState("info");
  const [error, setError] = useState(null);
  const [fileSearch, setFileSearch] = useState("");
  const [validation, setValidation] = useState(null);
  const [validatedFingerprint, setValidatedFingerprint] = useState("");
  const [lockInfo, setLockInfo] = useState(null);

  const currentUser = userProfile?.email || userProfile?.username || "";

  const refreshAll = async () => {
    const [statusData, catalogData, entityData] = await Promise.all([
      entityMetaApi.status(),
      entityMetaApi.catalog(),
      entityMetaApi.entities(),
    ]);
    setStatus(statusData || null);
    setCatalog(catalogData || { entities: [], dev_files: [] });
    setEntityOptions(entityData?.items || []);
  };

  useEffect(() => {
    refreshAll().catch((err) => setError(err.message || "Не удалось загрузить каталог entity meta"));
  }, []);

  const selectedEntity = useMemo(
    () => (catalog.entities || []).find((item) => item.entity_name === selection.entity_name) || null,
    [catalog.entities, selection.entity_name]
  );
  const branchPreview = useMemo(() => {
    const taskNorm = String(taskId || "").trim().toUpperCase();
    return taskNorm || "";
  }, [taskId]);
  const taskIdValid = /^DWH-\d+$/.test(String(taskId || "").trim().toUpperCase());

  const filteredDevFiles = useMemo(() => {
    const term = fileSearch.trim().toLowerCase();
    const rows = [...(catalog.dev_files || [])];
    if (!term) return rows;
    return rows.filter((item) => {
      const haystack = `${item.entity_name} ${item.schema_name} ${item.table_name}`.toLowerCase();
      return haystack.includes(term);
    });
  }, [catalog.dev_files, fileSearch]);

  const currentFingerprint = useMemo(() => (bundle ? bundleFingerprint(bundle) : ""), [bundle]);
  const isValidationFresh = Boolean(validation?.valid && validatedFingerprint && validatedFingerprint === currentFingerprint);

  const acquireLock = async (target) => {
    const lock = await entityMetaApi.lock(target);
    setLockInfo(lock || null);
  };

  const openBundle = async (target) => {
    setLoading(true);
    setError(null);
    setMessage(null);
    setValidation(null);
    try {
      const data = await entityMetaApi.init(target);
      await acquireLock(target);
      setSelection({
        entity_name: target.entity_name,
        schema_name: target.schema_name,
        table_name: target.table_name,
      });
      setBundle(data || null);
      setValidatedFingerprint("");
      setMessageType("success");
      setMessage(data?.exists ? `Объект открыт из ${data?.source || "dev"}.` : "Создан новый DEV-черновик.");
      await refreshAll();
    } catch (err) {
      setError(err.message || "Не удалось открыть объект");
    } finally {
      setLoading(false);
    }
  };

  const handleOpenCurrentSelection = async () => {
    if (!selection.entity_name || !selection.schema_name || !selection.table_name) {
      setError("Нужно выбрать сущность, схему и имя таблицы");
      return;
    }
    await openBundle(selection);
  };

  const handleValidate = async () => {
    if (!bundle) return;
    setValidating(true);
    setError(null);
    setMessage(null);
    try {
      const data = await entityMetaApi.validate({
        entity_name: selection.entity_name,
        schema_name: selection.schema_name,
        table_name: selection.table_name,
        task_id: taskId,
        yaml_content: bundle.yaml_content,
        recreate_sql: bundle.recreate_sql,
        insert_sql: bundle.insert_sql,
        truncate_sql: bundle.truncate_sql,
      });
      setValidation(data || null);
      if (data?.normalized?.yaml_content) {
        setBundle((prev) => ({
          ...prev,
          yaml_content: data.normalized.yaml_content,
        }));
      }
      const nextFingerprint = bundleFingerprint({
        ...bundle,
        yaml_content: data?.normalized?.yaml_content || bundle.yaml_content,
      });
      setValidatedFingerprint(data?.valid ? nextFingerprint : "");
      setMessageType(data?.valid ? "success" : "warning");
      setMessage(data?.valid ? "Проверка пройдена. Bundle готов к сохранению в DEV." : "Проверка завершилась с ошибками.");
    } catch (err) {
      setError(err.message || "Не удалось провалидировать bundle");
    } finally {
      setValidating(false);
    }
  };

  const handleSave = async () => {
    if (!bundle) return;
    if (!taskIdValid) {
      setMessageType("warning");
      setMessage("Перед сохранением укажите номер задачи в формате DWH-12345.");
      setError(null);
      return;
    }
    if (!isValidationFresh) {
      setMessageType("warning");
      setMessage("Перед сохранением нужна успешная проверка текущей версии bundle.");
      setError(null);
      return;
    }
    setSaving(true);
    setError(null);
    setMessage(null);
    try {
      const data = await entityMetaApi.save({
        entity_name: selection.entity_name,
        schema_name: selection.schema_name,
        table_name: selection.table_name,
        task_id: taskId,
        yaml_content: bundle.yaml_content,
        recreate_sql: bundle.recreate_sql,
        insert_sql: bundle.insert_sql,
        truncate_sql: bundle.truncate_sql,
      });
      if (data?.validation?.normalized?.yaml_content) {
        setBundle((prev) => ({
          ...prev,
          yaml_content: data.validation.normalized.yaml_content,
        }));
      }
      setValidation(data?.validation || null);
      setValidatedFingerprint(bundleFingerprint({
        ...bundle,
        yaml_content: data?.validation?.normalized?.yaml_content || bundle.yaml_content,
      }));
      await refreshAll();
      setMessageType("success");
      setMessage(`DEV bundle сохранен: ${data?.path || ""}`);
    } catch (err) {
      setError(err.message || "Не удалось сохранить bundle");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="container cc-page">
      <section className="cc-surface dev-meta-page">
        <div className="section-title">DEV Meta Workspace</div>
        <div className="section-subtitle">
          Редактор для `tech_etl/etl_loads_entity`: отдельная DEV-копия YAML и SQL перед релизом.
        </div>

        <div className="dev-meta-toolbar">
          <div className="muted">
            DEV root: {status?.dev_root || "—"} · Lock TTL: {status?.lock_ttl_minutes ?? 30} мин.
          </div>
        </div>

        {(message || error) && (
          <div className={`dev-meta-feedback ${error ? "error" : messageType}`}>
            <div className="dev-meta-feedback-title">
              {error ? "Операция не выполнена" : messageType === "success" ? "Успешно" : messageType === "warning" ? "Нужно исправить" : "Статус"}
            </div>
            <div className="dev-meta-feedback-text">{error || message}</div>
          </div>
        )}

        <div className="dev-meta-generator">
          <div className="section-subtitle">Открыть объект или создать DEV-черновик</div>
          <div className="dev-meta-generator-grid">
            <label className="admin-field">
              <span>Сущность</span>
              <select
                className="admin-select"
                value={selection.entity_name}
                onChange={(e) => setSelection((prev) => ({ ...prev, entity_name: e.target.value }))}
              >
                <option value="">Выберите сущность</option>
                {entityOptions.map((item) => (
                  <option key={`${item.entity_id}-${item.entity_name}`} value={item.entity_name}>
                    {item.entity_name}
                  </option>
                ))}
              </select>
            </label>
            <label className="admin-field">
              <span>Схема</span>
              <input
                list="entity-dev-schemas"
                value={selection.schema_name}
                onChange={(e) => setSelection((prev) => ({ ...prev, schema_name: e.target.value }))}
                placeholder="dm"
              />
              <datalist id="entity-dev-schemas">
                {(selectedEntity?.schemas || []).map((item) => (
                  <option key={item} value={item} />
                ))}
              </datalist>
            </label>
            <label className="admin-field">
              <span>Таблица</span>
              <input
                value={selection.table_name}
                onChange={(e) => setSelection((prev) => ({ ...prev, table_name: e.target.value }))}
                placeholder="transport_bill"
              />
            </label>
            <label className="admin-field">
              <span>Задача</span>
              <input
                value={taskId}
                onChange={(e) => setTaskId(e.target.value.toUpperCase())}
                placeholder="DWH-12345"
              />
            </label>
          </div>
          <div className="dev-meta-generator-actions">
            <button className="btn btn-primary" onClick={handleOpenCurrentSelection} disabled={loading}>
              {loading ? "Открываем..." : "Открыть / создать DEV-черновик"}
            </button>
            <span className="muted">{branchPreview ? `Ветка: ${branchPreview}` : "Укажите задачу, сущность, схему и таблицу"}</span>
          </div>
        </div>

        <div className="dev-meta-browser">
          <div className="dev-meta-file-block">
            <div className="dev-meta-file-head">
              <div>
                <div className="section-subtitle">DEV объекты</div>
                <div className="muted">Сохраняются в отдельном дереве `etl_loads_entity_dev`.</div>
              </div>
              <div className="dev-meta-file-tools">
                <input
                  className="dev-meta-file-search"
                  value={fileSearch}
                  onChange={(e) => setFileSearch(e.target.value)}
                  placeholder="Поиск по entity/schema/table"
                />
              </div>
            </div>
            <div className="dev-meta-file-list">
              {filteredDevFiles.map((file) => (
                <button
                  key={file.object_key}
                  className={`dev-meta-file ${bundle?.object_key === file.object_key ? "active" : ""}`}
                  onClick={() => openBundle(file)}
                >
                  <span className="mono dev-meta-file-name">{file.object_key}</span>
                  <span className="muted">{formatRuDateTime(file.updated_at)}</span>
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="dev-meta-layout">
          <div className="dev-meta-editor-shell">
            <div className="dev-meta-editor-head">
              <div className="dev-meta-editor-title">
                <div className="section-subtitle">Bundle редактор</div>
                <div className="muted dev-meta-editor-path">
                  {bundle?.object_key || "Сначала выберите объект"}
                </div>
              </div>
              <div className="dev-meta-actions">
                <button className="btn btn-secondary" onClick={handleValidate} disabled={!bundle || validating}>
                  {validating ? "Проверяем..." : "Проверить"}
                </button>
                <button className="btn btn-primary" onClick={handleSave} disabled={!bundle || saving || !isValidationFresh || !taskIdValid}>
                  {saving ? "Сохраняем..." : "Сохранить в DEV"}
                </button>
              </div>
            </div>

            <div className="dev-meta-lock-bar">
              <span>Lock:</span>
              <strong>{lockInfo?.locked_by || currentUser || "нет"}</strong>
              <span className="muted">
                {lockInfo?.expires_at ? `до ${formatRuDateTime(lockInfo.expires_at)}` : ""}
              </span>
            </div>

            {validation && (
              <div className="dev-meta-validation">
                <div className="section-subtitle">Результат проверки</div>
                <div className={`dev-meta-validation-pill ${validation.valid ? "ok" : "bad"}`}>
                  {validation.valid ? "Bundle валиден" : "Есть ошибки"}
                </div>
                {validation.errors?.length ? (
                  <ul className="dev-meta-validation-list">
                    {validation.errors.map((item, idx) => (
                      <li key={`entity-dev-err-${idx}`}>{item}</li>
                    ))}
                  </ul>
                ) : null}
                {validation.warnings?.length ? (
                  <ul className="dev-meta-validation-list warning">
                    {validation.warnings.map((item, idx) => (
                      <li key={`entity-dev-warn-${idx}`}>{item}</li>
                    ))}
                  </ul>
                ) : null}
              </div>
            )}

            <div className="entity-dev-editors">
              <label className="admin-field entity-dev-editor-field">
                <span>YAML</span>
                <textarea
                  className="dev-meta-editor entity-dev-editor"
                  value={bundle?.yaml_content || ""}
                  onChange={(e) => setBundle((prev) => ({ ...prev, yaml_content: e.target.value }))}
                  placeholder="meta_data_file.yaml"
                />
              </label>
              <label className="admin-field entity-dev-editor-field">
                <span>Recreate SQL</span>
                <textarea
                  className="dev-meta-editor entity-dev-editor"
                  value={bundle?.recreate_sql || ""}
                  onChange={(e) => setBundle((prev) => ({ ...prev, recreate_sql: e.target.value }))}
                  placeholder="sql_query_recreate_init.sql"
                />
              </label>
              <label className="admin-field entity-dev-editor-field">
                <span>Insert SQL</span>
                <textarea
                  className="dev-meta-editor entity-dev-editor"
                  value={bundle?.insert_sql || ""}
                  onChange={(e) => setBundle((prev) => ({ ...prev, insert_sql: e.target.value }))}
                  placeholder="sql_query_insert_init.sql"
                />
              </label>
              <label className="admin-field entity-dev-editor-field">
                <span>Truncate SQL</span>
                <textarea
                  className="dev-meta-editor entity-dev-editor"
                  value={bundle?.truncate_sql || ""}
                  onChange={(e) => setBundle((prev) => ({ ...prev, truncate_sql: e.target.value }))}
                  placeholder="sql_query_truncate.sql"
                />
              </label>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
