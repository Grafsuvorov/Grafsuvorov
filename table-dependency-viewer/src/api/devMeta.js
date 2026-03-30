import { apiClient } from "./client.js";

export const devMetaApi = {
  status: () => apiClient.get("/api/admin/dev-meta/status"),
  files: (schemaName) => apiClient.get("/api/admin/dev-meta/files", { params: { schema_name: schemaName } }),
  readFile: (body) => apiClient.post("/api/admin/dev-meta/file", body),
  lock: (body) => apiClient.post("/api/admin/dev-meta/lock", body),
  unlock: (body) => apiClient.post("/api/admin/dev-meta/unlock", body),
  validate: (body) => apiClient.post("/api/admin/dev-meta/validate", body),
  save: (body) => apiClient.post("/api/admin/dev-meta/save", body),
  deploy: (body) => apiClient.post("/api/admin/dev-meta/deploy", body),
  runDag: (body) => apiClient.post("/api/admin/dev-meta/run-dag", body),
};
