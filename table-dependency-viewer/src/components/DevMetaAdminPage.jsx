import React, { useEffect, useMemo, useState } from "react";
import { devMetaApi } from "../api/devMeta.js";
import { formatRuDateTime } from "../utils/datetime.js";

const SCHEMA_OPTIONS = [
  { value: "dm", label: "dm" },
  { value: "dm_view", label: "dm_view" },
];

export default function DevMetaAdminPage({ userProfile }) {
  const [schemaName, setSchemaName] = useState("dm");
  const [generator, setGenerator] = useState({
    schema_name_gp: "dm",
    object_name: "",
    order_by: "",
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
  const [message, setMessage] = useState(null);
  const [messageType, setMessageType] = useState("info");
  const [error, setError] = useState(null);

  const isAdmin = userProfile?.role === "admin";
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
    if (!isAdmin) return;
    refreshStatus().catch((err) => setError(err.message || "Не удалось загрузить статус"));
    refreshFiles().catch((err) => setError(err.message || "Не удалось загрузить файлы"));
  }, [isAdmin]);

  useEffect(() => {
    if (!isAdmin) return;
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

  const acquireLock = async (fileName) => {
    const data = await devMetaApi.lock({ schema_name: schemaName, file_name: fileName });
    setLockInfo(data || null);
    return data;
  };

  const handleSchemaChange = (nextSchema) => {
    setSchemaName(nextSchema);
    setSelectedFile(null);
    setContent("");
    setValidation(null);
    setLockInfo(null);
    setMessage(null);
    setMessageType("info");
    setError(null);
  };

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
      setMessage("Файл открыт и автоматически взят в работу.");
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
      await refreshFiles();
      setMessageType("success");
      setMessage(`Файл сохранен локально и отправлен на DEV сервер: ${data?.remote_path || "успешно"}`);
    } catch (err) {
      setError(err.message || "Не удалось сохранить и отправить файл на DEV сервер");
    } finally {
      setDeploying(false);
    }
  };

  const handleGenerate = async () => {
    setError(null);
    setMessage(null);
    setMessageType("info");
    try {
      if (schemaName !== "dm") {
        throw new Error("Автогенерация сейчас доступна только для схемы dm");
      }
      const orderBy = generator.order_by
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean);
      const data = await devMetaApi.generate({
        schema_name_gp: generator.schema_name_gp,
        object_name: generator.object_name,
        schema_name_click: schemaName,
        greenplum_table_name: null,
        order_by: orderBy,
      });
      if (data?.file_name) {
        await devMetaApi.lock({ schema_name: schemaName, file_name: data.file_name });
      }
      setSelectedFile(data?.file_name || null);
      setContent(data?.content || "");
      setValidation(null);
      setLockInfo(
        data?.file_name
          ? {
              schema_name: schemaName,
              file_name: data.file_name,
              locked_by: currentUser,
            }
          : null
      );
      await refreshFiles(schemaName);
      setMessage("Черновик YAML сгенерирован и автоматически взят в работу.");
    } catch (err) {
      setError(err.message || "Не удалось сгенерировать YAML");
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
          Отдельный admin-only контур для генерации, ручной правки, валидации и выкладки meta-файлов на DEV сервер без пересечения с основным набором meta.
        </div>

        <div className="dev-meta-kpis">
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
          <div className="dev-meta-kpi">
            <div className="label">DEV Deploy</div>
            <div className="value">{status?.deploy?.configured ? "Настроен" : "Не настроен"}</div>
          </div>
        </div>

        <div className="dev-meta-toolbar">
          <div className="dev-meta-tabs">
            {SCHEMA_OPTIONS.map((option) => (
              <button
                key={option.value}
                className={`btn ${schemaName === option.value ? "btn-primary" : "btn-secondary"}`}
                onClick={() => handleSchemaChange(option.value)}
              >
                {option.label}
              </button>
            ))}
          </div>
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
              <span>Имя таблицы / объекта</span>
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
          </div>
          <div className="dev-meta-generator-actions">
            <button className="btn btn-primary" onClick={handleGenerate} disabled={schemaName !== "dm"}>
              Сгенерировать черновик
            </button>
            <div className="muted">
              Генератор берет имя объекта из Greenplum и создает файл для той же схемы и того же имени в ClickHouse. Для `dm_view` оставлена только ручная правка существующих DEV-файлов.
            </div>
          </div>
        </div>

        <div className="dev-meta-browser">
          <div className="dev-meta-file-block">
            <div className="section-subtitle">DEV файлы</div>
            <div className="muted">Открытие файла сразу берет его в работу для текущего администратора.</div>
            <div className="dev-meta-file-list">
              {(files.dev_files || []).map((file) => (() => {
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
                  disabled={!selectedFile || deploying || isLockedByAnother || !status?.deploy?.configured}
                >
                  {deploying ? "Сохраняем и отправляем..." : "Сохранить и отправить на DEV"}
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

            {validation && (
              <div className="dev-meta-validation">
                <div className="section-subtitle">Результат проверки</div>
                <div className={`dev-meta-validation-pill ${validation.valid ? "ok" : "bad"}`}>
                  {validation.valid ? "Файл валиден" : "Есть ошибки"}
                </div>
                <div className="dev-meta-validation-meta">
                  Проверяем: синтаксис YAML, отступы и структуру файла, обязательные поля, `order_by`, `attributes`, допустимые значения схемы и объект в DEV Greenplum, если настроен `DEV_DATABASE_URL`. Для `dm_view` сейчас проверка базовая: файл не пустой и в SQL есть `SELECT`.
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

            <div className="dev-meta-notes">
              <div className="dev-meta-note">
                Рабочий поток: сгенерируй новый YAML или открой DEV-файл, проверь его и одной кнопкой сохрани в `meta_dev` и отправь на DEV сервер.
              </div>
              <div className="dev-meta-note">
                Отправка на DEV всегда перезаписывает одноименный файл на удаленном сервере, если он уже существует.
              </div>
            </div>

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
