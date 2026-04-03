import { apiClient } from "./client.js";

export function fetchHomePayload() {
  return Promise.all([
    apiClient.get("/api/incidents/active"),
    apiClient.get("/api/orderbreaches"),
    apiClient.get("/api/incidents/history", { params: { days: 7, limit: 10 } }),
    apiClient.get("/api/metrics"),
    apiClient.get("/api/graph/diagnostics", { params: { include_any: true } }),
    apiClient.get("/api/night-summary", { params: { days: 30, limit: 10 } }),
    apiClient.get("/api/incidents/timeline", { params: { days: 7 } }),
    apiClient.get("/api/dq/summary", { params: { days: 7, delta: 10 } }),
    apiClient.get("/api/dq/alerts", { params: { days: 7, delta: 10, limit: 8 } }),
    apiClient.get("/api/click/summary", { params: { days: 7, limit: 6 } }),
    apiClient.get("/api/click/slow-stages", { params: { days: 7, limit: 6 } }),
  ]).then(
    ([
      activeIncidents,
      orderBreaches,
      history,
      metrics,
      diagnostics,
      nightSummary,
      incidentTimeline,
      dqSummary,
      dqAlerts,
      clickSummary,
      clickSlow,
    ]) => ({
      activeIncidents,
      orderBreaches,
      history,
      metrics,
      diagnostics,
      nightSummary,
      incidentTimeline,
      dqSummary,
      dqAlerts,
      clickSummary: clickSummary?.summary || null,
      clickFailures: Array.isArray(clickSummary?.failures) ? clickSummary.failures : [],
      clickSlow: Array.isArray(clickSlow) ? clickSlow : [],
    }),
  );
}

