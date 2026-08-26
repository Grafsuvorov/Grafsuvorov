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
  const [tableMode, setTableMode] = useState("existing");
  const [tableQuery, setTableQuery] = useState("");
  const [tableOptions, setTableOptions] = useState([]);
  const [selectedTable, setSelectedTable] = useState(null);
  const [tablesLoading, setTablesLoading] = useState(true);
  const [tableMetaLoading, setTableMetaLoading] = useState(false);
  const [createIssue, setCreateIssue] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [result, setResult] = useState(null);
  const [currentUser, setCurrentUser] = useState(null);
  const [yamlCopied, setYamlCopied] = useState(false);

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
  const isSourceLayer = targetSchema === "stg" || targetSchema === "dict_stg";
  const isConditionLayer = targetSchema === "stg";

  useEffect(() => {
    let cancelled = false;
    setTablesLoading(true);
    adminApi.tablesDetailed()
      .then((data) => {
        if (cancelled) return;
        const rows = (Array.isArray(data) ? data : [])
          .filter((item) => (item?.source || "current") === "current")
          .map((item) => ({
            ...item,
            fqn: String(item?.fqn || "").toLowerCase(),
            __search: [
              item?.fqn,
              item?.entity_name,
              item?.label,
            ].filter(Boolean).join(" ").toLowerCase(),
          }));
        setTableOptions(rows);
      })
      .catch(() => {
        if (!cancelled) setTableOptions([]);
      })
      .finally(() => {
        if (!cancelled) setTablesLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const normalizedTaskText = useMemo(
    () => buildTemplateText(form, { skips, standDev, standProd, copyToClickhouse, linkedIssues, isConditionLayer }),
    [form, skips, standDev, standProd, copyToClickhouse, linkedIssues, isConditionLayer],
  );
  const totalExecutionSec = useMemo(
    () => Number(result?.preparation?.duration_sec || 0) + (Array.isArray(result?.execution) ? result.execution.reduce((acc, item) => acc + Number(item?.duration_sec || 0), 0) : 0),
    [result],
  );

  useEffect(() => {
    if (!yamlCopied) return undefined;
    const timer = window.setTimeout(() => setYamlCopied(false), 1600);
    return () => window.clearTimeout(timer);
  }, [yamlCopied]);

  const shouldShowField = (fieldKey) => {
    if (fieldKey === "load_condition") return isConditionLayer;
    return true;
  };

  const handleFieldChange = (field, value) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const handleSkipChange = (field, checked) => {
    setSkips((prev) => ({ ...prev, [field]: checked }));
  };

  const filteredTables = useMemo(() => {
    const q = String(tableQuery || "").trim().toLowerCase();
    if (!q) return tableOptions.slice(0, 8);
    return tableOptions.filter((item) => item.__search.includes(q)).slice(0, 8);
  }, [tableOptions, tableQuery]);

  const applyTableMeta = async (tableItem) => {
    if (!tableItem?.schema || !tableItem?.table) return;
    setTableMetaLoading(true);
    setError(null);
    try {
      const [meta, clickViewSearchResult, clickMetaResult, dependencyNodesResult] = await Promise.all([
        adminApi.tableCard(tableItem.schema, tableItem.table, { source: "current" }),
        adminApi.clickViewSearch(tableItem.schema, tableItem.table).catch(() => []),
        adminApi.clickMeta(tableItem.schema, tableItem.table).catch(() => null),
        apiClient.get(`/api/dependencies-nodes/${encodeURIComponent(tableItem.schema)}/${encodeURIComponent(tableItem.table)}`, {
          params: { max_depth: 1, max_nodes: 200 },
        }).catch(() => null),
      ]);
      const keyAttributes = Array.isArray(meta?.key_attributes) ? meta.key_attributes : [];
      const clickOrderBy = Array.isArray(clickMetaResult?.meta?.order_by) ? clickMetaResult.meta.order_by : [];
      const clickViews = Array.isArray(clickViewSearchResult?.matches)
        ? clickViewSearchResult.matches
        : Array.isArray(clickViewSearchResult)
          ? clickViewSearchResult
          : [];
      const dependentViews = Array.isArray(clickViews)
        ? clickViews
            .map((item) => {
              const viewSchema = String(item?.view_schema || "").trim();
              const viewName = String(item?.view_name || "").trim();
              return viewSchema && viewName ? `${viewSchema}.${viewName}` : "";
            })
            .filter(Boolean)
        : [];
      const dependencyNodes = Array.isArray(dependencyNodesResult?.nodes) ? dependencyNodesResult.nodes : [];
      const metaDependentViews = dependencyNodes.filter((fqn) => isViewLikeFqn(fqn, tableItem.fqn));
      const mergedDependentViews = Array.from(new Set([...dependentViews, ...metaDependentViews]));
      const summary = form.summary.trim() && !selectedTable
        ? form.summary
        : `(ДМЛ) Настроить обновление витрины ${tableItem.fqn}`;
      const mrValue = String(mrInput || "").trim();
      setSelectedTable(tableItem);
      setTableQuery(tableItem.fqn);
      setForm((prev) => ({
        ...prev,
        summary,
        git_reference: mrValue || prev.git_reference || "",
        entity_name: String(meta?.entity_name || tableItem.entity_name || prev.entity_name || ""),
        target_table_fqn: String(meta?.table_schema && meta?.table_name ? `${meta.table_schema}.${meta.table_name}` : tableItem.fqn || prev.target_table_fqn || ""),
        load_mode: String(meta?.table_load_mode || prev.load_mode || ""),
        business_key: joinItems(keyAttributes.length ? keyAttributes : splitItems(prev.business_key)),
        clickhouse_keys: joinItems(clickOrderBy.length ? clickOrderBy : splitItems(prev.clickhouse_keys)),
        dependent_views: joinItems(mergedDependentViews.length ? mergedDependentViews : splitItems(prev.dependent_views)),
      }));
    } catch (err) {
      setError(err?.message || "Не удалось подтянуть мету таблицы");
    } finally {
      setTableMetaLoading(false);
    }
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
        create_issue: createIssue,
      });
      setResult(payload || null);
      if (Array.isArray(payload?.execution) && payload.execution.length) {
        const totalSec =
          Number(payload?.preparation?.duration_sec || 0) +
          payload.execution.reduce((acc, item) => acc + Number(item?.duration_sec || 0), 0);
        if (totalSec > 0) {
          setForm((prev) => ({
            ...prev,
            script_runtime: totalSec >= 60 ? `${(totalSec / 60).toFixed(2)} мин` : `${totalSec.toFixed(3)} сек`,
          }));
        }
      }
    } catch (err) {
      setError(err?.message || "Не удалось выполнить prototype review");
    } finally {
      setLoading(false);
    }
  };

  const handleCopyYaml = async () => {
    const content = String(result?.yaml_bundle?.yaml_content || "").trim();
    if (!content) return;
    try {
      await navigator.clipboard.writeText(content);
      setYamlCopied(true);
    } catch (_) {
      setYamlCopied(false);
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
            <label className="prototype-skip-toggle" style={{ marginTop: 10 }}>
              <input type="checkbox" checked={createIssue} onChange={(event) => setCreateIssue(event.target.checked)} />
              <span>Создать задачу автоматически после проверки</span>
            </label>
            <div className="muted" style={{ marginTop: 10 }}>
              Инициатор в описании:
              {" "}
              <span className="mono">{currentUser?.username || currentUser?.email || "текущий пользователь"}</span>
            </div>
          </div>
        </div>
      </section>

      <section className="cc-surface">
        <div className="section-title">Таблица</div>
        <div className="muted" style={{ marginBottom: 14 }}>
          Если таблица уже существует, выберите её из каталога и форма подтянет сущность, ключи и базовые поля шаблона. Если таблица новая, переключитесь в ручной ввод.
        </div>
        <div className="prototype-chip-row" style={{ marginBottom: 14 }}>
          <button type="button" className={`btn ${tableMode === "existing" ? "btn-primary" : "btn-ghost"}`} onClick={() => setTableMode("existing")}>
            Выбрать существующую
          </button>
          <button type="button" className={`btn ${tableMode === "new" ? "btn-primary" : "btn-ghost"}`} onClick={() => setTableMode("new")}>
            Новая таблица
          </button>
        </div>
        {tableMode === "existing" ? (
          <div className="prototype-step-field" style={{ margin: 0 }}>
            <span className="slow-select-label">Поиск по каталогу</span>
            <input
              className="slow-entity-select"
              value={tableQuery}
              onChange={(event) => setTableQuery(event.target.value)}
              placeholder={tablesLoading ? "Загрузка каталога..." : "Например: dm.sales_foreign_metal_stock_balance_analysis"}
            />
            <div className="prototype-table-list">
              {filteredTables.map((item) => (
                <button
                  key={item.fqn}
                  type="button"
                  className={`prototype-table-option ${selectedTable?.fqn === item.fqn ? "active" : ""}`}
                  onClick={() => applyTableMeta(item)}
                >
                  <span className="mono">{item.fqn}</span>
                  <span>{item.entity_name || "—"}</span>
                </button>
              ))}
            </div>
            <div className="muted">
              {tableMetaLoading ? "Подтягиваем мету таблицы..." : "После выбора таблицы поля ниже останутся редактируемыми."}
            </div>
          </div>
        ) : (
          <div className="muted">Для новой таблицы просто заполните поля в шагах ниже вручную.</div>
        )}
      </section>

      {STEP_BLOCKS.filter((block) => !block.stgOnly || isSourceLayer).map((block) => (
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
      ))}

      <section className="cc-surface">
        <div className="section-title">Собранный Шаблон</div>
        <textarea className="slow-entity-select mono" value={normalizedTaskText} readOnly style={{ minHeight: 260, resize: "vertical" }} />
        <div className="prototype-import-actions">
          <div className="muted">Это итоговый нормализованный шаблон, который уйдёт в backend и в описание задачи.</div>
          <button className="btn btn-primary" onClick={handleRun} disabled={loading || !mrInput.trim()}>
            {loading ? "Выполняем..." : "Запустить review"}
          </button>
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
              <div className="label">Витрина</div>
              <div className="value mono" style={{ fontSize: "1rem", overflowWrap: "anywhere", wordBreak: "break-word" }}>
                {result.final_target || "—"}
              </div>
              <div className="hint">{result.resolved_entity_name ? `Сущность: ${result.resolved_entity_name}` : "Сущность не определена"}</div>
            </div>
            <div className="slow-summary-card">
              <div className="label">YTrack</div>
              <div className="value">{formatIssueStatus(result.issue)}</div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Витрина и проверка</div>
            <div className="table-wrapper">
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
                    <td>{result.resolved_entity_name || "—"}</td>
                    <td>{(result.key_attributes || []).length ? result.key_attributes.join(", ") : "—"}</td>
                    <td>{result.checks?.row_count !== undefined && result.checks?.row_count !== null ? formatCount(result.checks.row_count) : "—"}</td>
                    <td>{result.checks?.duplicate_groups !== undefined && result.checks?.duplicate_groups !== null ? formatCount(result.checks.duplicate_groups) : "—"}</td>
                    <td>{totalExecutionSec > 0 ? formatDuration(totalExecutionSec) : "—"}</td>
                  </tr>
                </tbody>
              </table>
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
            <div className="section-title">Параметры загрузки</div>
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
            <div className="section-title">Зависимости SQL</div>
            {Array.isArray(result.dependencies) && result.dependencies.length > 0 ? (
              <div className="card" style={{ display: "grid", gap: 10 }}>
                {result.dependencies.map((item) => (
                  <div key={item} className="mono" style={{ overflowWrap: "anywhere", wordBreak: "break-word" }}>{item}</div>
                ))}
              </div>
            ) : (
              <div className="muted">Зависимости не найдены.</div>
            )}
          </section>

          <section className="cc-surface">
            <div className="section-title">Потенциальное downstream-влияние</div>
            {Array.isArray(result.impact?.tables) && result.impact.tables.length > 0 ? (
              <div className="card" style={{ display: "grid", gap: 12 }}>
                {result.impact.tables.map((item) => (
                  <div key={item.fqn}>
                    <div style={{ fontWeight: 700 }}>{item.fqn || "—"}</div>
                    <div className="muted">{item.entity_name || "—"}</div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="muted">Downstream-объекты не найдены.</div>
            )}
          </section>

          <section className="cc-surface">
            <div className="section-title">Черновик YAML</div>
            {result.yaml_bundle?.yaml_content ? (
              <>
                <div className="prototype-chip-row" style={{ marginBottom: 14, alignItems: "center", justifyContent: "space-between" }}>
                  <div className="muted">
                    Источник:
                    {" "}
                    <strong>{formatYamlSource(result.yaml_bundle)}</strong>
                    {" · "}
                    Объект:
                    {" "}
                    <span className="mono">{result.final_target || "—"}</span>
                  </div>
                  <button type="button" className="btn btn-ghost" onClick={handleCopyYaml}>
                    {yamlCopied ? "Скопировано" : "Скопировать YAML"}
                  </button>
                </div>
                <textarea
                  className="slow-entity-select mono"
                  readOnly
                  value={result.yaml_bundle.yaml_content}
                  style={{ minHeight: 420, resize: "vertical" }}
                />
              </>
            ) : (
              <div className="muted">Не удалось автоматически собрать YAML для этой таблицы.</div>
            )}
          </section>
        </>
      ) : null}
    </div>
  );
}
