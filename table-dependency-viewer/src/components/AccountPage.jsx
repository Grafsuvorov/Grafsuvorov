import React, { useState } from "react";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

const ROLE_LABELS = {
  analyst: "Аналитик",
  engineer: "Инженер",
  admin: "Админ",
};

export default function AccountPage({ userProfile }) {
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [repeatPassword, setRepeatPassword] = useState("");
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError(null);
    setSuccess(null);
    if (!currentPassword || !newPassword) {
      setError("Заполните все поля.");
      return;
    }
    if (newPassword !== repeatPassword) {
      setError("Новый пароль и подтверждение не совпадают.");
      return;
    }
    setLoading(true);
    try {
      const resp = await fetch(`${API_BASE}/auth/change-password`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          current_password: currentPassword,
          new_password: newPassword,
        }),
      });
      if (!resp.ok) {
        const data = await resp.json().catch(() => ({}));
        throw new Error(data.detail || "Не удалось сменить пароль");
      }
      setSuccess("Пароль обновлён.");
      setCurrentPassword("");
      setNewPassword("");
      setRepeatPassword("");
    } catch (err) {
      setError(err.message || "Не удалось сменить пароль");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container cc-page">
      <section className="cc-surface account-card">
        <div className="section-title">Профиль</div>
        <div className="account-meta">
          <div>
            <div className="account-label">Пользователь</div>
            <div className="account-value">
              {userProfile?.username || userProfile?.email || "—"}
            </div>
          </div>
          <div>
            <div className="account-label">Роль</div>
            <div className="account-value">
              {ROLE_LABELS[userProfile?.role] || userProfile?.role || "—"}
            </div>
          </div>
        </div>
      </section>

      <section className="cc-surface account-card">
        <div className="section-title">Сменить пароль</div>
        <form className="account-form" onSubmit={handleSubmit}>
          <label className="account-label">Текущий пароль</label>
          <input
            type="password"
            value={currentPassword}
            onChange={(e) => setCurrentPassword(e.target.value)}
            placeholder="••••••••"
          />
          <label className="account-label">Новый пароль</label>
          <input
            type="password"
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            placeholder="Новый пароль"
          />
          <label className="account-label">Повторить пароль</label>
          <input
            type="password"
            value={repeatPassword}
            onChange={(e) => setRepeatPassword(e.target.value)}
            placeholder="Повторите пароль"
          />
          {error && <div className="login-error">{error}</div>}
          {success && <div className="account-success">{success}</div>}
          <button type="submit" className="account-submit" disabled={loading}>
            {loading ? "Сохраняем..." : "Обновить пароль"}
          </button>
        </form>
      </section>
    </div>
  );
}
