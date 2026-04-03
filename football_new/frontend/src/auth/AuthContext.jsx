import React, { createContext, useContext, useState, useEffect } from 'react';
import { syncFavoritesFromServer } from "@/lib/favoritesStorage.js";

const AuthContext = createContext(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  const isAuthenticated = !!user;

  const getStoredToken = (key) => {
    try {
      return localStorage.getItem(key) || sessionStorage.getItem(key);
    } catch {
      return null;
    }
  };

  const safeSetItem = (key, value) => {
    try {
      localStorage.setItem(key, value);
      return "local";
    } catch (e) {
      try {
        localStorage.removeItem("favorites_teams");
        localStorage.removeItem("favorites_players");
        localStorage.removeItem("recent_leagues");
      } catch {}
      try {
        localStorage.setItem(key, value);
        return "local";
      } catch {
        try {
          sessionStorage.setItem(key, value);
          return "session";
        } catch {
          return null;
        }
      }
    }
  };

  const clearStoredToken = (key) => {
    try {
      localStorage.removeItem(key);
    } catch {}
    try {
      sessionStorage.removeItem(key);
    } catch {}
  };

  const refreshSession = async () => {
    const refreshToken = getStoredToken('refresh_token');
    if (!refreshToken) return false;
    try {
      const response = await fetch('/auth-dwh/refresh', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refresh_token: refreshToken }),
      });
      if (!response.ok) return false;
      const data = await response.json();
      safeSetItem('access_token', data.access_token);
      safeSetItem('refresh_token', data.refresh_token);
      setUser(data.user);
      await syncFavoritesFromServer();
      return true;
    } catch {
      return false;
    }
  };

  const checkAuth = async () => {
    try {
      const token = getStoredToken('access_token');
      if (!token) {
        const refreshed = await refreshSession();
        if (!refreshed) {
          setIsLoading(false);
        }
        return;
      }

      const response = await fetch('/auth-dwh/me', {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      if (response.ok) {
        const userData = await response.json();
        setUser(userData);
        await syncFavoritesFromServer();
      } else if (response.status === 401 || response.status === 403) {
        const refreshed = await refreshSession();
        if (!refreshed) {
          clearStoredToken('access_token');
          clearStoredToken('refresh_token');
          setUser(null);
        }
      } else {
        // Не сносим сессию при временных ошибках сервиса auth
        console.warn('Auth service unavailable:', response.status);
      }
    } catch (error) {
      console.error('Auth check failed:', error);
      // Не чистим токены при сетевых/временных ошибках
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (email, password) => {
    try {
      const response = await fetch('/auth-dwh/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, password }),
      });

      if (response.ok) {
        const data = await response.json();
        safeSetItem('access_token', data.access_token);
        safeSetItem('refresh_token', data.refresh_token);
        setUser(data.user);
        await syncFavoritesFromServer();
        return true;
      } else {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Login failed');
      }
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  };

  const register = async (email, username, password) => {
    try {
      const response = await fetch('/auth-dwh/register', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, username, password }),
      });

      if (response.ok) {
        return true;
      } else {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Registration failed');
      }
    } catch (error) {
      console.error('Registration error:', error);
      throw error;
    }
  };

  const logout = () => {
    clearStoredToken('access_token');
    clearStoredToken('refresh_token');
    setUser(null);
  };

  useEffect(() => {
    checkAuth();
  }, []);

  const value = {
    user,
    isAuthenticated,
    isLoading,
    login,
    register,
    logout,
    checkAuth,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
