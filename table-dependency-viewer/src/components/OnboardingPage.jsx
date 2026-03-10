import { useNavigate } from "react-router-dom";
import "../style/app.css";

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
    title: "Аналитика",
    path: "/analytics",
    desc: "Раздел для анализа run-ов и ожидания. Для ClickHouse показывает реальную работу и отдельно паузу или ожидание между этапами.",
    useWhen: "Когда нужно понять, где длительность вызвана расчетом, а где ожиданием в очереди или паузой.",
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
    title: "Медленные",
    path: "/slow-tables",
    desc: "Стабильно тяжелые и нестабильные таблицы по историческим метрикам.",
    useWhen: "Когда ищете хронические узкие места, а не разовый инцидент.",
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
      "Откройте Аналитику и посмотрите работу и ожидание отдельно.",
      "Потом перейдите в карточку таблицы и проверьте последние ClickHouse-запуски.",
      "Если проблема системная, сравните с экраном Медленные.",
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
      "После этого возвращайтесь в Аналитику или Ночное окно для runtime-проверки.",
    ],
  },
];

const RCA_FLOW = [
  "Обзор: подтвердить, что проблема действительно актуальна сейчас.",
  "Ночное окно: найти тяжелый слот, аномалию или падение.",
  "Карточка таблицы: посмотреть историю запусков, ClickHouse-метрики и связанные релизы.",
  "Зависимости: понять upstream/downstream влияние.",
  "Релизы и задачи: проверить, не связано ли изменение с недавней поставкой.",
];

export default function OnboardingPage() {
  const navigate = useNavigate();

  return (
    <div className="container cc-page">
      <section className="cc-header-zone">
        <button className="btn" onClick={() => navigate("/")}>← Назад</button>
        <h1>Как пользоваться приложением</h1>
        <div className="cc-subtitle">
          Это не просто набор страниц. У каждой страницы есть свой вопрос, на который она отвечает.
        </div>
      </section>

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
              <div className="onboarding-step-title">Мониторинг и аналитика</div>
              <div className="muted">Мониторинг нужен для ответа на вопрос "что происходит сейчас", аналитика для ответа "почему это происходит".</div>
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
              С главной вы не расследуете до конца. Она должна привести вас либо в Ночное окно, либо в Аналитику, либо в карточку таблицы.
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
    </div>
  );
}
