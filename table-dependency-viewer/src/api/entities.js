import { apiClient } from "./client.js";

export const entitiesApi = {
  list: () => apiClient.get("/api/entities"),
  shared: (limit = 3) => apiClient.get("/api/entities/shared", { params: { limit } }),
  dq: (days = 7, delta = 10, limit = 12) =>
    apiClient.get("/api/dq/entity", { params: { days, delta, limit } }),
  coverage: (limit, offset) =>
    apiClient.get("/api/graph/orphans", { params: { limit, offset, meta_only: true } }),
  tables: (entityId) => apiClient.get(`/api/entities/${entityId}/table-info`),
};

