import { apiClient } from "./client.js";

export const devCopyApi = {
  status: () => apiClient.get("/api/admin/dev-copy/status"),
  runDag: (body) => apiClient.post("/api/admin/dev-copy/run-dag", body),
  dagStatus: (body) => apiClient.post("/api/admin/dev-copy/dag-status", body),
  runSchemaSyncDag: (body) => apiClient.post("/api/admin/dev-copy/schema-sync/run-dag", body),
  schemaSyncDagStatus: (body) => apiClient.post("/api/admin/dev-copy/schema-sync/dag-status", body),
  schemaSyncReport: (body) => apiClient.post("/api/admin/dev-copy/schema-sync/report", body),
};
