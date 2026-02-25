import { useNavigate } from "react-router-dom";
import "../style/app.css";

const QUICK_ROUTES = [
  {
    title: "Ночное окно",
    desc: "Пики загрузок, тяжелые таблицы по окну времени, фейлы.",
    path: "/night-ops",
  },
  {
    title: "Таблицы",
    desc: "Поиск таблиц и переход в детальную карточку.",
    path: "/tables",
  },
  {
    title: "Сущности",
    desc: "Справочник сущностей и покрытие до DM.",
    path: "/entities",
  },
  {
    title: "Медленные",
    desc: "Медленные и нестабильные таблицы по p95/CV.",
    path: "/slow-tables",
  },
];

export default function OnboardingPage() {
  const navigate = useNavigate();

  return (
    <div className="container cc-page">
      <section className="cc-header-zone">
        <button className="btn" onClick={() => navigate("/")}>← Назад</button>
        <h1>Как пользоваться</h1>
        <div className="cc-subtitle">Как быстро пользоваться приложением и с чего начинать анализ.</div>
      </section>

      <section className="cc-surface">
        <div className="section-title">Быстрый старт за 3 шага</div>
        <div className="onboarding-steps">
          <div className="onboarding-step">
            <div className="onboarding-step-index">1</div>
            <div>
              <div className="onboarding-step-title">Найдите всплеск</div>
              <div className="muted">Откройте Night Ops и задайте интервал (например, `04:30-05:20`).</div>
            </div>
          </div>
          <div className="onboarding-step">
            <div className="onboarding-step-index">2</div>
            <div>
              <div className="onboarding-step-title">Выделите кандидатов</div>
              <div className="muted">Смотрите Heavy/Long таблицы и открывайте карточки топ-таблиц.</div>
            </div>
          </div>
          <div className="onboarding-step">
            <div className="onboarding-step-index">3</div>
            <div>
              <div className="onboarding-step-title">Проверьте последствия</div>
              <div className="muted">В карточке запустите Dependency/Impact graph и сверяйте DQ.</div>
            </div>
          </div>
        </div>
      </section>

      <section className="cc-surface">
        <div className="section-title">Ключевые страницы</div>
        <div className="onboarding-grid">
          {QUICK_ROUTES.map((item) => (
            <button
              key={item.path}
              className="onboarding-card"
              onClick={() => navigate(item.path)}
            >
              <div className="onboarding-card-title">{item.title}</div>
              <div className="onboarding-card-desc">{item.desc}</div>
              <div className="onboarding-card-action">Открыть →</div>
            </button>
          ))}
        </div>
      </section>

      <section className="cc-surface">
        <div className="section-title">Рекомендуемый сценарий RCA</div>
        <div className="onboarding-rca">
          <div>1) Night Ops: интервал и тяжелые таблицы.</div>
          <div>2) Table Card: history + variants + DQ.</div>
          <div>3) Dependency Graph: upstream источник задержки.</div>
          <div>4) Impact Graph: какие витрины/сущности пострадали.</div>
        </div>
      </section>
    </div>
  );
}
