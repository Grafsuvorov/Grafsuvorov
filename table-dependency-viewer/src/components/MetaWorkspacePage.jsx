import React, { useState } from "react";
import DevMetaAdminPage from "./DevMetaAdminPage.jsx";
import EntityDevMetaWorkspace from "./EntityDevMetaWorkspace.jsx";
import { metaWorkspaceApi } from "../api/metaWorkspace.js";

export default function MetaWorkspacePage({ userProfile }) {
  const [mode, setMode] = useState("gp");
  const [taskId, setTaskId] = useState("");
  const [releaseBranch, setReleaseBranch] = useState("");
  const [creatingMr, setCreatingMr] = useState(false);
  const [message, setMessage] = useState(null);
  const [error, setError] = useState(null);

  const taskIdValid = /^DWH-\d+$/.test(String(taskId || "").trim().toUpperCase());

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

  return (
    <div className="container cc-page">
      <section className="cc-surface dev-meta-page">
        <div className="section-title">Подготовка релиза</div>
        <div className="section-subtitle">Общий раздел задачи: GP-объекты и ClickHouse мета с единым MR.</div>

        {(message || error) && (
          <div className={`dev-meta-feedback ${error ? "error" : "success"}`}>
            <div className="dev-meta-feedback-title">{error ? "Операция не выполнена" : "Статус"}</div>
            <div className="dev-meta-feedback-text">{error || message}</div>
          </div>
        )}

        <div className="dev-meta-generator">
          <div className="section-subtitle">Общий контекст задачи</div>
          <div className="dev-meta-generator-grid">
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

        <div className="dev-meta-tabs meta-workspace-tabs">
          <button type="button" className={`dev-meta-tab ${mode === "gp" ? "active" : ""}`} onClick={() => setMode("gp")}>
            Greenplum
          </button>
          <button type="button" className={`dev-meta-tab ${mode === "click" ? "active" : ""}`} onClick={() => setMode("click")}>
            ClickHouse
          </button>
        </div>

        {mode === "gp" ? (
          <EntityDevMetaWorkspace
            userProfile={userProfile}
            embedded
            taskId={taskId}
            onTaskIdChange={setTaskId}
            releaseBranch={releaseBranch}
            onReleaseBranchChange={setReleaseBranch}
            hideCreateMr
            hideHeader
            hideTaskControls
          />
        ) : (
          <DevMetaAdminPage userProfile={userProfile} embedded taskId={taskId} hideHeader />
        )}
      </section>
    </div>
  );
}
