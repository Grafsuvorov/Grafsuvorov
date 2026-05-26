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

  const taskIdValid = /^DWH-\d+$/.test(String(taskId || "").trim().toUpperCase());
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

  useEffect(() => {
    metaWorkspaceApi.branches()
      .then((data) => setBranchOptions(data?.items || []))
      .catch((err) => setError(err.message || "Не удалось загрузить список веток"));
  }, []);

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
    setError(null);
    setMessage(null);
    try {
      const data = await metaWorkspaceApi.branchCatalog({
        branch_name: branchValue,
        base_branch: baseBranch.trim(),
      });
      setBranchCatalog(data || { gp_objects: [], click_objects: [] });
      setMessage("Каталог изменений ветки обновлен.");
    } catch (err) {
      setError(err.message || "Не удалось построить каталог ветки");
    } finally {
      setCatalogLoading(false);
    }
  };

  const handleSelectBranch = async (nextBranch) => {
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
              <div className="section-subtitle">Каталог изменений ветки</div>
              <div className="muted">Подсветка объектов строится прямо из git diff выбранной ветки относительно base.</div>
            </div>
          </div>
          <div className="dev-meta-generator-grid meta-workspace-context-grid">
            <label className="admin-field">
              <span>Ветка</span>
              <input
                list="meta-workspace-branches"
                value={branchName}
                onChange={(e) => setBranchName(e.target.value)}
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
        </div>

        <div className="dev-meta-tabs meta-workspace-tabs">
          <button type="button" className={`dev-meta-tab ${mode === "gp" ? "active" : ""}`} onClick={() => setMode("gp")}>
            Greenplum
          </button>
          <button type="button" className={`dev-meta-tab ${mode === "click" ? "active" : ""}`} onClick={() => setMode("click")}>
            ClickHouse
          </button>
        </div>

        <div className="meta-workspace-pane">
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
            />
          )}
        </div>
      </section>
    </div>
  );
}
