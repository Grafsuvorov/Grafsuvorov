const PIPELINE_SCHEMA_ORDER = [
  "dm_view",
  "dm",
  "dm_calc",
  "dds",
  "ods",
  "stg",
  "dict_dds",
  "dict_stg",
  "dict_ods",
];

export function compareSchemaNames(left, right) {
  const a = String(left || "").toLowerCase();
  const b = String(right || "").toLowerCase();
  const aIdx = PIPELINE_SCHEMA_ORDER.indexOf(a);
  const bIdx = PIPELINE_SCHEMA_ORDER.indexOf(b);
  if (aIdx !== -1 || bIdx !== -1) {
    if (aIdx === -1) return 1;
    if (bIdx === -1) return -1;
    if (aIdx !== bIdx) return aIdx - bIdx;
  }
  return a.localeCompare(b, "ru");
}

export function sortSchemaNames(values) {
  return [...values].sort(compareSchemaNames);
}

