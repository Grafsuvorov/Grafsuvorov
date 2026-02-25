import React, { useEffect, useState } from "react";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

const ROLE_OPTIONS = [
  { value: "analyst", label: "Аналитик" },
  { value: "engineer", label: "Инженер" },
  { value: "admin", label: "Админ" },
];

export default function AdminUsersPage({ userProfile }) {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [form, setForm] = useState({
    email: "",
    username: "",
    password: "",
    role: "analyst",
  });

  const fetchUsers = async () => {
    setLoading(true);
    setError(null);
    try {
      const resp = await fetch(`${API_BASE}/auth/users`);
      if (!resp.ok) {
        const data = await resp.json().catch(() => ({}));
        throw new Error(data.detail || "Не удалось загрузить пользователей");
      }
      const data = await resp.json();
      setUsers(data);
    } catch (err) {
      setError(err.message || "Не удалось загрузить пользователей");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError(null);
    try {
      const resp = await fetch(`${API_BASE}/auth/users`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(form),
      });
      if (!resp.ok) {
        const data = await resp.json().catch(() => ({}));
        throw new Error(data.detail || "Не удалось создать пользователя");
      }
      setForm({ email: "", username: "", password: "", role: "analyst" });
      await fetchUsers();
    } catch (err) {
      setError(err.message || "Не удалось создать пользователя");
    }
  };

  if (userProfile?.role !== "admin") {
    return (
      <div className="container cc-page">
        <div className="cc-surface">
          <div className="section-title">Доступ запрещён</div>
          <div className="muted">Требуется роль администратора.</div>
        </div>
      </div>
    );
  }

  return (
    <div className="container cc-page">
      <section className="cc-surface admin-users">
        <div className="section-title">Управление пользователями</div>
        <div className="section-subtitle">
          Создавайте учётные записи и выдавайте доступ к системе.
        </div>

        <form className="admin-form" onSubmit={handleSubmit}>
          <div className="admin-field">
            <label>Email</label>
            <input
              type="email"
              value={form.email}
              onChange={(e) => setForm((prev) => ({ ...prev, email: e.target.value }))}
              placeholder="name@company.ru"
              required
            />
          </div>
          <div className="admin-field">
            <label>Логин</label>
            <input
              type="text"
              value={form.username}
              onChange={(e) => setForm((prev) => ({ ...prev, username: e.target.value }))}
              placeholder="username"
              required
            />
          </div>
          <div className="admin-field">
            <label>Пароль</label>
            <input
              type="text"
              value={form.password}
              onChange={(e) => setForm((prev) => ({ ...prev, password: e.target.value }))}
              placeholder="Временный пароль"
              required
            />
          </div>
          <div className="admin-field">
            <label>Роль</label>
            <select
              value={form.role}
              onChange={(e) => setForm((prev) => ({ ...prev, role: e.target.value }))}
            >
              {ROLE_OPTIONS.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </div>
          <button type="submit" className="admin-submit">
            Создать пользователя
          </button>
        </form>

        {error && <div className="login-error">{error}</div>}
      </section>

      <section className="cc-surface admin-users">
        <div className="section-title">Список пользователей</div>
        {loading && <div className="muted">Загрузка...</div>}
        {!loading && (
          <div className="admin-table">
            <div className="admin-row admin-header">
              <div>Email</div>
              <div>Логин</div>
              <div>Роль</div>
              <div>Статус</div>
            </div>
            {users.map((user) => (
              <div className="admin-row" key={user.id}>
                <div>{user.email}</div>
                <div>{user.username}</div>
                <div>{user.role}</div>
                <div>{user.is_active ? "Активен" : "Отключён"}</div>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
