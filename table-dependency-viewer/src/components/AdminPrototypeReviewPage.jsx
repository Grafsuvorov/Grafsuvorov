import { useEffect, useMemo, useState } from "react";
import { adminApi } from "../api/admin.js";
import { accountApi } from "../api/account.js";
import { apiClient } from "../api/client.js";

const DEFAULT_FORM = {
  summary: "",
  subject_area: "",
  entity_name: "",
  git_reference: "",
  source_name: "",
  source_schema: "",
  source_table: "",
  source_key: "",
  source_access: "",
  target_table_fqn: "",
  load_mode: "",
  load_condition: "",
  script_runtime: "",
  business_key: "",
  dependent_views: "",
  clickhouse_keys: "",
  pseudo_increment_steps: "",
};

const DEFAULT_SKIPS = {
  source_name: false,
  source_schema: false,
  source_table: false,
  source_key: false,
  source_access: false,
  load_condition: false,
  script_runtime: false,
  business_key: false,
  dependent_views: false,
  clickhouse_keys: false,
  pseudo_increment_steps: false,
};

const STEP_BLOCKS = [
  {
    title: "Шаг 1. Карточка",
    description: "Вставьте пример карточки или шаблон. Поля ниже заполнятся автоматически, их можно поправить.",
    fields: [],
  },
  {
    title: "Шаг 2. Источник",
    description: "Данные об источнике и доступе. Если данных нет, поле можно пропустить.",
    fields: ["subject_area", "source_name", "source_schema", "source_table", "source_key", "source_access"],
    stgOnly: true,
  },
  {
    title: "Шаг 3. Таргет",
    description: "Основные параметры загрузки целевой таблицы и MR.",
    fields: ["entity_name", "target_table_fqn", "git_reference", "load_mode", "load_condition"],
  },
  {
    title: "Шаг 4. Проверки",
    description: "Что использовать для duplicate-check и что ещё затрагивается.",
    fields: ["business_key", "clickhouse_keys", "dependent_views", "pseudo_increment_steps"],
  },
  {
    title: "Шаг 5. Релиз",
    description: "Контекст релиза и документации. Нужен для однотипного создания задач.",
    fields: ["summary", "script_runtime"],
  },
];

const FIELD_META = {
  summary: { label: "Название задачи", placeholder: "(ДМЛ) Настроить обновление витрины ...", kind: "text" },
  subject_area: { label: "Предметная область", placeholder: "SD", kind: "text" },
  entity_name: { label: "Сущность загрузки", placeholder: "BI_SB_WUC", kind: "text" },
  git_reference: { label: "Ссылка на гит / шаблон", placeholder: "https://gitlab... / ссылка на шаблон", kind: "textarea" },
  source_name: { label: "Источник", placeholder: "SAP / Oracle / CSV / ...", kind: "text", optional: true },
  source_schema: { label: "Название схемы на источнике", placeholder: "public", kind: "text", optional: true },
  source_table: { label: "Название таблицы на источнике", placeholder: "source_table", kind: "text", optional: true },
  source_key: { label: "Ключ на источнике", placeholder: "id, dt", kind: "textarea", optional: true },
  source_access: { label: "Доступ к таблице на источнике", placeholder: "есть / нет / запросить", kind: "textarea", optional: true },
  target_table_fqn: { label: "Название таблицы в таргете", placeholder: "dm.sales_foreign_metal_stock_balance_analysis", kind: "text" },
  load_mode: { label: "Способ обновления", placeholder: "Полный / Псевдоинкрементальный", kind: "text" },
  load_condition: { label: "Условие при загрузке", placeholder: "where dt >= current_date - 7", kind: "textarea", optional: true },
  script_runtime: { label: "Время работы скрипта", placeholder: "5-10 мин", kind: "text", optional: true },
  business_key: { label: "Бизнес ключ", placeholder: "warehouse_code, dt_report", kind: "textarea", optional: true },
  dependent_views: { label: "Зависимые представления", placeholder: "dm_view.sales_...", kind: "textarea", optional: true },
  clickhouse_keys: { label: "Ключевые поля для загрузки в ClickHouse", placeholder: "warehouse_code, dt_report", kind: "textarea", optional: true },
  pseudo_increment_steps: { label: "Последовательность действий при (псевдо)инкременте", placeholder: "1. ...", kind: "textarea", optional: true },
};

function splitItems(value) {
  return String(value || "")
    .split(/[\n,;]+/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function joinItems(value) {
  return Array.isArray(value) ? value.join(", ") : String(value || "");
}

function isViewLikeFqn(value, currentTableFqn = "") {
  const normalized = String(value || "").trim().toLowerCase();
  if (!normalized || !normalized.includes(".")) return false;
  if (normalized === String(currentTableFqn || "").trim().toLowerCase()) return false;
  const [schemaName] = normalized.split(".", 1);
  return schemaName.includes("view");
}

function parseTaskText(text) {
  const raw = String(text || "").trim();
  if (!raw) return {};
  const get = (pattern) => {
    const match = raw.match(pattern);
    return match ? String(match[1] || "").trim() : "";
  };
  const multilineField = (label) => {
    const match = raw.match(new RegExp(`${label}:\\s*([\\s\\S]+?)(?:\\n\\s*\\n|\\n[А-ЯA-Z][^:\\n]{0,80}:|$)`, "i"));
    if (!match) return "";
    return match[1]
      .split("\n")
      .map((line) => line.replace(/^[\s\-•]+/, "").trim())
      .filter(Boolean)
      .join(", ");
  };

  return {
    summary: get(/^([^\n]+)/m),
    subject_area: get(/Предметная область:\s*(.+)/i),
    entity_name: get(/Сущность загрузки:\s*(.+)/i),
    git_reference: get(/(?:Ссылка на гит|Ссылка на описание шаблона):\s*(.+)/i),
    source_name: get(/Источник:\s*(.+)/i),
    source_schema: get(/Название схемы на источнике:\s*(.+)/i),
    source_table: get(/Название таблицы на источнике:\s*(.+)/i),
    source_key: get(/Ключ на источнике:\s*(.+)/i),
    source_access: get(/Доступ к таблице на источнике:\s*(.+)/i),
    target_table_fqn: get(/(?:Название таблицы Greenplum|Название таблицы в таргете):\s*(.+)/i),
    load_mode: get(/Способ обновления:\s*(.+)/i),
    load_condition: get(/Условие при загрузке:\s*(.+)/i),
    script_runtime: get(/Время работы скрипта:\s*(.+)/i),
    business_key: multilineField("Бизнес[- ]ключ(?: для проверки на дубли)?"),
    dependent_views: multilineField("Зависимые представления|Зависимые представление"),
    clickhouse_keys: multilineField("Ключевые поля для загрузки в ClickHosue|Ключевые поля для загрузки в ClickHouse"),
    pseudo_increment_steps: multilineField("Последовательность действий при \\(псевдо\\)инкрементальном обновлении таблицы"),
    stand_dev: /Стенд:\s*.*DEV/i.test(raw),
    stand_prod: /Стенд:\s*.*PROD/i.test(raw),
    copy_to_clickhouse: !/Копировать в ClickHouse:\s*.*не нужно/i.test(raw),
    linked_issues: Array.from(new Set(raw.match(/\b[A-Z]+-\d+\b/g) || [])).join(", "),
  };
}

function buildTemplateText(form, options) {
  const lines = [];
  const pushField = (label, key, { multiline = false } = {}) => {
    if (options.skips[key]) {
      lines.push(`${label}: пропустить`);
      return;
    }
    const value = String(form[key] || "").trim();
    if (!value) {
      lines.push(`${label}:`);
      return;
    }
    if (!multiline) {
      lines.push(`${label}: ${value}`);
      return;
    }
    lines.push(`${label}:`);
    splitItems(value).forEach((item) => lines.push(item));
  };

  if (form.summary.trim()) lines.push(form.summary.trim(), "");
  pushField("Предметная область", "subject_area");
  pushField("Сущность загрузки", "entity_name");
  pushField("Источник", "source_name");
  pushField("Название схемы на источнике", "source_schema");
  pushField("Название таблицы на источнике", "source_table");
  pushField("Ключ на источнике", "source_key");
  if (options.isConditionLayer) {
    pushField("Условие при загрузке", "load_condition");
  }
  lines.push(`Стенд: ${options.standDev && options.standProd ? "DEV/PROD" : options.standDev ? "DEV" : options.standProd ? "PROD" : ""}`);
  pushField("Доступ к таблице на источнике", "source_access");
  pushField("Ссылка на гит", "git_reference");
  pushField("Название таблицы Greenplum", "target_table_fqn");
  pushField("Способ обновления", "load_mode");
  pushField("Время работы скрипта", "script_runtime");
  pushField("Бизнес ключ", "business_key", { multiline: true });
  pushField("Зависимые представления", "dependent_views", { multiline: true });
  lines.push(`Копировать в ClickHouse: ${options.copyToClickhouse ? "необходимо обновить данные в витрине (структуру обновлять не нужно)" : "не нужно"}`);
  pushField("Ключевые поля для загрузки в ClickHouse", "clickhouse_keys", { multiline: true });
  pushField("Последовательность действий при (псевдо)инкрементальном обновлении таблицы", "pseudo_increment_steps");
  if (options.linkedIssues.trim()) lines.push(`Связанные тикеты: ${options.linkedIssues.trim()}`);
  return lines.join("\n");
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

export default function AdminPrototypeReviewPage() {
  const [mrInput, setMrInput] = useState("");
  const [form, setForm] = useState(DEFAULT_FORM);
  const [skips, setSkips] = useState(DEFAULT_SKIPS);
  const [linkedIssues, setLinkedIssues] = useState("");
  const [standDev, setStandDev] = useState(true);
  const [standProd, setStandProd] = useState(true);
  const [copyToClickhouse, setCopyToClickhouse] = useState(true);
  const [loading, setLoading] = useState(false);
  const [creatingIssue, setCreatingIssue] = useState(false);
  const [error, setError] = useState(null);
  const [result, setResult] = useState(null);
  const [currentUser, setCurrentUser] = useState(null);
  const [yamlCopied, setYamlCopied] = useState(false);
  const [reviewItemsDraft, setReviewItemsDraft] = useState([]);

  useEffect(() => {
    accountApi.me().then(setCurrentUser).catch(() => {});
  }, []);

  useEffect(() => {
    const mrValue = String(mrInput || "").trim();
    if (!mrValue) return;
    setForm((prev) => {
      const currentRef = String(prev.git_reference || "").trim();
      if (currentRef && currentRef !== mrValue) return prev;
      if (currentRef === mrValue) return prev;
      return { ...prev, git_reference: mrValue };
    });
  }, [mrInput]);

  const targetSchema = String(form.target_table_fqn || "").trim().split(".", 1)[0].toLowerCase();
  const isConditionLayer = targetSchema === "stg";

  const normalizedTaskText = useMemo(
    () => buildTemplateText(form, { skips, standDev, standProd, copyToClickhouse, linkedIssues, isConditionLayer }),
    [form, skips, standDev, standProd, copyToClickhouse, linkedIssues, isConditionLayer],
  );
  const totalExecutionSec = useMemo(
    () => (Array.isArray(result?.execution) ? result.execution.reduce((acc, item) => acc + Number(item?.duration_sec || 0), 0) : 0),
    [result],
  );
  const unresolvedItemsCount = useMemo(
    () => reviewItemsDraft.filter((item) => item.requires_user_input && (
      !String(item.entity_name || "").trim() || !splitItems(item.key_attributes_text).length
    )).length,
    [reviewItemsDraft],
  );

  useEffect(() => {
    if (!yamlCopied) return undefined;
    const timer = window.setTimeout(() => setYamlCopied(false), 1600);
    return () => window.clearTimeout(timer);
  }, [yamlCopied]);

  useEffect(() => {
    const items = Array.isArray(result?.review_items) ? result.review_items : [];
    setReviewItemsDraft(items.map((item) => ({
      ...item,
      entity_name: item.entity_name || "",
      key_attributes_text: joinItems(item.key_attributes || []),
      clickhouse_keys_text: joinItems(item.clickhouse_keys || []),
      business_key_text: joinItems(item.business_key || []),
      dependent_views_text: joinItems(item.impact?.tables?.map((row) => row.fqn) || []),
    })));
  }, [result]);

  const shouldShowField = (fieldKey) => (fieldKey === "load_condition" ? isConditionLayer : true);

  const handleFieldChange = (field, value) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const handleSkipChange = (field, checked) => {
    setSkips((prev) => ({ ...prev, [field]: checked }));
  };

  const handleRun = async () => {
    const trimmedMr = String(mrInput || "").trim();
    if (!trimmedMr || loading) return;
    setLoading(true);
    setError(null);
    setResult(null);
    try {
      const payload = await adminApi.prototypeReviewRun({
        mr_input: trimmedMr,
        task_text: normalizedTaskText,
        issue_summary: form.summary.trim(),
        target_table_fqn: form.target_table_fqn.trim(),
        entity_name: form.entity_name.trim(),
        load_mode: form.load_mode.trim(),
        stand_dev: standDev,
        stand_prod: standProd,
        copy_to_clickhouse: copyToClickhouse,
        dependent_views: skips.dependent_views ? [] : splitItems(form.dependent_views),
        linked_issues: splitItems(linkedIssues),
        key_attributes: skips.clickhouse_keys ? [] : splitItems(form.clickhouse_keys || form.business_key),
        create_issue: false,
      });
      setResult(payload || null);
      const firstTarget = Array.isArray(payload?.review_items) && payload.review_items.length ? payload.review_items[0]?.target_fqn : "";
      const firstEntity = Array.isArray(payload?.review_items) && payload.review_items.length ? payload.review_items[0]?.entity_name : "";
      const totalSec = Array.isArray(payload?.execution)
        ? payload.execution.reduce((acc, item) => acc + Number(item?.duration_sec || 0), 0)
        : 0;
      setForm((prev) => ({
        ...prev,
        git_reference: String(mrInput || "").trim() || prev.git_reference || "",
        target_table_fqn: firstTarget || prev.target_table_fqn || "",
        entity_name: firstEntity || prev.entity_name || "",
        script_runtime: totalSec >= 60 ? `${(totalSec / 60).toFixed(2)} мин` : totalSec > 0 ? `${totalSec.toFixed(3)} сек` : prev.script_runtime,
      }));
    } catch (err) {
      setError(err?.message || "Не удалось выполнить prototype review");
    } finally {
      setLoading(false);
    }
  };

  const handleReviewItemChange = (targetFqn, field, value) => {
    setReviewItemsDraft((prev) => prev.map((item) => {
      if (item.target_fqn !== targetFqn) return item;
      const next = { ...item, [field]: value };
      const needsEntity = !String(next.entity_name || "").trim();
      const needsKeys = !splitItems(next.key_attributes_text).length;
      next.requires_user_input = Boolean(item.is_new || item.missing_fields?.length || needsEntity || needsKeys);
      return next;
    }));
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
        stand_dev: standDev,
        stand_prod: standProd,
        copy_to_clickhouse: copyToClickhouse,
        linked_issues: splitItems(linkedIssues),
        review_items: reviewItemsDraft.map((item) => ({
          path: item.path,
          target_fqn: item.target_fqn,
          entity_name: String(item.entity_name || "").trim(),
          key_attributes: splitItems(item.key_attributes_text),
          clickhouse_keys: splitItems(item.clickhouse_keys_text),
          business_key: splitItems(item.business_key_text),
          dependent_views: splitItems(item.dependent_views_text),
          is_new: item.is_new,
          object_type: item.object_type,
          duration_sec: item.duration_sec,
          row_count: item.checks?.row_count ?? null,
          duplicate_groups: item.checks?.duplicate_groups ?? null,
          dependencies: item.dependencies || [],
          impact_tables: item.impact?.tables || [],
          yaml_content: item.yaml_bundle?.yaml_content || "",
        })),
      });
      setResult((prev) => ({ ...(prev || {}), issue: payload?.issue || null }));
    } catch (err) {
      setError(err?.message || "Не удалось создать задачу");
    } finally {
      setCreatingIssue(false);
    }
  };

  const renderField = (fieldKey) => {
    const meta = FIELD_META[fieldKey];
    const value = form[fieldKey] || "";
    const isSkipped = Boolean(skips[fieldKey]);
    const InputTag = meta.kind === "textarea" ? "textarea" : "input";
    return (
      <div key={fieldKey} className="cc-surface prototype-step-field" style={{ margin: 0 }}>
        <div className="prototype-step-head">
          <span className="slow-select-label">{meta.label}</span>
          {meta.optional ? (
            <label className="prototype-skip-toggle">
              <input
                type="checkbox"
                checked={isSkipped}
                onChange={(event) => handleSkipChange(fieldKey, event.target.checked)}
              />
              <span>Пропустить</span>
            </label>
          ) : null}
        </div>
        <InputTag
          className="slow-entity-select"
          value={value}
          disabled={isSkipped}
          onChange={(event) => handleFieldChange(fieldKey, event.target.value)}
          placeholder={meta.placeholder}
          style={meta.kind === "textarea" ? { minHeight: 110, resize: "vertical" } : undefined}
        />
      </div>
    );
  };

  return (
    <div className="container cc-page slow-page prototype-review-page">
      <section className="cc-header-zone">
        <h1>Prototype Review / MR Review</h1>
        <div className="cc-subtitle">
          Цель: сократить время заведения задачи и собрать однотипную карточку из шаблона, MR и меты таблицы.
        </div>
      </section>

      <section className="cc-surface">
        <div className="section-title">Быстрый Старт</div>
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
            <span className="slow-select-label">Создание задачи</span>
            <div className="muted" style={{ marginTop: 10 }}>
              После `Запустить проверки` все найденные таблицы появятся ниже. Новые таблицы и объекты без ключей будут подсвечены, после ручной правки можно создать одну задачу по всему MR.
            </div>
            <div className="muted" style={{ marginTop: 10 }}>
              Инициатор в описании:
              {" "}
              <span className="mono">{currentUser?.username || currentUser?.email || "текущий пользователь"}</span>
            </div>
          </div>
        </div>
      </section>

      <section className="cc-surface">
        <div className="prototype-import-actions">
          <div className="muted">Сначала достаточно указать MR. Таблицы, сущности, ключи и статусы будут определены автоматически из SQL.</div>
          <button className="btn btn-primary" onClick={handleRun} disabled={loading || !mrInput.trim()}>
            {loading ? "Запускаем review..." : "Запустить review"}
          </button>
        </div>
      </section>

      {result ? STEP_BLOCKS.filter((block) => block.title !== "Шаг 2. Источник" && (!block.stgOnly || false)).map((block) => (
        <section key={block.title} className="cc-surface">
          <div className="section-title">{block.title}</div>
          <div className="muted" style={{ marginBottom: 14 }}>{block.description}</div>
          {block.title === "Шаг 1. Карточка" ? (
            <div className="prototype-step-grid">
              <div className="prototype-step-field" style={{ margin: 0 }}>
                <span className="slow-select-label">Стенд</span>
                <div className="prototype-chip-row">
                  <label className="prototype-skip-toggle">
                    <input type="checkbox" checked={standDev} onChange={(event) => setStandDev(event.target.checked)} />
                    <span>DEV</span>
                  </label>
                  <label className="prototype-skip-toggle">
                    <input type="checkbox" checked={standProd} onChange={(event) => setStandProd(event.target.checked)} />
                    <span>PROD</span>
                  </label>
                </div>
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
                <span className="slow-select-label">ClickHouse</span>
                <label className="prototype-skip-toggle" style={{ marginTop: 10 }}>
                  <input type="checkbox" checked={copyToClickhouse} onChange={(event) => setCopyToClickhouse(event.target.checked)} />
                  <span>Нужна загрузка / обновление в ClickHouse</span>
                </label>
              </div>
            </div>
          ) : (
            <div className="prototype-step-grid">
              {block.fields.filter(shouldShowField).map(renderField)}
            </div>
          )}
        </section>
      )) : null}

      {result ? <section className="cc-surface">
        <div className="section-title">Собранный Шаблон</div>
        <textarea className="slow-entity-select mono" value={normalizedTaskText} readOnly style={{ minHeight: 260, resize: "vertical" }} />
        <div className="prototype-import-actions">
          <div className="muted">Это итоговый нормализованный шаблон, который уйдёт в backend и в описание задачи.</div>
        </div>
      </section> : null}

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
              <div className="label">Таблицы MR</div>
              <div className="value">{Array.isArray(reviewItemsDraft) ? reviewItemsDraft.length : 0}</div>
              <div className="hint">
                {result.requires_user_input ? `Требуют ручной проверки: ${unresolvedItemsCount}` : "Все обязательные поля заполнены автоматически"}
              </div>
            </div>
            <div className="slow-summary-card">
              <div className="label">YTrack</div>
              <div className="value">{formatIssueStatus(result.issue)}</div>
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
            <div className="muted" style={{ marginBottom: 14 }}>
              Целевые таблицы определены автоматически по SQL-файлам MR. Для новых таблиц и объектов без ключей заполните поля вручную перед созданием задачи.
            </div>
            <div style={{ display: "grid", gap: 16 }}>
              {reviewItemsDraft.map((item) => {
                const needsEntity = !String(item.entity_name || "").trim();
                const needsKeys = !splitItems(item.key_attributes_text).length;
                const needsAttention = Boolean(item.is_new || item.requires_user_input || needsEntity || needsKeys);
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
                        <span className="card" style={{ padding: "6px 10px", margin: 0 }}>{item.is_new ? "Новая таблица" : "Существующий объект"}</span>
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
                        <span className="slow-select-label">Бизнес ключ</span>
                        <textarea
                          className="slow-entity-select"
                          value={item.business_key_text || ""}
                          onChange={(event) => handleReviewItemChange(item.target_fqn, "business_key_text", event.target.value)}
                          placeholder="warehouse_code, dt_report"
                          style={{ minHeight: 100, resize: "vertical" }}
                        />
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
            <div className="section-title">Общие параметры</div>
            <div className="table-wrapper">
              <table className="incidents-table slow-table">
                <thead>
                  <tr>
                    <th>Предметная область</th>
                    <th>Режим обновления</th>
                    <th>Стенды</th>
                    <th>Копировать в ClickHouse</th>
                    <th>Ключевые поля ClickHouse</th>
                    <th>Бизнес ключ</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>{result.task_context?.subject_area || "—"}</td>
                    <td>{result.task_context?.load_mode || "—"}</td>
                    <td>{Array.isArray(result.task_context?.environments) && result.task_context.environments.length ? result.task_context.environments.join(", ") : "—"}</td>
                    <td>{result.task_context?.copy_to_clickhouse ? "необходимо обновить данные в витрине (структуру обновлять не нужно)" : "не нужно"}</td>
                    <td>{Array.isArray(result.task_context?.clickhouse_keys) && result.task_context.clickhouse_keys.length ? result.task_context.clickhouse_keys.join(", ") : "—"}</td>
                    <td>{Array.isArray(result.task_context?.business_key) && result.task_context.business_key.length ? result.task_context.business_key.join(", ") : "—"}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Создание задачи</div>
            <div className="prototype-import-actions">
              <div className="muted">
                Одна задача будет создана на весь MR. В описании MR и diff будут указаны один раз, а по каждой таблице пойдет отдельный структурированный блок.
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
                Сначала заполните обязательные поля у {unresolvedItemsCount} таблиц.
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
