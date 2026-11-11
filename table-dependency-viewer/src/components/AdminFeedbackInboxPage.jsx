import { useCallback, useEffect, useMemo, useState } from "react";
import { formatRuDateTime } from "../utils/datetime.js";
import { adminApi } from "../api/admin.js";

const TOPICS = {
  bug: "Ошибка в приложении",
  idea: "Идея по улучшению",
  data: "Нет данных или данные неверные",
  ux: "Неудобный сценарий",
  other: "Другое",
};

const DAY_OPTIONS = [7, 30, 90, 365];

export default function AdminFeedbackInboxPage() {
  const [days, setDays] = useState(30);
  const [topic, setTopic] = useState("");
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const loadFeedback = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const response = await adminApi.feedback({ days, topic, limit: 200 });
      setItems(response?.items || []);
    } catch (err) {
      setError(err.message || "Не удалось загрузить обратную связь");
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, [days, topic]);

  useEffect(() => { loadFeedback(); }, [loadFeedback]);

  const summary = useMemo(() => ({
    total: items.length,
    bugs: items.filter((item) => item.topic === "bug").length,
    ideas: items.filter((item) => item.topic === "idea").length,
  }), [items]);

  return (
    <div className="container cc-page feedback-admin-page">
      <section className="cc-header-zone feedback-admin-header">
        <div>
          <div className="section-kicker">Администрирование</div>
          <h1>Обратная связь пользователей</h1>
          <div className="cc-subtitle">Сообщения, отправленные из приложения за выбранный период.</div>
        </div>
        <button type="button" className="btn btn-secondary" onClick={loadFeedback} disabled={loading}>
          {loading ? "Обновляем…" : "Обновить"}
        </button>
      </section>

      <section className="cc-surface feedback-admin-toolbar">
        <div>
          <div className="slow-select-label">Период</div>
          <div className="feedback-admin-days">
            {DAY_OPTIONS.map((value) => (
              <button key={value} type="button" className={`btn ${days === value ? "btn-primary" : "btn-ghost"}`} onClick={() => setDays(value)}>
                {value === 365 ? "Год" : `${value} дн.`}
              </button>
            ))}
          </div>
        </div>
        <label className="admin-field feedback-admin-topic">
          <span>Тема</span>
          <select className="admin-select" value={topic} onChange={(event) => setTopic(event.target.value)}>
            <option value="">Все темы</option>
            {Object.entries(TOPICS).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
          </select>
        </label>
      </section>

      <section className="feedback-admin-summary">
        <div className="feedback-admin-kpi"><span className="label">Всего сообщений</span><strong className="value">{summary.total}</strong></div>
        <div className="feedback-admin-kpi"><span className="label">Ошибки</span><strong className="value">{summary.bugs}</strong></div>
        <div className="feedback-admin-kpi"><span className="label">Идеи улучшений</span><strong className="value">{summary.ideas}</strong></div>
      </section>

      <section className="cc-surface feedback-admin-list">
        {error ? <div className="page-error">{error}</div> : null}
        {!loading && !error && !items.length ? <div className="feedback-admin-empty">За выбранный период сообщений нет.</div> : null}
        {items.map((item, index) => (
          <article className="feedback-admin-card" key={`${item.created_at}-${item.user_email}-${index}`}>
            <div className="feedback-admin-card-head">
              <span className="feedback-admin-topic-badge">{TOPICS[item.topic] || item.topic || "Без темы"}</span>
              <span className="feedback-admin-date">{formatRuDateTime(item.created_at)}</span>
            </div>
            <div className="feedback-admin-meta">
              <span>Пользователь: {item.user_name || item.user_email || "Не указан"}</span>
              {item.contact_email ? <span>Контакт: {item.contact_email}</span> : null}
              {item.page_path ? <span>Раздел: {item.page_path}</span> : null}
            </div>
            <div className="feedback-admin-message">{item.message}</div>
          </article>
        ))}
      </section>
    </div>
  );
}
