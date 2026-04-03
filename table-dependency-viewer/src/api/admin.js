import { apiClient } from "./client.js";

export const adminApi = {
  users: () => apiClient.get("/auth/users"),
  userAnalytics: (days) => apiClient.get("/auth/users/analytics", { params: { days } }),
  ciCdStatus: () => apiClient.get("/api/admin/ci-cd/status"),
  refreshCache: () => apiClient.post("/api/admin/refresh-cache"),
  runCiCd: () => apiClient.post("/api/admin/run-ci-cd"),
  createUser: (body) => apiClient.post("/auth/users", body),
  updateUser: (userId, body) => apiClient.put(`/auth/users/${userId}`, body),
  disableUser: (userId) => apiClient.post(`/auth/users/${userId}/disable`),
  enableUser: (userId) => apiClient.post(`/auth/users/${userId}/enable`),
  deleteUser: (userId) => apiClient.del(`/auth/users/${userId}`),
};
