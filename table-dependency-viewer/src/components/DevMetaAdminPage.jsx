import React, { useEffect, useMemo, useState } from "react";
import { devMetaApi } from "../api/devMeta.js";
import { formatRuDateTime } from "../utils/datetime.js";

export default function DevMetaAdminPage({ userProfile }) {
  const [schemaName, setSchemaName] = useState("dm");
  const [generator, setGenerator] = useState({
    schema_name_gp: "dm",
    object_name: "",
    order_by: "",
    dag_tags: "",
  });
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

  const canUseDevMeta = ["admin", "engineer"].includes(userProfile?.role || "");
  const currentUser = userProfile?.email || userProfile?.username || "";

  const refreshStatus = async () => {
    const data = await devMetaApi.status();
    setStatus(data || null);
  };

  const refreshFiles = async (schema = schemaName) => {
    const data = await devMetaApi.files(schema);
    setFiles(data || { dev_files: [], locks: [] });
  };

  useEffect(() => {
    if (!canUseDevMeta) return;
    refreshStatus().catch((err) => setError(err.message || "Не удалось загрузить статус"));
    refreshFiles().catch((err) => setError(err.message || "Не удалось загрузить файлы"));
  }, [canUseDevMeta]);

  const formatDateTime = (value) => (value ? formatRuDateTime(value) : "—");
  const dagRunState = String(dagStatus?.dag_run_state || "").toLowerCase();
  const isValidationFresh = Boolean(
    validation?.valid &&
    selectedFile &&
    validatedContent !== null &&
    validatedContent === content
  );

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
    const term = fileSearch.trim().toLowerCase();
    const rows = [...(files.dev_files || [])].sort((left, right) => {
      const leftTs = new Date(left.updated_at || 0).getTime();
      const rightTs = new Date(right.updated_at || 0).getTime();
      return rightTs - leftTs;
    });
    if (!term) {
      return rows;
    }
    return rows.filter((file) => file.file_name.toLowerCase().includes(term));
  }, [files.dev_files, fileSearch]);

  const openFile = async (fileName) => {
    setLoading(true);
    setError(null);
    setMessage(null);
    setMessageType("info");
    setValidation(null);
    try {
      await acquireLock(fileName);
      const data = await devMetaApi.readFile({ schema_name: schemaName, file_name: fileName, source: "dev" });
      setSelectedFile(fileName);
      setContent(data?.content || "");
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
          ? "Проверка пройдена: файл корректен и готов к сохранению."
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
      const data = await devMetaApi.deploy({
        schema_name: schemaName,
        file_name: selectedFile,
        content,
      });
      setValidation(data?.validation || null);
      setValidatedContent(data?.validation?.valid ? content : null);
      await refreshFiles();
      setMessageType("success");
      setMessage(`Файл сохранен локально и отправлен на DEV сервер: ${data?.remote_path || "успешно"}`);
    } catch (err) {
      setError(err.message || "Не удалось сохранить и отправить файл на DEV сервер");
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
      const targetSchema = "dm";
      if (!dagTags.length) {
        setError("Нужно указать хотя бы один dag_tag");
        return;
      }
      const data = await devMetaApi.generate({
        schema_name_gp: generator.schema_name_gp,
        object_name: generator.object_name,
        schema_name_click: targetSchema,
        greenplum_table_name: null,
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

  if (!canUseDevMeta) {
    return (
      <div className="container cc-page">
        <div className="cc-surface">
          <div className="section-title">Доступ запрещён</div>
          <div className="muted">Раздел доступен только администраторам и инженерам.</div>
        </div>
      </div>
    );
  }

  return (
    <div className="container cc-page">
      <section className="cc-surface dev-meta-page">
        <div className="section-title">DEV Meta Generator</div>
        <div className="section-subtitle">
          Инструмент для генерации YAML-файла объекта для загрузки в ClickHouse и запуска DEV DAG.
        </div>

        <div className="dev-meta-toolbar">
          <div className="muted">
            Lock TTL: {status?.lock_ttl_minutes ?? 30} минут. Сейчас блокировок: {status?.locks_count ?? 0}
          </div>
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

        <div className="dev-meta-generator">
          <div className="section-subtitle">Новый YAML из параметров</div>
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
        </div>

        <div className="dev-meta-browser">
          <div className="dev-meta-file-block">
            <div className="dev-meta-file-head">
              <div>
                <div className="section-subtitle">DEV файлы</div>
                <div className="muted">Открытие файла сразу берет его в работу для текущего пользователя.</div>
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
              {filteredFiles.map((file) => (() => {
                const fileLock = (files.locks || []).find(
                  (item) => item.schema_name === schemaName && item.file_name === file.file_name
                );
                const blocked = fileLock?.locked_by && fileLock.locked_by !== currentUser;
                return (
                  <button
                    key={`dev-${file.file_name}`}
                    className={`dev-meta-file ${selectedFile === file.file_name ? "active" : ""} ${blocked ? "blocked" : ""}`}
                    onClick={() => openFile(file.file_name)}
                    disabled={blocked}
                  >
                    <span className="mono dev-meta-file-name" title={file.file_name}>{file.file_name}</span>
                    <span className="muted">{formatDateTime(file.updated_at)}</span>
                    {file.last_action_by ? (
                      <span className="dev-meta-file-meta">
                        {file.last_action_by} · {formatDateTime(file.last_action_at)}
                      </span>
                    ) : null}
                    {blocked ? <span className="dev-meta-file-badge">Занят</span> : null}
                  </button>
                );
              })())}
            </div>
          </div>
        </div>

        <div className="dev-meta-layout">
          <div className="dev-meta-editor-shell">
            <div className="dev-meta-editor-head">
              <div>
                <div className="section-subtitle">Редактор</div>
                <div className="muted">
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
                  disabled={!selectedFile || deploying || isLockedByAnother || !status?.deploy?.configured || !isValidationFresh}
                >
                  {deploying ? "Сохраняем и отправляем..." : "Сохранить и отправить на DEV"}
                </button>
                <button
                  className="btn btn-secondary"
                  onClick={handleRunDag}
                  disabled={!selectedFile || runningDag || isLockedByAnother || !status?.airflow?.configured}
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

          </div>
        </div>
      </section>
    </div>
  );
}
