import { apiClient } from "./client.js";

export const feedbackApi = {
  submit: (body) => apiClient.post("/api/feedback", body),
};

