import { useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { feedbackApi } from "../api/feedback.js";

const FEEDBACK_TOPICS = [
  { value: "bug", label: "Ошибка в приложении" },
  { value: "idea", label: "Идея по улучшению" },
  { value: "data", label: "Нет данных или данные неверные" },
  { value: "ux", label: "Неудобный сценарий" },
  { value: "other", label: "Другое" },
];

export default function AdminFeedbackPage({ userProfile }) {
  const navigate = useNavigate();
  const location = useLocation();
  const sourcePage = useMemo(() => location.state?.from || "/", [location.state]);
  const [form, setForm] = useState({
    topic: "idea",
    message: "",
    contact_email: userProfile?.email || "",
  });
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState("");
  const [error, setError] = useState("");

  const handleSubmit = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    setSuccess("");
    setError("");

    try {
      await feedbackApi.submit({
        topic: form.topic,
        message: form.message.trim(),
        contact_email: form.contact_email.trim() || null,
        page_path: sourcePage,
      });
      setSuccess("Спасибо! Сообщение отправлено команде продукта.");
      setForm((current) => ({ ...current, message: "" }));
    } catch (err) {
      setError(err.message || "Не удалось отправить сообщение. Попробуйте ещё раз.");
    } finally {
      setSubmitting(false);
    }
  };

  const isSubmitDisabled = submitting || form.message.trim().length < 10;

  return (
    <div className="container cc-page feedback-submit-page">
      <section className="cc-header-zone feedback-submit-header">
        <button type="button" className="btn btn-secondary" onClick={() => navigate(sourcePage)}>
          ← Вернуться
        </button>
        <div className="feedback-submit-heading">
          <div className="feedback-submit-eyebrow">Помогите сделать DWH Контроль удобнее</div>
          <h1>Обратная связь</h1>
          <div className="cc-subtitle">
            Расскажите об ошибке, неудобном сценарии или предложите улучшение. Сообщение увидит команда продукта.
          </div>
        </div>
      </section>

      <section className="cc-surface feedback-submit-surface">
        <div className="feedback-submit-intro">
          <div>
            <div className="section-title">Новое сообщение</div>
            <div className="section-subtitle">
              Опишите, что произошло, чего вы ожидали и какой результат получили.
            </div>
          </div>
          <div className="feedback-submit-private">Ваше сообщение не показывается другим пользователям</div>
        </div>

        <form className="about-feedback-form feedback-submit-form" onSubmit={handleSubmit}>
          <label className="admin-field">
            <span>Тема</span>
            <select
              className="admin-select"
              value={form.topic}
              onChange={(event) => setForm((current) => ({ ...current, topic: event.target.value }))}
            >
              {FEEDBACK_TOPICS.map((item) => (
                <option key={item.value} value={item.value}>
                  {item.label}
                </option>
              ))}
            </select>
          </label>

          <label className="admin-field">
            <span>Контактный email <span className="muted">(необязательно)</span></span>
            <input
              type="email"
              value={form.contact_email}
              onChange={(event) => setForm((current) => ({ ...current, contact_email: event.target.value }))}
              placeholder="name@company.ru"
            />
          </label>

          <label className="admin-field">
            <span>Раздел приложения</span>
            <input value={sourcePage} readOnly />
          </label>

          <label className="admin-field about-feedback-wide">
            <span>Сообщение</span>
            <textarea
              className="about-feedback-textarea"
              value={form.message}
              onChange={(event) => setForm((current) => ({ ...current, message: event.target.value }))}
              placeholder="Например: на странице карточки таблицы не отображается последний запуск. Ожидал увидеть статус и время выполнения..."
              minLength={10}
              maxLength={4000}
              required
              autoFocus
            />
          </label>

          <div className="about-feedback-hint feedback-submit-hint">
            <span>Минимум 10 символов</span>
            <span>{form.message.length} / 4000</span>
          </div>

          <div className="about-feedback-actions">
            <button type="submit" className="btn btn-primary" disabled={isSubmitDisabled}>
              {submitting ? "Отправляем..." : "Отправить обратную связь"}
            </button>
          </div>
        </form>

        {success || error ? (
          <div className={`dev-meta-feedback ${error ? "error" : "success"}`} role="status">
            <div className="dev-meta-feedback-title">
              {error ? "Сообщение не отправлено" : "Сообщение принято"}
            </div>
            <div className="dev-meta-feedback-text">{error || success}</div>
          </div>
        ) : null}
      </section>
    </div>
  );
}
