import React, { useEffect, useState } from "react";
import { formatRuDateTime } from "../utils/datetime.js";
import { adminApi } from "../api/admin.js";

const ROLE_OPTIONS = [
  { value: "analyst", label: "Аналитик" },
  { value: "engineer", label: "Инженер" },
  { value: "admin", label: "Админ" },
];

const ROLE_LABELS = {
  analyst: "Аналитик",
  engineer: "Инженер",
  admin: "Админ",
};

const EVENT_LABELS = {
  login: "Вход",
  logout: "Выход",
  page_view: "Просмотр страницы",
  open_table: "Открыл карточку таблицы",
  open_dependency_graph: "Открыл граф зависимостей",
  open_impact_graph: "Открыл граф влияния",
  open_release: "Открыл релиз",
  open_logic_audit: "Открыл аудит логики",
  open_incident: "Открыл инцидент",
  register_success: "Регистрация",
  admin_create_user: "Создал пользователя",
};

const PAGE_LABELS = {
  "/": "Обзор",
  "/tables": "Каталог",
  "/slow-tables": "Производительность",
  "/night-ops": "Мониторинг",
  "/entities": "Сущности",
  "/releases": "Релизы",
  "/logic-audit": "Аудит логики",
  "/account": "Профиль",
  "/admin/users": "Админка",
  "/admin/feedback": "Обратная связь",
  "/onboarding": "Гид",
  "/about-app": "О приложении",
};

export default function AdminUsersPage({ userProfile }) {
  const [users, setUsers] = useState([]);
  const [auditDays, setAuditDays] = useState(30);
  const [audit, setAudit] = useState(null);
  const [auditLoading, setAuditLoading] = useState(false);
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
  const [roleUpdatingId, setRoleUpdatingId] = useState(null);
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

  const formatDateTime = (value) => {
    if (!value) return "—";
    return formatRuDateTime(value);
  };

  const formatRole = (value) => ROLE_LABELS[value] || value || "—";
  const formatEvent = (value) => EVENT_LABELS[value] || value || "—";
  const pageLabel = (value) => PAGE_LABELS[value] || value || "Не указана";
  const topUser = audit?.users?.[0] || null;
  const topPage = audit?.pages?.[0] || null;
  const topAction = audit?.actions?.[0] || null;

  const fetchUsers = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await adminApi.users();
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
    const loadAudit = async () => {
      setAuditLoading(true);
      try {
        const data = await adminApi.userAnalytics(auditDays);
        setAudit(data || null);
      } catch (err) {
        setError(err.message || "Не удалось загрузить аналитику пользователей");
      } finally {
        setAuditLoading(false);
      }
    };
    loadAudit();
  }, [auditDays]);

  useEffect(() => {
    const loadStatus = async () => {
      try {
        const data = await adminApi.ciCdStatus();
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
      await adminApi.refreshCache();
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
      const data = await adminApi.runCiCd();
      setDeployMsg("Скрипт ci_cd выполнен");
      setDeployOutput(data);
      setLastDeployAt(data?.last_run_at || new Date().toLocaleString("ru-RU"));
      setDeployReady(false);
    } catch (err) {
      setDeployError(normalizeError(err));
      if (err?.detail && typeof err.detail === "object") {
        setDeployOutput(err.detail);
        setLastDeployAt(err.detail?.last_run_at || null);
        return;
      }
      try {
        const status = await adminApi.ciCdStatus();
        setDeployOutput(status);
        setLastDeployAt(status?.last_run_at || null);
      } catch {
        // ignore secondary status load errors
      }
    } finally {
      setDeploying(false);
    }
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError(null);
    try {
      await adminApi.createUser(form);
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
      if (isActive) await adminApi.disableUser(userId);
      else await adminApi.enableUser(userId);
      await fetchUsers();
    } catch (err) {
      setError(err.message || "Не удалось изменить статус пользователя");
    } finally {
      setTogglingId(null);
    }
  };

  const handleChangeRole = async (userId, email, role) => {
    const nextRole = String(role || "").toLowerCase();
    if (!nextRole) return;
    if (!window.confirm(`Изменить роль пользователя ${email} на ${formatRole(nextRole)}?`)) return;
    setRoleUpdatingId(userId);
    setError(null);
    try {
      await adminApi.updateUser(userId, { role: nextRole });
      await fetchUsers();
    } catch (err) {
      setError(err.message || "Не удалось изменить роль пользователя");
    } finally {
      setRoleUpdatingId(null);
    }
  };

  const handleDeleteUser = async (userId, email) => {
    if (!window.confirm(`Удалить пользователя ${email}? Действие необратимо.`)) return;
    setDeletingId(userId);
    setError(null);
    try {
      await adminApi.deleteUser(userId);
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
        <div className="section-title">Активность пользователей</div>
        <div className="section-subtitle">
          Кто заходит в систему, какими разделами пользуется и какие действия совершает.
        </div>
        <div className="admin-analytics-toolbar">
          <label className="admin-field" style={{ maxWidth: 180 }}>
            <span>Окно, дней</span>
            <select value={auditDays} onChange={(e) => setAuditDays(Number(e.target.value))}>
              {[7, 14, 30].map((value) => (
                <option key={value} value={value}>
                  {value}
                </option>
              ))}
            </select>
          </label>
          <div className="muted">
            Данные аудита хранятся 30 дней. Основной фокус: логины, переходы по страницам и объектные действия.
          </div>
        </div>
        {auditLoading && <div className="muted">Загрузка аудита...</div>}
        {!auditLoading && audit?.summary && (
          <>
            <div className="admin-analytics-grid">
              <div className="admin-analytics-card">
                <div className="label">Пользователей</div>
                <div className="value">{audit.summary.users_count ?? 0}</div>
                <div className="hint">Уникальные email за окно</div>
              </div>
              <div className="admin-analytics-card">
                <div className="label">Успешных входов</div>
                <div className="value">{audit.summary.logins_count ?? 0}</div>
                <div className="hint">Рабочие входы в систему</div>
              </div>
              <div className="admin-analytics-card danger">
                <div className="label">Неуспешных входов</div>
                <div className="value">{audit.summary.failed_logins_count ?? 0}</div>
                <div className="hint">Ошибки логина и токена</div>
              </div>
              <div className="admin-analytics-card">
                <div className="label">Просмотров страниц</div>
                <div className="value">{audit.summary.page_views_count ?? 0}</div>
                <div className="hint">Навигация по разделам</div>
              </div>
              <div className="admin-analytics-card">
                <div className="label">Действий</div>
                <div className="value">{audit.summary.actions_count ?? 0}</div>
                <div className="hint">Карточки, графы, релизы, аудит</div>
              </div>
            </div>

            <div className="admin-analytics-overview">
              <div className="admin-analytics-spotlight">
                <div className="section-subtitle">Кто активнее всех</div>
                {topUser ? (
                  <div className="admin-spotlight-card">
                    <div className="admin-spotlight-head">
                      <div>
                        <div className="admin-spotlight-title">{topUser.user_email}</div>
                        <div className="muted">
                          {formatRole(topUser.user_role)} · последняя активность {formatDateTime(topUser.last_activity_at)}
                        </div>
                      </div>
                      <div className="admin-spotlight-badge">{topUser.events_count ?? 0} событий</div>
                    </div>
                    <div className="admin-spotlight-metrics">
                      <div>
                        <span>Входов</span>
                        <strong>{topUser.logins_count ?? 0}</strong>
                      </div>
                      <div>
                        <span>Просмотров</span>
                        <strong>{topUser.page_views_count ?? 0}</strong>
                      </div>
                      <div>
                        <span>Действий</span>
                        <strong>{topUser.actions_count ?? 0}</strong>
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="muted">Нет данных по пользователям.</div>
                )}
              </div>

              <div className="admin-analytics-spotlight">
                <div className="section-subtitle">Сводка использования</div>
                <div className="admin-mini-cards">
                  <div className="admin-mini-card">
                    <div className="label">Топ страница</div>
                    <div className="mini-title">{pageLabel(topPage?.page)}</div>
                    <div className="muted">{topPage?.events_count ?? 0} просмотров</div>
                  </div>
                  <div className="admin-mini-card">
                    <div className="label">Топ действие</div>
                    <div className="mini-title">{formatEvent(topAction?.event_type)}</div>
                    <div className="muted">{topAction?.events_count ?? 0} событий</div>
                  </div>
                  <div className="admin-mini-card">
                    <div className="label">Всего событий</div>
                    <div className="mini-title">{audit.summary.events_count ?? 0}</div>
                    <div className="muted">Все события в окне</div>
                  </div>
                </div>
              </div>
            </div>

            <div className="admin-analytics-columns admin-analytics-columns-main">
              <div className="admin-analytics-block">
                <div className="section-subtitle">Пользователи</div>
                <div className="admin-analytics-table">
                  <div className="admin-row admin-header admin-users-head">
                    <div>Пользователь</div>
                    <div>Входов</div>
                    <div>Страниц</div>
                    <div>Действий</div>
                    <div>Последняя активность</div>
                  </div>
                  {(audit.users || []).map((row) => (
                    <div className="admin-row admin-users-row" key={`user-${row.user_email}`}>
                      <div>
                        <div className="admin-primary">{row.user_email}</div>
                        <div className="muted">{formatRole(row.user_role)}</div>
                      </div>
                      <div>{row.logins_count ?? 0}</div>
                      <div>{row.page_views_count ?? 0}</div>
                      <div>{row.actions_count ?? 0}</div>
                      <div>{formatDateTime(row.last_activity_at)}</div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="admin-analytics-block">
                <div className="section-subtitle">Последние действия</div>
                <div className="admin-activity-feed admin-activity-feed-tall">
                  {(audit.recent || []).slice(0, 10).map((row, index) => (
                    <div className="admin-activity-item" key={`${row.ts}-${row.user_email || "unknown"}-${index}`}>
                      <div className="admin-activity-meta">
                        <span className="admin-activity-time">{formatDateTime(row.ts)}</span>
                        <span className={`admin-event-pill ${row.status === "failed" ? "danger" : ""}`}>
                          {formatEvent(row.event_type)}
                        </span>
                      </div>
                      <div className="admin-activity-main">
                        <strong>{row.user_email || "unknown"}</strong>
                        <span>{row.object_name || pageLabel(row.page) || "без объекта"}</span>
                      </div>
                      <div className="muted">
                        {formatRole(row.user_role)}
                        {row.page ? ` · ${pageLabel(row.page)}` : ""}
                        {row.object_type ? ` · ${row.object_type}` : ""}
                        {row.status ? ` · ${row.status}` : ""}
                      </div>
                    </div>
                  ))}
                  {!audit.recent?.length && <div className="muted">Событий пока нет.</div>}
                </div>
              </div>
            </div>

            <div className="admin-analytics-columns admin-analytics-columns-secondary" style={{ marginTop: 18 }}>
              <div className="admin-analytics-block">
                <div className="section-subtitle">Популярные страницы</div>
                <div className="admin-analytics-table">
                  <div className="admin-row admin-header admin-compact-row">
                    <div>Страница</div>
                    <div>Просмотров</div>
                  </div>
                  {(audit.pages || []).map((row) => (
                    <div className="admin-row admin-compact-row" key={row.page}>
                      <div className="admin-primary">{pageLabel(row.page)}</div>
                      <div>{row.events_count}</div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="admin-analytics-block">
                <div className="section-subtitle">Частые действия</div>
                <div className="admin-analytics-table">
                  <div className="admin-row admin-header admin-compact-row">
                    <div>Действие</div>
                    <div>Событий</div>
                  </div>
                  {(audit.actions || []).map((row) => (
                    <div className="admin-row admin-compact-row" key={row.event_type}>
                      <div className="admin-primary">{formatEvent(row.event_type)}</div>
                      <div>{row.events_count}</div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </>
        )}
      </section>

      <section className="cc-surface admin-users">
        <div className="section-title">Список пользователей</div>
        {loading && <div className="muted">Загрузка...</div>}
        {!loading && (
          <div className="admin-table">
            <div className="admin-row admin-header admin-users-head">
              <div>Email</div>
              <div>Логин</div>
              <div>Роль</div>
              <div>Статус</div>
              <div>Действия</div>
            </div>
            {users.map((user) => (
              <div className="admin-row admin-users-row" key={user.id}>
                <div>{user.email}</div>
                <div>{user.username}</div>
                <div>
                  <select
                    className="admin-role-select"
                    value={user.role}
                    disabled={roleUpdatingId === user.id}
                    onChange={(event) => handleChangeRole(user.id, user.email, event.target.value)}
                  >
                    {ROLE_OPTIONS.map((role) => (
                      <option key={role.value} value={role.value}>
                        {role.label}
                      </option>
                    ))}
                  </select>
                </div>
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
