import { useEffect, useMemo, useState } from "react";
import { adminApi } from "../api/admin.js";
import { accountApi } from "../api/account.js";

const DEFAULT_FORM = {
  summary: "",
  subject_area: "",
  git_reference: "",
  load_mode: "",
  script_runtime: "",
};

function sleep(ms) {
  return new Promise((resolve) => window.setTimeout(resolve, ms));
}

function splitItems(value) {
  return String(value || "")
    .split(/[\n,;]+/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function joinItems(value) {
  return Array.isArray(value) ? value.join(", ") : String(value || "");
}

function formatDuration(value) {
  const numeric = Number(value || 0);
  if (!Number.isFinite(numeric)) return "—";
  if (numeric >= 60) return `${(numeric / 60).toFixed(numeric >= 600 ? 1 : 2)} мин`;
  return `${numeric.toFixed(3)} сек`;
}

function formatCount(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return value ?? "—";
  return new Intl.NumberFormat("ru-RU").format(numeric);
}

function formatStatus(status) {
  if (status === "ok") return "OK";
  if (status === "warning") return "WARNING";
  return "ERROR";
}

function formatIssueStatus(issue) {
  if (issue?.status === "created") {
    return issue?.link ? <a href={issue.link} target="_blank" rel="noreferrer">{issue.issue_id}</a> : issue.issue_id;
  }
  if (issue?.status === "not_configured") return "YTrack не настроен";
  return issue?.status || "skipped";
}

function formatYamlSource(bundle) {
  if (!bundle) return "—";
  if (bundle.source === "new") return "Новая таблица";
  if (bundle.source === "dev") return "DEV meta";
  if (bundle.source === "prod") return "PROD meta";
  return bundle.source || "—";
}

function buildTaskText(form, linkedIssues) {
  const lines = [];
  const pushLine = (label, value) => {
    const text = String(value || "").trim();
    if (text) lines.push(`${label}: ${text}`);
  };

  if (String(form.summary || "").trim()) {
    lines.push(String(form.summary).trim(), "");
  }
  pushLine("Предметная область", form.subject_area);
  pushLine("Ссылка на гит", form.git_reference);
  pushLine("Способ обновления", form.load_mode);
  pushLine("Время работы скрипта", form.script_runtime);
  if (splitItems(linkedIssues).length) {
    lines.push(`Связанные тикеты: ${splitItems(linkedIssues).join(", ")}`);
  }
  return lines.join("\n");
}

function buildDraftItem(item) {
  return {
    ...item,
    entity_name: item.entity_name || "",
    key_attributes_text: joinItems(item.key_attributes || []),
    clickhouse_keys_text: joinItems(item.clickhouse_keys || []),
    stand_dev: item.stand_dev !== false,
    stand_prod: item.stand_prod !== false,
    copy_to_clickhouse: Boolean(item.copy_to_clickhouse),
    checks: item.checks || { row_count: null, duplicate_groups: null },
    rechecking: false,
    dependent_views_text: joinItems(item.impact?.tables?.map((row) => row.fqn) || []),
  };
}

export default function AdminPrototypeReviewPage() {
  const [mrInput, setMrInput] = useState("");
  const [form, setForm] = useState(DEFAULT_FORM);
  const [linkedIssues, setLinkedIssues] = useState("");
  const [loading, setLoading] = useState(false);
  const [creatingIssue, setCreatingIssue] = useState(false);
  const [error, setError] = useState(null);
  const [result, setResult] = useState(null);
  const [currentUser, setCurrentUser] = useState(null);
  const [yamlCopied, setYamlCopied] = useState(false);
  const [reviewItemsDraft, setReviewItemsDraft] = useState([]);
  const [runProgress, setRunProgress] = useState(null);

  useEffect(() => {
    accountApi.me().then(setCurrentUser).catch(() => {});
  }, []);

  useEffect(() => {
    const mrValue = String(mrInput || "").trim();
    if (!mrValue) return;
    setForm((prev) => {
      if (String(prev.git_reference || "").trim()) return prev;
      return { ...prev, git_reference: mrValue };
    });
  }, [mrInput]);

  useEffect(() => {
    if (!yamlCopied) return undefined;
    const timer = window.setTimeout(() => setYamlCopied(false), 1600);
    return () => window.clearTimeout(timer);
  }, [yamlCopied]);

  useEffect(() => {
    const items = Array.isArray(result?.review_items) ? result.review_items : [];
    setReviewItemsDraft(items.map(buildDraftItem));
  }, [result]);

  const normalizedTaskText = useMemo(
    () => buildTaskText(form, linkedIssues),
    [form, linkedIssues],
  );

  const totalExecutionSec = useMemo(
    () => (Array.isArray(result?.execution) ? result.execution.reduce((acc, item) => acc + Number(item?.duration_sec || 0), 0) : 0),
    [result],
  );

  const unresolvedItemsCount = useMemo(
    () => reviewItemsDraft.filter((item) => (
      !String(item.entity_name || "").trim() || !splitItems(item.key_attributes_text).length
    )).length,
    [reviewItemsDraft],
  );

  const progressText = useMemo(() => {
    if (!runProgress) return "";
    const current = Number(runProgress.current || 0);
    const total = Number(runProgress.total || 0);
    const remaining = total > 0 ? Math.max(total - current, 0) : null;
    const parts = [`Статус: ${runProgress.status || "running"}`];
    if (total > 0) {
      parts.push(`Проверено: ${current}/${total}`);
      parts.push(`Осталось: ${remaining}`);
    }
    if (runProgress.current_target) {
      parts.push(`Текущий объект: ${runProgress.current_target}`);
    }
    return parts.join(" · ");
  }, [runProgress]);

  const handleFieldChange = (field, value) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const handleReviewItemChange = (targetFqn, field, value) => {
    setReviewItemsDraft((prev) => prev.map((item) => {
      if (item.target_fqn !== targetFqn) return item;
      return { ...item, [field]: value };
    }));
  };

  const handleReviewItemToggle = (targetFqn, field, checked) => {
    setReviewItemsDraft((prev) => prev.map((item) => (
      item.target_fqn !== targetFqn ? item : { ...item, [field]: checked }
    )));
  };

  const handleCopyYaml = async (content) => {
    const value = String(content || "").trim();
    if (!value) return;
    try {
      await navigator.clipboard.writeText(value);
      setYamlCopied(true);
    } catch (_) {
      setYamlCopied(false);
    }
  };

  const handleRun = async () => {
    const trimmedMr = String(mrInput || "").trim();
    if (!trimmedMr || loading) return;
    setLoading(true);
    setError(null);
    setResult(null);
    setRunProgress({ status: "queued", current: 0, total: 0, current_target: null, current_file: null });
    try {
      const startPayload = await adminApi.prototypeReviewRunStart({
        mr_input: trimmedMr,
        task_text: normalizedTaskText,
        issue_summary: form.summary.trim(),
        load_mode: form.load_mode.trim(),
        linked_issues: splitItems(linkedIssues),
        create_issue: false,
      });
      const jobId = String(startPayload?.job_id || "").trim();
      if (!jobId) throw new Error("Backend не вернул job_id для prototype review");

      let statusPayload = null;
      for (;;) {
        statusPayload = await adminApi.prototypeReviewRunStatus(jobId);
        setRunProgress(statusPayload || null);
        if (statusPayload?.status === "completed") break;
        if (statusPayload?.status === "error") {
          throw new Error(statusPayload?.error || "Prototype review завершился с ошибкой");
        }
        await sleep(1000);
      }

      const payload = statusPayload?.result || null;
      setResult(payload);
      const firstTarget = Array.isArray(payload?.review_items) && payload.review_items.length ? payload.review_items[0]?.target_fqn : "";
      const firstEntity = Array.isArray(payload?.review_items) && payload.review_items.length ? payload.review_items[0]?.entity_name : "";
      const firstLoadMode = Array.isArray(payload?.review_items) && payload.review_items.length ? payload.review_items[0]?.load_mode : "";
      const totalSec = Array.isArray(payload?.execution)
        ? payload.execution.reduce((acc, item) => acc + Number(item?.duration_sec || 0), 0)
        : 0;
      setForm((prev) => ({
        ...prev,
        summary: prev.summary || (firstTarget ? `(ДМЛ) Настроить обновление витрины ${firstTarget}` : ""),
        git_reference: prev.git_reference || trimmedMr,
        subject_area: prev.subject_area || String(payload?.task_context?.subject_area || ""),
        load_mode: prev.load_mode || firstLoadMode || String(payload?.task_context?.load_mode || ""),
        script_runtime: totalSec >= 60 ? `${(totalSec / 60).toFixed(2)} мин` : totalSec > 0 ? `${totalSec.toFixed(3)} сек` : prev.script_runtime,
      }));
      if (!String(linkedIssues || "").trim() && Array.isArray(payload?.task_context?.linked_issues)) {
        setLinkedIssues(payload.task_context.linked_issues.join(", "));
      }
      if (!String(firstEntity || "").trim()) return;
    } catch (err) {
      setError(err?.message || "Не удалось выполнить prototype review");
    } finally {
      setLoading(false);
    }
  };

  const handleRecheckNewTable = async (targetFqn) => {
    const current = reviewItemsDraft.find((item) => item.target_fqn === targetFqn);
    if (!current || current.rechecking) return;
    const keyAttributes = splitItems(current.key_attributes_text);
    if (!keyAttributes.length) {
      setError("Сначала укажите ключевые поля для проверки дублей");
      return;
    }
    setError(null);
    setReviewItemsDraft((prev) => prev.map((item) => (
      item.target_fqn !== targetFqn ? item : { ...item, rechecking: true }
    )));
    try {
      const payload = await adminApi.prototypeReviewCheckTable({
        target_fqn: current.target_fqn,
        key_attributes: keyAttributes,
      });
      setReviewItemsDraft((prev) => prev.map((item) => (
        item.target_fqn !== targetFqn
          ? item
          : {
              ...item,
              checks: payload?.checks || item.checks,
              rechecking: false,
            }
      )));
    } catch (err) {
      setError(err?.message || "Не удалось перепроверить новую таблицу");
      setReviewItemsDraft((prev) => prev.map((item) => (
        item.target_fqn !== targetFqn ? item : { ...item, rechecking: false }
      )));
    }
  };

  const handleCreateIssue = async () => {
    const trimmedMr = String(mrInput || "").trim();
    if (!trimmedMr || creatingIssue) return;
    setCreatingIssue(true);
    setError(null);
    try {
      const payload = await adminApi.prototypeReviewCreateIssue({
        mr_input: trimmedMr,
        task_text: normalizedTaskText,
        issue_summary: form.summary.trim(),
        load_mode: form.load_mode.trim(),
        linked_issues: splitItems(linkedIssues),
        review_items: reviewItemsDraft.map((item) => ({
          path: item.path,
          target_fqn: item.target_fqn,
          entity_name: String(item.entity_name || "").trim(),
          key_attributes: splitItems(item.key_attributes_text),
          clickhouse_keys: splitItems(item.clickhouse_keys_text),
          dependent_views: splitItems(item.dependent_views_text),
          is_new: item.is_new,
          object_type: item.object_type,
          duration_sec: item.duration_sec,
          row_count: item.checks?.row_count ?? null,
          duplicate_groups: item.checks?.duplicate_groups ?? null,
          dependencies: item.dependencies || [],
          impact_tables: item.impact?.tables || [],
          yaml_content: item.yaml_bundle?.yaml_content || "",
          stand_dev: Boolean(item.stand_dev),
          stand_prod: Boolean(item.stand_prod),
          copy_to_clickhouse: Boolean(item.copy_to_clickhouse),
        })),
      });
      setResult((prev) => ({ ...(prev || {}), issue: payload?.issue || null }));
    } catch (err) {
      setError(err?.message || "Не удалось создать задачу");
    } finally {
      setCreatingIssue(false);
    }
  };

  return (
    <div className="container cc-page slow-page prototype-review-page">
      <section className="cc-header-zone">
        <h1>Prototype Review / MR Review</h1>
        <div className="cc-subtitle">
          Запустите проверку MR, заполните только то, что не определилось автоматически, и создайте задачу по всему набору объектов.
        </div>
      </section>

      <section className="cc-surface">
        <div className="prototype-top-grid">
          <div className="prototype-step-field" style={{ margin: 0 }}>
            <span className="slow-select-label">MR URL или IID</span>
            <input
              className="slow-entity-select"
              value={mrInput}
              onChange={(event) => setMrInput(event.target.value)}
              placeholder="https://gitlab.../-/merge_requests/123"
            />
          </div>
          <div className="prototype-step-field" style={{ margin: 0 }}>
            <span className="slow-select-label">Инициатор</span>
            <div className="muted" style={{ marginTop: 10 }}>
              <span className="mono">{currentUser?.username || currentUser?.email || "текущий пользователь"}</span>
            </div>
          </div>
        </div>

        <div className="prototype-import-actions">
          <div className="muted">После запуска появятся все целевые объекты MR и их статусы.</div>
          <button className="btn btn-primary" onClick={handleRun} disabled={loading || !mrInput.trim()}>
            {loading ? "Идет review..." : "Запустить review"}
          </button>
        </div>

        {loading || runProgress ? (
          <div className="card muted" style={{ marginTop: 14 }}>
            <div>{progressText || "Подготовка проверки..."}</div>
            <div>Файл: <span className="mono">{runProgress?.current_file || "—"}</span></div>
          </div>
        ) : null}
      </section>

      {error ? <div className="page-error">{error}</div> : null}

      {result ? (
        <>
          <section className="slow-summary">
            <div className={`slow-summary-card ${result.status === "ok" ? "success" : result.status === "warning" ? "warn" : "danger"}`}>
              <div className="label">Статус</div>
              <div className="value">{formatStatus(result.status)}</div>
              <div className="hint">{result.status_reason || "—"}</div>
            </div>
            <div className="slow-summary-card">
              <div className="label">Объекты MR</div>
              <div className="value">{reviewItemsDraft.length}</div>
              <div className="hint">
                {unresolvedItemsCount > 0 ? `Нужно заполнить: ${unresolvedItemsCount}` : "Все обязательные поля заполнены"}
              </div>
            </div>
            <div className="slow-summary-card">
              <div className="label">YTrack</div>
              <div className="value">{formatIssueStatus(result.issue)}</div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Параметры задачи</div>
            <div className="prototype-step-grid">
              <div className="prototype-step-field" style={{ margin: 0 }}>
                <span className="slow-select-label">Название задачи</span>
                <input
                  className="slow-entity-select"
                  value={form.summary}
                  onChange={(event) => handleFieldChange("summary", event.target.value)}
                  placeholder="(ДМЛ) Настроить обновление витрины ..."
                />
              </div>
              <div className="prototype-step-field" style={{ margin: 0 }}>
                <span className="slow-select-label">Связанные тикеты</span>
                <input
                  className="slow-entity-select"
                  value={linkedIssues}
                  onChange={(event) => setLinkedIssues(event.target.value)}
                  placeholder="DWH-15089, DWH-15539"
                />
              </div>
              <div className="prototype-step-field" style={{ margin: 0 }}>
                <span className="slow-select-label">Предметная область</span>
                <input
                  className="slow-entity-select"
                  value={form.subject_area}
                  onChange={(event) => handleFieldChange("subject_area", event.target.value)}
                  placeholder="SD"
                />
              </div>
              <div className="prototype-step-field" style={{ margin: 0 }}>
                <span className="slow-select-label">Режим обновления</span>
                <input
                  className="slow-entity-select"
                  value={form.load_mode}
                  onChange={(event) => handleFieldChange("load_mode", event.target.value)}
                  placeholder="Полный / Псевдоинкрементальный"
                />
              </div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Статусы файлов</div>
            <div className="table-wrapper">
              <table className="incidents-table slow-table">
                <thead>
                  <tr>
                    <th>Файл</th>
                    <th>Таблица</th>
                    <th>Проверка</th>
                    <th>Время</th>
                    <th>Ошибка</th>
                  </tr>
                </thead>
                <tbody>
                  {(result.execution || []).map((row) => (
                    <tr key={row.path}>
                      <td className="mono" style={{ overflowWrap: "anywhere", wordBreak: "break-word" }}>{row.path || "—"}</td>
                      <td className="mono">{row.target_fqn || "—"}</td>
                      <td>{row.status || "—"}</td>
                      <td>{row.duration_sec ? formatDuration(row.duration_sec) : "—"}</td>
                      <td style={{ maxWidth: 520, overflowWrap: "anywhere", wordBreak: "break-word" }}>{row.error_message || "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Объекты MR</div>
            <div style={{ display: "grid", gap: 16 }}>
              {reviewItemsDraft.map((item) => {
                const needsEntity = !String(item.entity_name || "").trim();
                const needsKeys = !splitItems(item.key_attributes_text).length;
                const needsAttention = Boolean(needsEntity || needsKeys);
                return (
                  <div
                    key={item.target_fqn}
                    className="cc-surface"
                    style={{
                      margin: 0,
                      border: needsAttention ? "1px solid rgba(214, 86, 46, 0.45)" : undefined,
                      boxShadow: needsAttention ? "0 0 0 1px rgba(214, 86, 46, 0.08) inset" : undefined,
                    }}
                  >
                    <div className="prototype-chip-row" style={{ justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
                      <div>
                        <div className="mono" style={{ fontSize: "1rem", fontWeight: 700 }}>{item.target_fqn || "—"}</div>
                        <div className="muted">{item.path || "—"}</div>
                      </div>
                      <div className="prototype-chip-row">
                        <span className="card" style={{ padding: "6px 10px", margin: 0 }}>{item.object_type || "TABLE"}</span>
                        {item.is_new ? <span className="card" style={{ padding: "6px 10px", margin: 0 }}>Новая таблица</span> : null}
                        {needsAttention ? <span className="card" style={{ padding: "6px 10px", margin: 0, color: "#b54708" }}>Нужно заполнить</span> : null}
                      </div>
                    </div>

                    <div className="table-wrapper" style={{ marginBottom: 14 }}>
                      <table className="incidents-table slow-table">
                        <thead>
                          <tr>
                            <th>Сущность</th>
                            <th>Ключевые поля</th>
                            <th>Количество строк</th>
                            <th>Кол-во дублей</th>
                            <th>Время выполнения SQL</th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr>
                            <td>{item.entity_name || "—"}</td>
                            <td>{splitItems(item.key_attributes_text).join(", ") || "—"}</td>
                            <td>{item.checks?.row_count !== undefined && item.checks?.row_count !== null ? formatCount(item.checks.row_count) : "—"}</td>
                            <td>{item.checks?.duplicate_groups !== undefined && item.checks?.duplicate_groups !== null ? formatCount(item.checks.duplicate_groups) : "—"}</td>
                            <td>{item.duration_sec ? formatDuration(item.duration_sec) : "—"}</td>
                          </tr>
                        </tbody>
                      </table>
                    </div>

                    <div className="prototype-step-grid">
                      <div className="prototype-step-field" style={{ margin: 0 }}>
                        <span className="slow-select-label">Сущность загрузки</span>
                        <input
                          className="slow-entity-select"
                          value={item.entity_name || ""}
                          onChange={(event) => handleReviewItemChange(item.target_fqn, "entity_name", event.target.value)}
                          placeholder="BI_SB_WUC"
                        />
                      </div>
                      <div className="prototype-step-field" style={{ margin: 0 }}>
                        <span className="slow-select-label">Ключевые поля</span>
                        <textarea
                          className="slow-entity-select"
                          value={item.key_attributes_text || ""}
                          onChange={(event) => handleReviewItemChange(item.target_fqn, "key_attributes_text", event.target.value)}
                          placeholder="warehouse_code, dt_report"
                          style={{ minHeight: 100, resize: "vertical" }}
                        />
                      </div>
                      <div className="prototype-step-field" style={{ margin: 0 }}>
                        <span className="slow-select-label">Ключевые поля ClickHouse</span>
                        <textarea
                          className="slow-entity-select"
                          value={item.clickhouse_keys_text || ""}
                          onChange={(event) => handleReviewItemChange(item.target_fqn, "clickhouse_keys_text", event.target.value)}
                          placeholder="warehouse_code, dt_report"
                          style={{ minHeight: 100, resize: "vertical" }}
                        />
                      </div>
                      <div className="prototype-step-field" style={{ margin: 0 }}>
                        <span className="slow-select-label">Параметры объекта</span>
                        <div className="prototype-chip-row" style={{ marginTop: 6 }}>
                          <label className="prototype-skip-toggle">
                            <input
                              type="checkbox"
                              checked={Boolean(item.stand_dev)}
                              onChange={(event) => handleReviewItemToggle(item.target_fqn, "stand_dev", event.target.checked)}
                            />
                            <span>DEV</span>
                          </label>
                          <label className="prototype-skip-toggle">
                            <input
                              type="checkbox"
                              checked={Boolean(item.stand_prod)}
                              onChange={(event) => handleReviewItemToggle(item.target_fqn, "stand_prod", event.target.checked)}
                            />
                            <span>PROD</span>
                          </label>
                          <label className="prototype-skip-toggle">
                            <input
                              type="checkbox"
                              checked={Boolean(item.copy_to_clickhouse)}
                              onChange={(event) => handleReviewItemToggle(item.target_fqn, "copy_to_clickhouse", event.target.checked)}
                            />
                            <span>Требуется ClickHouse</span>
                          </label>
                        </div>
                        {item.is_new ? (
                          <button
                            type="button"
                            className="btn btn-ghost"
                            onClick={() => handleRecheckNewTable(item.target_fqn)}
                            disabled={item.rechecking}
                            style={{ marginTop: 12 }}
                          >
                            {item.rechecking ? "Проверяем дубли..." : "Перепроверить новую таблицу"}
                          </button>
                        ) : null}
                      </div>
                    </div>

                    {(item.warnings || []).length ? (
                      <div className="card muted" style={{ marginTop: 14 }}>
                        {(item.warnings || []).map((warning) => <div key={warning}>• {warning}</div>)}
                      </div>
                    ) : null}

                    <div className="prototype-step-grid" style={{ marginTop: 14 }}>
                      <div className="cc-surface" style={{ margin: 0 }}>
                        <div className="section-title">Зависимости SQL</div>
                        {Array.isArray(item.dependencies) && item.dependencies.length > 0 ? (
                          <div style={{ display: "grid", gap: 8 }}>
                            {item.dependencies.map((dependency) => <div key={dependency} className="mono">{dependency}</div>)}
                          </div>
                        ) : <div className="muted">Зависимости не найдены.</div>}
                      </div>
                      <div className="cc-surface" style={{ margin: 0 }}>
                        <div className="section-title">Downstream-влияние</div>
                        {Array.isArray(item.impact?.tables) && item.impact.tables.length > 0 ? (
                          <div style={{ display: "grid", gap: 8 }}>
                            {item.impact.tables.map((row) => (
                              <div key={row.fqn}>
                                <div style={{ fontWeight: 700 }}>{row.fqn || "—"}</div>
                                <div className="muted">{row.entity_name || "—"}</div>
                              </div>
                            ))}
                          </div>
                        ) : <div className="muted">Downstream-объекты не найдены.</div>}
                      </div>
                    </div>

                    <div className="cc-surface" style={{ margin: "14px 0 0" }}>
                      <div className="prototype-chip-row" style={{ marginBottom: 14, alignItems: "center", justifyContent: "space-between" }}>
                        <div className="muted">
                          Источник YAML:
                          {" "}
                          <strong>{formatYamlSource(item.yaml_bundle)}</strong>
                        </div>
                        <button type="button" className="btn btn-ghost" onClick={() => handleCopyYaml(item.yaml_bundle?.yaml_content)}>
                          {yamlCopied ? "Скопировано" : "Скопировать YAML"}
                        </button>
                      </div>
                      <textarea
                        className="slow-entity-select mono"
                        readOnly
                        value={item.yaml_bundle?.yaml_content || ""}
                        style={{ minHeight: 220, resize: "vertical" }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
            {Array.isArray(result.validation_errors) && result.validation_errors.length > 0 ? (
              <div className="card muted" style={{ marginTop: 16 }}>
                {result.validation_errors.map((item) => <div key={item}>• {item}</div>)}
              </div>
            ) : null}
            {Array.isArray(result.validation_warnings) && result.validation_warnings.length > 0 ? (
              <div className="card muted" style={{ marginTop: 16 }}>
                {result.validation_warnings.map((item) => <div key={item}>• {item}</div>)}
              </div>
            ) : null}
          </section>

          <section className="cc-surface">
            <div className="section-title">Создание задачи</div>
            <div className="prototype-import-actions">
              <div className="muted">
                Одна задача будет создана на весь MR, а по каждому объекту в описание попадет отдельный блок со строками, дублями, стендами и YAML-вложением.
              </div>
              <button
                type="button"
                className="btn btn-primary"
                onClick={handleCreateIssue}
                disabled={creatingIssue || unresolvedItemsCount > 0 || !reviewItemsDraft.length}
              >
                {creatingIssue ? "Создаем задачу..." : "Создать задачу"}
              </button>
            </div>
            {unresolvedItemsCount > 0 ? (
              <div className="muted" style={{ marginTop: 12 }}>
                Сначала заполните обязательные поля у {unresolvedItemsCount} объектов.
              </div>
            ) : null}
            <div className="muted" style={{ marginTop: 12 }}>
              Общее время выполнения SQL:
              {" "}
              <strong>{totalExecutionSec > 0 ? formatDuration(totalExecutionSec) : "—"}</strong>
            </div>
          </section>
        </>
      ) : null}
    </div>
  );
}
