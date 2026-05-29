import { apiClient } from "./client.js";

export const metaWorkspaceApi = {
  branches: () => apiClient.get("/api/admin/meta-workspace/branches"),
  createBranch: (body) => apiClient.post("/api/admin/meta-workspace/branches", body),
  branchCatalog: (params) => apiClient.get("/api/admin/meta-workspace/branch-catalog", { params }),
  branchTree: (params) => apiClient.get("/api/admin/meta-workspace/branch-tree", { params }),
  branchFile: (body) => apiClient.post("/api/admin/meta-workspace/branch-file", body),
  branchGpBundle: (body) => apiClient.post("/api/admin/meta-workspace/branch-gp-bundle", body),
  saveBranchGpBundle: (body) => apiClient.post("/api/admin/meta-workspace/branch-gp-bundle/save", body),
  saveBranchFile: (body) => apiClient.post("/api/admin/meta-workspace/branch-file/save", body),
  validateAll: (body) => apiClient.post("/api/admin/meta-workspace/validate-all", body),
  syncBranch: (body) => apiClient.post("/api/admin/meta-workspace/sync-branch", body),
  createMr: (body) => apiClient.post("/api/admin/meta-workspace/mr", body),
};
