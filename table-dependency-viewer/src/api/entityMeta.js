import { apiClient } from "./client.js";

export const entityMetaApi = {
  status: () => apiClient.get("/api/admin/entity-meta/status"),
  catalog: () => apiClient.get("/api/admin/entity-meta/catalog"),
  entities: () => apiClient.get("/api/admin/entity-meta/reference/entities"),
  init: (body) => apiClient.post("/api/admin/entity-meta/init", body),
  lock: (body) => apiClient.post("/api/admin/entity-meta/lock", body),
  unlock: (body) => apiClient.post("/api/admin/entity-meta/unlock", body),
  validate: (body) => apiClient.post("/api/admin/entity-meta/validate", body),
  save: (body) => apiClient.post("/api/admin/entity-meta/save", body),
};
