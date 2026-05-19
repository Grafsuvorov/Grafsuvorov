import { apiClient } from "./client.js";

export const metaWorkspaceApi = {
  createMr: (body) => apiClient.post("/api/admin/meta-workspace/mr", body),
};
