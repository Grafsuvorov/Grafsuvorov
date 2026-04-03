const pad = (part) => String(part).padStart(2, "0");

export function parseLocalDateTime(value) {
  if (!value) return null;
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }

  const text = String(value).trim();
  if (!text) return null;

  const dateTimeMatch = text.match(
    /^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?(?:\.\d+)?(?:Z)?$/,
  );
  if (dateTimeMatch) {
    const [, year, month, day, hour = "00", minute = "00", second = "00"] = dateTimeMatch;
    const parsed = new Date(
      Number(year),
      Number(month) - 1,
      Number(day),
      Number(hour),
      Number(minute),
      Number(second),
    );
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  const parsed = new Date(text);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

export function formatLocalDateTime(value, { withSeconds = true } = {}) {
  const dt = parseLocalDateTime(value);
  if (!dt) return value || "—";

  const datePart = `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}-${pad(dt.getDate())}`;
  const timePart = withSeconds
    ? `${pad(dt.getHours())}:${pad(dt.getMinutes())}:${pad(dt.getSeconds())}`
    : `${pad(dt.getHours())}:${pad(dt.getMinutes())}`;
  return `${datePart} ${timePart}`;
}

export function formatRuDateTime(value, options) {
  const dt = parseLocalDateTime(value);
  if (!dt) return value || "—";
  return dt.toLocaleString("ru-RU", options);
}

export function formatShortDateTime(value) {
  const dt = parseLocalDateTime(value);
  if (!dt) return value || "—";
  return `${pad(dt.getDate())}.${pad(dt.getMonth() + 1)} ${pad(dt.getHours())}:${pad(dt.getMinutes())}`;
}

export function formatDateInputValue(value = new Date()) {
  const dt = parseLocalDateTime(value);
  if (!dt) return "";
  return `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}-${pad(dt.getDate())}`;
}

