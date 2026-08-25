import { apiClient } from "./client.js";

export const adminApi = {
  users: () => apiClient.get("/auth/users"),
  userAnalytics: (days) => apiClient.get("/auth/users/analytics", { params: { days } }),
  ciCdStatus: () => apiClient.get("/api/admin/ci-cd/status"),
  engineeringEfficiency: (days) => apiClient.get("/api/admin/engineering-efficiency", { params: { days } }),
  architectureWorkbench: () => apiClient.getCached("/api/admin/architecture/workbench", {
    ttlMs: 10 * 60 * 1000,
    params: { issue_type: "all", mode: "standard", min_score: 0.72, limit: 500, view_version: "2026-08-blocks-v2" },
  }),
  architectureBlockPair: (pairId) => apiClient.get(`/api/admin/architecture/block-pair/${encodeURIComponent(pairId)}`),
  releaseReports: (days) => apiClient.get("/api/admin/reports/releases", { params: { days } }),
  incidentReports: (days) => apiClient.get("/api/admin/reports/incidents", { params: { days } }),
  exportReportPdf: (body) => apiClient.post("/api/admin/reports/export-pdf", body, { expect: "response" }),
  feedback: (params) => apiClient.get("/api/admin/feedback", { params }),
  prototypeReviewRun: (body) => apiClient.post("/api/admin/prototype-review/run", body),
  tablesDetailed: () => apiClient.getCached("/api/tables", { ttlMs: 10 * 60 * 1000, params: { detailed: true } }),
  tableCard: (schema, table, params) => apiClient.get(`/api/card/${encodeURIComponent(schema)}/${encodeURIComponent(table)}`, { params }),
  refreshCache: () => apiClient.post("/api/admin/refresh-cache"),
  runCiCd: () => apiClient.post("/api/admin/run-ci-cd"),
  createUser: (body) => apiClient.post("/auth/users", body),
  updateUser: (userId, body) => apiClient.put(`/auth/users/${userId}`, body),
  disableUser: (userId) => apiClient.post(`/auth/users/${userId}/disable`),
  enableUser: (userId) => apiClient.post(`/auth/users/${userId}/enable`),
  deleteUser: (userId) => apiClient.del(`/auth/users/${userId}`),
};
