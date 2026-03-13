import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

const ROLE_LABELS = {
  analyst: "Аналитик",
  engineer: "Инженер",
  admin: "Админ",
};

export default function AccountPage({ userProfile }) {
  const navigate = useNavigate();
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [repeatPassword, setRepeatPassword] = useState("");
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [loading, setLoading] = useState(false);
  const [favorites, setFavorites] = useState([]);
  const [favoritesLoading, setFavoritesLoading] = useState(false);
  const [favoritesError, setFavoritesError] = useState(null);
  const [removingFavoriteId, setRemovingFavoriteId] = useState(null);
  const [passwordModalOpen, setPasswordModalOpen] = useState(false);

  const loadFavorites = async () => {
    setFavoritesLoading(true);
    setFavoritesError(null);
    try {
      const resp = await fetch(`${API_BASE}/auth/favorites/tables`);
      if (!resp.ok) {
        throw new Error("Не удалось загрузить избранные таблицы");
      }
      const data = await resp.json();
      setFavorites(Array.isArray(data?.items) ? data.items : []);
    } catch (err) {
      setFavoritesError(err.message || "Не удалось загрузить избранные таблицы");
    } finally {
      setFavoritesLoading(false);
    }
  };

  useEffect(() => {
    loadFavorites();
  }, []);

  const resetPasswordForm = () => {
    setCurrentPassword("");
    setNewPassword("");
    setRepeatPassword("");
    setError(null);
    setSuccess(null);
  };

  const closePasswordModal = () => {
    setPasswordModalOpen(false);
    resetPasswordForm();
  };

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

  const handleRemoveFavorite = async (tableId) => {
    setRemovingFavoriteId(tableId);
    try {
      const resp = await fetch(`${API_BASE}/auth/favorites/tables/${encodeURIComponent(tableId)}`, {
        method: "DELETE",
      });
      if (!resp.ok) {
        throw new Error("Не удалось убрать таблицу из избранного");
      }
      setFavorites((prev) => prev.filter((item) => item.table_id !== tableId));
    } catch (err) {
      setFavoritesError(err.message || "Не удалось убрать таблицу из избранного");
    } finally {
      setRemovingFavoriteId(null);
    }
  };

  return (
    <div className="container cc-page">
      <section className="cc-surface account-shell">
        <div className="account-hero">
          <div className="account-hero-main">
            <div className="account-avatar">
              {(userProfile?.username || userProfile?.email || "U").slice(0, 1).toUpperCase()}
            </div>
            <div className="account-hero-text">
              <div className="section-title">Профиль</div>
              <div className="account-hero-name">
                {userProfile?.username || userProfile?.email || "Пользователь"}
              </div>
              <div className="account-hero-email">{userProfile?.email || "—"}</div>
            </div>
          </div>
          <div className="account-hero-actions">
            <span className="account-role-pill">
              {ROLE_LABELS[userProfile?.role] || userProfile?.role || "—"}
            </span>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => {
                resetPasswordForm();
                setPasswordModalOpen(true);
              }}
            >
              Сменить пароль
            </button>
          </div>
        </div>

        <div className="account-stats">
          <div className="account-stat-card">
            <div className="account-stat-label">Роль</div>
            <div className="account-stat-value">
              {ROLE_LABELS[userProfile?.role] || userProfile?.role || "—"}
            </div>
          </div>
          <div className="account-stat-card">
            <div className="account-stat-label">Избранных таблиц</div>
            <div className="account-stat-value">{favorites.length}</div>
          </div>
          <div className="account-stat-card">
            <div className="account-stat-label">Email</div>
            <div className="account-stat-value account-stat-value-small">{userProfile?.email || "—"}</div>
          </div>
        </div>
      </section>

      <section className="cc-surface account-shell">
        <div className="section-title">Избранные таблицы</div>
        {favoritesError && <div className="login-error">{favoritesError}</div>}
        {favoritesLoading && <div className="muted">Загрузка избранного...</div>}
        {!favoritesLoading && !favorites.length && (
          <div className="account-favorites-empty">
            Пока нет избранных таблиц. Добавляй их из карточки таблицы.
          </div>
        )}
        {!favoritesLoading && favorites.length > 0 && (
          <div className="account-favorites-list">
            {favorites.map((item) => {
              const tableFqn = `${item.table_schema}.${item.table_name}`;
              return (
                <div key={item.table_id} className="account-favorite-row">
                  <div className="account-favorite-main">
                    <div className="account-favorite-title">{tableFqn}</div>
                    <div className="account-favorite-meta">
                      <span>{item.entity_name || "Сущность не найдена"}</span>
                      <span>ID {item.table_id}</span>
                      <span>Загрузка: {item.table_last_load || "—"}</span>
                    </div>
                  </div>
                  <div className="account-favorite-actions">
                    <button
                      type="button"
                      className="btn btn-secondary"
                      onClick={() =>
                        navigate(
                          `/table/${encodeURIComponent(item.table_schema)}/${encodeURIComponent(item.table_name)}`
                        )
                      }
                    >
                      Открыть
                    </button>
                    <button
                      type="button"
                      className="btn btn-ghost"
                      disabled={removingFavoriteId === item.table_id}
                      onClick={() => handleRemoveFavorite(item.table_id)}
                    >
                      {removingFavoriteId === item.table_id ? "Удаляем..." : "Убрать"}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </section>

      {passwordModalOpen && (
        <div className="account-modal-backdrop" onClick={closePasswordModal}>
          <div className="account-modal" onClick={(event) => event.stopPropagation()}>
            <div className="account-modal-head">
              <div>
                <div className="section-title">Смена пароля</div>
                <div className="muted">Обнови текущий пароль для своего аккаунта.</div>
              </div>
              <button type="button" className="btn btn-ghost" onClick={closePasswordModal}>
                Закрыть
              </button>
            </div>

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
              <label className="account-label">Повторите новый пароль</label>
              <input
                type="password"
                value={repeatPassword}
                onChange={(e) => setRepeatPassword(e.target.value)}
                placeholder="Повторите пароль"
              />
              {error && <div className="login-error">{error}</div>}
              {success && <div className="account-success">{success}</div>}
              <div className="account-modal-actions">
                <button type="button" className="btn btn-ghost" onClick={closePasswordModal}>
                  Отмена
                </button>
                <button type="submit" className="account-submit" disabled={loading}>
                  {loading ? "Сохраняем..." : "Обновить пароль"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
