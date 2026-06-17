import { useEffect, useMemo, useState } from "react";
import { adminApi } from "../api/admin.js";
import { formatRuDateTime } from "../utils/datetime.js";

const DAY_OPTIONS = [7, 30, 90, 180];
const TOPIC_LABELS = {
  bug: "Ошибка в приложении",
  idea: "Идея по улучшению",
  data: "Нет данных или данные неверные",
  ux: "Неудобный сценарий",
  other: "Другое",
};

function topicLabel(value) {
  return TOPIC_LABELS[value] || value || "Без темы";
}

function shorten(value, limit = 220) {
  const text = String(value || "").trim();
  if (!text) return "—";
  if (text.length <= limit) return text;
  return `${text.slice(0, limit - 1)}…`;
}

export default function AdminFeedbackPage() {
  const [days, setDays] = useState(30);
  const [topic, setTopic] = useState("");
  const [data, setData] = useState({ items: [] });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    setLoading(true);
    setError("");
    adminApi.feedback({ days, topic, limit: 200 })
      .then((payload) => setData(payload || { items: [] }))
      .catch((err) => {
        setError(err.message || "Не удалось загрузить обратную связь");
      })
      .finally(() => setLoading(false));
  }, [days, topic]);

  const topicOptions = useMemo(() => {
    const values = new Set((data?.items || []).map((item) => item.topic).filter(Boolean));
    return [...values].sort((a, b) => topicLabel(a).localeCompare(topicLabel(b), "ru"));
  }, [data?.items]);

  return (
    <div className="container cc-page">
      <section className="card feedback-admin-page">
        <div className="page-header feedback-admin-header">
          <div>
            <h1>Обратная связь</h1>
            <div className="muted">
              Сообщения пользователей по интерфейсу, данным и предложениям по доработке.
            </div>
          </div>
        </div>

        <div className="feedback-admin-toolbar">
          <div className="admin-field">
            <span>Окно</span>
            <div className="feedback-admin-days">
              {DAY_OPTIONS.map((option) => (
                <button
                  key={option}
                  type="button"
                  className={`btn ${days === option ? "btn-primary" : "btn-secondary"}`}
                  onClick={() => setDays(option)}
                >
                  {option} дн
                </button>
              ))}
            </div>
          </div>

          <label className="admin-field feedback-admin-topic">
            <span>Тема</span>
            <select
              className="admin-select"
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
            >
              <option value="">Все темы</option>
              {topicOptions.map((value) => (
                <option key={value} value={value}>
                  {topicLabel(value)}
                </option>
              ))}
            </select>
          </label>
        </div>

        {error ? (
          <div className="dev-meta-feedback error">
            <div className="dev-meta-feedback-title">Загрузка не выполнена</div>
            <div className="dev-meta-feedback-text">{error}</div>
          </div>
        ) : null}

        {loading ? <div className="muted">Загрузка обратной связи...</div> : null}

        {!loading && !error ? (
          <>
            <div className="feedback-admin-summary">
              <div className="feedback-admin-kpi">
                <div className="label">Сообщения</div>
                <div className="value">{data?.items?.length || 0}</div>
              </div>
              <div className="feedback-admin-kpi">
                <div className="label">Темы</div>
                <div className="value">{topicOptions.length}</div>
              </div>
              <div className="feedback-admin-kpi">
                <div className="label">Окно</div>
                <div className="value">{days} дн</div>
              </div>
            </div>

            <div className="feedback-admin-list">
              {(data?.items || []).length ? (
                data.items.map((item, idx) => (
                  <article key={`${item.created_at || "item"}-${idx}`} className="feedback-admin-card">
                    <div className="feedback-admin-card-head">
                      <div className="feedback-admin-topic-badge">{topicLabel(item.topic)}</div>
                      <div className="feedback-admin-date">{formatRuDateTime(item.created_at)}</div>
                    </div>
                    <div className="feedback-admin-meta">
                      <span>Пользователь: {item.user_name || item.user_email || "—"}</span>
                      <span>Контакт: {item.contact_email || "—"}</span>
                      <span>Страница: {item.page_path || "—"}</span>
                    </div>
                    <div className="feedback-admin-message">{shorten(item.message, 1200)}</div>
                  </article>
                ))
              ) : (
                <div className="feedback-admin-empty">За выбранный период сообщений нет.</div>
              )}
            </div>
          </>
        ) : null}
      </section>
    </div>
  );
}
