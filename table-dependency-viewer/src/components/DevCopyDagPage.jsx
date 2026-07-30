import React, { useEffect, useState } from "react";
import { devCopyApi } from "../api/devCopy.js";
import { formatRuDateTime } from "../utils/datetime.js";
import DagLoadingMiniGame from "./DagLoadingMiniGame.jsx";

export default function DevCopyDagPage({ userProfile }) {
  const [activeTool, setActiveTool] = useState("copy");
  const schemaSyncAuthor = userProfile?.username || userProfile?.email || "";
  const [status, setStatus] = useState(null);
  const [form, setForm] = useState({
    source_table_schema: "dm",
    source_table_name: "",
    target_table_schema: "dm",
    target_table_name: "",
    where: "",
  });
  const [schemaSyncForm, setSchemaSyncForm] = useState({
    run_mode: "self",
    check_table_schema: "dm",
    check_table_name: "",
  });
  const [running, setRunning] = useState(false);
  const [dagStatus, setDagStatus] = useState(null);
  const [schemaSyncRunning, setSchemaSyncRunning] = useState(false);
  const [schemaSyncDagStatus, setSchemaSyncDagStatus] = useState(null);
  const [message, setMessage] = useState(null);
  const [messageType, setMessageType] = useState("info");
  const [error, setError] = useState(null);

  const canUsePage = Boolean(userProfile);
  const dagRunState = String(dagStatus?.dag_run_state || "").toLowerCase();
  const dagIsActive = ["queued", "running"].includes(dagRunState);
  const schemaSyncDagRunState = String(schemaSyncDagStatus?.dag_run_state || "").toLowerCase();
  const schemaSyncDagIsActive = ["queued", "running"].includes(schemaSyncDagRunState);
  const schemaSyncIsAllMode = schemaSyncForm.run_mode === "all";
  const schemaSyncObjectLabel = schemaSyncIsAllMode
    ? "ALL"
    : [schemaSyncForm.check_table_schema, schemaSyncForm.check_table_name].filter(Boolean).join(".");
  const copyWindow = status?.window || null;
  const canRunNow = Boolean(copyWindow?.allowed);

  useEffect(() => {
    if (!canUsePage) return;
    devCopyApi.status()
      .then((data) => setStatus(data || null))
      .catch((err) => setError(err.message || "Не удалось загрузить статус DAG"));
  }, [canUsePage]);

  useEffect(() => {
    if (!dagStatus?.dag_run_id) return undefined;
    if (["success", "failed"].includes(String(dagStatus?.dag_run_state || "").toLowerCase())) {
      return undefined;
    }
    let cancelled = false;
    const poll = async () => {
      try {
        const data = await devCopyApi.dagStatus({
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
  }, [dagStatus?.dag_run_id, dagStatus?.dag_run_state, dagStatus?.auto_unpaused]);

  useEffect(() => {
    if (!schemaSyncDagStatus?.dag_run_id) return undefined;
    if (["success", "failed"].includes(String(schemaSyncDagStatus?.dag_run_state || "").toLowerCase())) {
      return undefined;
    }
    let cancelled = false;
    const poll = async () => {
      try {
        const data = await devCopyApi.schemaSyncDagStatus({
          dag_run_id: schemaSyncDagStatus.dag_run_id,
          auto_unpaused: Boolean(schemaSyncDagStatus.auto_unpaused),
        });
        if (!cancelled) {
          setSchemaSyncDagStatus(data?.response || null);
        }
      } catch (err) {
        if (!cancelled) {
          setError(err.message || "Не удалось получить статус DAG сверки");
        }
      }
    };
    poll();
    const timer = window.setInterval(poll, 7000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, [schemaSyncDagStatus?.dag_run_id, schemaSyncDagStatus?.dag_run_state, schemaSyncDagStatus?.auto_unpaused]);

  useEffect(() => {
    if (schemaSyncDagRunState !== "success") return;
    setError(null);
    setMessageType("success");
    setMessage(
      `Сверка завершена для ${schemaSyncObjectLabel || "выбранных объектов"}. Иди смотри в БД.`
    );
  }, [schemaSyncDagRunState, schemaSyncObjectLabel]);

  const handleRun = async () => {
    if (!form.source_table_schema || !form.source_table_name || !form.target_table_schema || !form.target_table_name) {
      setError("Нужно заполнить схему и таблицу для PROD и DEV");
      return;
    }
    setRunning(true);
    setError(null);
    setMessage(null);
    try {
      const data = await devCopyApi.runDag(form);
      const dagRun = data?.response?.response || data?.response || {};
      setDagStatus({
        dag_id: data?.response?.dag_id || status?.airflow?.dag_id || null,
        dag_run_id: dagRun?.dag_run_id,
        dag_run_state: dagRun?.state || "queued",
        failed_tasks: [],
        auto_unpaused: Boolean(data?.response?.auto_unpaused),
        dag_is_paused: Boolean(data?.response?.was_paused),
      });
      setMessageType("success");
      setMessage(`DEV copy DAG запущен: ${data?.response?.dag_id || status?.airflow?.dag_id || "—"}`);
    } catch (err) {
      setError(err.message || "Не удалось запустить DAG");
    } finally {
      setRunning(false);
    }
  };

  const handleRunSchemaSync = async () => {
    if (!schemaSyncIsAllMode && (!schemaSyncForm.check_table_schema || !schemaSyncForm.check_table_name)) {
      setError("Нужно заполнить check_table_schema и check_table_name");
      return;
    }
    setSchemaSyncRunning(true);
    setError(null);
    setMessage(null);
    try {
      const data = await devCopyApi.runSchemaSyncDag(schemaSyncForm);
      const dagRun = data?.response?.response || data?.response || {};
      setSchemaSyncDagStatus({
        dag_id: data?.response?.dag_id || status?.schema_sync?.dag_id || null,
        dag_run_id: dagRun?.dag_run_id,
        dag_run_state: dagRun?.state || "queued",
        failed_tasks: [],
        logical_date: dagRun?.logical_date || dagRun?.execution_date || null,
        auto_unpaused: Boolean(data?.response?.auto_unpaused),
        dag_is_paused: Boolean(data?.response?.was_paused),
      });
      setMessageType("success");
      setMessage(`DAG сверки metadata запущен: ${data?.response?.dag_id || status?.schema_sync?.dag_id || "—"}`);
    } catch (err) {
      setError(err.message || "Не удалось запустить DAG сверки metadata");
    } finally {
      setSchemaSyncRunning(false);
    }
  };

  if (!canUsePage) {
    return (
      <div className="container cc-page">
        <div className="cc-surface">
          <div className="section-title">Доступ запрещён</div>
          <div className="muted">Требуется авторизация.</div>
        </div>
      </div>
    );
  }

  return (
    <div className="container cc-page">
      <section className="cc-surface dev-meta-page">
        <div className="section-title">DEV Copy DAG</div>
        <div className="section-subtitle">
          Запуск DAG `load_from_prod_to_dev` для копирования данных из PROD в DEV. Копировать можно в любую схему и с любым названием целевой таблицы. Пользоваться страницей можно только с 08:00 до 21:00 по Москве.
        </div>

        <div className="dev-meta-tabs dev-copy-tabs">
          <button
            type="button"
            className={`dev-meta-tab ${activeTool === "copy" ? "active" : ""}`}
            onClick={() => setActiveTool("copy")}
          >
            Copy
          </button>
          <button
            type="button"
            className={`dev-meta-tab ${activeTool === "check" ? "active" : ""}`}
            onClick={() => setActiveTool("check")}
          >
            Check
          </button>
        </div>

        <div className="dev-copy-sections">
          {activeTool === "copy" ? (
            <div className="dev-copy-section">
              <div className="dev-copy-section-mark">Copy</div>
              <div className="dev-meta-generator dev-copy-card">
                <div className="section-subtitle">Параметры запуска</div>
                <div className="dev-meta-generator-grid">
                  <label className="admin-field">
                    <span>source_table_schema</span>
                    <input
                      value={form.source_table_schema}
                      onChange={(e) => setForm((prev) => ({ ...prev, source_table_schema: e.target.value }))}
                      placeholder="dm"
                    />
                  </label>
                  <label className="admin-field">
                    <span>source_table_name</span>
                    <input
                      value={form.source_table_name}
                      onChange={(e) => setForm((prev) => ({ ...prev, source_table_name: e.target.value }))}
                      placeholder="account_debt"
                    />
                  </label>
                  <label className="admin-field">
                    <span>target_table_schema</span>
                    <input
                      value={form.target_table_schema}
                      onChange={(e) => setForm((prev) => ({ ...prev, target_table_schema: e.target.value }))}
                      placeholder="dm"
                    />
                  </label>
                  <label className="admin-field">
                    <span>target_table_name</span>
                    <input
                      value={form.target_table_name}
                      onChange={(e) => setForm((prev) => ({ ...prev, target_table_name: e.target.value }))}
                      placeholder="account_debt_dev"
                    />
                  </label>
                  <label className="admin-field dev-meta-generator-wide">
                    <span>where</span>
                    <input
                      value={form.where}
                      onChange={(e) => setForm((prev) => ({ ...prev, where: e.target.value }))}
                      placeholder="dt_of_verification::date = '2026-07-29'"
                    />
                    <span className="muted">
                      Фильтр. `WHERE` писать не нужно. Пример: `dt_of_verification::date = '2026-07-29'`
                    </span>
                  </label>
                </div>
                <div className="dev-meta-generator-actions">
                  <button className="btn btn-primary" onClick={handleRun} disabled={running || !status?.airflow?.configured || !canRunNow}>
                    {running ? "Запускаем DAG..." : "Запустить DEV copy DAG"}
                  </button>
                  <span className="muted">
                    DAG: {status?.airflow?.dag_id || "не настроен"}
                  </span>
                </div>
                <div className="muted">
                  Окно запуска: {copyWindow?.allowed_from || "08:00"} - {copyWindow?.allowed_to || "21:00"} (МСК)
                  {copyWindow ? `, сейчас ${copyWindow.allowed ? "запуск разрешен" : "запуск недоступен"}` : ""}
                </div>
              </div>
            </div>
          ) : null}

          {activeTool === "check" ? (
            <div className="dev-copy-section">
              <div className="dev-copy-section-mark">Check</div>
              <div className="dev-meta-generator dev-copy-card">
                <div className="section-subtitle">Сверка metadata PROD vs DEV</div>
                <div className="muted">
                  Запуск DAG <span className="mono">{status?.schema_sync?.dag_id || "information_schema_sync"}</span>.
                </div>
                <div className="dev-meta-tabs">
                  <button
                    type="button"
                    className={`dev-meta-tab ${!schemaSyncIsAllMode ? "active" : ""}`}
                    onClick={() => setSchemaSyncForm((prev) => ({ ...prev, run_mode: "self" }))}
                  >
                    Свой author
                  </button>
                  <button
                    type="button"
                    className={`dev-meta-tab ${schemaSyncIsAllMode ? "active" : ""}`}
                    onClick={() => setSchemaSyncForm((prev) => ({ ...prev, run_mode: "all" }))}
                  >
                    ALL
                  </button>
                </div>
                <div className="muted">
                  {schemaSyncIsAllMode
                    ? "В режиме ALL DAG запускается без параметров."
                    : "В режиме author DAG запускается с author, check_table_schema и check_table_name."}
                </div>
                <div className="dev-meta-generator-grid">
                  {!schemaSyncIsAllMode ? (
                    <>
                      <label className="admin-field">
                        <span>author</span>
                        <input value={schemaSyncAuthor} disabled />
                      </label>
                      <label className="admin-field">
                        <span>check_table_schema</span>
                        <input
                          value={schemaSyncForm.check_table_schema}
                          onChange={(e) => setSchemaSyncForm((prev) => ({ ...prev, check_table_schema: e.target.value }))}
                          placeholder="dm"
                        />
                      </label>
                      <label className="admin-field">
                        <span>check_table_name</span>
                        <input
                          value={schemaSyncForm.check_table_name}
                          onChange={(e) => setSchemaSyncForm((prev) => ({ ...prev, check_table_name: e.target.value }))}
                          placeholder="account_debt"
                        />
                      </label>
                    </>
                  ) : null}
                </div>
                <div className="dev-meta-generator-actions">
                  <button
                    className="btn btn-primary"
                    onClick={handleRunSchemaSync}
                    disabled={schemaSyncRunning || (!schemaSyncIsAllMode && (!schemaSyncForm.check_table_schema || !schemaSyncForm.check_table_name))}
                  >
                    {schemaSyncRunning ? "Запускаем DAG сверки..." : "Запустить information_schema_sync"}
                  </button>
                  <span className="muted">DAG: {status?.schema_sync?.dag_id || "не настроен"}</span>
                </div>
              </div>
            </div>
          ) : null}
        </div>

        {(message || error) && (
          <div className={`dev-meta-feedback ${error ? "error" : messageType}`}>
            <div className="dev-meta-feedback-title">
              {error ? "Операция не выполнена" : "Статус"}
            </div>
            <div className="dev-meta-feedback-text">{error || message}</div>
          </div>
        )}

        {dagStatus && (
          <div className="dev-meta-dag-status">
            <div className="section-subtitle">Статус DEV copy DAG</div>
            <div className="dev-meta-dag-grid">
              <div className="dev-meta-dag-card">
                <span className="label">Run</span>
                <strong className="mono">{dagStatus.dag_run_id || "—"}</strong>
              </div>
              <div className={`dev-meta-dag-card dev-meta-dag-state dev-meta-dag-state-${dagRunState || "idle"}`}>
                <span className="label">Статус запуска</span>
                <strong>{dagStatus.dag_run_state || "—"}</strong>
              </div>
              <div className="dev-meta-dag-card">
                <span className="label">Дата запуска</span>
                <strong>{dagStatus.logical_date ? formatRuDateTime(dagStatus.logical_date) : "—"}</strong>
              </div>
            </div>
            {dagStatus.failed_tasks?.length ? (
              <div className="dev-meta-dag-failed">
                <div>Ошибки:</div>
                <div className="dev-copy-failed-list">
                  {dagStatus.failed_tasks.map((task) => (
                    <div key={`${task.task_id}:${task.try_number || 0}`} className="dev-copy-failed-item">
                      <div className="dev-copy-failed-head">
                        <strong>{task.task_id}</strong> <span>({task.state})</span>
                      </div>
                      {task.error_excerpt ? (
                        <pre className="dev-copy-failed-log">{task.error_excerpt}</pre>
                      ) : (
                        <div className="muted">Подробный текст ошибки Airflow не вернул.</div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
            {dagStatus.window_message ? (
              <div className="dev-meta-dag-failed">{dagStatus.window_message}</div>
            ) : null}
            <DagLoadingMiniGame active={dagIsActive} />
          </div>
        )}

        {schemaSyncDagStatus && (
          <div className="dev-meta-dag-status">
            <div className="section-subtitle">Статус сверки metadata</div>
            <div className="dev-meta-dag-grid">
              <div className="dev-meta-dag-card">
                <span className="label">Run</span>
                <strong className="mono">{schemaSyncDagStatus.dag_run_id || "—"}</strong>
              </div>
              <div className={`dev-meta-dag-card dev-meta-dag-state dev-meta-dag-state-${schemaSyncDagRunState || "idle"}`}>
                <span className="label">Статус запуска</span>
                <strong>{schemaSyncDagStatus.dag_run_state || "—"}</strong>
              </div>
              <div className="dev-meta-dag-card">
                <span className="label">Дата запуска</span>
                <strong>{schemaSyncDagStatus.logical_date ? formatRuDateTime(schemaSyncDagStatus.logical_date) : "—"}</strong>
              </div>
            </div>
            {schemaSyncDagStatus.failed_tasks?.length ? (
              <div className="dev-meta-dag-failed">
                <div>Ошибки:</div>
                <div className="dev-copy-failed-list">
                  {schemaSyncDagStatus.failed_tasks.map((task) => (
                    <div key={`${task.task_id}:${task.try_number || 0}`} className="dev-copy-failed-item">
                      <div className="dev-copy-failed-head">
                        <strong>{task.task_id}</strong> <span>({task.state})</span>
                      </div>
                      {task.error_excerpt ? (
                        <pre className="dev-copy-failed-log">{task.error_excerpt}</pre>
                      ) : (
                        <div className="muted">Подробный текст ошибки Airflow не вернул.</div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
            <DagLoadingMiniGame active={schemaSyncDagIsActive} />
          </div>
        )}

        {schemaSyncDagRunState === "success" && (
          <div className="dev-meta-dag-status">
            <div className="section-subtitle">Результат сверки schema metadata</div>
            <div className="dev-copy-report-empty">
              Сверка завершена для <span className="mono">{schemaSyncObjectLabel || "ALL"}</span>. Иди смотри результат в БД.
            </div>
          </div>
        )}
      </section>
    </div>
  );
}
