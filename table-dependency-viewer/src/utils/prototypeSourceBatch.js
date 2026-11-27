export function summarizeSourceBatch(rows) {
  const selected = rows.filter((row) => row.selected);
  const loads = selected.filter((row) => row.ready && !row.busy).map((row) => row.ready);
  const seen = new Set();
  const errors = [];
  for (const load of loads) {
    const target = `${load.target_schema}.${load.target_table}`.toLowerCase();
    if (seen.has(target)) errors.push(`Таблица ${load.target_schema}.${load.target_table} добавлена несколько раз`);
    seen.add(target);
  }
  return { loads, selected: selected.length, ready: loads.length,
    valid: loads.length === selected.length && !errors.length, busy: rows.some((row) => row.busy || row.lookupBusy), errors };
}

export function sourceTargetKey(value) {
  return String(value || '').trim().replace(/^"|"$/g, '').toLowerCase();
}

export function sourceDetailsForm(form, details, touched = new Set()) {
  const meta = details.metadata || {};
  const values = {
    fields: details.fields,
    primary_key: meta.primary_key || details.primary_key || (meta.key_attributes || []).map((name) => `"${name}"`).join(' || '),
    source_schema: meta.source_schema_name,
    source_table: meta.source_table_name,
    entity_name: details.entity_name || meta.entity_name,
    distribution_field: meta.distribution_field,
    server_id: meta.source_id == null ? undefined : String(meta.source_id),
  };
  const next = { ...form, target_table: details.table_name || form.target_table };
  for (const [key, value] of Object.entries(values)) {
    if (value !== undefined && value !== null && value !== '' && !touched.has(key)) next[key] = value;
  }
  return next;
}

export function sourceTaskWarning(response, submittedLoads) {
  if (!response?.issue?.issue_id || !submittedLoads.length) return '';
  const expected = submittedLoads.map((load) => `${load.target_schema}.${load.target_table}`.toLowerCase()).sort();
  const actual = response.task_contents?.source_targets?.map((target) => target.toLowerCase()).sort();
  if (!actual || expected.join('|') !== actual.join('|')) {
    return `Задача ${response.issue.issue_id} создана, но API не подтвердил включение всех STG-таблиц (${expected.join(', ')}). Проверьте состав задачи и обновление API; повторное создание создаст другую задачу.`;
  }
  return '';
}
