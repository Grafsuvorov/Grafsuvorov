import { useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import "../style/app.css";
import { feedbackApi } from "../api/feedback.js";

const APP_AREAS = [
  {
    title: "Обзор",
    path: "/",
    desc: "Главная страница. Показывает, что важно прямо сейчас: инциденты, ночное окно, ClickHouse лаги, DQ и архитектурные риски.",
    useWhen: "Когда нужно быстро понять обстановку и выбрать следующий экран.",
  },
  {
    title: "Ночное окно",
    path: "/night-ops",
    desc: "Оперативный мониторинг конкретной ночи: тяжелые таблицы, аномалии, ошибки и пиковые часы.",
    useWhen: "Когда расследуете задержку или сбой последнего окна загрузки.",
  },
  {
    title: "Таблицы",
    path: "/tables",
    desc: "Каталог и поиск таблиц с переходом в карточку объекта.",
    useWhen: "Когда знаете объект или хотите быстро открыть карточку таблицы.",
  },
  {
    title: "Сущности",
    path: "/entities",
    desc: "Структура сущностей, покрытие до DM и навигация по крупным направлениям и бизнес-блокам.",
    useWhen: "Когда нужно смотреть систему по направлениям, а не от конкретной таблицы.",
  },
  {
    title: "Производительность",
    path: "/slow-tables",
    desc: "Единый раздел для исторических узких мест, ночных пиков и анализа конкретного окна загрузок.",
    useWhen: "Когда нужно понять, что тормозит системно и что происходило в конкретном окне.",
  },
  {
    title: "Релизы",
    path: "/releases",
    desc: "Изменения объектов, релизная активность и связанные задачи YouTrack.",
    useWhen: "Когда нужно понять, что недавно менялось и почему поведение могло измениться.",
  },
];

const USER_FLOWS = [
  {
    title: "Если что-то сломалось сегодня",
    steps: [
      "Откройте Обзор и проверьте активные инциденты и ночное окно.",
      "Если проблема в runtime, переходите в Ночное окно.",
      "Если нужен конкретный объект, открывайте карточку таблицы.",
    ],
  },
  {
    title: "Если таблица грузится слишком долго",
    steps: [
      "Откройте Производительность и выберите режим анализа окна.",
      "Потом перейдите в карточку таблицы и проверьте последние ClickHouse-запуски.",
      "Если проблема системная, вернитесь в исторический режим этой же страницы.",
    ],
  },
  {
    title: "Если нужно понять влияние и зависимости",
    steps: [
      "Начните с карточки таблицы или со страницы Сущности.",
      "Проверьте зависимости, варианты таблицы и impact.",
      "На главной смотрите блок Архитектура и риски зависимостей для циклов и взаимных связок.",
    ],
  },
  {
    title: "Если поведение изменилось после доработок",
    steps: [
      "Откройте Релизы и найдите связанные изменения.",
      "Затем откройте карточку таблицы и проверьте связанные задачи.",
      "После этого возвращайтесь в Производительность или Ночное окно для runtime-проверки.",
    ],
  },
];

const RCA_FLOW = [
  "Обзор: подтвердить, что проблема действительно актуальна сейчас.",
  "Ночное окно: найти тяжелый слот, аномалию или падение.",
  "Карточка таблицы: посмотреть историю запусков, ClickHouse-метрики и связанные релизы.",
  "Зависимости: понять upstream/downstream влияние.",
  "Релизы и задачи: проверить, не связано ли изменение с недавней поставкой.",
  "Производительность: сравнить системный риск с конкретным окном загрузки.",
];

const FEEDBACK_TOPICS = [
  { value: "bug", label: "Ошибка в приложении" },
  { value: "idea", label: "Идея по улучшению" },
  { value: "data", label: "Нет данных или данные неверные" },
  { value: "ux", label: "Неудобный сценарий" },
  { value: "other", label: "Другое" },
];

export default function OnboardingPage({ userProfile }) {
  const navigate = useNavigate();
  const location = useLocation();
  const [activeTab, setActiveTab] = useState("guide");
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
        ? `Краткий гид по приложению и форма обратной связи для пользователя ${userProfile.username}.`
        : "Краткий гид по приложению и форма обратной связи.",
    [userProfile],
  );

  const handleSubmit = async (event) => {
    event.preventDefault();
    setSubmitting(true);
    setMessage("");
    setError("");
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
        <h1>Как пользоваться приложением</h1>
        <div className="cc-subtitle">{intro}</div>
      </section>

      <section className="cc-surface">
        <div className="about-tabs">
          <button
            type="button"
            className={`about-tab ${activeTab === "guide" ? "active" : ""}`}
            onClick={() => setActiveTab("guide")}
          >
            Гид
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

      {activeTab === "guide" ? (
        <>
          <section className="cc-surface">
            <div className="section-title">Сначала поймите логику приложения</div>
            <div className="onboarding-steps">
              <div className="onboarding-step">
                <div className="onboarding-step-index">1</div>
                <div>
                  <div className="onboarding-step-title">Обзор</div>
                  <div className="muted">Смотрите общую картину и выбирайте следующий экран, а не пытаетесь расследовать все прямо на главной.</div>
                </div>
              </div>
              <div className="onboarding-step">
                <div className="onboarding-step-index">2</div>
                <div>
                  <div className="onboarding-step-title">Мониторинг и производительность</div>
                  <div className="muted">Мониторинг нужен для ответа на вопрос "что происходит сейчас", производительность для ответа "что тормозит и почему".</div>
                </div>
              </div>
              <div className="onboarding-step">
                <div className="onboarding-step-index">3</div>
                <div>
                  <div className="onboarding-step-title">Объект и связи</div>
                  <div className="muted">Карточка таблицы и экран сущностей нужны для детального разбора объекта и его места в ландшафте.</div>
                </div>
              </div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Какая страница для чего нужна</div>
            <div className="onboarding-area-grid">
              {APP_AREAS.map((area) => (
                <button key={area.path} className="onboarding-area-card" onClick={() => navigate(area.path)}>
                  <div className="onboarding-area-head">
                    <div className="onboarding-card-title">{area.title}</div>
                    <div className="onboarding-card-action">Открыть →</div>
                  </div>
                  <div className="onboarding-card-desc">{area.desc}</div>
                  <div className="onboarding-area-when">
                    <span className="onboarding-area-label">Когда использовать</span>
                    <span>{area.useWhen}</span>
                  </div>
                </button>
              ))}
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Типовые маршруты пользователя</div>
            <div className="onboarding-flow-grid">
              {USER_FLOWS.map((flow) => (
                <div key={flow.title} className="onboarding-flow-card">
                  <div className="onboarding-flow-title">{flow.title}</div>
                  <div className="onboarding-flow-list">
                    {flow.steps.map((step) => (
                      <div key={step}>{step}</div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Что искать на главной</div>
            <div className="onboarding-map-grid">
              <div className="onboarding-map-card">
                <div className="onboarding-map-title">Блоки мониторинга</div>
                <div className="onboarding-map-text">
                  Активные инциденты, ночное окно, ClickHouse-загрузки, DQ и история проблемных таблиц. Эти блоки отвечают на вопрос: что болит сейчас.
                </div>
              </div>
              <div className="onboarding-map-card">
                <div className="onboarding-map-title">Блок архитектуры</div>
                <div className="onboarding-map-text">
                  Взаимные зависимости и циклы сущностей вынесены в нижнюю часть главной. Это не оперативный мониторинг, а диагностика структуры направлений и сущностей.
                </div>
              </div>
              <div className="onboarding-map-card">
                <div className="onboarding-map-title">Переходы по смыслу</div>
                <div className="onboarding-map-text">
                  С главной вы не расследуете до конца. Она должна привести вас либо в Ночное окно, либо в Производительность, либо в карточку таблицы.
                </div>
              </div>
            </div>
          </section>

          <section className="cc-surface">
            <div className="section-title">Рекомендуемый сценарий RCA</div>
            <div className="onboarding-rca">
              {RCA_FLOW.map((step) => (
                <div key={step}>{step}</div>
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
              Чем конкретнее описание, тем проще понять сценарий и воспроизвести проблему. Текущая страница передаётся автоматически и отдельно заполнять её не нужно.
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
