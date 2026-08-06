import { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { adminApi } from "../api/admin.js";

function splitFqn(fqn) {
  if (!fqn || !fqn.includes(".")) return null;
  const [schema, ...rest] = fqn.split(".");
  const table = rest.join(".");
  if (!schema || !table) return null;
  return { schema, table };
}

function formatPercent(value) {
  return `${Math.round(Number(value || 0) * 100)}%`;
}

function formatBlockType(value) {
  const map = {
    temp_table: "Temp table",
    create_as_select: "Create as select",
    insert_select: "Insert-select",
    query: "Select / CTE",
    statement: "SQL block",
  };
  return map[value] || value || "SQL block";
}

function normalizeExpr(value) {
  return String(value || "")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}

function buildBlockInsights(data) {
  const leftTargets = Array.isArray(data?.left?.select_targets) ? data.left.select_targets : [];
  const rightTargets = Array.isArray(data?.right?.select_targets) ? data.right.select_targets : [];

  const rightByExpr = new Map(
    rightTargets.map((target, index) => [
      `${target.alias || `expr_${index + 1}`}::${normalizeExpr(target.expression)}`,
      target,
    ]),
  );
  const leftByExpr = new Map(
    leftTargets.map((target, index) => [
      `${target.alias || `expr_${index + 1}`}::${normalizeExpr(target.expression)}`,
      target,
    ]),
  );

  const commonTargets = [];
  const leftOnlyTargets = [];
  const rightOnlyTargets = [];

  leftTargets.forEach((target, index) => {
    const key = `${target.alias || `expr_${index + 1}`}::${normalizeExpr(target.expression)}`;
    if (rightByExpr.has(key)) {
      commonTargets.push(target);
    } else {
      leftOnlyTargets.push(target);
    }
  });

  rightTargets.forEach((target, index) => {
    const key = `${target.alias || `expr_${index + 1}`}::${normalizeExpr(target.expression)}`;
    if (!leftByExpr.has(key)) {
      rightOnlyTargets.push(target);
    }
  });

  const leftSources = new Set(data?.left_features?.source_tables || []);
  const rightSources = new Set(data?.right_features?.source_tables || []);
  const commonSources = [...leftSources].filter((item) => rightSources.has(item));

  const leftFunctions = new Set(data?.left_features?.functions || []);
  const rightFunctions = new Set(data?.right_features?.functions || []);
  const commonFunctions = [...leftFunctions].filter((item) => rightFunctions.has(item));

  return {
    commonTargets,
    leftOnlyTargets,
    rightOnlyTargets,
    commonSources,
    commonFunctions,
  };
}

function buildRefactorAdvice(data, insights) {
  const commonCount = insights.commonTargets.length;
  const leftWhere = data?.left?.where_clause || "";
  const rightWhere = data?.right?.where_clause || "";
  const sameWhere = leftWhere && rightWhere && normalizeExpr(leftWhere) === normalizeExpr(rightWhere);
  const hasWhereDiff = Boolean(leftWhere || rightWhere) && !sameWhere;
  const hasOnlyMinorProjectionDiff = !insights.leftOnlyTargets.length && !insights.rightOnlyTargets.length;

  let title = "Похоже на общий расчётный слой";
  let summary = "Общий SQL-каркас уже виден, его можно выделить в reusable intermediate-слой.";
  let pattern = "Общий base-select -> отдельные финальные витрины";
  const steps = [];

  if (commonCount >= 8 && hasWhereDiff && hasOnlyMinorProjectionDiff) {
    title = "Вынести общий base-расчёт и развести фильтры отдельно";
    summary = "У пары совпадает расчётное ядро, а расходится в основном фильтрация. Это сильный кандидат на одну базовую таблицу/CTE и два тонких финальных селекта.";
    pattern = "Shared base table/view + thin business filters";
    steps.push("Собрать общий SELECT без бизнес-фильтра в промежуточный слой.");
    steps.push("Унести различия по WHERE в два финальных downstream-объекта.");
  } else if (commonCount >= 8) {
    title = "Вынести повторяющийся блок в общий intermediate";
    summary = "Большая часть выражений уже совпадает. Даже если финальная логика не полностью одинакова, общий расчётный блок можно изолировать.";
    pattern = "Shared intermediate block";
    steps.push("Выделить повторяющиеся SELECT-выражения в единый intermediate-слой.");
    steps.push("Оставить только уникальные поля/пост-обработку в целевых объектах.");
  } else {
    title = "Сначала зафиксировать общее ядро, потом решать вынос";
    summary = "Похожесть есть, но общий блок пока не выглядит достаточно чистым для прямого выноса в отдельную таблицу.";
    pattern = "Manual review before extraction";
    steps.push("Сначала выровнять состав полей и источники.");
  }

  if (insights.commonSources.length) {
    steps.push(`Базовые источники для выноса: ${insights.commonSources.slice(0, 4).join(", ")}.`);
  }
  if (insights.commonFunctions.length) {
    steps.push(`Повторяющиеся функции: ${insights.commonFunctions.slice(0, 4).join(", ")}.`);
  }
  if (insights.leftOnlyTargets.length || insights.rightOnlyTargets.length) {
    steps.push("Проверить, нужно ли уникальные выражения оставить в финальных слоях, а не в общем ядре.");
  }

  return { title, summary, pattern, steps };
}

export default function AdminArchitectureBlockPage() {
  const navigate = useNavigate();
  const { pairId } = useParams();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    adminApi.architectureBlockPair(pairId)
      .then((payload) => {
        if (!cancelled) setData(payload || null);
      })
      .catch((err) => {
        if (!cancelled) setError(err.message || "Не удалось загрузить сравнение блока");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [pairId]);

  const openTable = (fqn) => {
    const parsed = splitFqn(fqn);
    if (!parsed) return;
    navigate(`/table/${encodeURIComponent(parsed.schema)}/${encodeURIComponent(parsed.table)}`);
  };

  const title = useMemo(() => {
    if (!data) return "Сопоставление SQL-блоков";
    return `${data.left_fqn || "—"} ↔ ${data.right_fqn || "—"}`;
  }, [data]);
  const insights = useMemo(() => buildBlockInsights(data), [data]);
  const refactorAdvice = useMemo(() => buildRefactorAdvice(data, insights), [data, insights]);

  return (
    <div className="container cc-page">
      <section className="cc-header-zone">
        <button className="btn" onClick={() => navigate("/admin/architecture")}>← Назад к архитектуре</button>
        <h1>Сопоставление SQL-блоков</h1>
        <div className="cc-subtitle">
          Отдельный экран для сопоставления внутреннего SQL-фрагмента между двумя объектами: совпадения, отличия, источники, выражения и текст самого блока.
        </div>
      </section>

      {loading && <div className="muted">Загружаю детали блока...</div>}
      {error && <div className="login-error">{error}</div>}

      {!loading && !error && data ? (
        <>
          <section className="cc-surface">
            <div className="section-title">Итог по блоку</div>
            <div className="logic-audit-explain">
              <div className="logic-audit-mini-title">{title}</div>
              <div>{data.explanation?.summary}</div>
              <div className="logic-audit-explain-decision">{data.explanation?.decision}</div>
              <div className="architecture-row-badges">
                <span className="architecture-badge">{formatBlockType(data.left_block_type)}</span>
                <span className="architecture-badge">{data.expression_overlap_count || 0} expr</span>
                <span className="architecture-badge accent">{formatPercent(data.score)}</span>
                <span className="architecture-badge">{data.pair_kind || "block_pair"}</span>
              </div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Общее расчётное ядро</div>
            <div className="architecture-cluster-grid">
              <div className="architecture-reco-card">
                <div className="architecture-reco-kicker">Что реально повторяется</div>
                <div className="architecture-reco-title">{insights.commonTargets.length} общих выражений</div>
                <div className="architecture-reco-text">
                  Это и есть наиболее явный кандидат на вынос в общий промежуточный расчётный слой. Ниже показаны одинаковые поля/выражения, которые оба объекта считают одинаково.
                </div>
                <div className="architecture-context-grid">
                  <div className="architecture-context-item">
                    <span className="label">Общие поля</span>
                    <strong>{insights.commonTargets.length}</strong>
                  </div>
                  <div className="architecture-context-item">
                    <span className="label">Только слева</span>
                    <strong>{insights.leftOnlyTargets.length}</strong>
                  </div>
                  <div className="architecture-context-item">
                    <span className="label">Только справа</span>
                    <strong>{insights.rightOnlyTargets.length}</strong>
                  </div>
                  <div className="architecture-context-item">
                    <span className="label">Общие источники</span>
                    <strong>{insights.commonSources.length}</strong>
                  </div>
                </div>
              </div>

              <div className="architecture-reco-card">
                <div className="architecture-reco-kicker">Как это рефакторить</div>
                <div className="architecture-reco-title">{refactorAdvice.title}</div>
                <div className="architecture-reco-text">{refactorAdvice.summary}</div>
                <div className="architecture-reco-action">{refactorAdvice.pattern}</div>
                <div className="architecture-checklist">
                  {refactorAdvice.steps.map((item) => (
                    <div key={item} className="architecture-checklist-item">
                      <span className="architecture-checkmark">•</span>
                      <span>{item}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            <div className="logic-audit-compare-grid">
              <div className="logic-audit-compare-card is-same">
                <div className="logic-audit-mini-title">Одинаковые расчётные поля</div>
                <div className="logic-audit-targets">
                  {insights.commonTargets.length ? insights.commonTargets.map((target, idx) => (
                    <div key={`common-target-${idx}`} className="logic-audit-target-row">
                      <span className="mono">{target.alias || `expr_${idx + 1}`}</span>
                      <span className="muted">{target.expression}</span>
                    </div>
                  )) : <div className="muted">Не удалось выделить общее ядро по SELECT-полям.</div>}
                </div>
              </div>
              <div className="logic-audit-compare-card is-diff">
                <div className="logic-audit-mini-title">Что не входит в общее ядро</div>
                <div className="architecture-block-diff-grid">
                  <div>
                    <div className="logic-audit-compare-label">Только в левом блоке</div>
                    <div className="logic-audit-targets">
                      {insights.leftOnlyTargets.length ? insights.leftOnlyTargets.map((target, idx) => (
                        <div key={`left-only-${idx}`} className="logic-audit-target-row">
                          <span className="mono">{target.alias || `expr_${idx + 1}`}</span>
                          <span className="muted">{target.expression}</span>
                        </div>
                      )) : <div className="muted">Уникальных полей нет.</div>}
                    </div>
                  </div>
                  <div>
                    <div className="logic-audit-compare-label">Только в правом блоке</div>
                    <div className="logic-audit-targets">
                      {insights.rightOnlyTargets.length ? insights.rightOnlyTargets.map((target, idx) => (
                        <div key={`right-only-${idx}`} className="logic-audit-target-row">
                          <span className="mono">{target.alias || `expr_${idx + 1}`}</span>
                          <span className="muted">{target.expression}</span>
                        </div>
                      )) : <div className="muted">Уникальных полей нет.</div>}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Совпадает / отличается</div>
            <div className="logic-audit-compare-grid">
              <div className="logic-audit-compare-card is-same">
                <div className="logic-audit-mini-title">Совпадает</div>
                {!data.comparison?.same?.length && <div className="muted">Явных совпадений не выделено.</div>}
                {(data.comparison?.same || []).map((row) => (
                  <div className="logic-audit-compare-row" key={`same-${row.label}`}>
                    <div className="logic-audit-compare-label">{row.label}</div>
                    <div className="logic-audit-tags">
                      {(row.items || []).map((item) => (
                        <span key={`same-${row.label}-${item}`} className="logic-audit-tag mono">{item}</span>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
              <div className="logic-audit-compare-card is-diff">
                <div className="logic-audit-mini-title">Отличается</div>
                {!data.comparison?.different?.length && <div className="muted">Сильных отличий не найдено.</div>}
                {(data.comparison?.different || []).map((row) => (
                  <div className="logic-audit-compare-row" key={`diff-${row.label}`}>
                    <div className="logic-audit-compare-label">{row.label}</div>
                    <div className="logic-audit-tags">
                      {(row.items || []).map((item) => (
                        <span key={`diff-${row.label}-${item}`} className="logic-audit-tag mono">{item}</span>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Левый и правый блок</div>
            <div className="logic-audit-detail-grid">
              {[{ key: "left", title: "Block A" }, { key: "right", title: "Block B" }].map((side) => {
                const block = data[side.key] || {};
                const feature = data[`${side.key}_features`] || {};
                return (
                  <div key={side.key} className="logic-audit-detail-card">
                    <div className="logic-audit-detail-head">
                      <div className="logic-audit-detail-title">{side.title}</div>
                      <button className="btn btn-secondary" onClick={() => openTable(block.fqn)}>
                        Открыть таблицу
                      </button>
                    </div>
                    <div className="mono logic-audit-fqn-big">{block.fqn}</div>
                    <div className="architecture-row-meta">
                      <span>{block.entity_name || "Без сущности"}</span>
                      <span>{formatBlockType(block.block_type)}</span>
                      <span>{block.block_id || "—"}</span>
                    </div>
                    <div className="logic-audit-mini-title">Фичи блока</div>
                    <div className="logic-audit-tags">
                      {(feature.functions || []).slice(0, 12).map((fn) => (
                        <span key={`${side.key}-${fn}`} className="logic-audit-tag">fn:{fn}</span>
                      ))}
                      {(feature.source_tables || []).slice(0, 12).map((src) => (
                        <span key={`${side.key}-${src}`} className="logic-audit-tag mono">src:{src}</span>
                      ))}
                    </div>
                    <div className="logic-audit-mini-title">WHERE / фильтр блока</div>
                    <pre className="architecture-sql-pre architecture-sql-pre-compact">{block.where_clause || "—"}</pre>
                    <div className="logic-audit-mini-title">Совпавшие выражения и alias</div>
                    <div className="logic-audit-targets">
                      {(block.select_targets || []).slice(0, 12).map((target, idx) => (
                        <div key={`${side.key}-${idx}`} className="logic-audit-target-row">
                          <span className="mono">{target.alias || `expr_${idx + 1}`}</span>
                          <span className="muted">{target.expression}</span>
                        </div>
                      ))}
                    </div>
                    <div className="logic-audit-mini-title">SQL блока</div>
                    <pre className="architecture-sql-pre">{block.sql_preview || "—"}</pre>
                  </div>
                );
              })}
            </div>
          </section>
        </>
      ) : null}
    </div>
  );
}
