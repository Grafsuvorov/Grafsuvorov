import { useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import "../style/app.css";
import { feedbackApi } from "../api/feedback.js";

const ARTICLE_SECTIONS = [
  {
    title: "Назначение",
    text:
      "DWH Контроль собирает в одном интерфейсе мету объектов, историю загрузок, инциденты, зависимости, производительность и релизные изменения. Экран нужен для быстрого ответа на практический вопрос: что сломалось, где причина, что изменилось и на какие объекты это влияет.",
  },
  {
    title: "Кому полезно",
    text:
      "Приложение рассчитано на аналитиков, инженеров и администраторов. Аналитик может быстро открыть витрину и понять её источники. Инженер получает рабочий набор для разбора инцидентов, оценки зависимостей и проверки релизов. Администратор видит эксплуатационные и служебные сценарии.",
  },
  {
    title: "Основные сценарии",
    text:
      "Через каталог можно открыть карточку таблицы и проверить мету объекта. Через зависимости и граф влияния можно понять upstream и downstream. Через мониторинг и обзор можно быстро увидеть ошибки и просадки. Через релизы, DEV Meta, Meta Workspace и DEV Copy можно сопровождать изменения без ручного обхода нескольких систем.",
  },
  {
    title: "Разделы",
    text:
      "Обзор показывает текущее состояние и инциденты. Каталог нужен для поиска объектов и перехода в карточку таблицы. Производительность и Мониторинг помогают разбирать эксплуатационные проблемы. Сущности и зависимости показывают архитектурные связи. Релизы, DEV Meta, Meta Workspace и DEV Copy закрывают сценарии подготовки и сопровождения изменений.",
  },
  {
    title: "Как работать быстрее",
    text:
      "Если проблема произошла прямо сейчас, обычно логично начать с Обзора и Мониторинга. Если известен конкретный объект, быстрее идти через Каталог и карточку таблицы. Если нужно оценить риск изменений, полезнее открыть зависимости, сущности и релизные проверки. Если не хватает функциональности или поведение неудобно, используйте форму обратной связи на этой странице.",
  },
];

const FEEDBACK_TOPICS = [
  { value: "bug", label: "Ошибка в приложении" },
  { value: "idea", label: "Идея по улучшению" },
  { value: "data", label: "Нет данных или данные неверные" },
  { value: "ux", label: "Неудобный сценарий" },
  { value: "other", label: "Другое" },
];

export default function AboutAppPage({ userProfile }) {
  const navigate = useNavigate();
  const location = useLocation();
  const [activeTab, setActiveTab] = useState("article");
  const [form, setForm] = useState({
    topic: "idea",
    message: "",
    contact_email: userProfile?.email || "",
  });
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  const intro = useMemo(
    () =>
      userProfile?.username
        ? `Страница для знакомства с приложением и для передачи обратной связи от пользователя ${userProfile.username}.`
        : "Страница для знакомства с приложением и для передачи обратной связи.",
    [userProfile],
  );

  const quickNotes = useMemo(
    () => [
      {
        title: "Что делает",
        text: "Показывает объекты DWH, их связи, загрузки, инциденты и релизные изменения.",
      },
      {
        title: "Когда открывать",
        text: "Когда нужно быстро понять источник ошибки, зону влияния или последствия поставки.",
      },
      {
        title: "Что можно отправить",
        text: "Замечание по данным, ошибку интерфейса, неудобный сценарий или идею доработки.",
      },
    ],
    [],
  );

  const handleSubmit = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    setError("");
    setMessage("");
    try {
      const data = await feedbackApi.submit({
        ...form,
        page_path: location.pathname,
      });
      setMessage(data?.saved_at ? `Обратная связь сохранена (${data.saved_at}).` : "Обратная связь сохранена.");
      setForm((prev) => ({ ...prev, message: "" }));
    } catch (err) {
      setError(err.message || "Не удалось отправить обратную связь");
    } finally {
      setSubmitting(false);
    }
  };

  const isSubmitDisabled = submitting || form.message.trim().length < 10;

  return (
    <div className="container cc-page">
      <section className="cc-header-zone">
        <button className="btn" onClick={() => navigate("/")}>← Назад</button>
        <h1>О приложении</h1>
        <div className="cc-subtitle">{intro}</div>
      </section>

      <section className="cc-surface">
        <div className="about-tabs">
          <button
            type="button"
            className={`about-tab ${activeTab === "article" ? "active" : ""}`}
            onClick={() => setActiveTab("article")}
          >
            Статья
          </button>
          <button
            type="button"
            className={`about-tab ${activeTab === "feedback" ? "active" : ""}`}
            onClick={() => setActiveTab("feedback")}
          >
            Обратная связь
          </button>
        </div>
      </section>

      {activeTab === "article" ? (
        <>
          <section className="about-summary-grid">
            {quickNotes.map((note) => (
              <article key={note.title} className="cc-surface about-summary-card">
                <div className="about-summary-title">{note.title}</div>
                <div className="about-summary-text">{note.text}</div>
              </article>
            ))}
          </section>

          <section className="cc-surface">
            <div className="section-title">Описание приложения</div>
            <div className="about-article">
              {ARTICLE_SECTIONS.map((block) => (
                <article key={block.title} className="about-article-block">
                  <div className="about-article-title">{block.title}</div>
                  <div className="about-article-text">{block.text}</div>
                </article>
              ))}
            </div>
          </section>
        </>
      ) : (
        <section className="cc-surface">
          <div className="section-title">Форма обратной связи</div>
          <div className="section-subtitle">
            Здесь можно отправить замечание по интерфейсу, данным, качеству сценария или предложить доработку.
          </div>

          <form className="about-feedback-form" onSubmit={handleSubmit}>
            <label className="admin-field">
              <span>Тема</span>
              <select
                className="admin-select"
                value={form.topic}
                onChange={(e) => setForm((prev) => ({ ...prev, topic: e.target.value }))}
              >
                {FEEDBACK_TOPICS.map((item) => (
                  <option key={item.value} value={item.value}>
                    {item.label}
                  </option>
                ))}
              </select>
            </label>

            <label className="admin-field">
              <span>Контактный email</span>
              <input
                value={form.contact_email}
                onChange={(e) => setForm((prev) => ({ ...prev, contact_email: e.target.value }))}
                placeholder="name@company.ru"
              />
            </label>

            <label className="admin-field">
              <span>Текущая страница</span>
              <input value={location.pathname} readOnly />
            </label>

            <label className="admin-field about-feedback-wide">
              <span>Сообщение</span>
              <textarea
                className="about-feedback-textarea"
                value={form.message}
                onChange={(e) => setForm((prev) => ({ ...prev, message: e.target.value }))}
                placeholder="Опишите проблему, шаги воспроизведения, чего ожидаете и что получилось фактически"
              />
            </label>

            <div className="about-feedback-hint">
              Чем конкретнее описание, тем проще понять сценарий и воспроизвести проблему.
            </div>

            <div className="about-feedback-actions">
              <button type="submit" className="btn" disabled={isSubmitDisabled}>
                {submitting ? "Отправляем..." : "Отправить"}
              </button>
            </div>
          </form>

          {(message || error) ? (
            <div className={`dev-meta-feedback ${error ? "error" : "success"}`}>
              <div className="dev-meta-feedback-title">{error ? "Отправка не выполнена" : "Статус"}</div>
              <div className="dev-meta-feedback-text">{error || message}</div>
            </div>
          ) : null}
        </section>
      )}
    </div>
  );
}
