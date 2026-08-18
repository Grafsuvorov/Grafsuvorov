import { apiClient } from "./client.js";

export const performanceApi = {
  slowestTables: (days, limit) =>
    apiClient.get("/api/slowest-tables", { params: { days, limit } }),
  tableSizes: (limit = 30, schema = "", owner = "") =>
    apiClient.get("/api/table-sizes", { params: { limit, schema, owner } }),
  loadProfile: (days) =>
    apiClient.get("/api/load-profile", { params: { days } }),
  nightSummary: (days, limit = 50) =>
    apiClient.get("/api/night-summary", { params: { days, limit } }),
  entityLoads: (entityId, days, limit, schema) =>
    apiClient.get("/api/entity-loads", {
      params: { entity_id: entityId, days, limit, schema: schema === "all" ? "" : schema },
    }),
  windowRuns: ({ date, from, to, source }, force = false) =>
    apiClient.getCached("/api/window-runs", {
      ttlMs: 90 * 1000,
      force,
      params: { date, from, to, source },
    }),
  loadCompare: ({ dateA, dateB, entityId }, force = false) =>
    apiClient.getCached("/api/load-compare", {
      ttlMs: 90 * 1000,
      force,
      params: { date_a: dateA, date_b: dateB, entity_id: entityId || "" },
    }),
};
