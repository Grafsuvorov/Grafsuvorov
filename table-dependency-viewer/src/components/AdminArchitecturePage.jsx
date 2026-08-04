import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { adminApi } from "../api/admin.js";

const ISSUE_LABELS = {
  duplicate_exact: "Полные дубли",
  duplicate_candidate: "Кандидаты на дубли",
  similar_candidate: "Похожие блоки",
};

const RECOMMENDATION_FILTERS = [
  { id: "all", label: "Все" },
  { id: "shared", label: "Общий слой" },
  { id: "collapse", label: "Схлопывание" },
  { id: "semantic", label: "Семантический конфликт" },
  { id: "manual", label: "Ручной разбор" },
];

function formatPercent(value) {
  return `${Math.round(Number(value || 0) * 100)}%`;
}

function shortText(value, limit = 120) {
  const text = String(value || "").trim();
  if (!text) return "—";
  if (text.length <= limit) return text;
  return `${text.slice(0, limit - 1)}…`;
}

function formatDateTime(value) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleString("ru-RU", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function buildPressureScore(item) {
  const releaseScore = Number(item.releasesCount || 0) * 4;
  const incidentScore = Number(item.incidentsCount || 0) * 14;
  const downstreamScore = Number(item.transitiveDownstreamCount || 0) * 2;
  const duplicateScore = Number(item.highCount || 0) * 6 + Number(item.exactCount || 0) * 10;
  return Math.min(100, Math.round(releaseScore + incidentScore + downstreamScore + duplicateScore));
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

function buildObjectCluster(fqn, pairs) {
  const related = pairs.filter((pair) => pair.left_fqn === fqn || pair.right_fqn === fqn);
  if (!related.length) return null;
  const peerMap = new Map();
  const issueTypes = new Set();
  const entities = new Set();
  const hints = [];
  let exactCount = 0;
  let highCount = 0;
  let scoreSum = 0;

  related.forEach((pair) => {
    const peer = pair.left_fqn === fqn ? pair.right_fqn : pair.left_fqn;
    const peerEntity = pair.left_fqn === fqn ? pair.right_entity : pair.left_entity;
    issueTypes.add(pair.issue_type);
    if (pair.left_entity) entities.add(pair.left_entity);
    if (pair.right_entity) entities.add(pair.right_entity);
    if (pair.issue_type === "duplicate_exact") exactCount += 1;
    if ((pair.merge_potential || "").toUpperCase() === "HIGH") highCount += 1;
    scoreSum += Number(pair.score || 0);
    if (Array.isArray(pair.diff_hints)) {
      pair.diff_hints.forEach((hint) => {
        if (hint && hints.length < 8 && !hints.includes(hint)) hints.push(hint);
      });
    }
    if (!peerMap.has(peer)) {
      peerMap.set(peer, {
        fqn: peer,
        entity: peerEntity || "Без сущности",
        issueType: pair.issue_type,
        score: Number(pair.score || 0),
        overlap: pair.expression_overlap_count || 0,
        mergePotential: pair.merge_potential || "LOW",
        hints: pair.diff_hints || [],
      });
    }
  });

  return {
    fqn,
    related,
    peers: [...peerMap.values()].sort((a, b) => b.score - a.score).slice(0, 12),
    issues: [...issueTypes],
    entities: [...entities],
    exactCount,
    highCount,
    avgScore: related.length ? scoreSum / related.length : 0,
    hints,
  };
}

function buildRecommendation(cluster) {
  if (!cluster) return null;
  const crossEntity = new Set(cluster.peers.map((item) => item.entity).filter(Boolean)).size > 1;
  const exactDominates = cluster.exactCount >= 2 || (cluster.exactCount >= 1 && cluster.avgScore >= 0.9);
  const highDominates = cluster.highCount >= 3 || (cluster.highCount >= 2 && cluster.avgScore >= 0.86);
  let title = "Нужен ручной разбор";
  let kind = "manual";
  let action = "Проверить, не разошлась ли одна и та же бизнес-логика в нескольких объектах.";
  let rationale = "Похожесть есть, но паттерн ещё не выглядит как безопасный кандидат на прямое схлопывание.";

  if (exactDominates) {
    title = "Выносить в общий слой";
    kind = "shared";
    action = "Кандидат на shared CTE, reusable model или единый вычислительный блок.";
    rationale = "Есть точные дубли или почти идентичные пары с очень высоким score.";
  } else if (highDominates && crossEntity) {
    title = "Проверить конфликт бизнес-логики";
    kind = "semantic";
    action = "Сначала сравнить смысл расчёта между направлениями, потом решать вопрос консолидации.";
    rationale = "Высокая похожесть идёт через разные сущности, значит одинаковый расчёт мог разойтись семантически.";
  } else if (highDominates) {
    title = "Кандидат на схлопывание";
    kind = "collapse";
    action = "Можно собирать family review и выносить повторяющиеся части в общий шаблон.";
    rationale = "Объект стабильно участвует в HIGH-парах и повторяется в одном логическом контуре.";
  }

  return {
    kind,
    title,
    action,
    rationale,
  };
}

function buildAiBrief(cluster, recommendation) {
  if (!cluster || !recommendation) return "";
  return [
    `Объект ${cluster.fqn} участвует в ${cluster.related.length} похожих парах.`,
    `Средняя похожесть ${formatPercent(cluster.avgScore)}, HIGH-пар: ${cluster.highCount}, exact: ${cluster.exactCount}.`,
    cluster.entities.length ? `Контекст сущностей: ${cluster.entities.join(", ")}.` : "",
    cluster.hints.length ? `Ключевые сигналы: ${cluster.hints.slice(0, 4).join("; ")}.` : "",
    `Рекомендация: ${recommendation.title}. ${recommendation.action}`,
  ].filter(Boolean).join(" ");
}

function buildChecklist(cluster, recommendation) {
  if (!cluster || !recommendation) return [];
  const items = [
    "Проверить, совпадает ли бизнес-смысл расчёта у всех peer-объектов.",
    "Сравнить поля SELECT и критичные фильтры в парных объектах.",
    "Оценить, можно ли вынести общий CTE или intermediate model без изменения downstream-поведения.",
    "Проверить релизы и недавние инциденты для этих объектов перед рефакторингом.",
  ];
  if (recommendation.kind === "shared") {
    items.unshift("Выделить единый reusable block и определить одного владельца логики.");
  }
  if (recommendation.kind === "semantic") {
    items.unshift("Согласовать определение метрики/правила между направлениями до схлопывания.");
  }
  if (cluster.exactCount > 0) {
    items.push("Проверить, нет ли копий с различием только в именах витрин или схем.");
  }
  return items;
}

function buildAiPayload(cluster, recommendation, checklist, context = null) {
  if (!cluster || !recommendation) return null;
  return {
    generated_at: new Date().toISOString(),
    object_fqn: cluster.fqn,
    entities: cluster.entities,
    related_pairs_count: cluster.related.length,
    avg_similarity_score: Number(cluster.avgScore.toFixed(4)),
    exact_count: cluster.exactCount,
    high_count: cluster.highCount,
    recommendation,
    hints: cluster.hints,
    peers: cluster.peers.map((peer) => ({
      fqn: peer.fqn,
      entity: peer.entity,
      issue_type: peer.issueType,
      similarity_score: Number(peer.score.toFixed(4)),
      expression_overlap_count: peer.overlap,
      merge_potential: peer.mergePotential,
      hints: peer.hints,
    })),
    checklist,
    operational_context: context ? {
      releases_count: Number(context.releasesCount || 0),
      release_objects_count: Number(context.releaseObjectsCount || 0),
      release_tasks_count: Number(context.releaseTasksCount || 0),
      incidents_count: Number(context.incidentsCount || 0),
      direct_upstream_count: Number(context.directUpstreamCount || 0),
      direct_downstream_count: Number(context.directDownstreamCount || 0),
      transitive_downstream_count: Number(context.transitiveDownstreamCount || 0),
      downstream_entities_count: Number(context.downstreamEntitiesCount || 0),
      downstream_entities: context.downstream_entities || context.downstreamEntities || [],
      last_change: context.lastChange || null,
      latest_release: context.latestRelease || null,
      latest_incident: context.latestIncident || null,
      pressure_score: Number(context.pressureScore || 0),
    } : null,
  };
}

function buildMarkdownReport(cluster, recommendation, checklist, aiBrief, context = null) {
  if (!cluster || !recommendation) return "";
  const peerLines = cluster.peers.map((peer) =>
    `- ${peer.fqn} | ${peer.entity} | ${ISSUE_LABELS[peer.issueType] || peer.issueType} | ${formatPercent(peer.score)} | expr ${peer.overlap} | ${peer.mergePotential}`
  );
  const checklistLines = checklist.map((item) => `- ${item}`);
  return [
    `# Архитектурный кластер: ${cluster.fqn}`,
    "",
    `- Средняя похожесть: ${formatPercent(cluster.avgScore)}`,
    `- HIGH-пары: ${cluster.highCount}`,
    `- Exact-пары: ${cluster.exactCount}`,
    `- Сущности: ${cluster.entities.join(", ") || "Без сущности"}`,
    "",
    "## Рекомендация",
    `**${recommendation.title}**`,
    "",
    recommendation.rationale,
    "",
    recommendation.action,
    "",
    "## AI-ready summary",
    aiBrief,
    "",
    ...(context ? [
      "## Операционный контекст",
      `- Releases за окно: ${context.releasesCount || 0}`,
      `- Incidents за окно: ${context.incidentsCount || 0}`,
      `- Downstream (transitive): ${context.transitiveDownstreamCount || 0}`,
      `- Последний delivery-change: ${context.lastChange?.actor || "Не указан"} / ${context.lastChange?.changed_at || "—"}`,
      `- Последний инцидент: ${context.latestIncident?.issue_id || "—"} / ${context.latestIncident?.incident_start_dttm || "—"}`,
      "",
    ] : []),
    "",
    "## Peer-объекты",
    ...peerLines,
    "",
    "## Checklist",
    ...checklistLines,
  ].join("\n");
}

function buildHintStats(pairs) {
  const stats = new Map();
  pairs.forEach((pair) => {
    (pair.diff_hints || []).forEach((hint) => {
      const key = String(hint || "").trim();
      if (!key) return;
      const current = stats.get(key) || {
        hint: key,
        count: 0,
        highCount: 0,
        exactCount: 0,
      };
      current.count += 1;
      if ((pair.merge_potential || "").toUpperCase() === "HIGH") current.highCount += 1;
      if (pair.issue_type === "duplicate_exact") current.exactCount += 1;
      stats.set(key, current);
    });
  });
  return [...stats.values()].sort((a, b) => (
    (b.highCount - a.highCount) ||
    (b.exactCount - a.exactCount) ||
    (b.count - a.count) ||
    a.hint.localeCompare(b.hint)
  ));
}

function buildRecommendationPortfolio(candidates) {
  const buckets = new Map();
  candidates.forEach((item) => {
    const key = item.recommendation?.kind || "manual";
    const current = buckets.get(key) || {
      kind: key,
      title: item.recommendation?.title || "Нужен ручной разбор",
      count: 0,
      highCount: 0,
      exactCount: 0,
      avgScoreSum: 0,
    };
    current.count += 1;
    current.highCount += item.highCount || 0;
    current.exactCount += item.exactCount || 0;
    current.avgScoreSum += item.avgScore || 0;
    buckets.set(key, current);
  });
  return [...buckets.values()].map((item) => ({
    ...item,
    avgScore: item.count ? item.avgScoreSum / item.count : 0,
  })).sort((a, b) => b.count - a.count);
}

function buildRoadmap(candidates) {
  return {
    now: candidates
      .filter((item) => item.recommendation?.kind === "shared" || (item.exactCount >= 2 && item.highCount >= 1))
      .slice(0, 6),
    next: candidates
      .filter((item) => item.recommendation?.kind === "collapse")
      .slice(0, 6),
    watch: candidates
      .filter((item) => item.recommendation?.kind === "semantic" || item.recommendation?.kind === "manual")
      .slice(0, 6),
  };
}

function buildOwnerStats(candidates) {
  const buckets = new Map();
  candidates.forEach((item) => {
    const actor = item.lastChange?.actor || "Не указан";
    const current = buckets.get(actor) || {
      actor,
      objectsCount: 0,
      incidentsCount: 0,
      releasesCount: 0,
      pressureSum: 0,
    };
    current.objectsCount += 1;
    current.incidentsCount += Number(item.incidentsCount || 0);
    current.releasesCount += Number(item.releasesCount || 0);
    current.pressureSum += Number(item.pressureScore || 0);
    buckets.set(actor, current);
  });
  return [...buckets.values()]
    .map((item) => ({
      ...item,
      avgPressure: item.objectsCount ? item.pressureSum / item.objectsCount : 0,
    }))
    .sort((a, b) => (
      (b.objectsCount - a.objectsCount) ||
      (b.incidentsCount - a.incidentsCount) ||
      (b.avgPressure - a.avgPressure)
    ))
    .slice(0, 8);
}

function buildRiskMatrix(candidates) {
  const cells = new Map();
  const riskBand = (item) => {
    if ((item.pressureScore || 0) >= 75) return "Критичный";
    if ((item.pressureScore || 0) >= 45) return "Высокий";
    return "Средний";
  };
  const duplicateBand = (item) => {
    if ((item.exactCount || 0) >= 2) return "Точные";
    if ((item.highCount || 0) >= 2) return "Сильные";
    return "Наблюдение";
  };

  candidates.forEach((item) => {
    const row = riskBand(item);
    const col = duplicateBand(item);
    const key = `${row}|${col}`;
    const current = cells.get(key) || { row, col, count: 0, items: [] };
    current.count += 1;
    if (current.items.length < 3) current.items.push(item.fqn);
    cells.set(key, current);
  });

  const rowOrder = ["Критичный", "Высокий", "Средний"];
  const colOrder = ["Точные", "Сильные", "Наблюдение"];
  return rowOrder.flatMap((row) =>
    colOrder.map((col) => cells.get(`${row}|${col}`) || { row, col, count: 0, items: [] }),
  );
}

function buildOwnerAmbiguity(cluster, candidatesByFqn) {
  if (!cluster) return null;
  const rows = [cluster.fqn, ...cluster.peers.map((peer) => peer.fqn)]
    .map((fqn) => candidatesByFqn.get(fqn))
    .filter(Boolean);
  const owners = [...new Set(rows.map((row) => row.lastChange?.actor).filter(Boolean))];
  const incidentOwners = [...new Set(rows.filter((row) => row.incidentsCount > 0).map((row) => row.lastChange?.actor).filter(Boolean))];
  return {
    owners,
    ownerCount: owners.length,
    incidentOwners,
    incidentOwnerCount: incidentOwners.length,
    hasAmbiguity: owners.length >= 3,
    rows,
  };
}

function buildActivityTimeline(candidate) {
  if (!candidate) return [];
  const events = [];
  if (candidate.lastChange?.changed_at) {
    events.push({
      id: `change-${candidate.fqn}`,
      type: "delivery_change",
      title: "Последний delivery-change",
      actor: candidate.lastChange.actor || "Не указан",
      at: candidate.lastChange.changed_at,
      meta: candidate.lastChange.release_id || candidate.lastChange.task_id || "—",
      text: candidate.lastChange.task_summary || "Последнее изменение через релизный контур.",
      link: candidate.lastChange.task_link || null,
    });
  }
  if (candidate.latestRelease?.started_at) {
    events.push({
      id: `release-${candidate.fqn}`,
      type: "release",
      title: "Последний релиз",
      actor: candidate.latestRelease.initiated_by || candidate.latestRelease.actor || "Не указан",
      at: candidate.latestRelease.started_at,
      meta: candidate.latestRelease.release_id || "—",
      text: candidate.latestRelease.task_summary || candidate.latestRelease.release_type || "Поставка объекта.",
      link: candidate.latestRelease.task_link || null,
    });
  }
  if (candidate.latestIncident?.incident_start_dttm) {
    events.push({
      id: `incident-${candidate.fqn}`,
      type: "incident",
      title: "Последний инцидент",
      actor: candidate.latestIncident.assignee_name || candidate.latestIncident.author_name || "Не указан",
      at: candidate.latestIncident.incident_start_dttm,
      meta: candidate.latestIncident.issue_id || "—",
      text: candidate.latestIncident.summary || candidate.latestIncident.incident_reason_name || "Инцидент по объекту.",
      link: candidate.latestIncident.link || null,
    });
  }
  return events
    .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime())
    .slice(0, 5);
}

function downloadTextFile(content, filename, type = "text/plain;charset=utf-8") {
  const blob = new Blob([content], { type });
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.URL.revokeObjectURL(url);
}

export default function AdminArchitecturePage() {
  const navigate = useNavigate();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [selectedObjectFqn, setSelectedObjectFqn] = useState(null);
  const [search, setSearch] = useState("");
  const [issueFilter, setIssueFilter] = useState("all");
  const [recommendationFilter, setRecommendationFilter] = useState("all");
  const [copyStatus, setCopyStatus] = useState("");

  useEffect(() => {
    setLoading(true);
    setError(null);
    adminApi.architectureWorkbench()
      .then((payload) => setData(payload || null))
      .catch((err) => setError(err.message || "Не удалось загрузить архитектурный workbench"))
      .finally(() => setLoading(false));
  }, []);

  const pairs = data?.pairs || [];
  const enrichment = data?.enrichment || {};
  const enrichmentSummary = data?.enrichment_summary || {};

  const objectStats = useMemo(() => buildObjectStats(pairs), [pairs]);
  const entityStats = useMemo(() => buildEntityStats(pairs), [pairs]);

  const topCandidates = useMemo(() => {
    const term = search.trim().toLowerCase();
    return [...objectStats]
      .map((item) => ({
        ...item,
        recommendation: buildRecommendation({
          fqn: item.fqn,
          peers: [],
          entities: item.entities,
          exactCount: item.exactCount,
          highCount: item.highCount,
          avgScore: item.avgScore,
        }),
        ...(enrichment[item.fqn] || {}),
      }))
      .filter((item) => {
        if (issueFilter !== "all" && !item.issueTypes.includes(issueFilter)) return false;
        if (recommendationFilter !== "all" && item.recommendation?.kind !== recommendationFilter) return false;
        if (!term) return true;
        return (
          item.fqn.toLowerCase().includes(term) ||
          item.entities.some((entity) => String(entity || "").toLowerCase().includes(term)) ||
          String(item.lastChange?.actor || "").toLowerCase().includes(term)
        );
      })
      .map((item) => ({
        ...item,
        releasesCount: Number(item.releases_count || 0),
        releaseObjectsCount: Number(item.release_objects_count || 0),
        releaseTasksCount: Number(item.release_tasks_count || 0),
        incidentsCount: Number(item.incidents_count || 0),
        directUpstreamCount: Number(item.direct_upstream_count || 0),
        directDownstreamCount: Number(item.direct_downstream_count || 0),
        transitiveDownstreamCount: Number(item.transitive_downstream_count || 0),
        downstreamEntitiesCount: Number(item.downstream_entities_count || 0),
        downstreamEntities: item.downstream_entities || [],
        latestRelease: item.latest_release || null,
        latestIncident: item.latest_incident || null,
        lastChange: item.last_change || null,
        pressureScore: buildPressureScore({
          ...item,
          releasesCount: Number(item.releases_count || 0),
          incidentsCount: Number(item.incidents_count || 0),
          transitiveDownstreamCount: Number(item.transitive_downstream_count || 0),
        }),
      }))
      .sort((a, b) => (
        (b.pressureScore - a.pressureScore) ||
        (b.highCount - a.highCount) ||
        (b.exactCount - a.exactCount) ||
        (b.hits - a.hits) ||
        (b.avgScore - a.avgScore)
      ))
      .slice(0, 18);
  }, [enrichment, issueFilter, objectStats, recommendationFilter, search]);

  useEffect(() => {
    if (!selectedObjectFqn && topCandidates.length) {
      setSelectedObjectFqn(topCandidates[0].fqn);
    }
  }, [selectedObjectFqn, topCandidates]);

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
    withReleases: enrichmentSummary.objects_with_releases || 0,
    withIncidents: enrichmentSummary.objects_with_incidents || 0,
    withDownstream: enrichmentSummary.objects_with_downstream || 0,
    withLastChange: enrichmentSummary.objects_with_last_change || 0,
  }), [data?.objects_count, enrichmentSummary.objects_with_downstream, enrichmentSummary.objects_with_incidents, enrichmentSummary.objects_with_last_change, enrichmentSummary.objects_with_releases, pairs]);

  const selectedCluster = useMemo(
    () => buildObjectCluster(selectedObjectFqn, pairs),
    [selectedObjectFqn, pairs],
  );

  const selectedRecommendation = useMemo(
    () => buildRecommendation(selectedCluster),
    [selectedCluster],
  );

  const aiBrief = useMemo(
    () => buildAiBrief(selectedCluster, selectedRecommendation),
    [selectedCluster, selectedRecommendation],
  );
  const checklist = useMemo(
    () => buildChecklist(selectedCluster, selectedRecommendation),
    [selectedCluster, selectedRecommendation],
  );
  const aiPayload = useMemo(
    () => buildAiPayload(selectedCluster, selectedRecommendation, checklist, selectedCandidate),
    [checklist, selectedCandidate, selectedCluster, selectedRecommendation],
  );
  const markdownReport = useMemo(
    () => buildMarkdownReport(selectedCluster, selectedRecommendation, checklist, aiBrief, selectedCandidate),
    [aiBrief, checklist, selectedCandidate, selectedCluster, selectedRecommendation],
  );
  const hintStats = useMemo(
    () => buildHintStats(pairs).slice(0, 10),
    [pairs],
  );
  const recommendationPortfolio = useMemo(
    () => buildRecommendationPortfolio(topCandidates),
    [topCandidates],
  );
  const roadmap = useMemo(
    () => buildRoadmap(topCandidates),
    [topCandidates],
  );
  const selectedCandidate = useMemo(
    () => topCandidates.find((item) => item.fqn === selectedObjectFqn) || null,
    [selectedObjectFqn, topCandidates],
  );
  const ownerStats = useMemo(
    () => buildOwnerStats(topCandidates),
    [topCandidates],
  );
  const topIncidentCandidates = useMemo(
    () => [...topCandidates]
      .filter((item) => item.incidentsCount > 0)
      .sort((a, b) => (
        (b.incidentsCount - a.incidentsCount) ||
        (b.pressureScore - a.pressureScore) ||
        (b.transitiveDownstreamCount - a.transitiveDownstreamCount)
      ))
      .slice(0, 8),
    [topCandidates],
  );
  const topBlastRadiusCandidates = useMemo(
    () => [...topCandidates]
      .filter((item) => item.transitiveDownstreamCount > 0)
      .sort((a, b) => (
        (b.transitiveDownstreamCount - a.transitiveDownstreamCount) ||
        (b.incidentsCount - a.incidentsCount) ||
        (b.pressureScore - a.pressureScore)
      ))
      .slice(0, 8),
    [topCandidates],
  );
  const candidatesByFqn = useMemo(
    () => new Map(topCandidates.map((item) => [item.fqn, item])),
    [topCandidates],
  );
  const selectedOwnerAmbiguity = useMemo(
    () => buildOwnerAmbiguity(selectedCluster, candidatesByFqn),
    [candidatesByFqn, selectedCluster],
  );
  const selectedTimeline = useMemo(
    () => buildActivityTimeline(selectedCandidate),
    [selectedCandidate],
  );
  const riskMatrix = useMemo(
    () => buildRiskMatrix(topCandidates),
    [topCandidates],
  );

  const openLogicAudit = (fqn) => {
    if (!fqn) return;
    navigate(`/logic-audit?table=${encodeURIComponent(fqn)}`);
  };

  const openTable = (fqn) => {
    if (!fqn || !fqn.includes(".")) return;
    const [schema, ...rest] = fqn.split(".");
    navigate(`/table/${encodeURIComponent(schema)}/${encodeURIComponent(rest.join("."))}`);
  };

  const copyAiPayload = async (mode = "json") => {
    const content = mode === "json"
      ? JSON.stringify(aiPayload, null, 2)
      : markdownReport;
    if (!content) return;
    try {
      await navigator.clipboard.writeText(content);
      setCopyStatus(mode === "json" ? "AI-context JSON скопирован." : "Markdown-отчёт скопирован.");
      window.setTimeout(() => setCopyStatus(""), 2400);
    } catch {
      setCopyStatus("Не удалось скопировать. Используйте экспорт.");
      window.setTimeout(() => setCopyStatus(""), 2400);
    }
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
              <div className="architecture-kpi">
                <div className="label">С релизной активностью</div>
                <div className="value">{summary.withReleases}</div>
              </div>
              <div className="architecture-kpi">
                <div className="label">С инцидентами</div>
                <div className="value">{summary.withIncidents}</div>
              </div>
              <div className="architecture-kpi">
                <div className="label">С downstream-следом</div>
                <div className="value">{summary.withDownstream}</div>
              </div>
              <div className="architecture-kpi">
                <div className="label">С известным last change</div>
                <div className="value">{summary.withLastChange}</div>
              </div>
            </div>
          </section>

          <section className="cc-surface architecture-block">
            <div className="section-title">Фокус и фильтры</div>
            <div className="logic-audit-filters">
              <label className="logic-audit-field logic-audit-field-wide">
                Поиск
                <input
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="schema.table или сущность"
                />
              </label>
              <label className="logic-audit-field">
                Тип пары
                <select value={issueFilter} onChange={(e) => setIssueFilter(e.target.value)}>
                  <option value="all">Все</option>
                  {Object.entries(ISSUE_LABELS).map(([id, label]) => (
                    <option key={id} value={id}>{label}</option>
                  ))}
                </select>
              </label>
              <label className="logic-audit-field">
                Рекомендация
                <select value={recommendationFilter} onChange={(e) => setRecommendationFilter(e.target.value)}>
                  {RECOMMENDATION_FILTERS.map((item) => (
                    <option key={item.id} value={item.id}>{item.label}</option>
                  ))}
                </select>
              </label>
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
                        <span className="architecture-badge accent">risk {item.pressureScore}</span>
                        <span className="architecture-badge">{item.hits} пар</span>
                        <span className="architecture-badge">{item.highCount} HIGH</span>
                        <span className="architecture-badge">{item.exactCount} exact</span>
                        <span className="architecture-badge">{item.releasesCount} rel</span>
                        <span className="architecture-badge">{item.incidentsCount} inc</span>
                        <span className="architecture-badge">{item.transitiveDownstreamCount} down</span>
                        <span className="architecture-badge accent">{formatPercent(item.avgScore)}</span>
                      </div>
                    </div>
                    <div className="architecture-row-meta">
                      <span>{item.entities[0] || "Без сущности"}</span>
                      <span>{item.issueTypes.map((type) => ISSUE_LABELS[type] || type).join(" · ")}</span>
                      <span>{item.recommendation?.title || "Ручной разбор"}</span>
                    </div>
                    <div className="architecture-row-meta">
                      <span>Последний change: {item.lastChange?.actor || "Не указан"}</span>
                      <span>{item.lastChange?.changed_at ? formatDateTime(item.lastChange.changed_at) : "Без поставок в окне"}</span>
                    </div>
                    <div className="architecture-tags">
                      {item.sampleHints.map((hint) => (
                        <span key={`${item.fqn}-${hint}`} className="architecture-tag">{hint}</span>
                      ))}
                      {item.downstreamEntities.slice(0, 3).map((entity) => (
                        <span key={`${item.fqn}-entity-${entity}`} className="architecture-tag muted-tag">{entity}</span>
                      ))}
                    </div>
                    <div className="architecture-actions">
                      <button type="button" className="btn btn-primary" onClick={() => setSelectedObjectFqn(item.fqn)}>
                        Разобрать
                      </button>
                      <button type="button" className="btn btn-secondary" onClick={() => openTable(item.fqn)}>
                        Открыть таблицу
                      </button>
                      <button type="button" className="btn btn-ghost" onClick={() => openLogicAudit(item.fqn)}>
                        Открыть аудит
                      </button>
                    </div>
                  </article>
                ))}
                {!topCandidates.length ? <div className="muted">По текущим фильтрам кандидатов не найдено.</div> : null}
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
              <div className="section-title">Портфель рекомендаций</div>
              <div className="section-subtitle">
                Как по всему текущему срезу распределяются типы действий: общий слой, схлопывание, семантический конфликт или ручной разбор.
              </div>
              <div className="architecture-family-list">
                {recommendationPortfolio.map((item) => (
                  <div key={item.kind} className="architecture-family-card">
                    <div className="architecture-family-head">
                      <strong>{item.title}</strong>
                      <span className="architecture-badge accent">{formatPercent(item.avgScore)}</span>
                    </div>
                    <div className="architecture-family-bar">
                      <div
                        className="architecture-family-fill"
                        style={{ width: `${Math.min(100, item.count * 10 + item.highCount * 2)}%` }}
                      />
                    </div>
                    <div className="architecture-family-meta">
                      <span>{item.count} объектов</span>
                      <span>{item.highCount} HIGH</span>
                      <span>{item.exactCount} exact</span>
                    </div>
                  </div>
                ))}
              </div>
            </section>

            <section className="cc-surface architecture-block">
              <div className="section-title">Сигналы повторов</div>
              <div className="section-subtitle">
                Наиболее частые архитектурные паттерны, которые всплывают в похожих расчётах.
              </div>
              <div className="architecture-list compact">
                {hintStats.map((item) => (
                  <article key={item.hint} className="architecture-row-card compact">
                    <div className="architecture-row-head">
                      <div className="architecture-pair">{item.hint}</div>
                      <div className="architecture-row-badges">
                        <span className="architecture-badge">{item.count}</span>
                        <span className="architecture-badge">{item.highCount} HIGH</span>
                        <span className="architecture-badge">{item.exactCount} exact</span>
                      </div>
                    </div>
                  </article>
                ))}
              </div>
            </section>
          </section>

          <section className="architecture-grid">
            <section className="cc-surface architecture-block">
              <div className="section-title">Операционный риск</div>
              <div className="section-subtitle">
                Где похожая логика уже успела засветиться в инцидентах и где изменение сильнее всего ударит по downstream-контуру.
              </div>
              <div className="architecture-list compact">
                {topIncidentCandidates.map((item) => (
                  <article key={`incident-${item.fqn}`} className="architecture-row-card compact">
                    <div className="architecture-row-head">
                      <button type="button" className="architecture-link mono" onClick={() => setSelectedObjectFqn(item.fqn)}>
                        {item.fqn}
                      </button>
                      <div className="architecture-row-badges">
                        <span className="architecture-badge accent">risk {item.pressureScore}</span>
                        <span className="architecture-badge">{item.incidentsCount} inc</span>
                        <span className="architecture-badge">{item.releasesCount} rel</span>
                      </div>
                    </div>
                    <div className="architecture-row-meta">
                      <span>{item.latestIncident?.incident_reason_name || "Без инцидентов в окне"}</span>
                      <span>{item.latestIncident?.incident_start_dttm ? formatDateTime(item.latestIncident.incident_start_dttm) : "—"}</span>
                    </div>
                    <div className="muted">{shortText(item.latestIncident?.summary || item.sampleHints.join(" · "), 150)}</div>
                  </article>
                ))}
                {!topIncidentCandidates.length ? <div className="muted">В текущем окне кандидатов с инцидентами нет.</div> : null}
              </div>
            </section>

            <section className="cc-surface architecture-block">
              <div className="section-title">Blast Radius</div>
              <div className="section-subtitle">
                Кандидаты, у которых самый широкий downstream-след. Их рефакторить полезно, но нужно делать особенно аккуратно.
              </div>
              <div className="architecture-list compact">
                {topBlastRadiusCandidates.map((item) => (
                  <article key={`blast-${item.fqn}`} className="architecture-row-card compact">
                    <div className="architecture-row-head">
                      <button type="button" className="architecture-link mono" onClick={() => setSelectedObjectFqn(item.fqn)}>
                        {item.fqn}
                      </button>
                      <div className="architecture-row-badges">
                        <span className="architecture-badge">{item.transitiveDownstreamCount} total down</span>
                        <span className="architecture-badge">{item.directDownstreamCount} direct</span>
                      </div>
                    </div>
                    <div className="architecture-row-meta">
                      <span>{item.downstreamEntitiesCount} downstream-сущностей</span>
                      <span>{item.directUpstreamCount} upstream-источников</span>
                    </div>
                    <div className="architecture-tags">
                      {item.downstreamEntities.slice(0, 4).map((entity) => (
                        <span key={`blast-${item.fqn}-${entity}`} className="architecture-tag muted-tag">{entity}</span>
                      ))}
                    </div>
                  </article>
                ))}
                {!topBlastRadiusCandidates.length ? <div className="muted">Downstream-следов по текущему срезу не найдено.</div> : null}
              </div>
            </section>
          </section>

          <section className="architecture-grid">
            <section className="cc-surface architecture-block">
              <div className="section-title">Risk Matrix</div>
              <div className="section-subtitle">
                Матрица приоритета: чем выше операционный риск и чем точнее дубли, тем раньше это имеет смысл разбирать архитектору.
              </div>
              <div className="architecture-matrix">
                {riskMatrix.map((cell) => (
                  <div
                    key={`${cell.row}-${cell.col}`}
                    className={`architecture-matrix-cell tone-${cell.row === "Критичный" ? "critical" : cell.row === "Высокий" ? "high" : "watch"}`}
                  >
                    <div className="architecture-matrix-head">
                      <span>{cell.row}</span>
                      <span>{cell.col}</span>
                    </div>
                    <div className="architecture-matrix-value">{cell.count}</div>
                    <div className="architecture-matrix-sample">
                      {cell.items.length ? cell.items.join(" · ") : "Пока пусто"}
                    </div>
                  </div>
                ))}
              </div>
            </section>

            <section className="cc-surface architecture-block">
              <div className="section-title">Owner Ambiguity</div>
              <div className="section-subtitle">
                Чем больше разных последних владельцев у похожих объектов, тем выше риск, что рефакторинг упрётся в рассинхрон ответственности.
              </div>
              <div className="architecture-owner-grid">
                {ownerStats.map((item) => (
                  <article key={`owner-signal-${item.actor}`} className="architecture-owner-card">
                    <div className="architecture-row-head">
                      <div className="architecture-pair">{item.actor}</div>
                      <span className="architecture-badge accent">{Math.round(item.avgPressure)}</span>
                    </div>
                    <div className="architecture-row-meta">
                      <span>{item.objectsCount} объектов</span>
                      <span>{item.releasesCount} rel</span>
                      <span>{item.incidentsCount} inc</span>
                    </div>
                  </article>
                ))}
              </div>
            </section>
          </section>

          {selectedCluster ? (
            <section className="cc-surface architecture-block">
              <div className="section-title">Разбор кластера</div>
              <div className="section-subtitle">
                Детализация по выбранному кандидату на схлопывание и готовое архитектурное заключение.
              </div>
              <div className="architecture-cluster-grid">
                <div className="architecture-cluster-main">
                  <div className="architecture-cluster-head">
                    <div>
                      <div className="architecture-cluster-title mono">{selectedCluster.fqn}</div>
                      <div className="architecture-row-meta">
                        <span>{selectedCluster.entities.join(" · ") || "Без сущности"}</span>
                        <span>{selectedCluster.related.length} связанных пар</span>
                        <span>{formatPercent(selectedCluster.avgScore)} средняя похожесть</span>
                      </div>
                    </div>
                    <div className="architecture-row-badges">
                      <span className="architecture-badge">{selectedCluster.highCount} HIGH</span>
                      <span className="architecture-badge">{selectedCluster.exactCount} exact</span>
                    </div>
                  </div>

                  <div className="architecture-cluster-peers">
                    {selectedCluster.peers.map((peer) => (
                      <article key={`${selectedCluster.fqn}-${peer.fqn}`} className="architecture-peer-card">
                        <div className="architecture-row-head">
                          <button type="button" className="architecture-link mono" onClick={() => openLogicAudit(peer.fqn)}>
                            {peer.fqn}
                          </button>
                          <span className="architecture-badge accent">{formatPercent(peer.score)}</span>
                        </div>
                        <div className="architecture-row-meta">
                          <span>{peer.entity}</span>
                          <span>{ISSUE_LABELS[peer.issueType] || peer.issueType}</span>
                          <span>{peer.overlap} expr</span>
                          <span>{peer.mergePotential}</span>
                        </div>
                        <div className="muted">{shortText((peer.hints || []).join(" · "))}</div>
                      </article>
                    ))}
                  </div>
                </div>

                <div className="architecture-cluster-side">
                  <div className="architecture-reco-card">
                    <div className="architecture-reco-kicker">Рекомендация</div>
                    <div className="architecture-reco-title">{selectedRecommendation?.title}</div>
                    <div className="architecture-reco-text">{selectedRecommendation?.rationale}</div>
                    <div className="architecture-reco-action">{selectedRecommendation?.action}</div>
                  </div>

                  <div className="architecture-reco-card">
                    <div className="architecture-reco-kicker">AI-ready summary</div>
                    <div className="architecture-reco-text">{aiBrief}</div>
                    <div className="architecture-actions">
                      <button type="button" className="btn btn-secondary" onClick={() => copyAiPayload("markdown")}>
                        Копировать brief
                      </button>
                      <button type="button" className="btn btn-ghost" onClick={() => copyAiPayload("json")}>
                        Копировать JSON
                      </button>
                    </div>
                    {copyStatus ? <div className="muted">{copyStatus}</div> : null}
                  </div>

                  <div className="architecture-reco-card">
                    <div className="architecture-reco-kicker">Операционный контекст</div>
                    <div className="architecture-context-grid">
                      <div className="architecture-context-item">
                        <span className="label">Pressure score</span>
                        <strong>{selectedCandidate?.pressureScore ?? 0}</strong>
                      </div>
                      <div className="architecture-context-item">
                        <span className="label">Releases</span>
                        <strong>{selectedCandidate?.releasesCount ?? 0}</strong>
                      </div>
                      <div className="architecture-context-item">
                        <span className="label">Incidents</span>
                        <strong>{selectedCandidate?.incidentsCount ?? 0}</strong>
                      </div>
                      <div className="architecture-context-item">
                        <span className="label">Downstream</span>
                        <strong>{selectedCandidate?.transitiveDownstreamCount ?? 0}</strong>
                      </div>
                    </div>
                    <div className="architecture-context-list">
                      <div className="architecture-context-row">
                        <span>Последний delivery-change</span>
                        <span>{selectedCandidate?.lastChange?.actor || "Не указан"}</span>
                      </div>
                      <div className="architecture-context-row">
                        <span>Когда</span>
                        <span>{formatDateTime(selectedCandidate?.lastChange?.changed_at)}</span>
                      </div>
                      <div className="architecture-context-row">
                        <span>Последний релиз</span>
                        <span>{selectedCandidate?.latestRelease?.release_id || "—"}</span>
                      </div>
                      <div className="architecture-context-row">
                        <span>Последний инцидент</span>
                        <span>{selectedCandidate?.latestIncident?.issue_id || "—"}</span>
                      </div>
                    </div>
                    {selectedCandidate?.latestIncident?.summary ? (
                      <div className="muted">{shortText(selectedCandidate.latestIncident.summary, 150)}</div>
                    ) : null}
                  </div>

                  <div className="architecture-reco-card">
                    <div className="architecture-reco-kicker">Owner ambiguity</div>
                    <div className="architecture-reco-title">
                      {selectedOwnerAmbiguity?.ownerCount || 0} владельца в кластере
                    </div>
                    <div className="architecture-reco-text">
                      {selectedOwnerAmbiguity?.hasAmbiguity
                        ? "Ответственность размазана: перед схлопыванием нужен owner alignment и один контур решений."
                        : "Кластер выглядит управляемым: контур владельцев ещё не слишком разросся."}
                    </div>
                    <div className="architecture-tags">
                      {(selectedOwnerAmbiguity?.owners || []).map((owner) => (
                        <span key={`owner-tag-${owner}`} className="architecture-tag">{owner}</span>
                      ))}
                    </div>
                  </div>

                  <div className="architecture-reco-card">
                    <div className="architecture-reco-kicker">Checklist</div>
                    <div className="architecture-checklist">
                      {checklist.map((item) => (
                        <div key={item} className="architecture-checklist-item">
                          <span className="architecture-checkmark">•</span>
                          <span>{item}</span>
                        </div>
                      ))}
                    </div>
                  </div>

                  <div className="architecture-reco-card">
                    <div className="architecture-reco-kicker">Экспорт</div>
                    <div className="architecture-reco-text">
                      Этот пакет можно уже сейчас отдавать корпоративному агенту как structured context.
                    </div>
                    <div className="architecture-actions">
                      <button
                        type="button"
                        className="btn btn-secondary"
                        onClick={() => downloadTextFile(JSON.stringify(aiPayload, null, 2), `architecture-context-${selectedCluster.fqn.replaceAll(".", "_")}.json`, "application/json;charset=utf-8")}
                      >
                        Скачать JSON
                      </button>
                      <button
                        type="button"
                        className="btn btn-ghost"
                        onClick={() => downloadTextFile(markdownReport, `architecture-brief-${selectedCluster.fqn.replaceAll(".", "_")}.md`, "text/markdown;charset=utf-8")}
                      >
                        Скачать Markdown
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              <div className="architecture-timeline-block">
                <div className="architecture-reco-kicker">Activity timeline</div>
                <div className="architecture-timeline-list">
                  {selectedTimeline.map((event) => (
                    <article key={event.id} className={`architecture-timeline-card tone-${event.type}`}>
                      <div className="architecture-timeline-dot" />
                      <div className="architecture-timeline-body">
                        <div className="architecture-row-head">
                          <div className="architecture-pair">{event.title}</div>
                          <span className="architecture-badge">{formatDateTime(event.at)}</span>
                        </div>
                        <div className="architecture-row-meta">
                          <span>{event.actor}</span>
                          <span>{event.meta}</span>
                        </div>
                        <div className="muted">{shortText(event.text, 180)}</div>
                        {event.link ? (
                          <div className="architecture-actions">
                            <a className="btn btn-ghost" href={event.link} target="_blank" rel="noreferrer">Открыть</a>
                          </div>
                        ) : null}
                      </div>
                    </article>
                  ))}
                  {!selectedTimeline.length ? <div className="muted">Для выбранного объекта пока нет событий в окне анализа.</div> : null}
                </div>
              </div>
            </section>
          ) : null}

          <section className="architecture-grid">
            <section className="cc-surface architecture-block">
              <div className="section-title">Последние владельцы изменений</div>
              <div className="section-subtitle">
                Кто чаще всего фигурирует как последний delivery-change по текущим кандидатам. Удобно для планирования review и согласования рефакторинга.
              </div>
              <div className="architecture-list compact">
                {ownerStats.map((item) => (
                  <article key={`owner-${item.actor}`} className="architecture-row-card compact">
                    <div className="architecture-row-head">
                      <div className="architecture-pair">{item.actor}</div>
                      <div className="architecture-row-badges">
                        <span className="architecture-badge">{item.objectsCount} obj</span>
                        <span className="architecture-badge">{item.releasesCount} rel</span>
                        <span className="architecture-badge">{item.incidentsCount} inc</span>
                        <span className="architecture-badge accent">{Math.round(item.avgPressure)}</span>
                      </div>
                    </div>
                    <div className="architecture-row-meta">
                      <span>Средний pressure</span>
                      <span>{Math.round(item.avgPressure)}</span>
                    </div>
                  </article>
                ))}
              </div>
            </section>

            <section className="cc-surface architecture-block">
              <div className="section-title">Дорожная карта рефакторинга</div>
              <div className="section-subtitle">
                Текущий workbench уже раскладывает кандидатов на три волны: сделать сейчас, взять следующим этапом, держать под наблюдением.
              </div>
              <div className="architecture-roadmap-grid">
                {[
                  { key: "now", title: "Делать сейчас", items: roadmap.now },
                  { key: "next", title: "Следующий этап", items: roadmap.next },
                  { key: "watch", title: "Под наблюдением", items: roadmap.watch },
                ].map((column) => (
                  <div key={column.key} className="architecture-roadmap-card">
                    <div className="architecture-roadmap-title">{column.title}</div>
                    <div className="architecture-roadmap-list">
                      {column.items.length ? column.items.map((item) => (
                        <button
                          key={`${column.key}-${item.fqn}`}
                          type="button"
                          className="architecture-roadmap-item"
                          onClick={() => setSelectedObjectFqn(item.fqn)}
                        >
                          <span className="mono">{item.fqn}</span>
                          <span>{item.recommendation?.title || "Ручной разбор"}</span>
                        </button>
                      )) : <div className="muted">Пока пусто.</div>}
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
