import React, { useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";
const TOKEN_KEY = "tdv_access_token";
const USER_KEY = "tdv_user_profile";

export default function LoginPage({ onLogin }) {
  const location = useLocation();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(true);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const params = useMemo(() => new URLSearchParams(location.search), [location.search]);
  const sessionExpired = params.get("reason") === "session-expired";
  const nextPath = params.get("next") || "/";

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const resp = await fetch(`${API_BASE}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      if (!resp.ok) {
        const data = await resp.json().catch(() => ({}));
        throw new Error(data.detail || "Ошибка входа");
      }
      const data = await resp.json();
      const storage = remember ? localStorage : sessionStorage;
      const otherStorage = remember ? sessionStorage : localStorage;
      otherStorage.removeItem(TOKEN_KEY);
      otherStorage.removeItem(USER_KEY);
      storage.setItem(TOKEN_KEY, data.access_token);
      storage.setItem(
        USER_KEY,
        JSON.stringify({ email: data.email, username: data.username, role: data.role })
      );
      if (onLogin) {
        onLogin({
          token: data.access_token,
          profile: { email: data.email, username: data.username, role: data.role },
        });
      }
      navigate(nextPath, { replace: true });
    } catch (err) {
      setError(err.message || "Ошибка входа");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-eyebrow">DWH Контроль</div>
        <div className="login-title">Вход в систему</div>
        <div className="login-subtitle">
          Операционная панель контроля платформы, загрузок и релизного контура.
        </div>
        {sessionExpired && !error && (
          <div className="login-error">
            Сессия истекла. Войдите снова, чтобы продолжить работу.
          </div>
        )}
        <form onSubmit={handleSubmit} className="login-form">
          <label className="login-label">Email</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="name@company.ru"
            required
          />
          <label className="login-label">Пароль</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="••••••••"
            required
          />
          <label className="login-remember">
            <input
              type="checkbox"
              checked={remember}
              onChange={(e) => setRemember(e.target.checked)}
            />
            Запомнить меня
          </label>
          {error && <div className="login-error">{error}</div>}
          <button type="submit" disabled={loading}>
            {loading ? "Входим..." : "Войти"}
          </button>
        </form>
        <div className="login-help">
          <strong>Нет доступа?</strong> Запросите учётную запись у администратора.
        </div>
      </div>
    </div>
  );
}
