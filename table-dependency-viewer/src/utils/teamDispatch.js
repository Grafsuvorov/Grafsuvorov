const normalize = (value) => String(value || "").trim().toLowerCase().replace(/\s+/g, " ");
const ACTIVE = new Set(["в работе", "визуализация", "интеграция", "проверка / тест", "прод. подлежит проверке", "системный анализ"]);
const RELEASE = new Set(["dev. подготовлено к релизу", "ожидание релиза"]);
const PAUSED = new Set(["отложена / в ожидании", "требуется уточнение", "подлежит обсуждению"]);
export const STAGES = [
  { id: "active", label: "В работе", color: "#38bdf8" },
  { id: "queue", label: "В очереди", color: "#a78bfa" },
  { id: "release", label: "Ждут релиза", color: "#34d399" },
  { id: "paused", label: "Ожидание / уточнение", color: "#fbbf24" },
];
export function taskStage(task) {
  const state = normalize(task.state);
  return ACTIVE.has(state) ? "active" : RELEASE.has(state) ? "release" : PAUSED.has(state) ? "paused" : "queue";
}
export function parseObjects(text) {
  return [...new Set((String(text || "").match(/\b[a-zA-Z_][\w]*\.[a-zA-Z_][\w]*\b/g) || []).map(normalize))];
}
export function currentEmployees(data, tasks = data?.tasks || []) {
  return (data?.engineers || []).filter((e) => e.is_active).map((e) => {
    const open = tasks.filter((t) => t.is_open && t.owner_id === e.user_id);
    const stages = Object.fromEntries(STAGES.map((s) => [s.id, open.filter((t) => taskStage(t) === s.id)]));
    const handsOn = [...stages.active, ...stages.queue];
    const estimated = handsOn.filter((t) => t.remaining_hours != null && !t.estimate_exhausted);
    const remaining = estimated.reduce((sum, t) => sum + t.remaining_hours, 0);
    const unknown = handsOn.filter((t) => t.remaining_hours == null || t.estimate_exhausted).length;
    const load = stages.active.length * 3 + stages.queue.length + stages.release.length * 0.25 + stages.paused.length * 0.5 + remaining / 8;
    return { ...e, open, stages, remaining, unknown, load, estimatedCount: estimated.length, handsOnCount: handsOn.length };
  });
}
export function recommendEngineers(data, { taskId = "", objects = [], strategy = "balanced" } = {}) {
  const tasks = (data?.tasks || []).filter((t) => t.issue_id !== taskId);
  const target = (data?.tasks || []).find((t) => t.issue_id === taskId);
  const requested = new Set([...(target?.objects || []), ...objects].map(normalize));
  const links = data?.object_links || [];
  return currentEmployees(data, tasks).map((e) => {
    const matches = [];
    for (const task of e.open) {
      const exact = (task.objects || []).map(normalize).filter((o) => requested.has(o));
      const related = links.filter((link) => [...requested].some((object) =>
        (link.source === object && (task.objects || []).map(normalize).includes(link.target)) ||
        (link.target === object && (task.objects || []).map(normalize).includes(link.source))));
      if (exact.length || related.length) matches.push({ task, exact, related });
    }
    const exactCount = matches.filter((m) => m.exact.length).length;
    const relatedCount = matches.filter((m) => m.related.length && !m.exact.length).length;
    const affinity = Math.min(exactCount * 4 + relatedCount * 2, 8);
    const score = strategy === "capacity" ? e.load : strategy === "context" ? e.load - affinity * 3 : e.load - affinity;
    return { ...e, matches, exactCount, relatedCount, score };
  }).sort((a, b) => a.score - b.score || a.load - b.load || a.engineer.localeCompare(b.engineer));
}
