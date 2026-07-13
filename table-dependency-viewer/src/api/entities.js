import { apiClient } from "./client.js";

export const entitiesApi = {
  list: () => apiClient.get("/api/entities"),
  shared: (limit = 3) => apiClient.get("/api/entities/shared", { params: { limit } }),
  dq: (days = 7, delta = 10, limit = 12) =>
    apiClient.get("/api/dq/entity", { params: { days, delta, limit } }),
  timeline: (days = 7) =>
    apiClient.get("/api/entities/timeline", { params: { days } }),
  intersections: (limit = 120, minScore = 1) =>
    apiClient.get("/api/entities/intersections", { params: { limit, min_score: minScore } }),
  coverage: (limit, offset) =>
    apiClient.get("/api/graph/orphans", { params: { limit, offset, meta_only: true } }),
  tables: (entityId) => apiClient.get(`/api/entities/${entityId}/table-info`),
};
