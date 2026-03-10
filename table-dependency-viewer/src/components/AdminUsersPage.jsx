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
  const [refreshing, setRefreshing] = useState(false);
  const [refreshMsg, setRefreshMsg] = useState(null);
  const [deploying, setDeploying] = useState(false);
  const [deployMsg, setDeployMsg] = useState(null);
  const [deployOutput, setDeployOutput] = useState(null);
  const [deployError, setDeployError] = useState(null);
  const [deployReady, setDeployReady] = useState(false);
  const [lastDeployAt, setLastDeployAt] = useState(null);
  const [deletingId, setDeletingId] = useState(null);
  const [togglingId, setTogglingId] = useState(null);
  const [form, setForm] = useState({
    email: "",
    username: "",
    password: "",
    role: "analyst",
  });

  const normalizeError = (value) => {
    if (!value) return "Неизвестная ошибка";
    if (typeof value === "string") return value;
    if (value.detail) {
      if (typeof value.detail === "string") return value.detail;
      if (Array.isArray(value.detail)) {
        return value.detail.map((d) => d.msg || JSON.stringify(d)).join("; ");
      }
      return JSON.stringify(value.detail);
    }
    try {
      return JSON.stringify(value);
    } catch {
      return String(value);
    }
  };

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

  useEffect(() => {
    const loadStatus = async () => {
      try {
        const resp = await fetch(`${API_BASE}/api/admin/ci-cd/status`);
        if (!resp.ok) {
          const data = await resp.json().catch(() => ({}));
          throw data;
        }
        const data = await resp.json();
        setLastDeployAt(data?.last_run_at || null);
        if (data?.stdout || data?.stderr) {
          setDeployOutput({
            stdout: data?.stdout || "",
            stderr: data?.stderr || "",
            status: data?.status || null,
            return_code: data?.return_code ?? null,
          });
        }
      } catch {
        // ignore (silent)
      }
    };
    loadStatus();
  }, []);

  const handleRefreshCache = async () => {
    setRefreshing(true);
    setRefreshMsg(null);
    setError(null);
    try {
      const resp = await fetch(`${API_BASE}/api/admin/refresh-cache`, { method: "POST" });
      if (!resp.ok) {
        const data = await resp.json().catch(() => ({}));
        throw new Error(data.detail || "Не удалось обновить кеш");
      }
      setRefreshMsg("Кеш обновлён");
    } catch (err) {
      setError(err.message || "Не удалось обновить кеш");
    } finally {
      setRefreshing(false);
    }
  };

  const handleRunCiCd = async () => {
    if (!deployReady) {
      setError("Подтвердите запуск ci_cd");
      return;
    }
    setDeploying(true);
    setDeployMsg(null);
    setDeployError(null);
    setDeployOutput(null);
    setError(null);
    try {
      const resp = await fetch(`${API_BASE}/api/admin/run-ci-cd`, { method: "POST" });
      if (!resp.ok) {
        const data = await resp.json().catch(() => ({}));
        const detail = data.detail || data;
        const errText = detail?.stderr || normalizeError(detail) || "Не удалось запустить ci_cd";
        setDeployError(errText);
        setDeployOutput(detail?.stdout || detail?.stderr ? detail : null);
        throw new Error(errText);
      }
      const data = await resp.json().catch(() => ({}));
      setDeployMsg("Скрипт ci_cd выполнен");
      setDeployOutput(data);
      setLastDeployAt(data?.last_run_at || new Date().toLocaleString("ru-RU"));
      setDeployReady(false);
    } catch (err) {
      setError(normalizeError(err));
    } finally {
      setDeploying(false);
    }
  };

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

  const handleToggleUser = async (userId, email, isActive) => {
    const actionLabel = isActive ? "Отключить" : "Включить";
    if (!window.confirm(`${actionLabel} пользователя ${email}?`)) return;
    setTogglingId(userId);
    setError(null);
    try {
      const endpoint = isActive
        ? `${API_BASE}/auth/users/${userId}/disable`
        : `${API_BASE}/auth/users/${userId}/enable`;
      const resp = await fetch(endpoint, { method: "POST" });
      if (!resp.ok) {
        const data = await resp.json().catch(() => ({}));
        throw new Error(data.detail || "Не удалось изменить статус пользователя");
      }
      await fetchUsers();
    } catch (err) {
      setError(err.message || "Не удалось изменить статус пользователя");
    } finally {
      setTogglingId(null);
    }
  };

  const handleDeleteUser = async (userId, email) => {
    if (!window.confirm(`Удалить пользователя ${email}? Действие необратимо.`)) return;
    setDeletingId(userId);
    setError(null);
    try {
      const resp = await fetch(`${API_BASE}/auth/users/${userId}`, { method: "DELETE" });
      if (!resp.ok) {
        const data = await resp.json().catch(() => ({}));
        throw new Error(data.detail || "Не удалось удалить пользователя");
      }
      await fetchUsers();
    } catch (err) {
      setError(err.message || "Не удалось удалить пользователя");
    } finally {
      setDeletingId(null);
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
        <div style={{ display: "flex", gap: 12, alignItems: "center", marginBottom: 16 }}>
          <button className="btn btn-secondary" onClick={handleRefreshCache} disabled={refreshing}>
            {refreshing ? "Обновляем кеш..." : "Принудительно обновить кеш"}
          </button>
          <button className="btn btn-secondary" onClick={handleRunCiCd} disabled={deploying}>
            {deploying ? "Запускаем ci_cd..." : "Обновить метаданные (ci_cd)"}
          </button>
          {refreshMsg && <div className="muted">{refreshMsg}</div>}
          {deployMsg && <div className="muted">{deployMsg}</div>}
        </div>
        <div className="admin-ci-block">
          <label className="admin-ci-check">
            <input
              type="checkbox"
              checked={deployReady}
              onChange={(e) => setDeployReady(e.target.checked)}
            />
            Подтверждаю запуск ci_cd
          </label>
          {lastDeployAt && <div className="muted">Последний запуск: {lastDeployAt}</div>}
          {deployError && <div className="login-error">{deployError}</div>}
          {deployOutput && (
            <div className="admin-ci-output">
              <div className="muted">Вывод ci_cd</div>
              {deployOutput?.status && (
                <div className="muted">Статус: {deployOutput.status}</div>
              )}
              {deployOutput?.stdout && (
                <pre className="admin-ci-pre">{deployOutput.stdout}</pre>
              )}
              {deployOutput?.stderr && (
                <pre className="admin-ci-pre error">{deployOutput.stderr}</pre>
              )}
            </div>
          )}
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

        {error && <div className="login-error">{normalizeError(error)}</div>}
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
              <div>Действия</div>
            </div>
            {users.map((user) => (
              <div className="admin-row" key={user.id}>
                <div>{user.email}</div>
                <div>{user.username}</div>
                <div>{user.role}</div>
                <div>{user.is_active ? "Активен" : "Отключён"}</div>
                <div>
                  <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                    <button
                      className="btn btn-ghost"
                      disabled={userProfile?.email === user.email || togglingId === user.id}
                      onClick={() => handleToggleUser(user.id, user.email, user.is_active)}
                    >
                      {togglingId === user.id
                        ? "Обновляем..."
                        : user.is_active
                          ? "Отключить"
                          : "Включить"}
                    </button>
                    <button
                      className="btn btn-ghost"
                      disabled={userProfile?.email === user.email || deletingId === user.id}
                      onClick={() => handleDeleteUser(user.id, user.email)}
                    >
                      {deletingId === user.id ? "Удаляем..." : "Удалить"}
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
