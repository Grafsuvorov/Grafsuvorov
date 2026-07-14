import { apiClient } from "./client.js";

export const devMetaApi = {
  status: () => apiClient.get("/api/admin/dev-meta/status"),
  files: (schemaName) => apiClient.get("/api/admin/dev-meta/files", { params: { schema_name: schemaName } }),
  generate: (body) => apiClient.post("/api/admin/dev-meta/generate", body),
  readFile: (body) => apiClient.post("/api/admin/dev-meta/file", body),
  lock: (body) => apiClient.post("/api/admin/dev-meta/lock", body),
  unlock: (body) => apiClient.post("/api/admin/dev-meta/unlock", body),
  validate: (body) => apiClient.post("/api/admin/dev-meta/validate", body),
  save: (body) => apiClient.post("/api/admin/dev-meta/save", body),
  deploy: (body) => apiClient.post("/api/admin/dev-meta/deploy", body),
  runDag: (body) => apiClient.post("/api/admin/dev-meta/run-dag", body),
  dagStatus: (body) => apiClient.post("/api/admin/dev-meta/dag-status", body),
};

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
