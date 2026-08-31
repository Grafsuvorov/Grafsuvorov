import { useEffect, useMemo, useState } from "react";
import { adminApi } from "../api/admin.js";
import { accountApi } from "../api/account.js";

const DEFAULT_FORM = {
  summary: "",
  git_reference: "",
  script_runtime: "",
  release_date: "",
  direction: "",
  business_key_changed: false,
};

const DIRECTION_OPTIONS = [
  "Финансы",
  "Сбыт",
  "Управление запасами",
  "Транспортировка",
  "Производство",
  "ТОРО",
  "НСИ",
  "TECH",
];

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

function compactList(value, fallback = "—") {
  const items = splitItems(value);
  return items.length ? items.join(", ") : fallback;
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
  pushLine("Ссылка на гит", form.git_reference);
  pushLine("Время работы скрипта", form.script_runtime);
  pushLine("Дата релиза", form.release_date);
  pushLine("Направление", form.direction);
  pushLine("Меняется бизнес-ключ", form.business_key_changed ? "Да" : "Нет");
  if (splitItems(linkedIssues).length) {
    lines.push(`Связанные тикеты: ${splitItems(linkedIssues).join(", ")}`);
  }
  return lines.join("\n");
}

function formatReleaseDate(value) {
  const text = String(value || "").trim();
  if (!text) return "—";
  const date = new Date(`${text}T00:00:00`);
  if (Number.isNaN(date.getTime())) return text;
  const month = new Intl.DateTimeFormat("ru-RU", { month: "short" }).format(date).replace(".", "");
  return `${date.getDate()}. ${month}. ${date.getFullYear()}`;
}

function buildDraftItem(item) {
  const keyAttributesText = joinItems(item.key_attributes || []);
  return {
    ...item,
    entity_name: item.entity_name || "",
    key_attributes_text: keyAttributesText,
    clickhouse_keys_text: joinItems(item.clickhouse_keys || []),
    stand_dev: item.stand_dev !== false,
    stand_prod: item.stand_prod !== false,
    copy_to_clickhouse: Boolean(item.copy_to_clickhouse),
    checks: item.checks || { row_count: null, duplicate_groups: null },
    rechecking: false,
    last_checked_key_attributes_text: keyAttributesText,
    checks_stale: false,
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
  }, [result?.review_items]);

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
      !String(item.entity_name || "").trim()
      || (String(item.object_type || "TABLE").toUpperCase() === "TABLE" && !splitItems(item.key_attributes_text).length)
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

  const handleReviewItemChange = (itemId, field, value) => {
    setReviewItemsDraft((prev) => prev.map((item) => {
      if (item.item_id !== itemId) return item;
      if (field === "key_attributes_text") {
        const nextValue = String(value || "");
        return {
          ...item,
          [field]: nextValue,
          checks_stale: joinItems(splitItems(nextValue)) !== joinItems(splitItems(item.last_checked_key_attributes_text || "")),
        };
      }
      return { ...item, [field]: value };
    }));
  };

  const handleReviewItemToggle = (itemId, field, checked) => {
    setReviewItemsDraft((prev) => prev.map((item) => (
      item.item_id !== itemId
        ? item
        : {
            ...item,
            [field]: checked,
            ...(field === "copy_to_clickhouse" && !checked ? { clickhouse_keys_text: "" } : {}),
          }
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
        linked_issues: splitItems(linkedIssues),
        release_date: form.release_date || "",
        direction: form.direction || "",
        business_key_changed: Boolean(form.business_key_changed),
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
      const totalSec = Array.isArray(payload?.execution)
        ? payload.execution.reduce((acc, item) => acc + Number(item?.duration_sec || 0), 0)
        : 0;
      setForm((prev) => ({
        ...prev,
        git_reference: prev.git_reference || trimmedMr,
        script_runtime: totalSec >= 60 ? `${(totalSec / 60).toFixed(2)} мин` : totalSec > 0 ? `${totalSec.toFixed(3)} сек` : prev.script_runtime,
        release_date: prev.release_date || String(payload?.task_context?.release_date || "").trim(),
        direction: prev.direction || String(payload?.task_context?.direction || "").trim(),
        business_key_changed: typeof payload?.task_context?.business_key_changed === "boolean"
          ? payload.task_context.business_key_changed
          : prev.business_key_changed,
      }));
      if (!String(linkedIssues || "").trim() && Array.isArray(payload?.task_context?.linked_issues)) {
        setLinkedIssues(payload.task_context.linked_issues.join(", "));
      }
    } catch (err) {
      setError(err?.message || "Не удалось выполнить prototype review");
    } finally {
      setLoading(false);
    }
  };

  const handleRecheckTable = async (itemId) => {
    const current = reviewItemsDraft.find((item) => item.item_id === itemId);
    if (!current || current.rechecking) return;
    const keyAttributes = splitItems(current.key_attributes_text);
    if (!keyAttributes.length) {
      setError("Сначала укажите ключевые поля для проверки дублей");
      return;
    }
    setError(null);
    setReviewItemsDraft((prev) => prev.map((item) => (
      item.item_id !== itemId ? item : { ...item, rechecking: true }
    )));
    try {
      const payload = await adminApi.prototypeReviewCheckTable({
        mr_input: String(mrInput || "").trim(),
        item_id: current.item_id,
        target_fqn: current.target_fqn,
        entity_name: String(current.entity_name || "").trim(),
        key_attributes: keyAttributes,
      });
      setReviewItemsDraft((prev) => prev.map((item) => (
        item.item_id !== itemId
          ? item
          : {
              ...item,
              ...buildDraftItem(payload?.item || item),
              path: item.path,
              object_type: item.object_type,
              preparation: item.preparation,
              dependencies: Array.isArray(payload?.item?.dependencies) && payload.item.dependencies.length
                ? payload.item.dependencies
                : item.dependencies,
              duration_sec: item.duration_sec,
              stand_dev: item.stand_dev,
              stand_prod: item.stand_prod,
              copy_to_clickhouse: item.copy_to_clickhouse,
              rechecking: false,
            }
      )));
    } catch (err) {
      setError(err?.message || "Не удалось перепроверить таблицу");
      setReviewItemsDraft((prev) => prev.map((item) => (
        item.item_id !== itemId ? item : { ...item, rechecking: false }
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
        linked_issues: splitItems(linkedIssues),
        release_date: form.release_date || "",
        direction: form.direction || "",
        business_key_changed: Boolean(form.business_key_changed),
        review_items: reviewItemsDraft.map((item) => ({
          item_id: item.item_id,
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
      setResult((prev) => (
        prev
          ? {
              ...prev,
              issue: payload?.issue || null,
              meta_branch: payload?.meta_branch || null,
              meta_files: payload?.meta_files || [],
              meta_error: payload?.meta_error || null,
              meta_mr: payload?.meta_mr || null,
              meta_mr_error: payload?.meta_mr_error || null,
            }
          : prev
      ));
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
            <span className="slow-select-label">MR / DIFF URL или IID</span>
            <input
              className="slow-entity-select"
              value={mrInput}
              onChange={(event) => setMrInput(event.target.value)}
              placeholder="https://gitlab.../-/merge_requests/123 или .../diffs"
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
          <div className="muted">После запуска появятся все целевые объекты MR или его diff и их статусы.</div>
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
                  placeholder="Настроить обновление витрины ..."
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
                const needsKeys = String(item.object_type || "TABLE").toUpperCase() === "TABLE" && !splitItems(item.key_attributes_text).length;
                const needsAttention = Boolean(needsEntity || needsKeys);
                return (
                  <div
                    key={item.item_id || `${item.target_fqn}:${item.object_type || "TABLE"}`}
                    className="cc-surface"
                    style={{
                      margin: 0,
                      border: needsAttention ? "1px solid rgba(214, 86, 46, 0.45)" : undefined,
                      boxShadow: needsAttention ? "0 0 0 1px rgba(214, 86, 46, 0.08) inset" : undefined,
                    }}
                  >
                    <div className="prototype-object-header">
                      <div>
                        <div className="prototype-object-title mono">{item.target_fqn || "—"}</div>
                        <div className="prototype-object-subtitle">{item.path || "—"}</div>
                      </div>
                      <div className="prototype-chip-row">
                        <span className="prototype-badge">{item.object_type || "TABLE"}</span>
                        {item.is_new ? <span className="prototype-badge">Новый объект</span> : null}
                        {needsAttention ? <span className="prototype-badge warning">Нужно заполнить</span> : null}
                      </div>
                    </div>

                    <div className="prototype-object-stats">
                      <div className="prototype-stat-card">
                        <div className="prototype-stat-label">Сущность</div>
                        <div className="prototype-stat-value">{item.entity_name || "—"}</div>
                      </div>
                      <div className="prototype-stat-card">
                        <div className="prototype-stat-label">Ключевые поля</div>
                        <div className="prototype-stat-value">{compactList(item.key_attributes_text)}</div>
                      </div>
                      <div className="prototype-stat-card">
                        <div className="prototype-stat-label">Количество строк</div>
                        <div className="prototype-stat-value">
                          {item.checks?.row_count !== undefined && item.checks?.row_count !== null ? formatCount(item.checks.row_count) : "—"}
                        </div>
                      </div>
                      <div className="prototype-stat-card">
                        <div className="prototype-stat-label">Кол-во дублей</div>
                        <div className="prototype-stat-value">
                          {item.checks?.duplicate_groups !== undefined && item.checks?.duplicate_groups !== null ? formatCount(item.checks.duplicate_groups) : "—"}
                        </div>
                      </div>
                      <div className="prototype-stat-card">
                        <div className="prototype-stat-label">Время SQL</div>
                        <div className="prototype-stat-value">{item.duration_sec ? formatDuration(item.duration_sec) : "—"}</div>
                      </div>
                      <div className="prototype-stat-card">
                        <div className="prototype-stat-label">YAML</div>
                        <div className="prototype-stat-value">{formatYamlSource(item.yaml_bundle)}</div>
                      </div>
                    </div>

                    <div className="prototype-object-layout">
                      <div className="prototype-object-main">
                        <div className="prototype-step-field" style={{ margin: 0 }}>
                        <span className="slow-select-label">Сущность загрузки</span>
                        <input
                          className="slow-entity-select"
                          value={item.entity_name || ""}
                          onChange={(event) => handleReviewItemChange(item.item_id, "entity_name", event.target.value)}
                          placeholder="BI_SB_WUC"
                        />
                        </div>
                        <div className="prototype-step-field" style={{ margin: 0 }}>
                        <span className="slow-select-label">Ключевые поля</span>
                        <textarea
                          className="slow-entity-select"
                          value={item.key_attributes_text || ""}
                          onChange={(event) => handleReviewItemChange(item.item_id, "key_attributes_text", event.target.value)}
                          placeholder="warehouse_code, dt_report"
                          style={{ minHeight: 100, resize: "vertical" }}
                        />
                        </div>
                        {item.copy_to_clickhouse ? (
                          <div className="prototype-step-field" style={{ margin: 0 }}>
                            <span className="slow-select-label">Ключевые поля ClickHouse</span>
                            <textarea
                              className="slow-entity-select"
                              value={item.clickhouse_keys_text || ""}
                              onChange={(event) => handleReviewItemChange(item.item_id, "clickhouse_keys_text", event.target.value)}
                              placeholder="warehouse_code, dt_report"
                              style={{ minHeight: 100, resize: "vertical" }}
                            />
                          </div>
                        ) : null}
                      </div>
                      <div className="prototype-object-side">
                        <div className="prototype-control-card">
                          <div className="prototype-control-title">Параметры объекта</div>
                          <div className="prototype-control-list">
                            <label className="prototype-toggle-card">
                            <input
                              type="checkbox"
                              checked={Boolean(item.stand_dev)}
                              onChange={(event) => handleReviewItemToggle(item.item_id, "stand_dev", event.target.checked)}
                            />
                            <span>DEV</span>
                          </label>
                            <label className="prototype-toggle-card">
                            <input
                              type="checkbox"
                              checked={Boolean(item.stand_prod)}
                              onChange={(event) => handleReviewItemToggle(item.item_id, "stand_prod", event.target.checked)}
                            />
                            <span>PROD</span>
                          </label>
                            <label className="prototype-toggle-card wide">
                            <input
                              type="checkbox"
                              checked={Boolean(item.copy_to_clickhouse)}
                              onChange={(event) => handleReviewItemToggle(item.item_id, "copy_to_clickhouse", event.target.checked)}
                            />
                            <span>Требуется ClickHouse</span>
                          </label>
                          </div>
                          {String(item.object_type || "TABLE").toUpperCase() === "TABLE" ? (
                            <button
                              type="button"
                              className="btn btn-ghost"
                              onClick={() => handleRecheckTable(item.item_id)}
                              disabled={item.rechecking || !splitItems(item.key_attributes_text).length}
                              style={{ marginTop: 12 }}
                            >
                              {item.rechecking ? "Проверяем дубли..." : item.checks_stale ? "Перепроверить по новым ключам" : "Проверить дубль/строки"}
                            </button>
                          ) : null}
                        </div>

                        {(item.warnings || []).length ? (
                          <div className="prototype-warning-card">
                            <div className="prototype-control-title">Что требует внимания</div>
                            {(item.warnings || []).map((warning) => <div key={warning} className="prototype-warning-item">{warning}</div>)}
                          </div>
                        ) : null}
                      </div>
                    </div>

                    <div className="prototype-step-grid" style={{ marginTop: 14 }}>
                      <div className="cc-surface prototype-detail-card" style={{ margin: 0 }}>
                        <div className="section-title">Зависимости SQL</div>
                        {Array.isArray(item.dependencies) && item.dependencies.length > 0 ? (
                          <div className="prototype-detail-list">
                            {item.dependencies.map((dependency) => <div key={dependency} className="mono prototype-detail-item">{dependency}</div>)}
                          </div>
                        ) : <div className="muted">Зависимости не найдены.</div>}
                      </div>
                      <div className="cc-surface prototype-detail-card" style={{ margin: 0 }}>
                        <div className="section-title">Downstream-влияние</div>
                        {Array.isArray(item.impact?.tables) && item.impact.tables.length > 0 ? (
                          <div className="prototype-detail-list">
                            {item.impact.tables.map((row) => (
                              <div key={row.fqn} className="prototype-impact-item">
                                <div className="prototype-impact-title">{row.fqn || "—"}</div>
                                <div className="muted">{row.entity_name || "—"}</div>
                              </div>
                            ))}
                          </div>
                        ) : <div className="muted">Downstream-объекты не найдены.</div>}
                      </div>
                    </div>

                    <div className="cc-surface prototype-yaml-card" style={{ margin: "14px 0 0" }}>
                      <div className="prototype-chip-row" style={{ marginBottom: 14, alignItems: "center", justifyContent: "space-between" }}>
                        <div className="muted">
                          YAML draft
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
            <div className="prototype-top-grid" style={{ marginBottom: 16 }}>
              <div className="prototype-step-field" style={{ margin: 0 }}>
                <span className="slow-select-label">Дата релиза</span>
                <input
                  className="slow-entity-select"
                  type="date"
                  value={form.release_date || ""}
                  onChange={(event) => handleFieldChange("release_date", event.target.value)}
                />
                <div className="muted" style={{ marginTop: 8 }}>
                  {formatReleaseDate(form.release_date)}
                </div>
              </div>
              <div className="prototype-step-field" style={{ margin: 0 }}>
                <span className="slow-select-label">Направление</span>
                <select
                  className="slow-entity-select"
                  value={form.direction || ""}
                  onChange={(event) => handleFieldChange("direction", event.target.value)}
                >
                  <option value="">Не выбрано</option>
                  {DIRECTION_OPTIONS.map((option) => (
                    <option key={option} value={option}>{option}</option>
                  ))}
                </select>
              </div>
              <label className="prototype-toggle-card wide" style={{ alignSelf: "end", minHeight: 44 }}>
                <input
                  type="checkbox"
                  checked={Boolean(form.business_key_changed)}
                  onChange={(event) => handleFieldChange("business_key_changed", event.target.checked)}
                />
                <span>Меняется бизнес-ключ</span>
              </label>
            </div>
            <div className="prototype-import-actions">
              <div className="muted">
                Одна задача будет создана на весь MR, а YAML по GP-объектам будет записан в инженерный репозиторий в ветку задачи.
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
            {result?.meta_branch ? (
              <div className="muted" style={{ marginTop: 12 }}>
                Ветка инженеров:
                {" "}
                <span className="mono">{result.meta_branch}</span>
              </div>
            ) : null}
            {Array.isArray(result?.meta_files) && result.meta_files.length > 0 ? (
              <div className="muted" style={{ marginTop: 12 }}>
                YAML обновлены:
                {" "}
                {result.meta_files.map((item) => item.file_path).join(", ")}
              </div>
            ) : null}
            {result?.meta_mr?.mr_url ? (
              <div className="muted" style={{ marginTop: 12 }}>
                Инженерный MR в main:
                {" "}
                <a href={result.meta_mr.mr_url} target="_blank" rel="noreferrer">{result.meta_mr.mr_url}</a>
              </div>
            ) : null}
            {result?.meta_error ? (
              <div className="page-error" style={{ marginTop: 12 }}>
                YAML в инженерный репозиторий не записан: {result.meta_error}
              </div>
            ) : null}
            {result?.meta_mr_error ? (
              <div className="page-error" style={{ marginTop: 12 }}>
                MR в main не создан: {result.meta_mr_error}
              </div>
            ) : null}
          </section>
        </>
      ) : null}
    </div>
  );
}
