import { useState } from "react";
import { adminApi } from "../api/admin.js";

function formatDuration(value) {
  const numeric = Number(value || 0);
  if (!Number.isFinite(numeric)) return "—";
  if (numeric >= 60) {
    return `${(numeric / 60).toFixed(numeric >= 600 ? 1 : 2)} мин`;
  }
  return `${numeric.toFixed(3)} сек`;
}

function formatStatus(status) {
  return status === "passed" ? "PASS" : "FAIL";
}

function formatIssueStatus(issue) {
  if (issue?.status === "created") {
    return issue?.link ? <a href={issue.link} target="_blank" rel="noreferrer">{issue.issue_id}</a> : issue.issue_id;
  }
  if (issue?.status === "not_configured") return "YTrack не настроен";
  return issue?.status || "skipped";
}

export default function AdminPrototypeReviewPage() {
  const [mrInput, setMrInput] = useState("");
  const [keyAttributesText, setKeyAttributesText] = useState("");
  const [createIssue, setCreateIssue] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [result, setResult] = useState(null);

  const handleRun = async () => {
    const trimmed = String(mrInput || "").trim();
    if (!trimmed || loading) return;
    setLoading(true);
    setError(null);
    setResult(null);
    try {
      const payload = await adminApi.prototypeReviewRun({
        mr_input: trimmed,
        key_attributes: keyAttributesText
          .split(",")
          .map((item) => item.trim())
          .filter(Boolean),
        create_issue: createIssue,
      });
      setResult(payload || null);
    } catch (err) {
      setError(err?.message || "Не удалось выполнить prototype review");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container cc-page slow-page">
      <section className="cc-header-zone">
        <h1>Prototype Review</h1>
        <div className="cc-subtitle">
          Берет SQL из merge request аналитика, выполняет в DEV, проверяет финальную витрину и при успехе создает задачу в YTrack.
        </div>
      </section>

      <section className="slow-controls">
        <div className="section-title">Запуск</div>
        <div className="slow-controls-row slow-entity-controls" style={{ alignItems: "flex-end", flexWrap: "wrap" }}>
          <div className="slow-select-group" style={{ minWidth: 420, flex: "1 1 420px" }}>
            <span className="slow-select-label">MR URL или IID</span>
            <input
              className="slow-entity-select"
              value={mrInput}
              onChange={(event) => setMrInput(event.target.value)}
              placeholder="https://gitlab.../-/merge_requests/123"
            />
          </div>
          <div className="slow-select-group" style={{ minWidth: 340, flex: "1 1 340px" }}>
            <span className="slow-select-label">Override key attributes</span>
            <input
              className="slow-entity-select"
              value={keyAttributesText}
              onChange={(event) => setKeyAttributesText(event.target.value)}
              placeholder="id, load_dt"
            />
          </div>
          <label className="slow-select-group" style={{ minWidth: 220 }}>
            <span className="slow-select-label">YTrack</span>
            <span className="muted">
              <input
                type="checkbox"
                checked={createIssue}
                onChange={(event) => setCreateIssue(event.target.checked)}
                style={{ marginRight: 8 }}
              />
              Создать задачу при success
            </span>
          </label>
          <button className="btn btn-primary" onClick={handleRun} disabled={loading || !mrInput.trim()}>
            {loading ? "Выполняем..." : "Запустить review"}
          </button>
        </div>
      </section>

      {error ? <div className="page-error">{error}</div> : null}

      {result ? (
        <>
          <section className="slow-summary">
            <div className={`slow-summary-card ${result.status === "passed" ? "" : "danger"}`}>
              <div className="label">Статус</div>
              <div className="value">{formatStatus(result.status)}</div>
              <div className="hint">{result.status_reason || "—"}</div>
            </div>
            <div className="slow-summary-card">
              <div className="label">Финальная витрина</div>
              <div className="value mono" style={{ fontSize: "1rem", overflowWrap: "anywhere", wordBreak: "break-word" }}>
                {result.final_target || "—"}
              </div>
            </div>
            <div className="slow-summary-card">
              <div className="label">SQL файлов</div>
              <div className="value">{(result.files || []).length}</div>
            </div>
            <div className="slow-summary-card">
              <div className="label">Downstream impact</div>
              <div className="value">{result.impact?.count ?? 0}</div>
              <div className="hint">{result.impact?.truncated ? "Показан неполный список" : "Потенциально затронутые downstream-таблицы"}</div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Что проверяется</div>
            <div className="card muted">
              <div>`PASS` означает: финальная витрина определена по последнему `INSERT`/`CREATE TABLE`, SQL из MR выполнился в DEV, и по выбранному ключу не найдено дублей.</div>
              <div style={{ marginTop: 8 }}>`Проверки` показывают ключ, `row count` после выполнения и количество duplicate groups по этому ключу.</div>
              <div style={{ marginTop: 8 }}>`SQL statements` — это число SQL-операторов в файле после разбиения по `;`, а не число строк.</div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">MR</div>
            <div className="card muted">
              <div><strong>{result.mr?.title || "—"}</strong></div>
              <div>Проект: {result.mr?.project || "—"}</div>
              <div>Ветка: {result.mr?.source_branch || "—"} → {result.mr?.target_branch || "—"}</div>
              <div>Автор: {result.mr?.author || "—"}</div>
              {result.mr?.web_url ? <div><a href={result.mr.web_url} target="_blank" rel="noreferrer">{result.mr.web_url}</a></div> : null}
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Проверки</div>
            <div className="table-wrapper">
              <table className="incidents-table slow-table">
                <thead>
                  <tr>
                    <th>Key attributes</th>
                    <th>Row count</th>
                    <th>Duplicate groups</th>
                    <th>YTrack</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>{(result.key_attributes || []).length ? result.key_attributes.join(", ") : "—"}</td>
                    <td>{result.checks?.row_count ?? "—"}</td>
                    <td>{result.checks?.duplicate_groups ?? "—"}</td>
                    <td>{formatIssueStatus(result.issue)}</td>
                  </tr>
                </tbody>
              </table>
            </div>
            {Array.isArray(result.validation_errors) && result.validation_errors.length > 0 ? (
              <div className="card muted" style={{ marginTop: 16 }}>
                {result.validation_errors.map((item) => (
                  <div key={item}>• {item}</div>
                ))}
              </div>
            ) : null}
          </section>

          <section className="cc-surface">
            <div className="section-title">Выполнение SQL</div>
            <div className="table-wrapper">
              <table className="incidents-table slow-table">
                <thead>
                  <tr>
                    <th>Файл</th>
                    <th>SQL statements</th>
                    <th>Статус</th>
                    <th>Время</th>
                  </tr>
                </thead>
                <tbody>
                  {(result.files || []).map((item) => {
                    const execRow = (result.execution || []).find((entry) => entry.path === item.path) || {};
                    return (
                      <tr key={item.path}>
                        <td className="mono" style={{ overflowWrap: "anywhere", wordBreak: "break-word" }}>{item.path}</td>
                        <td>{item.statements_count ?? "—"}</td>
                        <td>{execRow.status || "—"}</td>
                        <td>{execRow.duration_sec !== undefined ? formatDuration(execRow.duration_sec) : "—"}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">SQL зависимости</div>
            <div className="card muted">
              {(result.dependencies || []).length ? (
                result.dependencies.map((item) => (
                  <div key={item} className="mono" style={{ overflowWrap: "anywhere", wordBreak: "break-word" }}>
                    {item}
                  </div>
                ))
              ) : (
                "Не нашли боевых schema.table зависимостей в SQL."
              )}
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Потенциальное влияние</div>
            <div className="table-wrapper">
              <table className="incidents-table slow-table">
                <thead>
                  <tr>
                    <th>Таблица</th>
                    <th>Сущность</th>
                  </tr>
                </thead>
                <tbody>
                  {(result.impact?.tables || []).length ? (
                    result.impact.tables.map((item) => (
                      <tr key={item.fqn}>
                        <td className="mono" style={{ overflowWrap: "anywhere", wordBreak: "break-word" }}>{item.fqn}</td>
                        <td>{item.entity_name || "—"}</td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={2}>Downstream-зависимости по графу меты не найдены.</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </section>
        </>
      ) : null}
    </div>
  );
}
