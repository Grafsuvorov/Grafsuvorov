import { apiClient } from "./client.js";

export const assistantApi = {
  query: (body) => apiClient.post("/api/admin/assistant/query", body),
};
