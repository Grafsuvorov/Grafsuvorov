export const formatMinutes = (value) => (value !== null && value !== undefined ? `${value} мин` : "—");
export const formatFixed = (value, digits = 2) => (Number.isFinite(value) ? value.toFixed(digits) : "—");
export const formatInt = (value) => (Number.isFinite(value) ? Math.round(value).toLocaleString("ru-RU") : "—");
export const formatPercent = (value) =>
  Number.isFinite(value) ? `${value > 0 ? "+" : ""}${value.toFixed(1)}%` : "—";

