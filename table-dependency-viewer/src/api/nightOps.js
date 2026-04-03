import { apiClient } from "./client.js";

const SHORT_TTL = 5 * 60 * 1000;
const MEDIUM_TTL = 3 * 60 * 1000;

export const nightOpsApi = {
  summary: (days = 30, limit = 50, shiftDays = 0) =>
    apiClient.getCached("/api/night-summary", {
      ttlMs: SHORT_TTL,
      params: { days, limit, ...(shiftDays ? { shift_days: shiftDays } : {}) },
    }),
  clickSlowStages: (days = 7, limit = 20) =>
    apiClient.getCached("/api/click/slow-stages", {
      ttlMs: MEDIUM_TTL,
      params: { days, limit },
    }),
  clickSummary: (days = 7, limit = 10) =>
    apiClient.getCached("/api/click/summary", {
      ttlMs: MEDIUM_TTL,
      params: { days, limit },
    }),
  heavyTables: ({ days = 30, limit, windowStart, windowEnd }) =>
    apiClient.getCached("/api/night/heavy-tables", {
      ttlMs: MEDIUM_TTL,
      params: { days, limit, window_start: windowStart, window_end: windowEnd },
    }),
};

