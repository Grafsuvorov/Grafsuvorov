import { apiClient } from "./client.js";

export const devCopyApi = {
  status: () => apiClient.get("/api/admin/dev-copy/status"),
  runDag: (body) => apiClient.post("/api/admin/dev-copy/run-dag", body),
  dagStatus: (body) => apiClient.post("/api/admin/dev-copy/dag-status", body),
};
