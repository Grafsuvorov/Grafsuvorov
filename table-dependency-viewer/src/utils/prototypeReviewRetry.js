export function reviewItemNeedsRetry(item) {
  return Boolean(item.source_stale || item.checks_stale
    || item.validation_errors?.length
    || item.execution?.status === "error" || item.preparation?.status === "error"
    || (!item.is_clickhouse_view && item.execution?.status === "skipped")
    || Number(item.checks?.duplicate_groups || 0) > 0
    || (item.warnings || []).some((w) => String(w).startsWith("Не удалось посчитать строки/дубли в DEV:")));
}

export function mergeReviewRetry(previous, fresh, buildDraftItem) {
  const replacements = new Map((fresh.review_items || []).map((item) => [item.item_id, item]));
  const manifest = new Map((fresh.source_manifest || []).map((item) => [item.item_id, item]));
  return previous.map((item) => {
    const replacement = replacements.get(item.item_id);
    if (replacement) {
      const checked = buildDraftItem(replacement);
      const currentKeys = String(item.key_attributes_text || "").split(/[,;\n]+/).map((key) => key.trim()).filter(Boolean).join(", ");
      // Preserve the analyst's form edits, refresh only execution and identity.
      return { ...item, ...Object.fromEntries([
        "execution", "checks", "preparation", "duration_sec", "warnings", "sql_fingerprint", "paths", "path",
        "table_id", "is_new", "requires_user_input", "missing_fields", "validation_errors",
      ].map((key) => [key, checked[key]])), checks_stale: currentKeys !== checked.key_attributes_text, source_stale: false,
      rechecking: false, last_checked_key_attributes_text: checked.key_attributes_text };
    }
    const source = manifest.get(item.item_id);
    return { ...item, source_stale: item.source_stale || !source || source.sql_fingerprint !== item.sql_fingerprint
      || (fresh.invalidated_item_ids || []).includes(item.item_id) };
  });
}

export function reviewResultWithItems(previous, fresh, drafts, selected) {
  const selectedIds = new Set(selected);
  const replaceRows = (key) => [...(previous[key] || []).filter((r) => !selectedIds.has(r.item_id)), ...(fresh[key] || [])];
  const failed = drafts.filter(reviewItemNeedsRetry);
  const warnings = drafts.flatMap((i) => i.warnings || []);
  return { ...previous, mr: fresh.mr, source_manifest: fresh.source_manifest,
    composition_stale: (fresh.source_manifest || []).length !== drafts.length
      || (fresh.source_manifest || []).some((source) => !drafts.some((item) => item.item_id === source.item_id)),
    review_items: drafts, execution: replaceRows("execution"), preparation: replaceRows("preparation"),
    validation_errors: fresh.validation_errors || [], validation_warnings: warnings,
    status: failed.length || fresh.status === "error" ? "error" : warnings.length ? "warning" : "ok",
    status_reason: failed.length ? `Нужна повторная проверка объектов: ${failed.length}` : fresh.status_reason,
  };
}
