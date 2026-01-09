// frontend/src/config/auth.js
export const API_BASE_URL = 'http://localhost:8001';

export const AUTH_CONFIG = {
  TOKEN_KEY: 'auth_token',
  TOKEN_TYPE: 'Bearer',
  LOGIN_URL: '/login',
  REGISTER_URL: '/register',
  PROFILE_URL: '/profile'
};

export const apiUrl = (endpoint) => {
  return `${API_BASE_URL}${endpoint}`;
};
