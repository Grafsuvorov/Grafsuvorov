import React, { useEffect, useState } from "react";
import { devCopyApi } from "../api/devCopy.js";
import { formatRuDateTime } from "../utils/datetime.js";
import DagLoadingMiniGame from "./DagLoadingMiniGame.jsx";

export default function DevCopyDagPage({ userProfile }) {
  const [status, setStatus] = useState(null);
  const [form, setForm] = useState({
    prod_schema_name: "dm",
    prod_table_name: "",
    dev_schema_name: "dm",
    dev_table_name: "",
  });
  const [running, setRunning] = useState(false);
  const [dagStatus, setDagStatus] = useState(null);
  const [message, setMessage] = useState(null);
  const [messageType, setMessageType] = useState("info");
  const [error, setError] = useState(null);

  const canUsePage = userProfile?.role === "admin";
  const dagRunState = String(dagStatus?.dag_run_state || "").toLowerCase();
  const dagIsActive = ["queued", "running"].includes(dagRunState);

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

  const handleRun = async () => {
    if (!form.prod_schema_name || !form.prod_table_name || !form.dev_schema_name || !form.dev_table_name) {
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

  if (!canUsePage) {
    return (
      <div className="container cc-page">
        <div className="cc-surface">
          <div className="section-title">Доступ запрещён</div>
          <div className="muted">Требуется роль администратора.</div>
        </div>
      </div>
    );
  }

  return (
    <div className="container cc-page">
      <section className="cc-surface dev-meta-page">
        <div className="section-title">DEV Copy DAG</div>
        <div className="section-subtitle">
          Запуск фиксированного DAG для копирования данных из PROD в DEV по параметрам схемы и таблицы.
        </div>

        <div className="dev-meta-generator">
          <div className="section-subtitle">Параметры запуска</div>
          <div className="dev-meta-generator-grid">
            <label className="admin-field">
              <span>PROD схема</span>
              <input
                value={form.prod_schema_name}
                onChange={(e) => setForm((prev) => ({ ...prev, prod_schema_name: e.target.value }))}
                placeholder="dm"
              />
            </label>
            <label className="admin-field">
              <span>PROD таблица</span>
              <input
                value={form.prod_table_name}
                onChange={(e) => setForm((prev) => ({ ...prev, prod_table_name: e.target.value }))}
                placeholder="account_debt"
              />
            </label>
            <label className="admin-field">
              <span>DEV схема</span>
              <input
                value={form.dev_schema_name}
                onChange={(e) => setForm((prev) => ({ ...prev, dev_schema_name: e.target.value }))}
                placeholder="dm"
              />
            </label>
            <label className="admin-field">
              <span>DEV таблица</span>
              <input
                value={form.dev_table_name}
                onChange={(e) => setForm((prev) => ({ ...prev, dev_table_name: e.target.value }))}
                placeholder="account_debt_dev"
              />
            </label>
          </div>
          <div className="dev-meta-generator-actions">
            <button className="btn btn-primary" onClick={handleRun} disabled={running || !status?.airflow?.configured}>
              {running ? "Запускаем DAG..." : "Запустить DEV copy DAG"}
            </button>
            <span className="muted">
              DAG: {status?.airflow?.dag_id || "не настроен"}
            </span>
          </div>
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
                Ошибки: {dagStatus.failed_tasks.map((task) => `${task.task_id} (${task.state})`).join(", ")}
              </div>
            ) : null}
            <DagLoadingMiniGame active={dagIsActive} />
          </div>
        )}
      </section>
    </div>
  );
}
