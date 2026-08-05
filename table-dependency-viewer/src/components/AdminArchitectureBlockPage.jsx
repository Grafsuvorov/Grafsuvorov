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
