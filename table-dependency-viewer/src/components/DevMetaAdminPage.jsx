import React, { useEffect, useMemo, useState } from "react";
import { devMetaApi } from "../api/devMeta.js";
import { metaWorkspaceApi } from "../api/metaWorkspace.js";
import { formatRuDateTime } from "../utils/datetime.js";
import DagLoadingMiniGame from "./DagLoadingMiniGame.jsx";

const DEV_META_CLICK_SCHEMAS = ["dm", "dm_view", "dm_calc", "dds", "ods", "stg", "dict_dds", "dict_stg"];

const DEV_META_RUNBOOK = [
  {
    title: "Когда нужен новый файл",
    items: [
      "Создавайте новый YAML, если у объекта изменилась структура в DEV или объекта еще нет в списке.",
      "Укажите GP схему, имя объекта, целевую ClickHouse-схему и поля для ORDER BY. Поля сортировки должны быть заполнены и не содержать NULL.",
      "В DAG tags укажите направление к которому относится объект.",
    ],
  },
  {
    title: "Порядок действий",
    items: [
      "Нажмите «Сгенерировать черновик». Новый файл откроется в редакторе.",
      "Нажмите «Проверить» и дождитесь успешной валидации.",
      "Нажмите «Сохранить и отправить на DEV». После этого Airflow нужно время, чтобы подхватить изменения.",
      "Нажмите «Запустить DEV DAG». Если DAG еще не готов, подождите и повторите запуск.",
      "Следите за статусом запуска, пока он не станет Success.",
    ],
  },
  {
    title: "Что должно получиться",
    items: [
      "На источнике появится объект в схеме dm.",
      "В схеме dm_view создастся одноименная view.",
      "Если возникли другие ошибки, напишите в поддержку.",
    ],
  },
];

export default function DevMetaAdminPage({
  userProfile,
  embedded = false,
  taskId: externalTaskId,
  hideHeader = false,
  externalOpenRequest = null,
  externalBranchFile = null,
  branchSaveContext = null,
  onBranchSaved = null,
  allowedFiles = null,
  allowedBranchFiles = null,
  branchScopedActive = false,
  generatorAnchorId = "",
}) {
  const [schemaName, setSchemaName] = useState("dm");
  const [generator, setGenerator] = useState({
    schema_name_gp: "dm",
    schema_name_click: "dm",
    object_name: "",
    greenplum_table_name: "",
    order_by: "",
    dag_tags: "",
  });
  const [newViewName, setNewViewName] = useState("");
  const [status, setStatus] = useState(null);
  const [files, setFiles] = useState({ dev_files: [], locks: [] });
  const [selectedFile, setSelectedFile] = useState(null);
  const [content, setContent] = useState("");
  const [loading, setLoading] = useState(false);
  const [deploying, setDeploying] = useState(false);
  const [validating, setValidating] = useState(false);
  const [lockInfo, setLockInfo] = useState(null);
  const [validation, setValidation] = useState(null);
  const [validatedContent, setValidatedContent] = useState(null);
  const [message, setMessage] = useState(null);
  const [messageType, setMessageType] = useState("info");
  const [error, setError] = useState(null);
  const [fileSearch, setFileSearch] = useState("");
  const [runningDag, setRunningDag] = useState(false);
  const [dagStatus, setDagStatus] = useState(null);
  const [generating, setGenerating] = useState(false);
  const [selectedRevision, setSelectedRevision] = useState(null);

  const canUseDevMeta = Boolean(userProfile);
  const currentUser = userProfile?.email || userProfile?.username || "";
  const taskId = String(externalTaskId || "").trim().toUpperCase();

  const refreshStatus = async () => {
    const data = await devMetaApi.status();
    setStatus(data || null);
  };

  const refreshFiles = async (schema = schemaName) => {
    const data = await devMetaApi.files(schema);
    setFiles(data || { dev_files: [], locks: [] });
    if (data?.remote_error) {
      setMessageType("warning");
      setError(null);
      setMessage(`Не удалось прочитать DEV-файлы с удаленного сервера: ${data.remote_error}`);
    }
  };

  useEffect(() => {
    if (!canUseDevMeta) return;
    refreshStatus().catch((err) => setError(err.message || "Не удалось загрузить статус"));
    refreshFiles().catch((err) => setError(err.message || "Не удалось загрузить файлы"));
  }, [canUseDevMeta]);

  useEffect(() => {
    if (!canUseDevMeta) return;
    setSelectedFile(null);
    setContent("");
    setValidation(null);
    setValidatedContent(null);
    setLockInfo(null);
    refreshFiles(schemaName).catch((err) => setError(err.message || "Не удалось загрузить файлы"));
  }, [schemaName]);

  const formatDateTime = (value) => (value ? formatRuDateTime(value) : "—");
  const dagIsActive = ["queued", "running"].includes(String(dagStatus?.dag_run_state || "").toLowerCase());
  const dagRunState = String(dagStatus?.dag_run_state || "").toLowerCase();
  const isValidationFresh = Boolean(
    validation?.valid &&
    selectedFile &&
    validatedContent !== null &&
    validatedContent === content
  );
  const branchMode = Boolean(
    branchSaveContext?.branch_name &&
    branchSaveContext?.base_branch
  );
  const scopedFileMode = embedded && (branchMode || allowedFiles instanceof Set);

  const lockRow = useMemo(() => {
    if (!selectedFile) return null;
    return (files.locks || []).find(
      (item) => item.schema_name === schemaName && item.file_name === selectedFile
    );
  }, [files.locks, schemaName, selectedFile]);

  const isLockedByAnother = Boolean(
    (lockInfo?.locked_by || lockRow?.locked_by) &&
      (lockInfo?.locked_by || lockRow?.locked_by) !== currentUser
  );

  const acquireLock = async (fileName) => {
    const data = await devMetaApi.lock({ schema_name: schemaName, file_name: fileName });
    setLockInfo(data || null);
    return data;
  };

  const filteredFiles = useMemo(() => {
    if (branchMode && Array.isArray(allowedBranchFiles)) {
      const term = fileSearch.trim().toLowerCase();
      const rows = [...allowedBranchFiles]
        .filter((file) => file.schema_name === schemaName)
        .sort((left, right) => String(left.file_name || "").localeCompare(String(right.file_name || "")));
      if (!term) {
        return rows;
      }
      return rows.filter((file) => String(file.file_name || "").toLowerCase().includes(term));
    }
    const term = fileSearch.trim().toLowerCase();
    const allowedEntries = allowedFiles instanceof Set ? allowedFiles : null;
    const rows = [...(files.dev_files || [])]
      .filter((file) => !allowedEntries || allowedEntries.has(`${schemaName}/${file.file_name}`))
      .sort((left, right) => {
      const leftTs = new Date(left.updated_at || 0).getTime();
      const rightTs = new Date(right.updated_at || 0).getTime();
      return rightTs - leftTs;
    });
    if (!term) {
      return rows;
    }
    return rows.filter((file) => file.file_name.toLowerCase().includes(term));
  }, [files.dev_files, fileSearch, allowedFiles, schemaName]);

  const openFile = async (fileName) => {
    setLoading(true);
    setError(null);
    setMessage(null);
    setMessageType("info");
    setValidation(null);
    try {
      if (branchMode) {
        const data = await metaWorkspaceApi.branchFile({
          branch_name: branchSaveContext.branch_name,
          file_path: `${schemaName}/${fileName}`,
        });
        setSelectedFile(fileName);
        setContent(data?.content || "");
        setSelectedRevision(data?.revision || null);
        setValidation(null);
        setValidatedContent(null);
        setLockInfo(null);
        setMessage(`Файл открыт из ветки ${data?.branch_name || branchSaveContext.branch_name}.`);
        return;
      }
      await acquireLock(fileName);
      const data = await devMetaApi.readFile({ schema_name: schemaName, file_name: fileName, source: "dev" });
      setSelectedFile(fileName);
      setContent(data?.content || "");
      setSelectedRevision(null);
      setValidation(null);
      setValidatedContent(null);
      setMessage("Файл открыт и взят в работу.");
      await refreshFiles();
    } catch (err) {
      setError(err.message || "Не удалось открыть файл");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!externalOpenRequest?.token) return;
    const nextSchema = externalOpenRequest.schema_name || "dm";
    const nextFile = externalOpenRequest.file_name;
    if (!nextFile) return;
    const openExternalFile = async () => {
      setSchemaName(nextSchema);
      setLoading(true);
      setError(null);
      setMessage(null);
      setMessageType("info");
      setValidation(null);
      try {
        const lock = await devMetaApi.lock({ schema_name: nextSchema, file_name: nextFile });
        setLockInfo(lock || null);
        const data = await devMetaApi.readFile({ schema_name: nextSchema, file_name: nextFile, source: "dev" });
        setSelectedFile(nextFile);
        setContent(data?.content || "");
        setSelectedRevision(null);
        setValidation(null);
        setValidatedContent(null);
        setMessage("Файл открыт и взят в работу.");
        await refreshFiles(nextSchema);
      } catch (err) {
        setError(err.message || "Не удалось открыть файл");
      } finally {
        setLoading(false);
      }
    };
    openExternalFile();
  }, [externalOpenRequest?.token]);

  useEffect(() => {
    if (!externalBranchFile?.token || !externalBranchFile?.file) return;
    const data = externalBranchFile.file;
    setSchemaName(data.schema_name);
    setSelectedFile(data.file_name);
    setContent(data.content || "");
    setSelectedRevision(data.revision || null);
    setValidation(null);
    setValidatedContent(null);
    setLockInfo(null);
    setMessageType("success");
    setError(null);
    setMessage(`Файл открыт из ветки ${externalBranchFile.branch_name || ""}.`);
  }, [externalBranchFile?.token]);

  const handleValidate = async () => {
    if (!selectedFile) return;
    setValidating(true);
    setError(null);
    try {
      const data = await devMetaApi.validate({
        schema_name: schemaName,
        file_name: selectedFile,
        content,
      });
      setValidation(data);
      setValidatedContent(data?.valid ? content : null);
      setMessageType(data?.valid ? "success" : "warning");
      setMessage(
        data?.valid
          ? branchMode
            ? "Проверка пройдена: файл корректен и готов к сохранению в ветку."
            : "Проверка пройдена: файл корректен и готов к сохранению."
          : "Проверка завершилась с ошибками. Исправь их перед сохранением."
      );
    } catch (err) {
      setError(err.message || "Не удалось провалидировать файл");
    } finally {
      setValidating(false);
    }
  };

  const handleSaveAndDeploy = async () => {
    if (!selectedFile) return;
    if (!branchMode && externalTaskId !== undefined && !taskId) {
      setMessageType("warning");
      setError(null);
      setMessage("Перед отправкой в DEV укажите номер задачи в формате DWH-12345.");
      return;
    }
    if (!isValidationFresh) {
      setMessageType("warning");
      setError(null);
      setMessage("Перед отправкой в DEV нужно успешно проверить текущую версию файла.");
      return;
    }
    setDeploying(true);
    setError(null);
    setMessage(null);
    setMessageType("info");
    try {
      if (branchMode) {
        const data = await metaWorkspaceApi.saveBranchFile({
          branch_name: branchSaveContext.branch_name,
          base_branch: branchSaveContext.base_branch,
          file_path: `${schemaName}/${selectedFile}`,
          content,
          task_id: taskId,
          expected_revision: selectedRevision || null,
        });
        setSelectedRevision(data?.revision || null);
        setValidatedContent(content);
        setMessageType("success");
        setMessage(
          data?.committed
            ? `Файл сохранен в ветку ${data?.branch_name || branchSaveContext.branch_name}.`
            : `Новых изменений для коммита в ветку ${data?.branch_name || branchSaveContext.branch_name} не было.`
        );
        if (typeof onBranchSaved === "function") {
          await onBranchSaved(data);
        }
      } else {
        const data = await devMetaApi.deploy({
          schema_name: schemaName,
          file_name: selectedFile,
          content,
          task_id: taskId,
        });
        setValidation(data?.validation || null);
        setValidatedContent(data?.validation?.valid ? content : null);
        await refreshFiles();
        setMessageType("success");
        setMessage(`Файл сохранен локально и отправлен на DEV сервер: ${data?.remote_path || "успешно"}`);
      }
    } catch (err) {
      setError(err.message || (branchMode ? "Не удалось сохранить файл в ветку" : "Не удалось сохранить и отправить файл на DEV сервер"));
    } finally {
      setDeploying(false);
    }
  };

  const handleRunDag = async () => {
    if (!selectedFile) return;
    setRunningDag(true);
    setError(null);
    setMessage(null);
    setMessageType("info");
    try {
      const data = await devMetaApi.runDag({
        schema_name: schemaName,
        file_name: selectedFile,
      });
      const dagRun = data?.response?.response || data?.response || {};
      setDagStatus({
        dag_id: data?.response?.dag_id || dagRun?.dag_id || selectedFile.replace(/\.[^.]+$/, ""),
        dag_run_id: dagRun?.dag_run_id,
        dag_run_state: dagRun?.state || "queued",
        failed_tasks: [],
        auto_unpaused: Boolean(data?.response?.auto_unpaused),
        dag_is_paused: Boolean(data?.response?.was_paused),
      });
      setMessageType("success");
      setMessage(`DEV DAG запущен: ${data?.response?.dag_id || dagRun?.dag_id || selectedFile.replace(/\.[^.]+$/, "")}`);
    } catch (err) {
      setError(err.message || "Не удалось запустить DEV DAG");
    } finally {
      setRunningDag(false);
    }
  };

  useEffect(() => {
    if (!dagStatus?.dag_id || !dagStatus?.dag_run_id) {
      return undefined;
    }
    const isTerminal = ["success", "failed"].includes(String(dagStatus.dag_run_state || "").toLowerCase());
    if (isTerminal) {
      return undefined;
    }
    let cancelled = false;
    const poll = async () => {
      try {
        const data = await devMetaApi.dagStatus({
          schema_name: schemaName,
          file_name: selectedFile,
          dag_id: dagStatus.dag_id,
          dag_run_id: dagStatus.dag_run_id,
          auto_unpaused: Boolean(dagStatus.auto_unpaused),
        });
        if (!cancelled) {
          setDagStatus(data?.response || null);
        }
      } catch (err) {
        if (!cancelled) {
          setError(err.message || "Не удалось получить статус DAG");
        }
      }
    };
    poll();
    const timer = window.setInterval(poll, 7000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, [dagStatus?.dag_id, dagStatus?.dag_run_id, dagStatus?.dag_run_state]);

  const handleGenerate = async () => {
    setGenerating(true);
    setError(null);
    setMessage(null);
    setMessageType("info");
    try {
      const orderBy = generator.order_by
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean);
      const dagTags = generator.dag_tags
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean);
      const targetSchema = String(generator.schema_name_click || "dm").trim().toLowerCase() || "dm";
      if (!dagTags.length) {
        setError("Нужно указать хотя бы один dag_tag");
        return;
      }
      const data = await devMetaApi.generate({
        schema_name_gp: generator.schema_name_gp,
        object_name: generator.object_name,
        schema_name_click: targetSchema,
        greenplum_table_name: generator.greenplum_table_name.trim() || null,
        order_by: orderBy,
        dag_tags: dagTags,
      });
      if (data?.file_name) {
        await devMetaApi.lock({ schema_name: targetSchema, file_name: data.file_name });
      }
      setSchemaName(targetSchema);
      setSelectedFile(data?.file_name || null);
      setContent(data?.content || "");
      setValidation(null);
      setValidatedContent(null);
      setLockInfo(
        data?.file_name
          ? {
              schema_name: targetSchema,
              file_name: data.file_name,
              locked_by: currentUser,
            }
          : null
      );
      await refreshFiles(targetSchema);
      setMessage(`Черновик YAML создан и открыт: ${data?.file_name || ""}`);
    } catch (err) {
      setError(err.message || "Не удалось сгенерировать YAML");
    } finally {
      setGenerating(false);
    }
  };

  const handleCreateViewDraft = async () => {
    const name = String(newViewName || "").trim();
    if (!name) {
      setError("Укажите имя view");
      return;
    }
    const fileName = `${name}.sql`;
    const draft = `create or replace view dm_view.${name} as\nselect\n  1 as stub_column;\n`;
    try {
      await devMetaApi.lock({ schema_name: "dm_view", file_name: fileName });
      setSchemaName("dm_view");
      setSelectedFile(fileName);
      setContent(draft);
      setValidation(null);
      setValidatedContent(null);
      setLockInfo({
        schema_name: "dm_view",
        file_name: fileName,
        locked_by: currentUser,
      });
      setMessageType("success");
      setError(null);
      setMessage(`Черновик view создан: ${fileName}`);
    } catch (err) {
      setError(err.message || "Не удалось создать черновик view");
    }
  };

  const handleDownloadFile = () => {
    if (!selectedFile || !content) return;
    const blob = new Blob([content], { type: "text/yaml;charset=utf-8" });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = selectedFile;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
  };

  if (!canUseDevMeta) {
    return (
      <div className="container cc-page">
        <div className="cc-surface">
          <div className="section-title">Доступ запрещён</div>
          <div className="muted">Для работы с разделом нужно войти в систему.</div>
        </div>
      </div>
    );
  }

  const contentNode = (
      <section className={embedded ? "dev-meta-page" : "cc-surface dev-meta-page"}>
        {!hideHeader ? (
          <>
            <div className="section-title">DEV Meta Generator</div>
            <div className="section-subtitle">
              Инструмент для генерации YAML-файла объекта для загрузки в ClickHouse и запуска DEV DAG.
            </div>
          </>
        ) : null}

        {!embedded ? (
          <div className="dev-meta-toolbar">
            <div className="muted">
              Lock TTL: {status?.lock_ttl_minutes ?? 30} минут. Сейчас блокировок: {status?.locks_count ?? 0}
            </div>
          </div>
        ) : null}

        {!embedded ? (
        <div className="dev-meta-runbook">
          <div className="dev-meta-runbook-head">
            <div>
              <div className="section-subtitle">Как работать с генератором</div>
              <div className="muted">Короткая инструкция для создания и отправки нового файла в DEV.</div>
            </div>
          </div>
          <div className="dev-meta-runbook-grid">
            {DEV_META_RUNBOOK.map((section) => (
              <div key={section.title} className="dev-meta-runbook-card">
                <div className="dev-meta-runbook-title">{section.title}</div>
                <ol className="dev-meta-runbook-list">
                  {section.items.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ol>
              </div>
            ))}
          </div>
        </div>
        ) : null}

        <div className="dev-meta-tabs">
          <button type="button" className={`dev-meta-tab ${schemaName === "dm" ? "active" : ""}`} onClick={() => setSchemaName("dm")}>
            Click table
          </button>
          <button type="button" className={`dev-meta-tab ${schemaName === "dm_view" ? "active" : ""}`} onClick={() => setSchemaName("dm_view")}>
            Click view
          </button>
        </div>

        {(message || error) && (
          <div className={`dev-meta-feedback ${error ? "error" : messageType}`}>
            <div className="dev-meta-feedback-title">
              {error
                ? "Операция не выполнена"
                : messageType === "success"
                  ? "Успешно"
                  : messageType === "warning"
                    ? "Нужно исправить"
                    : "Статус"}
            </div>
            <div className="dev-meta-feedback-text">{error || message}</div>
          </div>
        )}

        <div className="dev-meta-generator" id={generatorAnchorId || undefined}>
          <div className="section-subtitle">{schemaName === "dm" ? "Новый YAML из параметров" : "Новый view SQL"}</div>
          {schemaName === "dm_view" ? (
            <>
              <div className="dev-meta-generator-grid">
                <label className="admin-field">
                  <span>Имя view</span>
                  <input
                    value={newViewName}
                    onChange={(e) => setNewViewName(e.target.value)}
                    placeholder="account_debt_for_working_capital_final"
                  />
                </label>
              </div>
              <div className="dev-meta-generator-actions">
                <button className="btn btn-primary" onClick={handleCreateViewDraft}>
                  Создать черновик view
                </button>
              </div>
            </>
          ) : (
          <>
          <div className="dev-meta-generator-grid">
            <label className="admin-field">
              <span>GP схема</span>
              <input
                value={generator.schema_name_gp}
                onChange={(e) => setGenerator((prev) => ({ ...prev, schema_name_gp: e.target.value }))}
                placeholder="dm"
              />
            </label>
            <label className="admin-field">
              <span>Объект</span>
              <input
                value={generator.object_name}
                onChange={(e) => setGenerator((prev) => ({ ...prev, object_name: e.target.value }))}
                placeholder="counterparty_profile"
              />
            </label>
            <label className="admin-field">
              <span>ClickHouse схема</span>
              <select
                value={generator.schema_name_click}
                onChange={(e) => setGenerator((prev) => ({ ...prev, schema_name_click: e.target.value }))}
              >
                {DEV_META_CLICK_SCHEMAS.map((item) => (
                  <option key={item} value={item}>{item}</option>
                ))}
              </select>
            </label>
            <label className="admin-field dev-meta-generator-wide">
              <span>Имя таблицы в GP, если отличается</span>
              <input
                value={generator.greenplum_table_name}
                onChange={(e) => setGenerator((prev) => ({ ...prev, greenplum_table_name: e.target.value }))}
                placeholder="source_counterparty_profile"
              />
            </label>
            <label className="admin-field dev-meta-generator-wide">
              <span>ORDER BY</span>
              <input
                value={generator.order_by}
                onChange={(e) => setGenerator((prev) => ({ ...prev, order_by: e.target.value }))}
                placeholder="counterparty_code, dttm_updated"
              />
            </label>
            <label className="admin-field dev-meta-generator-wide">
              <span>DAG tags</span>
              <input
                value={generator.dag_tags}
                onChange={(e) => setGenerator((prev) => ({ ...prev, dag_tags: e.target.value }))}
                placeholder="DICT_LOADER, DAILY_LOAD"
              />
            </label>
          </div>
          <div className="dev-meta-generator-actions">
            <button className="btn btn-primary" onClick={handleGenerate} disabled={generating}>
              {generating ? "Генерируем черновик..." : "Сгенерировать черновик"}
            </button>
            {generating ? <span className="muted">Читаем структуру объекта и собираем YAML…</span> : null}
          </div>
          </>
          )}
        </div>

        <div className="dev-meta-browser">
          <div className="dev-meta-file-block">
            <div className="dev-meta-file-head">
              <div>
                <div className="section-subtitle">{branchMode ? "Файлы ветки" : "DEV файлы"}</div>
                <div className="muted">
                  {branchMode
                    ? "Показаны файлы выбранной ветки."
                    : allowedFiles instanceof Set
                    ? "Показаны только файлы из выбранной ветки."
                    : "Открытие файла сразу берет его в работу для текущего пользователя."}
                </div>
              </div>
              <div className="dev-meta-file-tools">
                <input
                  className="dev-meta-file-search"
                  value={fileSearch}
                  onChange={(e) => setFileSearch(e.target.value)}
                  placeholder="Поиск по имени файла"
                />
                <div className="muted">Сортировка: сначала последние изменения</div>
              </div>
            </div>
            <div className="dev-meta-file-list">
              {scopedFileMode && !branchScopedActive ? (
                <div className="muted dev-meta-scoped-empty">Сначала выбери ветку выше. После этого здесь появятся только файлы этой ветки.</div>
              ) : filteredFiles.length ? filteredFiles.map((file) => (() => {
                const fileLock = (files.locks || []).find(
                  (item) => item.schema_name === schemaName && item.file_name === file.file_name
                );
                const blocked = fileLock?.locked_by && fileLock.locked_by !== currentUser;
                return (
                  <button
                    key={`dev-${file.file_name}`}
                    className={`dev-meta-file ${selectedFile === file.file_name ? "active" : ""} ${blocked ? "blocked" : ""}`}
                    onClick={() => openFile(file.file_name)}
                    disabled={branchMode ? false : blocked}
                  >
                    <span className="mono dev-meta-file-name" title={file.file_name}>{file.file_name}</span>
                    {"updated_at" in file ? <span className="muted">{formatDateTime(file.updated_at)}</span> : null}
                    {file.last_action_by ? (
                      <span className="dev-meta-file-meta">
                        {file.last_action_by} · {formatDateTime(file.last_action_at)}
                      </span>
                    ) : null}
                    {blocked && !branchMode ? <span className="dev-meta-file-badge">Занят</span> : null}
                  </button>
                );
              })()) : <div className="muted">Для выбранной ветки файлов пока нет.</div>}
            </div>
          </div>
        </div>

        <div className="dev-meta-layout">
          <div className="dev-meta-editor-shell">
            <div className="dev-meta-editor-head">
              <div className="dev-meta-editor-title">
                <div className="section-subtitle">Редактор</div>
                <div className="muted dev-meta-editor-path">
                  {selectedFile ? `${schemaName}/${selectedFile}` : "Сгенерируйте новый YAML или выберите DEV-файл"}
                </div>
              </div>
              <div className="dev-meta-actions">
                <button className="btn btn-secondary" onClick={handleValidate} disabled={!selectedFile || validating}>
                  {validating ? "Проверяем..." : "Проверить"}
                </button>
                <button
                  className="btn btn-primary"
                  onClick={handleSaveAndDeploy}
                  disabled={
                    branchMode
                      ? (!selectedFile || deploying || !isValidationFresh)
                      : (!selectedFile || deploying || isLockedByAnother || !status?.deploy?.configured || !isValidationFresh)
                  }
                >
                  {deploying ? "Сохраняем..." : branchMode ? "Сохранить в ветку" : "Сохранить и отправить на DEV"}
                </button>
                <button
                  className="btn btn-secondary"
                  onClick={handleRunDag}
                  disabled={!selectedFile || runningDag || isLockedByAnother || !status?.airflow?.configured || branchMode}
                >
                  {runningDag ? "Запускаем DAG..." : "Запустить DEV DAG"}
                </button>
              </div>
            </div>

            <div className="dev-meta-lock-bar">
              <span>Lock:</span>
              <strong>{lockInfo?.locked_by || lockRow?.locked_by || "нет"}</strong>
              <span className="muted">
                {lockInfo?.expires_at || lockRow?.expires_at ? `до ${formatDateTime(lockInfo?.expires_at || lockRow?.expires_at)}` : ""}
              </span>
            </div>

            {dagStatus && (
              <div className="dev-meta-dag-status">
                <div className="section-subtitle">Статус DEV DAG</div>
                <div className="dev-meta-dag-grid">
                  <div className="dev-meta-dag-card">
                    <span className="label">Run</span>
                    <strong className="mono">{dagStatus.dag_run_id || "—"}</strong>
                  </div>
                  <div className={`dev-meta-dag-card dev-meta-dag-state dev-meta-dag-state-${dagRunState || "idle"}`}>
                    <span className="label">Статус запуска</span>
                    <strong>{dagStatus.dag_run_state || "—"}</strong>
                  </div>
                </div>
                {dagStatus.failed_tasks?.length ? (
                  <div className="dev-meta-dag-failed">
                    Ошибки: {dagStatus.failed_tasks.map((task) => `${task.task_id} (${task.state})`).join(", ")}
                  </div>
                ) : null}
                <DagLoadingMiniGame active={dagIsActive} />
              </div>
            )}

            {validation && (
              <div className="dev-meta-validation">
                <div className="section-subtitle">Результат проверки</div>
                <div className={`dev-meta-validation-pill ${validation.valid ? "ok" : "bad"}`}>
                  {validation.valid ? "Файл валиден" : "Есть ошибки"}
                </div>
                {validation.valid && !isValidationFresh ? (
                  <div className="dev-meta-validation-meta">
                    Файл менялся после последней успешной проверки. Проверь его заново перед отправкой в DEV.
                  </div>
                ) : null}
                {validation.errors?.length ? (
                  <ul className="dev-meta-validation-list">
                    {validation.errors.map((item, idx) => (
                      <li key={`err-${idx}`}>{item}</li>
                    ))}
                  </ul>
                ) : null}
                {validation.warnings?.length ? (
                  <ul className="dev-meta-validation-list warning">
                    {validation.warnings.map((item, idx) => (
                      <li key={`warn-${idx}`}>{item}</li>
                    ))}
                  </ul>
                ) : null}
              </div>
            )}

            <textarea
              className="dev-meta-editor"
              value={content}
              onChange={(e) => setContent(e.target.value)}
              disabled={isLockedByAnother}
              placeholder="Сгенерируйте новый YAML или откройте DEV-файл, чтобы начать работу"
            />

            <div className="dev-meta-editor-tools">
              <button className="btn btn-secondary" onClick={handleDownloadFile} disabled={!selectedFile || !content}>
                Скачать файл
              </button>
            </div>

          </div>
        </div>
      </section>
  );
  return embedded ? contentNode : <div className="container cc-page">{contentNode}</div>;
}
