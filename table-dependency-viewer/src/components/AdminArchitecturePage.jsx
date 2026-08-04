import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { adminApi } from "../api/admin.js";

const ISSUE_LABELS = {
  duplicate_exact: "Полные дубли",
  duplicate_candidate: "Кандидаты на дубли",
  similar_candidate: "Похожие блоки",
};

function formatPercent(value) {
  return `${Math.round(Number(value || 0) * 100)}%`;
}

function shortText(value, limit = 120) {
  const text = String(value || "").trim();
  if (!text) return "—";
  if (text.length <= limit) return text;
  return `${text.slice(0, limit - 1)}…`;
}

function buildObjectStats(pairs) {
  const map = new Map();

  const pushRow = (fqn, entity, pair) => {
    if (!fqn) return;
    const current = map.get(fqn) || {
      fqn,
      entities: new Set(),
      hits: 0,
      exactCount: 0,
      highCount: 0,
      scoreSum: 0,
      maxScore: 0,
      issueTypes: new Set(),
      sampleHints: [],
    };
    current.hits += 1;
    current.scoreSum += Number(pair.score || 0);
    current.maxScore = Math.max(current.maxScore, Number(pair.score || 0));
    if (entity) current.entities.add(entity);
    if (pair.issue_type) current.issueTypes.add(pair.issue_type);
    if (pair.issue_type === "duplicate_exact") current.exactCount += 1;
    if ((pair.merge_potential || "").toUpperCase() === "HIGH") current.highCount += 1;
    if (Array.isArray(pair.diff_hints)) {
      pair.diff_hints.forEach((item) => {
        if (item && current.sampleHints.length < 4 && !current.sampleHints.includes(item)) {
          current.sampleHints.push(item);
        }
      });
    }
    map.set(fqn, current);
  };

  pairs.forEach((pair) => {
    pushRow(pair.left_fqn, pair.left_entity, pair);
    pushRow(pair.right_fqn, pair.right_entity, pair);
  });

  return [...map.values()].map((item) => ({
    ...item,
    avgScore: item.hits ? item.scoreSum / item.hits : 0,
    entities: [...item.entities],
    issueTypes: [...item.issueTypes],
  }));
}

function buildEntityStats(pairs) {
  const map = new Map();

  const track = (entity, pair) => {
    const key = String(entity || "Без сущности").trim() || "Без сущности";
    const current = map.get(key) || {
      entity: key,
      pairs: 0,
      highCount: 0,
      exactCount: 0,
      scoreSum: 0,
      objects: new Set(),
    };
    current.pairs += 1;
    current.scoreSum += Number(pair.score || 0);
    if ((pair.merge_potential || "").toUpperCase() === "HIGH") current.highCount += 1;
    if (pair.issue_type === "duplicate_exact") current.exactCount += 1;
    if (pair.left_fqn) current.objects.add(pair.left_fqn);
    if (pair.right_fqn) current.objects.add(pair.right_fqn);
    map.set(key, current);
  };

  pairs.forEach((pair) => {
    track(pair.left_entity, pair);
    if ((pair.right_entity || "") !== (pair.left_entity || "")) {
      track(pair.right_entity, pair);
    }
  });

  return [...map.values()].map((item) => ({
    ...item,
    avgScore: item.pairs ? item.scoreSum / item.pairs : 0,
    objectsCount: item.objects.size,
  }));
}

export default function AdminArchitecturePage() {
  const navigate = useNavigate();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    setLoading(true);
    setError(null);
    adminApi.architectureWorkbench()
      .then((payload) => setData(payload || null))
      .catch((err) => setError(err.message || "Не удалось загрузить архитектурный workbench"))
      .finally(() => setLoading(false));
  }, []);

  const pairs = data?.pairs || [];

  const objectStats = useMemo(() => buildObjectStats(pairs), [pairs]);
  const entityStats = useMemo(() => buildEntityStats(pairs), [pairs]);

  const topCandidates = useMemo(
    () =>
      [...objectStats]
        .sort((a, b) => (
          (b.highCount - a.highCount) ||
          (b.exactCount - a.exactCount) ||
          (b.hits - a.hits) ||
          (b.avgScore - a.avgScore)
        ))
        .slice(0, 12),
    [objectStats],
  );

  const exactDuplicates = useMemo(
    () => pairs.filter((row) => row.issue_type === "duplicate_exact").slice(0, 12),
    [pairs],
  );

  const similarFamilies = useMemo(
    () =>
      [...entityStats]
        .sort((a, b) => (
          (b.highCount - a.highCount) ||
          (b.pairs - a.pairs) ||
          (b.avgScore - a.avgScore)
        ))
        .slice(0, 10),
    [entityStats],
  );

  const crossEntityPairs = useMemo(
    () =>
      pairs
        .filter((row) => row.left_entity && row.right_entity && row.left_entity !== row.right_entity)
        .sort((a, b) => (
          (Number(b.score || 0) - Number(a.score || 0)) ||
          String(a.left_entity || "").localeCompare(String(b.left_entity || ""))
        ))
        .slice(0, 10),
    [pairs],
  );

  const summary = useMemo(() => ({
    objects: data?.objects_count || 0,
    pairs: pairs.length,
    exact: pairs.filter((row) => row.issue_type === "duplicate_exact").length,
    high: pairs.filter((row) => (row.merge_potential || "").toUpperCase() === "HIGH").length,
  }), [data?.objects_count, pairs]);

  const openLogicAudit = (fqn) => {
    if (!fqn) return;
    navigate(`/logic-audit?table=${encodeURIComponent(fqn)}`);
  };

  const openTable = (fqn) => {
    if (!fqn || !fqn.includes(".")) return;
    const [schema, ...rest] = fqn.split(".");
    navigate(`/table/${encodeURIComponent(schema)}/${encodeURIComponent(rest.join("."))}`);
  };

  return (
    <div className="container cc-page">
      <section className="cc-header-zone">
        <button className="btn" onClick={() => navigate("/")}>← Назад</button>
        <h1>Архитектурный Workbench</h1>
        <div className="cc-subtitle">
          Admin-only экран для поиска повторяющейся логики, кандидатов на схлопывание и зон риска в SQL-ландшафте.
        </div>
      </section>

      <section className="cc-surface architecture-page">
        <div className="section-title">Что это показывает</div>
        <div className="architecture-intro-grid">
          <div className="architecture-intro-card">
            <div className="architecture-intro-title">Кандидаты на схлопывание</div>
            <div className="muted">Объекты, которые слишком часто участвуют в похожих или дублирующихся расчётах.</div>
          </div>
          <div className="architecture-intro-card">
            <div className="architecture-intro-title">Семейства логики</div>
            <div className="muted">Сущности и направления, где одни и те же шаблоны расчётов живут в нескольких реализациях.</div>
          </div>
          <div className="architecture-intro-card">
            <div className="architecture-intro-title">Риск изменения</div>
            <div className="muted">Где один и тот же блок затрагивает много downstream-объектов и требует аккуратной консолидации.</div>
          </div>
        </div>
      </section>

      {loading && <div className="muted">Загружаю архитектурный workbench...</div>}
      {error && <div className="login-error">{error}</div>}

      {!loading && !error && data ? (
        <>
          <section className="cc-surface">
            <div className="section-title">Сводка</div>
            <div className="architecture-kpis">
              <div className="architecture-kpi">
                <div className="label">Объектов в аудите</div>
                <div className="value">{summary.objects}</div>
              </div>
              <div className="architecture-kpi">
                <div className="label">Найдено пар</div>
                <div className="value">{summary.pairs}</div>
              </div>
              <div className="architecture-kpi">
                <div className="label">Полные дубли</div>
                <div className="value">{summary.exact}</div>
              </div>
              <div className="architecture-kpi">
                <div className="label">HIGH merge potential</div>
                <div className="value">{summary.high}</div>
              </div>
            </div>
          </section>

          <section className="architecture-grid">
            <section className="cc-surface architecture-block">
              <div className="section-title">Кандидаты на схлопывание</div>
              <div className="section-subtitle">
                Чем больше `HIGH`, `exact` и средняя похожесть, тем выше шанс, что логику стоит вынести в общий слой.
              </div>
              <div className="architecture-list">
                {topCandidates.map((item) => (
                  <article key={item.fqn} className="architecture-row-card">
                    <div className="architecture-row-head">
                      <button type="button" className="architecture-link mono" onClick={() => openLogicAudit(item.fqn)}>
                        {item.fqn}
                      </button>
                      <div className="architecture-row-badges">
                        <span className="architecture-badge">{item.hits} пар</span>
                        <span className="architecture-badge">{item.highCount} HIGH</span>
                        <span className="architecture-badge">{item.exactCount} exact</span>
                        <span className="architecture-badge accent">{formatPercent(item.avgScore)}</span>
                      </div>
                    </div>
                    <div className="architecture-row-meta">
                      <span>{item.entities[0] || "Без сущности"}</span>
                      <span>{item.issueTypes.map((type) => ISSUE_LABELS[type] || type).join(" · ")}</span>
                    </div>
                    <div className="architecture-tags">
                      {item.sampleHints.map((hint) => (
                        <span key={`${item.fqn}-${hint}`} className="architecture-tag">{hint}</span>
                      ))}
                    </div>
                    <div className="architecture-actions">
                      <button type="button" className="btn btn-secondary" onClick={() => openTable(item.fqn)}>
                        Открыть таблицу
                      </button>
                      <button type="button" className="btn btn-ghost" onClick={() => openLogicAudit(item.fqn)}>
                        Открыть аудит
                      </button>
                    </div>
                  </article>
                ))}
              </div>
            </section>

            <section className="cc-surface architecture-block">
              <div className="section-title">Семейства повторяющейся логики</div>
              <div className="architecture-family-list">
                {similarFamilies.map((item) => (
                  <div key={item.entity} className="architecture-family-card">
                    <div className="architecture-family-head">
                      <strong>{item.entity}</strong>
                      <span className="architecture-badge accent">{formatPercent(item.avgScore)}</span>
                    </div>
                    <div className="architecture-family-bar">
                      <div
                        className="architecture-family-fill"
                        style={{ width: `${Math.min(100, item.highCount * 12 + item.pairs * 3)}%` }}
                      />
                    </div>
                    <div className="architecture-family-meta">
                      <span>{item.pairs} пар</span>
                      <span>{item.highCount} HIGH</span>
                      <span>{item.objectsCount} объектов</span>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          </section>

          <section className="architecture-grid">
            <section className="cc-surface architecture-block">
              <div className="section-title">Точные дубли</div>
              <div className="section-subtitle">
                Пары с максимальным шансом на прямую консолидацию или вынос общего расчёта.
              </div>
              <div className="architecture-list compact">
                {exactDuplicates.map((pair) => (
                  <article key={pair.pair_id} className="architecture-row-card compact">
                    <div className="architecture-row-head">
                      <div className="architecture-pair mono">{pair.left_fqn} ↔ {pair.right_fqn}</div>
                      <span className="architecture-badge accent">{formatPercent(pair.score)}</span>
                    </div>
                    <div className="architecture-row-meta">
                      <span>{pair.left_entity || "—"}</span>
                      <span>{pair.right_entity || "—"}</span>
                      <span>{pair.expression_overlap_count || 0} expr</span>
                    </div>
                    <div className="muted">{shortText((pair.diff_hints || []).join(" · "))}</div>
                  </article>
                ))}
              </div>
            </section>

            <section className="cc-surface architecture-block">
              <div className="section-title">Кросс-сущностные повторы</div>
              <div className="section-subtitle">
                Здесь особенно высокий шанс, что одинаковый расчёт был реализован в разных направлениях независимо.
              </div>
              <div className="architecture-list compact">
                {crossEntityPairs.map((pair) => (
                  <article key={pair.pair_id} className="architecture-row-card compact">
                    <div className="architecture-row-head">
                      <div className="architecture-pair mono">{pair.left_fqn} ↔ {pair.right_fqn}</div>
                      <span className="architecture-badge accent">{formatPercent(pair.score)}</span>
                    </div>
                    <div className="architecture-row-meta">
                      <span>{pair.left_entity || "—"}</span>
                      <span>{pair.right_entity || "—"}</span>
                      <span>{ISSUE_LABELS[pair.issue_type] || pair.issue_type}</span>
                    </div>
                    <div className="muted">{shortText((pair.diff_hints || []).join(" · "))}</div>
                  </article>
                ))}
              </div>
            </section>
          </section>
        </>
      ) : null}
    </div>
  );
}
