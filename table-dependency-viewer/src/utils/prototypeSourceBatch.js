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
    valid: loads.length === selected.length && !errors.length, busy: rows.some((row) => row.busy), errors };
}
