import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

function splitFqn(fqn) {
  if (!fqn || !fqn.includes(".")) return null;
  const [schema, ...rest] = fqn.split(".");
  const table = rest.join(".");
  if (!schema || !table) return null;
  return { schema, table };
}

export default function LogicAuditPage() {
  const navigate = useNavigate();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const [issueType, setIssueType] = useState("all");
  const [mode, setMode] = useState("standard");
  const [minScore, setMinScore] = useState(0.72);
  const [search, setSearch] = useState("");

  const [selectedPairId, setSelectedPairId] = useState(null);
  const [pairDetails, setPairDetails] = useState(null);
  const [pairLoading, setPairLoading] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    const params = new URLSearchParams({
      issue_type: issueType,
      mode,
      min_score: String(minScore),
      limit: "400",
      search,
    });

    fetch(`${API_BASE}/api/logic-audit?${params.toString()}`)
      .then((res) => (res.ok ? res.json() : Promise.reject(`HTTP ${res.status}`)))
      .then((json) => {
        if (!cancelled) setData(json);
      })
      .catch((err) => {
        if (!cancelled) setError(typeof err === "string" ? err : "Failed to load logic audit");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [issueType, mode, minScore, search]);

  useEffect(() => {
    if (!selectedPairId) {
      setPairDetails(null);
      return;
    }

    let cancelled = false;
    setPairLoading(true);

    fetch(`${API_BASE}/api/logic-audit/pair/${encodeURIComponent(selectedPairId)}`)
      .then((res) => (res.ok ? res.json() : Promise.reject(`HTTP ${res.status}`)))
      .then((json) => {
        if (!cancelled) setPairDetails(json);
      })
      .catch(() => {
        if (!cancelled) setPairDetails(null);
      })
      .finally(() => {
        if (!cancelled) setPairLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [selectedPairId]);

  const pairs = useMemo(() => data?.pairs || [], [data]);

  const openTable = (fqn) => {
    const parsed = splitFqn(fqn);
    if (!parsed) return;
    navigate(`/table/${encodeURIComponent(parsed.schema)}/${encodeURIComponent(parsed.table)}`);
  };

  return (
    <div className="container cc-page">
      <section className="cc-header-zone">
        <button className="btn" onClick={() => navigate("/")}>← Назад</button>
        <h1>Logic Audit</h1>
        <div className="cc-subtitle">Поиск дублирующейся и слишком похожей SQL-логики между объектами.</div>
      </section>

      <section className="cc-surface">
        <div className="section-title">Фильтры</div>
        <div className="logic-audit-filters">
          <label className="logic-audit-field">
            Тип
            <select value={issueType} onChange={(e) => setIssueType(e.target.value)}>
              <option value="all">Все</option>
              <option value="duplicate_exact">Полные дубликаты</option>
              <option value="duplicate_candidate">Кандидаты на дубли</option>
              <option value="similar_candidate">Похожие</option>
            </select>
          </label>
          <label className="logic-audit-field">
            Режим
            <select value={mode} onChange={(e) => setMode(e.target.value)}>
              <option value="standard">Стандартный</option>
              <option value="strict">Строгий (пересечение полей)</option>
            </select>
          </label>
          <label className="logic-audit-field">
            Min score
            <select value={String(minScore)} onChange={(e) => setMinScore(Number(e.target.value))}>
              {[0.72, 0.78, 0.84, 0.9].map((v) => (
                <option key={v} value={v}>{v}</option>
              ))}
            </select>
          </label>
          <label className="logic-audit-field logic-audit-field-wide">
            Поиск
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="schema.table, entity..."
            />
          </label>
        </div>
        <div className="muted">Min score — минимальный общий коэффициент похожести (от 0 до 1).</div>
      </section>

      {loading && <div className="muted">Загружаю аудит...</div>}
      {error && <div className="dep-error-title">{error}</div>}

      {!loading && !error && data && (
        <>
          <section className="logic-audit-kpis">
            <div className="logic-audit-kpi">
              <div className="label">Объектов</div>
              <div className="value">{data.objects_count ?? 0}</div>
            </div>
            <div className="logic-audit-kpi">
              <div className="label">Найдено пар</div>
              <div className="value">{data.returned_count ?? 0}</div>
            </div>
            <div className="logic-audit-kpi">
              <div className="label">Полные дубли</div>
              <div className="value">{data.stats?.duplicate_exact ?? 0}</div>
            </div>
            <div className="logic-audit-kpi">
              <div className="label">Потенциал merge</div>
              <div className="value">{pairs.filter((x) => x.merge_potential === "HIGH").length}</div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Найденные пары</div>
            {!pairs.length && <div className="muted">Ничего не найдено по текущим фильтрам.</div>}
            <div className="logic-audit-list">
              {pairs.map((pair) => (
                <button
                  key={pair.pair_id}
                  className={`logic-audit-card ${selectedPairId === pair.pair_id ? "active" : ""}`}
                  onClick={() => setSelectedPairId(pair.pair_id)}
                >
                  <div className="logic-audit-card-head">
                    <span className="logic-audit-score">{Math.round((pair.score || 0) * 100)}%</span>
                    <span className={`logic-audit-pill tone-${(pair.merge_potential || "LOW").toLowerCase()}`}>
                      {pair.merge_potential || "LOW"}
                    </span>
                    <span className="logic-audit-type">{pair.issue_type}</span>
                    <span className="logic-audit-type">expr: {pair.expression_overlap_count || 0}</span>
                  </div>
                  <div className="logic-audit-fqns">
                    <span className="mono">{pair.left_fqn}</span>
                    <span>↔</span>
                    <span className="mono">{pair.right_fqn}</span>
                  </div>
                  <div className="muted">{(pair.diff_hints || []).join(" · ")}</div>
                </button>
              ))}
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Детали</div>
            {!selectedPairId && <div className="muted">Выберите пару, чтобы провалиться в детали.</div>}
            {pairLoading && <div className="muted">Загружаю детали пары...</div>}
            {!pairLoading && pairDetails && (
              <>
                <div className="logic-audit-explain">
                  <div className="logic-audit-mini-title">Итог по паре</div>
                  <div>{pairDetails.explanation?.summary}</div>
                  <div className="logic-audit-explain-decision">{pairDetails.explanation?.decision}</div>
                </div>
                <div className="logic-audit-compare-grid">
                  <div className="logic-audit-compare-card is-same">
                    <div className="logic-audit-mini-title">Совпадает</div>
                    {!pairDetails.comparison?.same?.length && <div className="muted">Явных совпадений не выделено.</div>}
                    {(pairDetails.comparison?.same || []).map((row) => (
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
                    {!pairDetails.comparison?.different?.length && <div className="muted">Сильных отличий не найдено.</div>}
                    {(pairDetails.comparison?.different || []).map((row) => (
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
                <div className="logic-audit-detail-grid">
                  {[{ key: "left", title: "Object A" }, { key: "right", title: "Object B" }].map((side) => {
                  const obj = pairDetails[side.key] || {};
                  const feature = pairDetails[`${side.key}_features`] || {};
                  return (
                    <div key={side.key} className="logic-audit-detail-card">
                      <div className="logic-audit-detail-head">
                        <div className="logic-audit-detail-title">{side.title}</div>
                        <button className="btn btn-secondary" onClick={() => openTable(obj.fqn)}>
                          Открыть таблицу
                        </button>
                      </div>
                      <div className="mono logic-audit-fqn-big">{obj.fqn}</div>
                      <div className="muted">{obj.story}</div>
                      <div className="logic-audit-mini-title">Фичи SQL</div>
                      <div className="logic-audit-tags">
                        {(feature.functions || []).slice(0, 12).map((fn) => (
                          <span key={`${side.key}-${fn}`} className="logic-audit-tag">fn:{fn}</span>
                        ))}
                        {(feature.source_tables || []).slice(0, 10).map((src) => (
                          <span key={`${side.key}-${src}`} className="logic-audit-tag mono">src:{src}</span>
                        ))}
                      </div>
                      <div className="logic-audit-mini-title">SELECT-выражения</div>
                      <div className="logic-audit-targets">
                        {(obj.select_targets || []).slice(0, 8).map((target, idx) => (
                          <div key={`${side.key}-${idx}`} className="logic-audit-target-row">
                            <span className="mono">{target.alias || `expr_${idx + 1}`}</span>
                            <span className="muted">{target.expression}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  );
                  })}
                </div>
              </>
            )}
          </section>
        </>
      )}
    </div>
  );
}
