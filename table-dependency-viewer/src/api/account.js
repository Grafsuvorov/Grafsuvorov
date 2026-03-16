import { apiClient } from "./client.js";

export const accountApi = {
  me: () => apiClient.get("/auth/me"),
  updateProfile: (body) => apiClient.put("/auth/me", body),
  changePassword: (body) => apiClient.post("/auth/change-password", body),
  favoriteTables: () => apiClient.get("/auth/favorites/tables"),
  favoriteEntities: () => apiClient.get("/auth/favorites/entities"),
  addFavoriteTable: (body) => apiClient.post("/auth/favorites/tables", body),
  removeFavoriteTable: (tableId) => apiClient.del(`/auth/favorites/tables/${encodeURIComponent(tableId)}`),
  isFavoriteTable: (tableId) => apiClient.get(`/auth/favorites/tables/${encodeURIComponent(tableId)}`),
  addFavoriteEntity: (body) => apiClient.post("/auth/favorites/entities", body),
  removeFavoriteEntity: (entityId) =>
    apiClient.del(`/auth/favorites/entities/${encodeURIComponent(entityId)}`),
  isFavoriteEntity: (entityId) => apiClient.get(`/auth/favorites/entities/${encodeURIComponent(entityId)}`),
};

