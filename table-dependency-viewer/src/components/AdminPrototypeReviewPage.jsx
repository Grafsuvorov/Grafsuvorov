import { useEffect, useState } from "react";
import { adminApi } from "../api/admin.js";
import { accountApi } from "../api/account.js";

function formatDuration(value) {
  const numeric = Number(value || 0);
  if (!Number.isFinite(numeric)) return "—";
  if (numeric >= 60) {
    return `${(numeric / 60).toFixed(numeric >= 600 ? 1 : 2)} мин`;
  }
  return `${numeric.toFixed(3)} сек`;
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

function parseTaskText(text) {
  const raw = String(text || "").trim();
  if (!raw) return {};
  const get = (pattern) => {
    const match = raw.match(pattern);
    return match ? String(match[1] || "").trim() : "";
  };
  const splitList = (value) =>
    String(value || "")
      .split(/[,;/\n]+/)
      .map((item) => item.trim())
      .filter(Boolean);

  const clickhouseKeysMatch = raw.match(/Ключевые поля.*?:\s*([\s\S]+?)(?:\n\s*\n|\nсвязана с|\nподзадача для|$)/i);
  const clickhouseKeys = clickhouseKeysMatch
    ? clickhouseKeysMatch[1]
        .split("\n")
        .map((line) => line.replace(/^[\s\-•]+/, "").trim())
        .filter(Boolean)
    : [];

  const relatedIssues = Array.from(new Set(raw.match(/\b[A-Z]+-\d+\b/g) || []));
  return {
    issue_summary: get(/^([^\n]+)/m),
    entity_name: get(/Сущность загрузки:\s*(.+)/i),
    target_table_fqn: get(/Название таблицы Greenplum:\s*(.+)/i),
    load_mode: get(/Способ обновления:\s*(.+)/i),
    dependent_views: splitList(get(/Зависимые представления:\s*(.+)/i)),
    copy_to_clickhouse: !/Копировать в ClickHouse:\s*.*не нужно/i.test(raw),
    linked_issues: relatedIssues,
    stand_dev: /Стенд:\s*.*DEV/i.test(raw),
    stand_prod: /Стенд:\s*.*PROD/i.test(raw),
    key_attributes: clickhouseKeys,
  };
}

export default function AdminPrototypeReviewPage() {
  const [mrInput, setMrInput] = useState("");
  const [taskText, setTaskText] = useState("");
  const [issueSummary, setIssueSummary] = useState("");
  const [targetTableFqn, setTargetTableFqn] = useState("");
  const [entityName, setEntityName] = useState("");
  const [loadMode, setLoadMode] = useState("Полный");
  const [standDev, setStandDev] = useState(true);
  const [standProd, setStandProd] = useState(true);
  const [copyToClickhouse, setCopyToClickhouse] = useState(true);
  const [dependentViewsText, setDependentViewsText] = useState("");
  const [linkedIssuesText, setLinkedIssuesText] = useState("");
  const [keyAttributesText, setKeyAttributesText] = useState("");
  const [createIssue, setCreateIssue] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [result, setResult] = useState(null);
  const [currentUser, setCurrentUser] = useState(null);

  useEffect(() => {
    accountApi.me().then(setCurrentUser).catch(() => {});
  }, []);

  const applyTaskTemplate = () => {
    const parsed = parseTaskText(taskText);
    if (parsed.issue_summary) setIssueSummary(parsed.issue_summary);
    if (parsed.target_table_fqn) setTargetTableFqn(parsed.target_table_fqn);
    if (parsed.entity_name) setEntityName(parsed.entity_name);
    if (parsed.load_mode) setLoadMode(parsed.load_mode);
    if (parsed.dependent_views?.length) setDependentViewsText(parsed.dependent_views.join(", "));
    if (parsed.linked_issues?.length) setLinkedIssuesText(parsed.linked_issues.join(", "));
    if (parsed.key_attributes?.length) setKeyAttributesText(parsed.key_attributes.join(", "));
    if (typeof parsed.copy_to_clickhouse === "boolean") setCopyToClickhouse(parsed.copy_to_clickhouse);
    setStandDev(parsed.stand_dev !== false);
    setStandProd(parsed.stand_prod !== false);
  };

  const handleRun = async () => {
    const trimmed = String(mrInput || "").trim();
    if (!trimmed || loading) return;
    setLoading(true);
    setError(null);
    setResult(null);
    try {
      const payload = await adminApi.prototypeReviewRun({
        mr_input: trimmed,
        task_text: taskText,
        issue_summary: issueSummary.trim(),
        target_table_fqn: targetTableFqn.trim(),
        entity_name: entityName.trim(),
        load_mode: loadMode.trim(),
        stand_dev: standDev,
        stand_prod: standProd,
        copy_to_clickhouse: copyToClickhouse,
        dependent_views: dependentViewsText
          .split(",")
          .map((item) => item.trim())
          .filter(Boolean),
        linked_issues: linkedIssuesText
          .split(",")
          .map((item) => item.trim())
          .filter(Boolean),
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
            <span className="slow-select-label">Финальная таблица</span>
            <input
              className="slow-entity-select"
              value={targetTableFqn}
              onChange={(event) => setTargetTableFqn(event.target.value)}
              placeholder="dm.sales_foreign_metal_stock_balance_analysis"
            />
          </div>
          <div className="slow-select-group" style={{ minWidth: 300, flex: "1 1 300px" }}>
            <span className="slow-select-label">Сущность</span>
            <input
              className="slow-entity-select"
              value={entityName}
              onChange={(event) => setEntityName(event.target.value)}
              placeholder="BI_SB_WUC"
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
          <div className="slow-select-group" style={{ minWidth: 280, flex: "1 1 280px" }}>
            <span className="slow-select-label">Summary задачи</span>
            <input
              className="slow-entity-select"
              value={issueSummary}
              onChange={(event) => setIssueSummary(event.target.value)}
              placeholder="(ДМЛ) Настроить обновление витрины ..."
            />
          </div>
          <div className="slow-select-group" style={{ minWidth: 220 }}>
            <span className="slow-select-label">Режим обновления</span>
            <input
              className="slow-entity-select"
              value={loadMode}
              onChange={(event) => setLoadMode(event.target.value)}
              placeholder="Полный"
            />
          </div>
          <label className="slow-select-group" style={{ minWidth: 220 }}>
            <span className="slow-select-label">Создание задачи</span>
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
          <label className="slow-select-group" style={{ minWidth: 180 }}>
            <span className="slow-select-label">Стенды</span>
            <span className="muted">
              <input type="checkbox" checked={standDev} onChange={(event) => setStandDev(event.target.checked)} style={{ marginRight: 8 }} />
              DEV
            </span>
            <span className="muted" style={{ marginTop: 6 }}>
              <input type="checkbox" checked={standProd} onChange={(event) => setStandProd(event.target.checked)} style={{ marginRight: 8 }} />
              PROD
            </span>
          </label>
          <label className="slow-select-group" style={{ minWidth: 220 }}>
            <span className="slow-select-label">ClickHouse</span>
            <span className="muted">
              <input
                type="checkbox"
                checked={copyToClickhouse}
                onChange={(event) => setCopyToClickhouse(event.target.checked)}
                style={{ marginRight: 8 }}
              />
              Нужна загрузка в CH
            </span>
          </label>
          <button className="btn btn-primary" onClick={handleRun} disabled={loading || !mrInput.trim()}>
            {loading ? "Выполняем..." : "Запустить review"}
          </button>
        </div>
        <div className="slow-controls-row slow-entity-controls" style={{ alignItems: "stretch", flexWrap: "wrap", marginTop: 12 }}>
          <div className="slow-select-group" style={{ minWidth: 520, flex: "2 1 520px" }}>
            <span className="slow-select-label">Текст задачи / описание карточки</span>
            <textarea
              className="slow-entity-select"
              value={taskText}
              onChange={(event) => setTaskText(event.target.value)}
              placeholder="Вставьте описание задачи целиком"
              style={{ minHeight: 180, resize: "vertical" }}
            />
          </div>
          <div className="slow-select-group" style={{ minWidth: 280, flex: "1 1 280px" }}>
            <span className="slow-select-label">Зависимые view</span>
            <textarea
              className="slow-entity-select"
              value={dependentViewsText}
              onChange={(event) => setDependentViewsText(event.target.value)}
              placeholder="dm_view.sales_..."
              style={{ minHeight: 84, resize: "vertical" }}
            />
            <span className="slow-select-label" style={{ marginTop: 12 }}>Связанные тикеты</span>
            <textarea
              className="slow-entity-select"
              value={linkedIssuesText}
              onChange={(event) => setLinkedIssuesText(event.target.value)}
              placeholder="DWH-15089, DWH-15539"
              style={{ minHeight: 84, resize: "vertical" }}
            />
            <button type="button" className="btn btn-ghost" onClick={applyTaskTemplate} style={{ marginTop: 12 }}>
              Заполнить поля из текста
            </button>
          </div>
        </div>
        <div className="muted" style={{ marginTop: 8 }}>
          Задача в YouTrack будет создана сервисным токеном. Инициатором в описании будет указан
          {" "}
          <span className="mono">{currentUser?.username || currentUser?.email || "текущий пользователь"}</span>.
        </div>
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
              <div className="label">Финальная витрина</div>
              <div className="value mono" style={{ fontSize: "1rem", overflowWrap: "anywhere", wordBreak: "break-word" }}>
                {result.final_target || "—"}
              </div>
              <div className="hint">{result.resolved_entity_name || "Сущность не определена"}</div>
            </div>
            <div className="slow-summary-card">
              <div className="label">SQL файлов</div>
              <div className="value">{(result.files || []).length}</div>
            </div>
            <div className="slow-summary-card">
              <div className="label">Потенциальное влияние</div>
              <div className="value">{result.impact?.count ?? 0}</div>
              <div className="hint">{result.impact?.truncated ? "Показан неполный список downstream-таблиц" : "Downstream-таблицы из графа меты"}</div>
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
            <div className="section-title">Подготовка DEV</div>
            <div className="card muted">
              <div><strong>{formatStatus(result.preparation?.status === "ok" ? "ok" : result.preparation?.status === "warning" ? "warning" : "error")}</strong></div>
              <div>{result.preparation?.message || "—"}</div>
              {result.preparation?.target_fqn ? <div className="mono" style={{ marginTop: 8 }}>{result.preparation.target_fqn}</div> : null}
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
            {Array.isArray(result.validation_warnings) && result.validation_warnings.length > 0 ? (
              <div className="card muted" style={{ marginTop: 16 }}>
                {result.validation_warnings.map((item) => (
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
                    <th>Глубина</th>
                  </tr>
                </thead>
                <tbody>
                  {(result.impact?.tables || []).length ? (
                    result.impact.tables.map((item) => (
                      <tr key={item.fqn}>
                        <td className="mono" style={{ overflowWrap: "anywhere", wordBreak: "break-word" }}>{item.fqn}</td>
                        <td>{item.entity_name || "—"}</td>
                        <td>{item.depth ?? "—"}</td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={3}>Downstream-зависимости по графу меты не найдены.</td>
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
