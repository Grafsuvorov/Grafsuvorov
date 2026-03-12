const API_BASE = import.meta.env.VITE_API_BASE_URL || "";
const AUTH_ENABLED = import.meta.env.VITE_AUTH_ENABLED === "true";

export function sendAuditEvent(payload) {
  if (!AUTH_ENABLED || typeof window === "undefined" || !payload?.event_type) return;

  const token =
    window.localStorage.getItem("tdv_access_token") ||
    window.sessionStorage.getItem("tdv_access_token");
  if (!token) return;

  fetch(`${API_BASE}/auth/audit/event`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
    keepalive: true,
  }).catch(() => {});
}
