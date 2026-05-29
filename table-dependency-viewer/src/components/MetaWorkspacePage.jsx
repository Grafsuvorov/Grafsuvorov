import React, { useEffect, useMemo, useState } from "react";
import DevMetaAdminPage from "./DevMetaAdminPage.jsx";
import EntityDevMetaWorkspace from "./EntityDevMetaWorkspace.jsx";
import { metaWorkspaceApi } from "../api/metaWorkspace.js";

function groupGpObjects(items) {
  const tree = new Map();
  for (const item of items || []) {
    if (!tree.has(item.entity_name)) tree.set(item.entity_name, new Map());
    const schemaMap = tree.get(item.entity_name);
    if (!schemaMap.has(item.schema_name)) schemaMap.set(item.schema_name, []);
    schemaMap.get(item.schema_name).push(item);
  }
  return Array.from(tree.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([entityName, schemaMap]) => ({
      entity_name: entityName,
      schemas: Array.from(schemaMap.entries())
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([schemaName, rows]) => ({
          schema_name: schemaName,
          items: [...rows].sort((a, b) => String(a.table_name || "").localeCompare(String(b.table_name || ""))),
        })),
    }));
}

function groupClickObjects(items) {
  const tree = new Map();
  for (const item of items || []) {
    if (!tree.has(item.schema_name)) tree.set(item.schema_name, []);
    tree.get(item.schema_name).push(item);
  }
  return Array.from(tree.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([schemaName, rows]) => ({
      schema_name: schemaName,
      items: [...rows].sort((a, b) => String(a.file_name || "").localeCompare(String(b.file_name || ""))),
    }));
}

export default function MetaWorkspacePage({ userProfile }) {
  const [mode, setMode] = useState("gp");
  const [taskId, setTaskId] = useState("");
  const [releaseBranch, setReleaseBranch] = useState("");
  const [branchName, setBranchName] = useState("");
  const [baseBranch, setBaseBranch] = useState("main");
  const [branchOptions, setBranchOptions] = useState([]);
  const [branchNameEdited, setBranchNameEdited] = useState(false);
  const [branchCatalog, setBranchCatalog] = useState({ gp_objects: [], click_objects: [] });
  const [catalogLoading, setCatalogLoading] = useState(false);
  const [creatingMr, setCreatingMr] = useState(false);
  const [message, setMessage] = useState(null);
  const [error, setError] = useState(null);
  const [gpOpenRequest, setGpOpenRequest] = useState(null);
  const [clickOpenRequest, setClickOpenRequest] = useState(null);
  const [activeSelection, setActiveSelection] = useState(null);
  const [branchValidation, setBranchValidation] = useState(null);
  const [validatingBranch, setValidatingBranch] = useState(false);
  const [syncingBranch, setSyncingBranch] = useState(false);
  const [creatingBranch, setCreatingBranch] = useState(false);
  const [branchTree, setBranchTree] = useState({ gp_entities: [], click_schemas: [] });
  const [treeLoading, setTreeLoading] = useState(false);
  const [branchFileLoading, setBranchFileLoading] = useState(false);
  const [gpBranchBundle, setGpBranchBundle] = useState(null);
  const branchScopedActive = Boolean(branchCatalog.branch_name);

  const taskIdValid = /^DWH-\d+$/.test(String(taskId || "").trim().toUpperCase());
  const suggestedBranchName = useMemo(
    () => (taskIdValid ? `feature/${String(taskId || "").trim().toUpperCase()}` : ""),
    [taskId, taskIdValid]
  );
  const groupedGp = useMemo(() => groupGpObjects(branchCatalog.gp_objects), [branchCatalog.gp_objects]);
  const groupedClick = useMemo(() => groupClickObjects(branchCatalog.click_objects), [branchCatalog.click_objects]);
  const branchSummary = useMemo(
    () => ({
      gp: branchCatalog.gp_objects?.length || 0,
      click: branchCatalog.click_objects?.length || 0,
    }),
    [branchCatalog]
  );
  const filteredBranchOptions = useMemo(() => {
    const term = String(branchName || "").trim().toLowerCase();
    if (!term) return branchOptions;
    return branchOptions.filter((item) => String(item || "").toLowerCase().includes(term));
  }, [branchOptions, branchName]);
  const allowedGpObjectKeys = useMemo(
    () => new Set((branchCatalog.gp_objects || []).map((item) => item.object_key).filter(Boolean)),
    [branchCatalog.gp_objects]
  );
  const allowedClickFiles = useMemo(
    () => new Set((branchCatalog.click_objects || []).map((item) => `${item.schema_name}/${item.file_name}`).filter(Boolean)),
    [branchCatalog.click_objects]
  );
  const hasGpObjects = branchSummary.gp > 0;
  const hasClickObjects = branchSummary.click > 0;
  const showGpTab = !branchScopedActive || hasGpObjects;
  const showClickTab = !branchScopedActive || hasClickObjects;
  useEffect(() => {
    metaWorkspaceApi.branches()
      .then((data) => setBranchOptions(data?.items || []))
      .catch((err) => setError(err.message || "Не удалось загрузить список веток"));
  }, []);

  useEffect(() => {
    if (!suggestedBranchName || branchNameEdited) return;
    setBranchName(suggestedBranchName);
  }, [suggestedBranchName, branchNameEdited]);

  useEffect(() => {
    if (!branchScopedActive) return;
    if (mode === "gp" && !showGpTab && showClickTab) {
      setMode("click");
    } else if (mode === "click" && !showClickTab && showGpTab) {
      setMode("gp");
    }
  }, [branchScopedActive, mode, showClickTab, showGpTab]);

  const loadBranchCatalog = async (selectedBranch) => {
    const branchValue = String(selectedBranch || branchName || "").trim();
    if (!branchValue) {
      setError("Укажите ветку для просмотра изменений");
      return;
    }
    if (!String(baseBranch || "").trim()) {
      setError("Укажите base-ветку");
      return;
    }
    setCatalogLoading(true);
    setTreeLoading(true);
    setError(null);
    setMessage(null);
    try {
      const [data, treeData] = await Promise.all([
        metaWorkspaceApi.branchCatalog({
          branch_name: branchValue,
          base_branch: baseBranch.trim(),
        }),
        metaWorkspaceApi.branchTree({
          branch_name: branchValue,
          base_branch: baseBranch.trim(),
        }),
      ]);
      setBranchCatalog(data || { gp_objects: [], click_objects: [] });
      setBranchTree(treeData || { gp_entities: [], click_schemas: [] });
      setMessage("Каталог изменений ветки обновлен.");
    } catch (err) {
      setError(err.message || "Не удалось построить каталог ветки");
    } finally {
      setCatalogLoading(false);
      setTreeLoading(false);
    }
  };

  const handleSelectBranch = async (nextBranch) => {
    setBranchNameEdited(true);
    setBranchName(nextBranch);
    await loadBranchCatalog(nextBranch);
  };

  const handleCreateMr = async () => {
    if (!taskIdValid) {
      setError(null);
      setMessage("Укажите номер задачи в формате DWH-12345.");
      return;
    }
    if (!String(releaseBranch || "").trim()) {
      setError(null);
      setMessage("Укажите release-ветку.");
      return;
    }
    setCreatingMr(true);
    setMessage(null);
    setError(null);
    try {
      const data = await metaWorkspaceApi.createMr({
        task_id: taskId.trim().toUpperCase(),
        release_branch: releaseBranch.trim(),
      });
      setMessage(data?.mr_url ? `MR создан/обновлен: ${data.mr_url}` : "MR создан/обновлен.");
    } catch (err) {
      setError(err.message || "Не удалось создать MR");
    } finally {
      setCreatingMr(false);
    }
  };

  const handleCreateBranch = async () => {
    const nextBranch = String(branchName || "").trim();
    if (!nextBranch) {
      setError("Укажите имя новой ветки");
      return;
    }
    setCreatingBranch(true);
    setError(null);
    setMessage(null);
    try {
      const data = await metaWorkspaceApi.createBranch({
        branch_name: nextBranch,
        base_branch: "main",
      });
      setBaseBranch("main");
      const refreshed = await metaWorkspaceApi.branches();
      setBranchOptions(refreshed?.items || []);
      setMessage(
        data?.already_exists
          ? `Ветка уже существует: ${data.branch_name}`
          : `Ветка создана от ${data.base_branch}: ${data.branch_name}`
      );
      await loadBranchCatalog(nextBranch);
      jumpToGenerator("gp");
    } catch (err) {
      setError(err.message || "Не удалось создать ветку");
    } finally {
      setCreatingBranch(false);
    }
  };

  const handleValidateAll = async () => {
    if (!String(branchName || "").trim() || !String(baseBranch || "").trim()) {
      setError("Укажите ветку и base-ветку");
      return;
    }
    setValidatingBranch(true);
    setError(null);
    setMessage(null);
    try {
      const data = await metaWorkspaceApi.validateAll({
        branch_name: branchName.trim(),
        base_branch: baseBranch.trim(),
      });
      setBranchValidation(data || null);
      setMessage("Проверка всех объектов ветки завершена.");
    } catch (err) {
      setError(err.message || "Не удалось проверить объекты ветки");
    } finally {
      setValidatingBranch(false);
    }
  };

  const handleSyncBranch = async () => {
    if (!taskIdValid) {
      setError("Укажите номер задачи в формате DWH-12345");
      return;
    }
    if (!String(branchName || "").trim() || !String(baseBranch || "").trim()) {
      setError("Укажите ветку и base-ветку");
      return;
    }
    setSyncingBranch(true);
    setError(null);
    setMessage(null);
    try {
      const data = await metaWorkspaceApi.syncBranch({
        task_id: taskId.trim().toUpperCase(),
        branch_name: branchName.trim(),
        base_branch: baseBranch.trim(),
      });
      const committedText = data?.committed ? "Изменения закоммичены и отправлены в ветку." : "Новых изменений для коммита не было, ветка обновлена.";
      setMessage(`${committedText} Ветка: ${data?.branch_name || branchName.trim()}`);
      await loadBranchCatalog(branchName.trim());
    } catch (err) {
      setError(err.message || "Не удалось сохранить изменения в ветку");
    } finally {
      setSyncingBranch(false);
    }
  };

  const openGpObject = (item) => {
    if (branchScopedActive) {
      handleOpenBranchGpTable(item.entity_name, item.schema_name, item.table_name);
      return;
    }
    setMode("gp");
    setActiveSelection({
      domain: "gp",
      title: `${item.entity_name} / ${item.schema_name} / ${item.table_name}`,
    });
    setGpOpenRequest({
      token: `${item.object_key}:${Date.now()}`,
      entity_name: item.entity_name,
      schema_name: item.schema_name,
      table_name: item.table_name,
    });
  };

  const openClickObject = (item) => {
    setMode("click");
    setActiveSelection({
      domain: "click",
      title: `${item.schema_name} / ${item.file_name}`,
    });
    setClickOpenRequest({
      token: `${item.object_key}:${Date.now()}`,
      schema_name: item.schema_name,
      file_name: item.file_name,
    });
  };

  const handleBackToBranchList = () => {
    setActiveSelection(null);
    setGpOpenRequest(null);
    setClickOpenRequest(null);
    window.requestAnimationFrame(() => {
      document.getElementById("meta-workspace-branch-browser")?.scrollIntoView({
        behavior: "smooth",
        block: "start",
      });
    });
  };

  const handleOpenBranchGpTable = async (entityName, schemaName, tableName) => {
    if (!String(branchName || "").trim() || !entityName || !schemaName || !tableName) return;
    setBranchFileLoading(true);
    setError(null);
    try {
      const data = await metaWorkspaceApi.branchGpBundle({
        branch_name: branchName.trim(),
        entity_name: entityName,
        schema_name: schemaName,
        table_name: tableName,
      });
      setGpBranchBundle({
        token: `${data.object_key}:${Date.now()}`,
        branch_name: data.branch_name,
        bundle: data,
      });
      setMode("gp");
      setActiveSelection({
        domain: "gp",
        title: `${entityName} / ${schemaName} / ${tableName}`,
      });
    } catch (err) {
      setError(err.message || "Не удалось открыть объект ветки");
    } finally {
      setBranchFileLoading(false);
    }
  };

  const jumpToGenerator = (nextMode) => {
    setMode(nextMode);
    setActiveSelection(null);
    const targetId = nextMode === "gp" ? "meta-workspace-gp-generator" : "meta-workspace-click-generator";
    window.requestAnimationFrame(() => {
      document.getElementById(targetId)?.scrollIntoView({
        behavior: "smooth",
        block: "start",
      });
    });
  };

  return (
    <div className="container cc-page">
      <section className="cc-surface dev-meta-page meta-workspace-page">
        <div className="meta-workspace-hero">
          <div className="meta-workspace-hero-copy">
            <div className="section-title">Meta Workspace</div>
            <div className="section-subtitle">Выберите git-ветку, найдите измененные объекты и откройте их в редакторе прямо из рабочего контура релиза.</div>
          </div>
          <div className="meta-workspace-badge">Admin only</div>
        </div>

        {(message || error) && (
          <div className={`dev-meta-feedback ${error ? "error" : "success"}`}>
            <div className="dev-meta-feedback-title">{error ? "Операция не выполнена" : "Статус"}</div>
            <div className="dev-meta-feedback-text">{error || message}</div>
          </div>
        )}

        <div className="dev-meta-generator meta-workspace-context">
          <div className="meta-workspace-context-head">
            <div>
              <div className="section-subtitle">Общий раздел задачи</div>
              <div className="muted">Один MR для всех изменений этой задачи.</div>
            </div>
          </div>
          <div className="dev-meta-generator-grid meta-workspace-context-grid">
            <label className="admin-field">
              <span>Задача</span>
              <input value={taskId} onChange={(e) => setTaskId(e.target.value.toUpperCase())} placeholder="DWH-12345" />
            </label>
            <label className="admin-field">
              <span>Release ветка</span>
              <input value={releaseBranch} onChange={(e) => setReleaseBranch(e.target.value)} placeholder="release/2026-05-19" />
            </label>
          </div>
          <div className="dev-meta-generator-actions">
            <button type="button" className="btn btn-secondary" onClick={handleCreateMr} disabled={creatingMr || !taskIdValid || !String(releaseBranch || "").trim()}>
              {creatingMr ? "Создаем MR..." : "Создать MR"}
            </button>
            <span className="muted">В один MR попадут GP объекты и Click файлы этой задачи.</span>
          </div>
        </div>

        <div className="dev-meta-generator meta-workspace-context">
          <div className="meta-workspace-context-head">
            <div>
              <div className="section-subtitle">Измененные объекты в выбранной ветке</div>
            </div>
          </div>
          <div className="dev-meta-generator-grid meta-workspace-context-grid">
            <label className="admin-field">
              <span>Ветка</span>
              <input
                list="meta-workspace-branches"
                value={branchName}
                onChange={(e) => {
                  setBranchNameEdited(true);
                  setBranchName(e.target.value);
                }}
                placeholder="feature/DWH-12345"
              />
              <datalist id="meta-workspace-branches">
                {branchOptions.map((item) => <option key={item} value={item} />)}
              </datalist>
            </label>
            <label className="admin-field">
              <span>Base ветка</span>
              <input value={baseBranch} onChange={(e) => setBaseBranch(e.target.value)} placeholder="main" />
            </label>
          </div>
          <div className="dev-meta-generator-actions">
            <button type="button" className="btn btn-secondary" onClick={handleCreateBranch} disabled={creatingBranch || !String(branchName || "").trim()}>
              {creatingBranch ? "Создаем ветку..." : "Создать ветку от main"}
            </button>
            <button type="button" className="btn btn-primary" onClick={() => loadBranchCatalog()} disabled={catalogLoading || !String(branchName || "").trim() || !String(baseBranch || "").trim()}>
              {catalogLoading ? "Обновляем diff..." : "Показать изменения ветки"}
            </button>
            <button type="button" className="btn btn-secondary" onClick={handleValidateAll} disabled={validatingBranch || !String(branchName || "").trim() || !String(baseBranch || "").trim()}>
              {validatingBranch ? "Проверяем всё..." : "Проверить все объекты ветки"}
            </button>
            <span className="muted">GP: {branchSummary.gp} · Click: {branchSummary.click}</span>
          </div>
          <div className="meta-workspace-branch-picker">
            {filteredBranchOptions.length ? filteredBranchOptions.slice(0, 40).map((item) => (
              <button
                key={item}
                type="button"
                className={`meta-workspace-branch-pill ${item === branchCatalog.branch_name ? "active" : ""}`}
                onClick={() => handleSelectBranch(item)}
                disabled={catalogLoading}
              >
                {item}
              </button>
            )) : (
              <div className="muted">Подходящих веток не найдено.</div>
            )}
          </div>
        </div>

        <div className="meta-workspace-branch-browser" id="meta-workspace-branch-browser">
          {showGpTab ? (
          <div className="meta-workspace-branch-column">
            <div className="section-subtitle">Greenplum</div>
            <div className="meta-workspace-branch-tree">
              {groupedGp.length ? groupedGp.map((entityGroup) => (
                <div key={entityGroup.entity_name} className="meta-workspace-entity-group">
                  <div className="meta-workspace-entity-title">{entityGroup.entity_name}</div>
                  {entityGroup.schemas.map((schemaGroup) => (
                    <div key={`${entityGroup.entity_name}/${schemaGroup.schema_name}`} className="meta-workspace-schema-group">
                      <div className="meta-workspace-schema-title">{schemaGroup.schema_name}</div>
                      <div className="meta-workspace-table-list">
                        {schemaGroup.items.map((item) => (
                          <button
                            type="button"
                            key={item.object_key}
                            className={`meta-workspace-object-card change-${item.change_type}`}
                            onClick={() => openGpObject(item)}
                          >
                            <span className="meta-workspace-object-name">{item.table_name}</span>
                            <span className="meta-workspace-object-meta">{item.changed_files.join(", ")}</span>
                          </button>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              )) : <div className="muted">Измененных GP-объектов пока нет.</div>}
            </div>
          </div>
          ) : null}

          {showClickTab ? (
          <div className="meta-workspace-branch-column">
            <div className="section-subtitle">ClickHouse</div>
            <div className="meta-workspace-branch-tree">
              {groupedClick.length ? groupedClick.map((schemaGroup) => (
                <div key={schemaGroup.schema_name} className="meta-workspace-schema-group">
                  <div className="meta-workspace-schema-title">{schemaGroup.schema_name}</div>
                  <div className="meta-workspace-table-list">
                    {schemaGroup.items.map((item) => (
                      <button
                        type="button"
                        key={item.object_key}
                        className={`meta-workspace-object-card change-${item.change_type}`}
                        onClick={() => openClickObject(item)}
                      >
                        <span className="meta-workspace-object-name">{item.file_name}</span>
                        <span className="meta-workspace-object-meta">{item.object_kind === "view" ? "Click view" : "Click table"}</span>
                      </button>
                    ))}
                  </div>
                </div>
              )) : <div className="muted">Измененных Click-файлов пока нет.</div>}
            </div>
          </div>
          ) : null}
        </div>

        <div className="dev-meta-generator meta-workspace-context">
          <div className="meta-workspace-context-head">
            <div>
              <div className="section-subtitle">Структура ветки</div>
              <div className="muted">Выбранная ветка: {branchCatalog.branch_name || branchName || "—"}</div>
            </div>
          </div>
          <div className="dev-meta-generator-actions">
            <span className="muted">{treeLoading ? "Читаем дерево ветки..." : "Можно открыть и сохранить любой файл прямо в ветку."}</span>
          </div>
          <div className="meta-workspace-real-tree">
            <div className="meta-workspace-branch-column">
              <div className="section-subtitle">Greenplum</div>
              {(branchTree.gp_entities || []).length ? (
                (branchTree.gp_entities || []).map((entity) => (
                  <details key={entity.entity_name} className="meta-workspace-tree-node">
                    <summary className="meta-workspace-tree-summary entity">{entity.entity_name}</summary>
                    {(entity.schemas || []).map((schema) => (
                      <details key={`${entity.entity_name}/${schema.schema_name}`} className="meta-workspace-tree-node">
                        <summary className="meta-workspace-tree-summary schema">{schema.schema_name}</summary>
                        {(schema.tables || []).map((table) => (
                          <details key={`${entity.entity_name}/${schema.schema_name}/${table.table_name}`} className="meta-workspace-tree-node">
                            <summary
                              className={`meta-workspace-tree-summary table ${table.changed ? "changed" : ""}`}
                              onClick={(e) => {
                                e.preventDefault();
                                handleOpenBranchGpTable(entity.entity_name, schema.schema_name, table.table_name);
                              }}
                            >
                              {table.table_name}
                            </summary>
                            <div className="meta-workspace-tree-files">
                              {(table.files || []).map((file) => (
                                <div key={file.file_path} className={`meta-workspace-file-button passive ${file.changed ? "changed" : ""}`}>
                                  {file.file_name}
                                </div>
                              ))}
                            </div>
                          </details>
                        ))}
                      </details>
                    ))}
                  </details>
                ))
              ) : (
                <div className="muted">Файлы GP в ветке не найдены.</div>
              )}
            </div>

            <div className="meta-workspace-branch-column">
              <div className="section-subtitle">ClickHouse</div>
              {(branchTree.click_schemas || []).length ? (
                (branchTree.click_schemas || []).map((schema) => (
                  <details key={schema.schema_name} className="meta-workspace-tree-node">
                    <summary className="meta-workspace-tree-summary schema">{schema.schema_name}</summary>
                    <div className="meta-workspace-tree-files">
                      {(schema.files || []).map((file) => (
                        <div
                          key={file.file_path}
                          className={`meta-workspace-file-button passive ${file.changed ? "changed" : ""}`}
                        >
                          {file.file_name}
                        </div>
                      ))}
                    </div>
                  </details>
                ))
              ) : (
                <div className="muted">Файлы Click в ветке не найдены.</div>
              )}
            </div>
          </div>
        </div>

        <div className="dev-meta-tabs meta-workspace-tabs">
          {showGpTab ? (
          <button type="button" className={`dev-meta-tab ${mode === "gp" ? "active" : ""}`} onClick={() => setMode("gp")}>
            Greenplum
          </button>
          ) : null}
          {showClickTab ? (
          <button type="button" className={`dev-meta-tab ${mode === "click" ? "active" : ""}`} onClick={() => setMode("click")}>
            ClickHouse
          </button>
          ) : null}
        </div>

        <div className="meta-workspace-pane">
          {branchScopedActive ? (
            <div className="meta-workspace-selection-bar">
              <button type="button" className="btn btn-secondary" onClick={() => jumpToGenerator("gp")}>
                Новый GP объект
              </button>
              <button type="button" className="btn btn-secondary" onClick={() => jumpToGenerator("click")}>
                Новый Click файл
              </button>
              <div className="meta-workspace-selection-copy">
                <div className="meta-workspace-selection-label">Рабочая ветка</div>
                <div className="meta-workspace-selection-title">{branchCatalog.branch_name}</div>
              </div>
            </div>
          ) : null}
          {branchValidation?.summary ? (
            <div className="meta-workspace-validation">
              <div className="meta-workspace-validation-head">
                <div className="section-subtitle">Результат проверки ветки</div>
                <div className="meta-workspace-validation-actions">
                  <div className="muted">
                    Всего: {branchValidation.summary.total} · OK: {branchValidation.summary.valid} · Ошибки: {branchValidation.summary.invalid} · Warnings: {branchValidation.summary.warnings}
                  </div>
                  <button
                    type="button"
                    className="btn btn-primary"
                    onClick={handleSyncBranch}
                    disabled={syncingBranch || !taskIdValid || !String(branchName || "").trim() || !String(baseBranch || "").trim()}
                  >
                    {syncingBranch ? "Сохраняем в ветку..." : "Сохранить в ветку"}
                  </button>
                  <button type="button" className="btn btn-secondary" onClick={handleCreateMr} disabled={creatingMr || !taskIdValid || !String(releaseBranch || "").trim()}>
                    {creatingMr ? "Создаем MR..." : "Создать MR"}
                  </button>
                </div>
              </div>
              <div className="meta-workspace-validation-list">
                {[...(branchValidation.gp_results || []), ...(branchValidation.click_results || [])].map((item) => (
                  <div key={`${item.object_key}:${item.change_type}`} className={`meta-workspace-validation-card ${item.valid ? "ok" : "bad"}`}>
                    <div className="meta-workspace-validation-title">{item.object_key}</div>
                    <div className="meta-workspace-validation-meta">{item.valid ? "OK" : "Есть ошибки"} · {item.change_type}</div>
                    {item.errors?.length ? (
                      <ul className="meta-workspace-validation-points bad">
                        {item.errors.map((point, idx) => <li key={`${item.object_key}-err-${idx}`}>{point}</li>)}
                      </ul>
                    ) : null}
                    {item.warnings?.length ? (
                      <ul className="meta-workspace-validation-points warn">
                        {item.warnings.map((point, idx) => <li key={`${item.object_key}-warn-${idx}`}>{point}</li>)}
                      </ul>
                    ) : null}
                  </div>
                ))}
              </div>
            </div>
          ) : null}
          {activeSelection ? (
            <div className="meta-workspace-selection-bar">
              <button type="button" className="btn btn-ghost" onClick={handleBackToBranchList}>
                ← К списку веток
              </button>
              <div className="meta-workspace-selection-copy">
                <div className="meta-workspace-selection-label">
                  {activeSelection.domain === "gp" ? "Открыт GP объект" : "Открыт Click объект"}
                </div>
                <div className="meta-workspace-selection-title">{activeSelection.title}</div>
              </div>
            </div>
          ) : null}
          {mode === "gp" ? (
            <EntityDevMetaWorkspace
              userProfile={userProfile}
              embedded
              taskId={taskId}
              onTaskIdChange={setTaskId}
              releaseBranch={releaseBranch}
              onReleaseBranchChange={setReleaseBranch}
              externalOpenRequest={gpOpenRequest}
              externalBranchBundle={gpBranchBundle}
              allowedObjectKeys={allowedGpObjectKeys}
              branchScopedActive={branchScopedActive}
              generatorAnchorId="meta-workspace-gp-generator"
              hideCreateMr
              hideHeader
              hideTaskControls
            />
          ) : (
            <DevMetaAdminPage
              userProfile={userProfile}
              embedded
              taskId={taskId}
              hideHeader
              externalOpenRequest={clickOpenRequest}
              allowedFiles={allowedClickFiles}
              branchScopedActive={branchScopedActive}
              generatorAnchorId="meta-workspace-click-generator"
            />
          )}
        </div>
      </section>
    </div>
  );
}
