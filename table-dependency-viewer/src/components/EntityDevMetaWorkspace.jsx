import React, { useEffect, useMemo, useRef, useState } from "react";
import { entityMetaApi } from "../api/entityMeta.js";
import { formatRuDateTime } from "../utils/datetime.js";

const COMMON_SCHEMAS = ["stg", "ods", "dict_dds", "dict_stg", "dq", "dm", "dm_calc", "dm_view", "dds"];
const CUSTOM_SCHEMA_OPTION = "__custom__";

function objectFingerprint(bundle) {
  return JSON.stringify({
    yaml_content: bundle.yaml_content || "",
    recreate_sql: bundle.recreate_sql || "",
    insert_sql: bundle.insert_sql || "",
    truncate_sql: bundle.truncate_sql || "",
  });
}

function EntityPicker({ options, value, onChange, placeholder = "Выберите сущность" }) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState(value || "");
  const rootRef = useRef(null);

  useEffect(() => {
    setQuery(value || "");
  }, [value]);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (!rootRef.current?.contains(event.target)) {
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const filteredOptions = useMemo(() => {
    const term = String(query || "").trim().toLowerCase();
    if (!term) return options;
    return options.filter((item) => String(item || "").toLowerCase().includes(term));
  }, [options, query]);

  return (
    <div className={`entity-picker ${open ? "open" : ""}`} ref={rootRef}>
      <input
        className="entity-picker-input"
        value={query}
        onChange={(e) => {
          const next = e.target.value;
          setQuery(next);
          onChange(next);
          setOpen(true);
        }}
        onFocus={() => setOpen(true)}
        placeholder={placeholder}
      />
      <button type="button" className="entity-picker-toggle" onClick={() => setOpen((prev) => !prev)} aria-label="Открыть список сущностей">
        ▾
      </button>
      {open ? (
        <div className="entity-picker-menu">
          {filteredOptions.length ? (
            filteredOptions.map((item) => (
              <button
                type="button"
                key={item}
                className={`entity-picker-option ${item === value ? "active" : ""}`}
                onClick={() => {
                  setQuery(item);
                  onChange(item);
                  setOpen(false);
                }}
              >
                {item}
              </button>
            ))
          ) : (
            <div className="entity-picker-empty">Ничего не найдено</div>
          )}
        </div>
      ) : null}
    </div>
  );
}

function MultiEntityPicker({ options, values, onChange, placeholder = "Выберите сущности" }) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const rootRef = useRef(null);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (!rootRef.current?.contains(event.target)) {
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const filteredOptions = useMemo(() => {
    const term = String(query || "").trim().toLowerCase();
    if (!term) return options;
    return options.filter((item) => String(item || "").toLowerCase().includes(term));
  }, [options, query]);

  const selectedLabel = values.length ? values.join(", ") : "";

  const toggleValue = (item) => {
    if (values.includes(item)) {
      onChange(values.filter((value) => value !== item));
      return;
    }
    onChange([...values, item]);
  };

  return (
    <div className={`entity-picker multi ${open ? "open" : ""}`} ref={rootRef}>
      <input
        className="entity-picker-input"
        value={open ? query : selectedLabel}
        onChange={(e) => {
          setQuery(e.target.value);
          setOpen(true);
        }}
        onFocus={() => setOpen(true)}
        placeholder={placeholder}
        readOnly={!open}
      />
      <button type="button" className="entity-picker-toggle" onClick={() => setOpen((prev) => !prev)} aria-label="Открыть список сущностей">
        ▾
      </button>
      {open ? (
        <div className="entity-picker-menu">
          {filteredOptions.length ? (
            filteredOptions.map((item) => (
              <label key={item} className={`entity-picker-check ${values.includes(item) ? "active" : ""}`}>
                <input type="checkbox" checked={values.includes(item)} onChange={() => toggleValue(item)} />
                <span>{item}</span>
              </label>
            ))
          ) : (
            <div className="entity-picker-empty">Ничего не найдено</div>
          )}
        </div>
      ) : null}
    </div>
  );
}

export default function EntityDevMetaWorkspace({
  userProfile,
  embedded = false,
  taskId: externalTaskId,
  onTaskIdChange,
  releaseBranch: externalReleaseBranch,
  onReleaseBranchChange,
  hideCreateMr = false,
  hideHeader = false,
  hideTaskControls = false,
}) {
  const [status, setStatus] = useState(null);
  const [catalog, setCatalog] = useState({ entities: [], dev_files: [] });
  const [entityOptions, setEntityOptions] = useState([]);
  const [selection, setSelection] = useState({
    entity_name: "",
    schema_name: "dm",
    table_name: "",
  });
  const [moveTarget, setMoveTarget] = useState({
    entity_name: "",
    schema_name: "dm",
    table_name: "",
  });
  const [schemaMode, setSchemaMode] = useState("dm");
  const [moveSchemaMode, setMoveSchemaMode] = useState("dm");
  const [taskIdState, setTaskIdState] = useState("");
  const [releaseBranchState, setReleaseBranchState] = useState("");
  const [keyAttributesText, setKeyAttributesText] = useState("");
  const [replicaEntitiesText, setReplicaEntitiesText] = useState("");
  const [replicaPickerValues, setReplicaPickerValues] = useState([]);
  const [editorSections, setEditorSections] = useState({
    yaml: true,
    recreate: true,
    insert: true,
    truncate: true,
  });
  const [fullscreenEditor, setFullscreenEditor] = useState(null);
  const [bundle, setBundle] = useState(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [creatingPr, setCreatingPr] = useState(false);
  const [moving, setMoving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [validating, setValidating] = useState(false);
  const [message, setMessage] = useState(null);
  const [messageType, setMessageType] = useState("info");
  const [error, setError] = useState(null);
  const [fileSearch, setFileSearch] = useState("");
  const [validation, setValidation] = useState(null);
  const [validatedFingerprint, setValidatedFingerprint] = useState("");
  const [lockInfo, setLockInfo] = useState(null);
  const yamlEditorRef = useRef(null);

  const currentUser = userProfile?.email || userProfile?.username || "";
  const taskId = externalTaskId ?? taskIdState;
  const setTaskId = onTaskIdChange ?? setTaskIdState;
  const releaseBranch = externalReleaseBranch ?? releaseBranchState;
  const setReleaseBranch = onReleaseBranchChange ?? setReleaseBranchState;

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

  const branchPreview = useMemo(() => {
    const taskNorm = String(taskId || "").trim().toUpperCase();
    return taskNorm || "";
  }, [taskId]);
  const taskIdValid = /^DWH-\d+$/.test(String(taskId || "").trim().toUpperCase());

  const filteredDevFiles = useMemo(() => {
    const term = fileSearch.trim().toLowerCase();
    const rows = [...(catalog.dev_files || [])];
    if (!term) return rows;
    return rows.filter((item) => String(item.table_name || "").toLowerCase().includes(term));
  }, [catalog.dev_files, fileSearch]);
  const entityNames = useMemo(() => entityOptions.map((item) => item.entity_name), [entityOptions]);
  const groupedDevFiles = useMemo(() => {
    const tree = new Map();
    for (const item of catalog.dev_files || []) {
      if (!tree.has(item.entity_name)) tree.set(item.entity_name, new Map());
      const schemas = tree.get(item.entity_name);
      if (!schemas.has(item.schema_name)) schemas.set(item.schema_name, []);
      schemas.get(item.schema_name).push(item);
    }
    return Array.from(tree.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([entityName, schemas]) => ({
        entity_name: entityName,
        schemas: Array.from(schemas.entries())
          .sort(([a], [b]) => a.localeCompare(b))
          .map(([schemaName, items]) => ({
            schema_name: schemaName,
            items: [...items].sort((a, b) => String(a.table_name || "").localeCompare(String(b.table_name || ""))),
          })),
      }));
  }, [catalog.dev_files]);

  const currentFingerprint = useMemo(() => (bundle ? objectFingerprint(bundle) : ""), [bundle]);
  const isValidationFresh = Boolean(validation?.valid && validatedFingerprint && validatedFingerprint === currentFingerprint);

  const appendReplicaEntity = () => {
    const nextValues = replicaPickerValues
      .map((item) => String(item || "").trim())
      .filter(Boolean);
    if (!nextValues.length) return;
    const current = replicaEntitiesText
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);
    const next = [...current];
    for (const value of nextValues) {
      if (!next.includes(value) && value !== selection.entity_name) {
        next.push(value);
      }
    }
    setReplicaEntitiesText(next.join(", "));
    setReplicaPickerValues([]);
  };

  const toggleEditorSection = (section) => {
    setEditorSections((prev) => ({ ...prev, [section]: !prev[section] }));
  };

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
      setSchemaMode(COMMON_SCHEMAS.includes(target.schema_name) ? target.schema_name : CUSTOM_SCHEMA_OPTION);
      setMoveTarget({
        entity_name: target.entity_name,
        schema_name: target.schema_name,
        table_name: target.table_name,
      });
      setMoveSchemaMode(COMMON_SCHEMAS.includes(target.schema_name) ? target.schema_name : CUSTOM_SCHEMA_OPTION);
      setKeyAttributesText((prev) => (Array.isArray(data?.key_attributes) && data.key_attributes.length ? data.key_attributes.join(", ") : prev));
      setBundle(data || null);
      setEditorSections({
        yaml: true,
        recreate: true,
        insert: true,
        truncate: true,
      });
      setValidatedFingerprint("");
      setMessageType("success");
      setMessage(data?.exists ? `Объект открыт из ${data?.source || "dev"}.` : "Создан новый DEV-черновик.");
      await refreshAll();
      window.setTimeout(() => {
        yamlEditorRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
        yamlEditorRef.current?.focus();
      }, 0);
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
    await openBundle({
      ...selection,
      key_attributes: keyAttributesText.split(",").map((item) => item.trim()).filter(Boolean),
    });
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
        key_attributes: keyAttributesText.split(",").map((item) => item.trim()).filter(Boolean),
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
      if (Array.isArray(data?.normalized?.key_attributes)) {
        setKeyAttributesText(data.normalized.key_attributes.join(", "));
      }
      const nextFingerprint = objectFingerprint({
        ...bundle,
        yaml_content: data?.normalized?.yaml_content || bundle.yaml_content,
      });
      setValidatedFingerprint(data?.valid ? nextFingerprint : "");
      setMessageType(data?.valid ? "success" : "warning");
      setMessage(data?.valid ? "Проверка пройдена. Объект готов к сохранению в DEV." : "Проверка завершилась с ошибками.");
    } catch (err) {
      setError(err.message || "Не удалось провалидировать объект");
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
      setMessage("Перед сохранением нужна успешная проверка текущей версии объекта.");
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
        key_attributes: keyAttributesText.split(",").map((item) => item.trim()).filter(Boolean),
        replica_entity_names: replicaEntitiesText.split(",").map((item) => item.trim()).filter(Boolean),
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
      if (Array.isArray(data?.validation?.normalized?.key_attributes)) {
        setKeyAttributesText(data.validation.normalized.key_attributes.join(", "));
      }
      setValidation(data?.validation || null);
      setValidatedFingerprint(objectFingerprint({
        ...bundle,
        yaml_content: data?.validation?.normalized?.yaml_content || bundle.yaml_content,
      }));
      await refreshAll();
      setMessageType("success");
      setMessage(`DEV объект сохранен: ${data?.path || ""}`);
    } catch (err) {
      setError(err.message || "Не удалось сохранить объект");
    } finally {
      setSaving(false);
    }
  };

  const handleCreateMr = async () => {
    if (!taskIdValid) {
      setMessageType("warning");
      setMessage("Перед созданием MR укажите номер задачи в формате DWH-12345.");
      setError(null);
      return;
    }
    if (!String(releaseBranch || "").trim()) {
      setMessageType("warning");
      setMessage("Укажите release-ветку для MR.");
      setError(null);
      return;
    }
    setCreatingPr(true);
    setError(null);
    setMessage(null);
    try {
      const data = await entityMetaApi.createMr({
        task_id: taskId,
        release_branch: releaseBranch.trim(),
      });
      setMessageType("success");
      setMessage(data?.mr_url ? `MR создан/обновлен: ${data.mr_url}` : "MR создан/обновлен.");
    } catch (err) {
      setError(err.message || "Не удалось создать MR");
    } finally {
      setCreatingPr(false);
    }
  };

  const handleDelete = async () => {
    if (!bundle) return;
    if (!taskIdValid) {
      setMessageType("warning");
      setMessage("Перед удалением укажите номер задачи в формате DWH-12345.");
      setError(null);
      return;
    }
    const confirmed = window.confirm(`Удалить DEV объект ${bundle.object_key}?`);
    if (!confirmed) return;

    setDeleting(true);
    setError(null);
    setMessage(null);
    try {
      await entityMetaApi.delete({
        entity_name: selection.entity_name,
        schema_name: selection.schema_name,
        table_name: selection.table_name,
        task_id: taskId,
      });
      setBundle(null);
      setValidation(null);
      setValidatedFingerprint("");
      setLockInfo(null);
      await refreshAll();
      setMessageType("success");
      setMessage("DEV объект удален.");
    } catch (err) {
      setError(err.message || "Не удалось удалить объект");
    } finally {
      setDeleting(false);
    }
  };

  const handleMove = async () => {
    if (!bundle) return;
    if (!taskIdValid) {
      setMessageType("warning");
      setMessage("Перед переносом укажите номер задачи в формате DWH-12345.");
      setError(null);
      return;
    }
    if (!moveTarget.entity_name || !moveTarget.schema_name || !moveTarget.table_name) {
      setError("Для переноса нужно заполнить целевую сущность, схему и таблицу");
      return;
    }
    setMoving(true);
    setError(null);
    setMessage(null);
    try {
      const data = await entityMetaApi.move({
        source_entity_name: selection.entity_name,
        source_schema_name: selection.schema_name,
        source_table_name: selection.table_name,
        target_entity_name: moveTarget.entity_name,
        target_schema_name: moveTarget.schema_name,
        target_table_name: moveTarget.table_name,
        task_id: taskId,
      });
      if (data?.bundle) {
        setBundle(data.bundle);
        setSelection({
          entity_name: data.bundle.entity_name,
          schema_name: data.bundle.schema_name,
          table_name: data.bundle.table_name,
        });
        setSchemaMode(COMMON_SCHEMAS.includes(data.bundle.schema_name) ? data.bundle.schema_name : CUSTOM_SCHEMA_OPTION);
        setMoveTarget({
          entity_name: data.bundle.entity_name,
          schema_name: data.bundle.schema_name,
          table_name: data.bundle.table_name,
        });
        setMoveSchemaMode(COMMON_SCHEMAS.includes(data.bundle.schema_name) ? data.bundle.schema_name : CUSTOM_SCHEMA_OPTION);
        setKeyAttributesText(Array.isArray(data.bundle.key_attributes) ? data.bundle.key_attributes.join(", ") : "");
      }
      setValidation(null);
      setValidatedFingerprint("");
      await acquireLock({
        entity_name: moveTarget.entity_name,
        schema_name: moveTarget.schema_name,
        table_name: moveTarget.table_name,
      });
      await refreshAll();
      setMessageType("success");
      setMessage(`Объект перемещен: ${data?.object_key || ""}`);
    } catch (err) {
      setError(err.message || "Не удалось переместить объект");
    } finally {
      setMoving(false);
    }
  };

  const content = (
      <section className={embedded ? "dev-meta-page" : "cc-surface dev-meta-page"}>
        {!hideHeader ? (
          <>
            <div className="section-title">DEV Meta Workspace</div>
            <div className="section-subtitle">
              Редактор для `tech_etl/etl_loads_entity`: отдельная DEV-копия YAML и SQL перед релизом.
            </div>
          </>
        ) : null}

        {!embedded ? (
          <div className="dev-meta-toolbar">
            <div className="muted">
              DEV root: {status?.dev_root || "—"} · Lock TTL: {status?.lock_ttl_minutes ?? 30} мин.
            </div>
          </div>
        ) : null}

        <div className="dev-meta-generator">
          <div className="section-subtitle">Открыть объект или создать DEV-черновик</div>
          <div className="dev-meta-generator-grid">
            <label className="admin-field">
              <span>Сущность</span>
              <EntityPicker
                options={entityNames}
                value={selection.entity_name}
                onChange={(next) => setSelection((prev) => ({ ...prev, entity_name: next }))}
                placeholder="BI_SB_WUC"
              />
            </label>
            <label className="admin-field">
              <span>Схема</span>
              <select
                className="admin-select"
                value={schemaMode}
                onChange={(e) => {
                  const nextMode = e.target.value;
                  setSchemaMode(nextMode);
                  if (nextMode !== CUSTOM_SCHEMA_OPTION) {
                    setSelection((prev) => ({ ...prev, schema_name: nextMode }));
                  }
                }}
              >
                {COMMON_SCHEMAS.map((item) => (
                  <option key={item} value={item}>
                    {item}
                  </option>
                ))}
                <option value={CUSTOM_SCHEMA_OPTION}>Другая схема</option>
              </select>
              {schemaMode === CUSTOM_SCHEMA_OPTION ? (
                <input
                  value={selection.schema_name}
                  onChange={(e) => setSelection((prev) => ({ ...prev, schema_name: e.target.value }))}
                  placeholder="custom_schema"
                />
              ) : null}
            </label>
            <label className="admin-field">
              <span>Таблица</span>
              <input
                value={selection.table_name}
                onChange={(e) => setSelection((prev) => ({ ...prev, table_name: e.target.value }))}
                placeholder="transport_bill"
              />
            </label>
            {!hideTaskControls ? (
              <>
                <label className="admin-field">
                  <span>Задача</span>
                  <input
                    value={taskId}
                    onChange={(e) => setTaskId(e.target.value.toUpperCase())}
                    placeholder="DWH-12345"
                  />
                </label>
                <label className="admin-field">
                  <span>Release ветка</span>
                  <input
                    value={releaseBranch}
                    onChange={(e) => setReleaseBranch(e.target.value)}
                    placeholder="release/2026-05-18"
                  />
                </label>
              </>
            ) : null}
            <label className="admin-field dev-meta-generator-wide">
              <span>Ключи</span>
              <input
                value={keyAttributesText}
                onChange={(e) => setKeyAttributesText(e.target.value)}
                placeholder="delivery_number_sales, batch, dt_report"
              />
            </label>
            <label className="admin-field dev-meta-generator-wide">
                <span>Размножить в сущности</span>
              <div className="dev-meta-replica-picker">
                <MultiEntityPicker
                  options={entityNames.filter((item) => item !== selection.entity_name)}
                  values={replicaPickerValues}
                  onChange={setReplicaPickerValues}
                  placeholder="Выберите сущности"
                />
                <button type="button" className="btn btn-secondary" onClick={appendReplicaEntity} disabled={!replicaPickerValues.length}>
                  Добавить выбранные
                </button>
              </div>
              <input
                value={replicaEntitiesText}
                onChange={(e) => setReplicaEntitiesText(e.target.value)}
                placeholder="MANAGMENT_REPORTING_2, MANAGMENT_REPORTING_3"
              />
            </label>
          </div>
          <div className="dev-meta-generator-actions">
            <button className="btn btn-primary" onClick={handleOpenCurrentSelection} disabled={loading}>
              {loading ? "Открываем..." : "Открыть / создать DEV-черновик"}
            </button>
            {!hideCreateMr ? (
              <button className="btn btn-secondary" onClick={handleCreateMr} disabled={creatingPr || !taskIdValid || !String(releaseBranch || "").trim()}>
                {creatingPr ? "Создаем MR..." : "Создать MR"}
              </button>
            ) : null}
            <span className="muted">{branchPreview ? `Ветка: ${branchPreview}` : "Укажите задачу, сущность, схему и таблицу"}</span>
          </div>
        </div>

        {bundle?.exists && (
          <div className="dev-meta-generator">
            <div className="section-subtitle">Перемещение и удаление</div>
            <div className="dev-meta-generator-grid">
              <label className="admin-field">
                <span>Новая сущность</span>
                <EntityPicker
                  options={entityNames}
                  value={moveTarget.entity_name}
                  onChange={(next) => setMoveTarget((prev) => ({ ...prev, entity_name: next }))}
                  placeholder="BI_FI"
                />
              </label>
              <label className="admin-field">
                <span>Новая схема</span>
                <select
                  className="admin-select"
                  value={moveSchemaMode}
                  onChange={(e) => {
                    const nextMode = e.target.value;
                    setMoveSchemaMode(nextMode);
                    if (nextMode !== CUSTOM_SCHEMA_OPTION) {
                      setMoveTarget((prev) => ({ ...prev, schema_name: nextMode }));
                    }
                  }}
                >
                  {COMMON_SCHEMAS.map((item) => (
                    <option key={item} value={item}>
                      {item}
                    </option>
                  ))}
                  <option value={CUSTOM_SCHEMA_OPTION}>Другая схема</option>
                </select>
                {moveSchemaMode === CUSTOM_SCHEMA_OPTION ? (
                  <input
                    value={moveTarget.schema_name}
                    onChange={(e) => setMoveTarget((prev) => ({ ...prev, schema_name: e.target.value }))}
                    placeholder="custom_schema"
                  />
                ) : null}
              </label>
              <label className="admin-field">
                <span>Новая таблица</span>
                <input
                  value={moveTarget.table_name}
                  onChange={(e) => setMoveTarget((prev) => ({ ...prev, table_name: e.target.value }))}
                  placeholder="sb_wuc"
                />
              </label>
            </div>
            <div className="dev-meta-generator-actions">
              <button className="btn btn-secondary" onClick={handleMove} disabled={!bundle || moving}>
                {moving ? "Перемещаем..." : "Переместить объект"}
              </button>
              <button className="btn btn-danger" onClick={handleDelete} disabled={!bundle || deleting}>
                {deleting ? "Удаляем..." : "Удалить объект"}
              </button>
            </div>
          </div>
        )}

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
                  placeholder="Поиск по имени объекта"
                />
              </div>
            </div>
            {fileSearch.trim() ? (
              <div className="dev-meta-file-list">
                {filteredDevFiles.map((file) => (
                  <button
                    key={file.object_key}
                    className={`dev-meta-file ${bundle?.object_key === file.object_key ? "active" : ""}`}
                    onClick={() => openBundle(file)}
                  >
                    <span className="mono dev-meta-file-short">{file.table_name}</span>
                    <span className="dev-meta-file-path">{file.entity_name} / {file.schema_name}</span>
                    <span className="muted">{formatRuDateTime(file.updated_at)}</span>
                  </button>
                ))}
              </div>
            ) : (
              <div className="dev-meta-tree">
                {groupedDevFiles.map((entityNode) => (
                  <details key={entityNode.entity_name} className="dev-meta-tree-entity">
                    <summary className="dev-meta-tree-summary">{entityNode.entity_name}</summary>
                    <div className="dev-meta-tree-schemas">
                      {entityNode.schemas.map((schemaNode) => (
                        <details key={`${entityNode.entity_name}-${schemaNode.schema_name}`} className="dev-meta-tree-schema">
                          <summary className="dev-meta-tree-summary schema">{schemaNode.schema_name}</summary>
                          <div className="dev-meta-file-list compact">
                            {schemaNode.items.map((file) => (
                              <button
                                key={file.object_key}
                                className={`dev-meta-file ${bundle?.object_key === file.object_key ? "active" : ""}`}
                                onClick={() => openBundle(file)}
                              >
                                <span className="mono dev-meta-file-short">{file.table_name}</span>
                                <span className="mono dev-meta-file-path">{file.object_key}</span>
                                <span className="muted">{formatRuDateTime(file.updated_at)}</span>
                              </button>
                            ))}
                          </div>
                        </details>
                      ))}
                    </div>
                  </details>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="dev-meta-layout">
          <div className="dev-meta-editor-shell">
            <div className="dev-meta-editor-head">
              <div className="dev-meta-editor-title">
                <div className="section-subtitle">Редактор объекта</div>
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

            {(message || error) && (
              <div className={`dev-meta-feedback inline ${error ? "error" : messageType}`}>
                <div className="dev-meta-feedback-title">
                  {error ? "Операция не выполнена" : messageType === "success" ? "Успешно" : messageType === "warning" ? "Нужно исправить" : "Статус"}
                </div>
                <div className="dev-meta-feedback-text">{error || message}</div>
              </div>
            )}

            {validation && (
              <div className="dev-meta-validation">
                <div className="section-subtitle">Результат проверки</div>
                <div className={`dev-meta-validation-pill ${validation.valid ? "ok" : "bad"}`}>
                  {validation.valid ? "Объект валиден" : "Есть ошибки"}
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
                {validation.checks?.length ? (
                  <ul className="dev-meta-validation-list info">
                    {validation.checks.map((item, idx) => (
                      <li key={`entity-dev-check-${idx}`}>{item}</li>
                    ))}
                  </ul>
                ) : null}
              </div>
            )}

            <div className="entity-dev-editors">
              <label className="admin-field entity-dev-editor-field">
                <button type="button" className="entity-dev-editor-toggle" onClick={() => toggleEditorSection("yaml")}>
                  <span className="entity-dev-editor-label">
                    <span>YAML</span>
                    <span className="entity-dev-editor-state">{editorSections.yaml ? "Открыт" : "Свернут"}</span>
                  </span>
                  <span className="entity-dev-editor-toggle-actions">
                    <span className="entity-dev-editor-expand" onClick={(e) => { e.stopPropagation(); setFullscreenEditor("yaml"); }} title="Раскрыть полностью" aria-label="Раскрыть полностью">
                      ⤢
                    </span>
                    <span className={`entity-dev-editor-chevron ${editorSections.yaml ? "open" : ""}`}>⌄</span>
                  </span>
                </button>
                {editorSections.yaml ? (
                  <textarea
                    ref={yamlEditorRef}
                    className="dev-meta-editor entity-dev-editor"
                    value={bundle?.yaml_content || ""}
                    onChange={(e) => setBundle((prev) => ({ ...prev, yaml_content: e.target.value }))}
                    placeholder="meta_data_file.yaml"
                  />
                ) : null}
              </label>
              <label className="admin-field entity-dev-editor-field">
                <button type="button" className="entity-dev-editor-toggle" onClick={() => toggleEditorSection("recreate")}>
                  <span className="entity-dev-editor-label">
                    <span>Recreate SQL</span>
                    <span className="entity-dev-editor-state">{editorSections.recreate ? "Открыт" : "Свернут"}</span>
                  </span>
                  <span className="entity-dev-editor-toggle-actions">
                    <span className="entity-dev-editor-expand" onClick={(e) => { e.stopPropagation(); setFullscreenEditor("recreate"); }} title="Раскрыть полностью" aria-label="Раскрыть полностью">
                      ⤢
                    </span>
                    <span className={`entity-dev-editor-chevron ${editorSections.recreate ? "open" : ""}`}>⌄</span>
                  </span>
                </button>
                {editorSections.recreate ? (
                  <textarea
                    className="dev-meta-editor entity-dev-editor"
                    value={bundle?.recreate_sql || ""}
                    onChange={(e) => setBundle((prev) => ({ ...prev, recreate_sql: e.target.value }))}
                    placeholder="sql_query_recreate_init.sql"
                  />
                ) : null}
              </label>
              <label className="admin-field entity-dev-editor-field">
                <button type="button" className="entity-dev-editor-toggle" onClick={() => toggleEditorSection("insert")}>
                  <span className="entity-dev-editor-label">
                    <span>Insert SQL</span>
                    <span className="entity-dev-editor-state">{editorSections.insert ? "Открыт" : "Свернут"}</span>
                  </span>
                  <span className="entity-dev-editor-toggle-actions">
                    <span className="entity-dev-editor-expand" onClick={(e) => { e.stopPropagation(); setFullscreenEditor("insert"); }} title="Раскрыть полностью" aria-label="Раскрыть полностью">
                      ⤢
                    </span>
                    <span className={`entity-dev-editor-chevron ${editorSections.insert ? "open" : ""}`}>⌄</span>
                  </span>
                </button>
                {editorSections.insert ? (
                  <textarea
                    className="dev-meta-editor entity-dev-editor"
                    value={bundle?.insert_sql || ""}
                    onChange={(e) => setBundle((prev) => ({ ...prev, insert_sql: e.target.value }))}
                    placeholder="sql_query_insert_init.sql"
                  />
                ) : null}
              </label>
              <label className="admin-field entity-dev-editor-field">
                <button type="button" className="entity-dev-editor-toggle" onClick={() => toggleEditorSection("truncate")}>
                  <span className="entity-dev-editor-label">
                    <span>Truncate SQL</span>
                    <span className="entity-dev-editor-state">{editorSections.truncate ? "Открыт" : "Свернут"}</span>
                  </span>
                  <span className="entity-dev-editor-toggle-actions">
                    <span className="entity-dev-editor-expand" onClick={(e) => { e.stopPropagation(); setFullscreenEditor("truncate"); }} title="Раскрыть полностью" aria-label="Раскрыть полностью">
                      ⤢
                    </span>
                    <span className={`entity-dev-editor-chevron ${editorSections.truncate ? "open" : ""}`}>⌄</span>
                  </span>
                </button>
                {editorSections.truncate ? (
                  <textarea
                    className="dev-meta-editor entity-dev-editor"
                    value={bundle?.truncate_sql || ""}
                    onChange={(e) => setBundle((prev) => ({ ...prev, truncate_sql: e.target.value }))}
                    placeholder="sql_query_truncate.sql"
                  />
                ) : null}
              </label>
            </div>
            {fullscreenEditor ? (
              <div className="entity-dev-modal">
                <div className="entity-dev-modal-card">
                  <div className="entity-dev-modal-head">
                    <strong>
                      {fullscreenEditor === "yaml" ? "YAML" : fullscreenEditor === "recreate" ? "Recreate SQL" : fullscreenEditor === "insert" ? "Insert SQL" : "Truncate SQL"}
                    </strong>
                    <button type="button" className="btn btn-secondary" onClick={() => setFullscreenEditor(null)}>
                      Закрыть
                    </button>
                  </div>
                  <textarea
                    className="dev-meta-editor entity-dev-editor entity-dev-editor-modal"
                    value={
                      fullscreenEditor === "yaml"
                        ? bundle?.yaml_content || ""
                        : fullscreenEditor === "recreate"
                          ? bundle?.recreate_sql || ""
                          : fullscreenEditor === "insert"
                            ? bundle?.insert_sql || ""
                            : bundle?.truncate_sql || ""
                    }
                    onChange={(e) =>
                      setBundle((prev) => ({
                        ...prev,
                        [fullscreenEditor === "yaml"
                          ? "yaml_content"
                          : fullscreenEditor === "recreate"
                            ? "recreate_sql"
                            : fullscreenEditor === "insert"
                              ? "insert_sql"
                              : "truncate_sql"]: e.target.value,
                      }))
                    }
                  />
                </div>
              </div>
            ) : null}
          </div>
        </div>
      </section>
  );
  return embedded ? content : <div className="container cc-page">{content}</div>;
}
