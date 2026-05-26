import { apiClient } from "./client.js";

export const metaWorkspaceApi = {
  branches: () => apiClient.get("/api/admin/meta-workspace/branches"),
  branchCatalog: (params) => apiClient.get("/api/admin/meta-workspace/branch-catalog", { params }),
  validateAll: (body) => apiClient.post("/api/admin/meta-workspace/validate-all", body),
  syncBranch: (body) => apiClient.post("/api/admin/meta-workspace/sync-branch", body),
  createMr: (body) => apiClient.post("/api/admin/meta-workspace/mr", body),
};
