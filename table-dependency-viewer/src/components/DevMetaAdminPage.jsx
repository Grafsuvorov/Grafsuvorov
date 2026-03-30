import React, { useEffect, useMemo, useState } from "react";
import { devMetaApi } from "../api/devMeta.js";
import { formatRuDateTime } from "../utils/datetime.js";

const SCHEMA_OPTIONS = [
  { value: "dm", label: "dm" },
  { value: "dm_view", label: "dm_view" },
];

export default function DevMetaAdminPage({ userProfile }) {
  const [schemaName, setSchemaName] = useState("dm");
  const [status, setStatus] = useState(null);
  const [files, setFiles] = useState({ prod_files: [], dev_files: [], locks: [] });
  const [selectedFile, setSelectedFile] = useState(null);
  const [selectedSource, setSelectedSource] = useState("prod");
  const [content, setContent] = useState("");
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [validating, setValidating] = useState(false);
  const [runningDag, setRunningDag] = useState(false);
  const [lockInfo, setLockInfo] = useState(null);
  const [validation, setValidation] = useState(null);
  const [message, setMessage] = useState(null);
  const [error, setError] = useState(null);

  const isAdmin = userProfile?.role === "admin";
  const currentUser = userProfile?.email || userProfile?.username || "";

  const refreshStatus = async () => {
    const data = await devMetaApi.status();
    setStatus(data || null);
  };

  const refreshFiles = async (schema = schemaName) => {
    const data = await devMetaApi.files(schema);
    setFiles(data || { prod_files: [], dev_files: [], locks: [] });
  };

  useEffect(() => {
    if (!isAdmin) return;
    refreshStatus().catch((err) => setError(err.message || "Не удалось загрузить статус"));
    refreshFiles().catch((err) => setError(err.message || "Не удалось загрузить файлы"));
  }, [isAdmin]);

  useEffect(() => {
    if (!isAdmin) return;
    setSelectedFile(null);
    setSelectedSource("prod");
    setContent("");
    setValidation(null);
    setLockInfo(null);
    refreshFiles(schemaName).catch((err) => setError(err.message || "Не удалось загрузить файлы"));
  }, [schemaName, isAdmin]);

  const formatDateTime = (value) => (value ? formatRuDateTime(value) : "—");

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

  const openFile = async (fileName, source) => {
    setLoading(true);
    setError(null);
    setMessage(null);
    setValidation(null);
    try {
      const data = await devMetaApi.readFile({
        schema_name: schemaName,
        file_name: fileName,
        source,
      });
      setSelectedFile(fileName);
      setSelectedSource(source);
      setContent(data?.content || "");
      const currentLock = (files.locks || []).find(
        (item) => item.schema_name === schemaName && item.file_name === fileName
      );
      setLockInfo(currentLock || null);
    } catch (err) {
      setError(err.message || "Не удалось открыть файл");
    } finally {
      setLoading(false);
    }
  };

  const handleLock = async () => {
    if (!selectedFile) return;
    setError(null);
    try {
      const data = await devMetaApi.lock({ schema_name: schemaName, file_name: selectedFile });
      setLockInfo(data);
      await refreshFiles();
      setMessage("Файл взят в работу");
    } catch (err) {
      setError(err.message || "Не удалось взять файл в работу");
    }
  };

  const handleUnlock = async () => {
    if (!selectedFile) return;
    setError(null);
    try {
      await devMetaApi.unlock({ schema_name: schemaName, file_name: selectedFile });
      setLockInfo(null);
      await refreshFiles();
      setMessage("Блокировка снята");
    } catch (err) {
      setError(err.message || "Не удалось снять блокировку");
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
      setMessage(data?.valid ? "Валидация пройдена" : "Найдены ошибки валидации");
    } catch (err) {
      setError(err.message || "Не удалось провалидировать файл");
    } finally {
      setValidating(false);
    }
  };

  const handleSave = async () => {
    if (!selectedFile) return;
    setSaving(true);
    setError(null);
    setMessage(null);
    try {
      const data = await devMetaApi.save({
        schema_name: schemaName,
        file_name: selectedFile,
        content,
      });
      setValidation(data?.validation || null);
      setSelectedSource("dev");
      await refreshFiles();
      setMessage("Файл сохранен в DEV-контур");
    } catch (err) {
      setError(err.message || "Не удалось сохранить файл");
    } finally {
      setSaving(false);
    }
  };

  const handleRunDag = async () => {
    if (!selectedFile) return;
    setRunningDag(true);
    setError(null);
    try {
      await devMetaApi.runDag({
        schema_name: schemaName,
        file_name: selectedFile,
      });
      setMessage("DEV DAG запущен");
    } catch (err) {
      setError(err.message || "Не удалось запустить DAG");
    } finally {
      setRunningDag(false);
    }
  };

  if (!isAdmin) {
    return (
      <div className="container cc-page">
        <div className="cc-surface">
          <div className="section-title">Доступ запрещён</div>
          <div className="muted">Раздел доступен только администраторам.</div>
        </div>
      </div>
    );
  }

  return (
    <div className="container cc-page">
      <section className="cc-surface dev-meta-page">
        <div className="section-title">DEV Meta Generator</div>
        <div className="section-subtitle">
          Отдельный admin-only контур для генерации, ручной правки, валидации и запуска DEV DAG без пересечения с PROD meta.
        </div>

        <div className="dev-meta-kpis">
          <div className="dev-meta-kpi">
            <div className="label">PROD путь</div>
            <div className="value mono">{status?.prod_root || "—"}</div>
          </div>
          <div className="dev-meta-kpi">
            <div className="label">DEV путь</div>
            <div className="value mono">{status?.dev_root || "—"}</div>
          </div>
          <div className="dev-meta-kpi">
            <div className="label">DEV Airflow</div>
            <div className="value">{status?.airflow?.configured ? "Настроен" : "Не настроен"}</div>
          </div>
          <div className="dev-meta-kpi">
            <div className="label">DEV GP check</div>
            <div className="value">{status?.dev_database_configured ? "Настроен" : "Опционально"}</div>
          </div>
        </div>

        <div className="dev-meta-toolbar">
          <div className="dev-meta-tabs">
            {SCHEMA_OPTIONS.map((option) => (
              <button
                key={option.value}
                className={`btn ${schemaName === option.value ? "btn-primary" : "btn-secondary"}`}
                onClick={() => setSchemaName(option.value)}
              >
                {option.label}
              </button>
            ))}
          </div>
          <div className="muted">
            Lock TTL: {status?.lock_ttl_minutes ?? 30} минут. Сейчас блокировок: {status?.locks_count ?? 0}
          </div>
        </div>

        {message && <div className="muted">{message}</div>}
        {error && <div className="login-error">{error}</div>}

        <div className="dev-meta-layout">
          <div className="dev-meta-side">
            <div className="dev-meta-file-block">
              <div className="section-subtitle">PROD файлы</div>
              <div className="dev-meta-file-list">
                {(files.prod_files || []).map((file) => (() => {
                  const fileLock = (files.locks || []).find(
                    (item) => item.schema_name === schemaName && item.file_name === file.file_name
                  );
                  const blocked = fileLock?.locked_by && fileLock.locked_by !== currentUser;
                  return (
                    <button
                      key={`prod-${file.file_name}`}
                      className={`dev-meta-file ${selectedFile === file.file_name && selectedSource === "prod" ? "active" : ""} ${blocked ? "blocked" : ""}`}
                      onClick={() => openFile(file.file_name, "prod")}
                      disabled={blocked}
                    >
                      <span className="mono">{file.file_name}</span>
                      <span className="muted">{formatDateTime(file.updated_at)}</span>
                      {file.last_action_by ? (
                        <span className="dev-meta-file-meta">
                          DEV: {file.last_action_by} · {formatDateTime(file.last_action_at)}
                        </span>
                      ) : null}
                      {blocked ? <span className="dev-meta-file-badge">Занят</span> : null}
                    </button>
                  );
                })())}
              </div>
            </div>

            <div className="dev-meta-file-block">
              <div className="section-subtitle">DEV файлы</div>
              <div className="dev-meta-file-list">
                {(files.dev_files || []).map((file) => (() => {
                  const fileLock = (files.locks || []).find(
                    (item) => item.schema_name === schemaName && item.file_name === file.file_name
                  );
                  const blocked = fileLock?.locked_by && fileLock.locked_by !== currentUser;
                  return (
                    <button
                      key={`dev-${file.file_name}`}
                      className={`dev-meta-file ${selectedFile === file.file_name && selectedSource === "dev" ? "active" : ""} ${blocked ? "blocked" : ""}`}
                      onClick={() => openFile(file.file_name, "dev")}
                      disabled={blocked}
                    >
                      <span className="mono">{file.file_name}</span>
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

          <div className="dev-meta-editor-shell">
            <div className="dev-meta-editor-head">
              <div>
                <div className="section-subtitle">Редактор</div>
                <div className="muted">
                  {selectedFile ? `${schemaName}/${selectedFile} · source: ${selectedSource}` : "Выберите файл"}
                </div>
              </div>
              <div className="dev-meta-actions">
                <button className="btn btn-secondary" onClick={handleLock} disabled={!selectedFile || isLockedByAnother}>
                  Взять в работу
                </button>
                <button className="btn btn-secondary" onClick={handleUnlock} disabled={!selectedFile}>
                  Снять блок
                </button>
                <button className="btn btn-secondary" onClick={handleValidate} disabled={!selectedFile || validating}>
                  {validating ? "Проверяем..." : "Проверить"}
                </button>
                <button className="btn btn-primary" onClick={handleSave} disabled={!selectedFile || saving || isLockedByAnother}>
                  {saving ? "Сохраняем..." : "Сохранить в DEV"}
                </button>
                <button
                  className="btn btn-secondary"
                  onClick={handleRunDag}
                  disabled={!selectedFile || runningDag || isLockedByAnother || !status?.airflow?.configured}
                >
                  {runningDag ? "Запускаем..." : "Запустить DEV DAG"}
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

            <div className="dev-meta-notes">
              <div className="dev-meta-note">
                Рабочий поток: открой PROD-файл, возьми lock, внеси правки, проверь, сохрани в `meta_dev`, затем запускай DEV DAG.
              </div>
              <div className="dev-meta-note">
                `DEV_DATABASE_URL` нужен только для проверки существования объекта в DEV Greenplum. Без него YAML/SQL валидация все равно работает.
              </div>
            </div>

            <textarea
              className="dev-meta-editor"
              value={content}
              onChange={(e) => setContent(e.target.value)}
              disabled={isLockedByAnother}
              placeholder="Выберите продовый или dev файл, чтобы начать работу"
            />

            {validation && (
              <div className="dev-meta-validation">
                <div className="section-subtitle">Результат проверки</div>
                <div className={`dev-meta-validation-pill ${validation.valid ? "ok" : "bad"}`}>
                  {validation.valid ? "Файл валиден" : "Есть ошибки"}
                </div>
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
          </div>
        </div>
      </section>
    </div>
  );
}
