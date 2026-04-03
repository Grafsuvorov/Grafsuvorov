// src/components/LeagueTabsHeaderMockups.jsx
// Комплексный макет выбора лиг: топ-листы, страны, кубки, журнал
import React from "react";

const TOP_LEAGUES = [
  { name: "Premier League", country: "Англия", tier: "Tier 1", logo: "/icons/leagues/premier_league.png" },
  { name: "La Liga", country: "Испания", tier: "Tier 1", logo: "/icons/leagues/la_liga.png" },
  { name: "Serie A", country: "Италия", tier: "Tier 1", logo: "/icons/leagues/serie_a.png" },
  { name: "Bundesliga", country: "Германия", tier: "Tier 1", logo: "/icons/leagues/bundesliga.png" },
  { name: "Ligue 1", country: "Франция", tier: "Tier 1", logo: "/icons/leagues/ligue_1.png" },
  { name: "UEFA Champions League", country: "Европа", tier: "Кубок", logo: "/icons/cups/champions_league.png" },
];

const COUNTRY_CATALOG = [
  {
    name: "Англия",
    flag: "/icons/flags/GB.png",
    highlight: "Топ-5 лиг",
    leagues: [
      { title: "Premier League", tier: "Tier 1", info: "20 клубов", logo: "/icons/leagues/premier_league.png" },
      { title: "Championship", tier: "Tier 2", info: "24 клуба", logo: "/icons/leagues/championship.png" },
      { title: "League One", tier: "Tier 3", info: "24 клуба", logo: "/icons/leagues/league_one.png" },
    ],
    cups: ["FA Cup", "Carabao Cup"],
  },
  {
    name: "Испания",
    flag: "/icons/flags/ES.png",
    highlight: "Сильные академии",
    leagues: [
      { title: "La Liga", tier: "Tier 1", info: "20 клубов", logo: "/icons/leagues/la_liga.png" },
      { title: "Segunda División", tier: "Tier 2", info: "22 клуба", logo: "/icons/leagues/segunda.png" },
    ],
    cups: ["Copa del Rey", "Supercopa"],
  },
  {
    name: "Германия",
    flag: "/icons/flags/DE.png",
    highlight: "Высокая посещаемость",
    leagues: [
      { title: "Bundesliga", tier: "Tier 1", info: "18 клубов", logo: "/icons/leagues/bundesliga.png" },
      { title: "2. Bundesliga", tier: "Tier 2", info: "18 клубов", logo: "/icons/leagues/bundesliga2.png" },
    ],
    cups: ["DFB Pokal"],
  },
  {
    name: "Италия",
    flag: "/icons/flags/IT.png",
    highlight: "Тактическая школа",
    leagues: [
      { title: "Serie A", tier: "Tier 1", info: "20 клубов", logo: "/icons/leagues/serie_a.png" },
      { title: "Serie B", tier: "Tier 2", info: "20 клубов", logo: "/icons/leagues/serie_b.png" },
    ],
    cups: ["Coppa Italia", "Supercoppa"],
  },
];

const EURO_CUPS = [
  { title: "Champions League", subtitle: "Группы + плей-офф", logo: "/icons/cups/champions_league.png" },
  { title: "Europa League", subtitle: "Лига Европы", logo: "/icons/cups/europa_league.png" },
  { title: "Conference League", subtitle: "Третий еврокубок", logo: "/icons/cups/conference_league.png" },
];

const MAG_STATS = [
  { label: "Команд", value: "20", desc: "в высшем дивизионе" },
  { label: "Игроков", value: "560", desc: "участвуют в сезоне" },
  { label: "Матчей", value: "380", desc: "в регулярке" },
];

const MAG_FEATURES = [
  { title: "Горячие серии", excerpt: "Liverpool выиграл 8 из последних 9 матчей — смотри график формы." },
  { title: "Разбор дерби", excerpt: "Manchester vs City: xG, давление и карточки за 5 лет." },
  { title: "Инсайды", excerpt: "Молодые таланты академий: кто готов к старту следующего сезона?" },
];

function Section({ title, subtitle, children }) {
  return (
    <section className="rounded-3xl border border-glass bg-surface-1/90 shadow-lg">
      <header className="border-b border-glass px-6 py-4">
        <h2 className="text-xl font-semibold text-white">{title}</h2>
        {subtitle && <p className="text-sm text-slate-400">{subtitle}</p>}
      </header>
      <div className="space-y-6 bg-surface-1/60 px-6 py-6">{children}</div>
    </section>
  );
}

function HeaderBar() {
  return (
    <div className="flex flex-wrap items-center justify-between gap-4 rounded-3xl bg-surface-2/90 px-6 py-5 shadow-sm border border-glass">
      <div>
        <div className="text-xs uppercase tracking-wide text-slate-400">Текущий турнир</div>
        <div className="text-3xl font-bold text-white">Premier League</div>
        <div className="text-sm text-slate-400">Англия · Tier 1</div>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <button className="inline-flex items-center gap-2 rounded-full bg-surface-2/80 px-3 py-1 text-sm shadow-sm ring-1 ring-white/20">
          <span>Сезон</span>
          <span className="rounded-full bg-white/15 px-2 py-0.5 text-xs text-white">2025</span>
          <span className="text-slate-300">▾</span>
        </button>
        <button className="inline-flex items-center gap-2 rounded-full bg-rose-500 px-4 py-2 text-sm font-semibold text-white shadow">
          🌍 Каталог лиг
        </button>
      </div>
    </div>
  );
}

function TopGallery() {
  return (
    <div className="flex items-center justify-between gap-3">
      <div className="flex gap-2 overflow-x-auto rounded-2xl bg-surface-2/70 px-3 py-2 shadow-inner border border-glass">
        {TOP_LEAGUES.map((league, index) => {
          const active = index === 0;
          const cls = "flex items-center gap-2 rounded-full px-3 py-1.5 text-sm transition " + (active ? "bg-rose-500 text-white shadow" : "bg-surface-2/80 text-slate-300 border border-glass");
          return (
            <button key={league.name} className={cls}>
              <span className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-surface-1/70">
                <img src={league.logo} alt={league.name} className="h-4 w-4 object-contain" onError={(e) => { e.currentTarget.style.display = 'none'; }} />
              </span>
              <span>{league.name}</span>
            </button>
          );
        })}
      </div>
      <button className="inline-flex items-center gap-2 rounded-full border border-glass bg-surface-2/80 px-3 py-1.5 text-sm text-slate-300 hover:bg-surface-2">
        <span className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-white/15 text-white">≡</span>
        <span>Все лиги</span>
      </button>
    </div>
  );
}

function TopLeagueCards() {
  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {TOP_LEAGUES.map((league) => (
        <div key={league.name} className="flex items-center gap-3 rounded-2xl border border-glass bg-surface-2/90 px-4 py-4 shadow-sm">
          <span className="inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-surface-1/70">
            <img src={league.logo} alt={league.name} className="h-8 w-8 object-contain" onError={(e) => { e.currentTarget.style.display = 'none'; }} />
          </span>
          <div className="flex-1">
            <div className="text-base font-semibold text-white">{league.name}</div>
            <div className="text-xs uppercase tracking-wide text-slate-400">{league.country} · {league.tier}</div>
          </div>
          <button className="rounded-full border border-glass px-3 py-1 text-xs text-slate-300">Перейти →</button>
        </div>
      ))}
    </div>
  );
}

function CountryCard({ country }) {
  return (
    <div className="flex flex-col gap-4 rounded-3xl border border-glass bg-surface-2/90 px-5 py-5 shadow-sm">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-surface-1/70">
            <img src={country.flag} alt={country.name} className="h-8 w-8 object-contain" onError={(e) => { e.currentTarget.style.display = 'none'; }} />
          </span>
          <div>
            <div className="text-lg font-semibold text-white">{country.name}</div>
            <div className="text-xs text-slate-400">{country.highlight}</div>
          </div>
        </div>
        <button className="rounded-full border border-glass px-3 py-1 text-xs text-slate-300">Перейти →</button>
      </div>
      <div className="space-y-3">
        {country.leagues.map((league) => (
          <div key={league.title} className="flex items-center gap-3 rounded-2xl border border-glass bg-surface-1/70 px-3 py-3">
            <span className="inline-flex h-10 w-10 items-center justify-center rounded-2xl bg-surface-2/80">
              <img src={league.logo} alt={league.title} className="h-6 w-6 object-contain" onError={(e) => { e.currentTarget.style.display = 'none'; }} />
            </span>
            <div className="flex-1">
              <div className="text-sm font-semibold text-slate-100">{league.title}</div>
              <div className="text-xs uppercase tracking-wide text-slate-400">{league.tier}</div>
            </div>
            <div className="text-xs text-slate-400">{league.info}</div>
          </div>
        ))}
      </div>
      <div className="flex flex-wrap gap-2 text-xs text-slate-400">
        {country.cups.map((cup) => (
          <span key={cup} className="rounded-full border border-glass px-3 py-1">{cup}</span>
        ))}
      </div>
    </div>
  );
}

function CountryCatalogue() {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <span className="text-sm font-semibold text-slate-200">Каталог по странам</span>
        <button className="rounded-full border border-glass px-3 py-1 text-xs text-slate-300">Открыть полный список</button>
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        {COUNTRY_CATALOG.map((country) => (
          <CountryCard key={country.name} country={country} />
        ))}
      </div>
    </div>
  );
}

function EuroCupsSection() {
  return (
    <div className="space-y-4">
      <div className="text-sm font-semibold text-slate-200">Международные кубки</div>
      <div className="grid gap-3 sm:grid-cols-3">
        {EURO_CUPS.map((cup) => (
          <div key={cup.title} className="flex flex-col items-center gap-3 rounded-2xl bg-gradient-to-br from-slate-900 via-slate-800 to-slate-700 px-4 py-5 text-white shadow-lg">
            <span className="inline-flex h-14 w-14 items-center justify-center rounded-full bg-white/20">
              <img src={cup.logo} alt={cup.title} className="h-10 w-10 object-contain" onError={(e) => { e.currentTarget.style.display = 'none'; }} />
            </span>
            <span className="text-center text-sm font-semibold">{cup.title}</span>
            <span className="text-xs text-white/80">{cup.subtitle}</span>
            <button className="rounded-full bg-white/20 px-3 py-1 text-xs uppercase tracking-wide text-white/90">
              Подробнее
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

function MagazineLayout() {
  return (
    <div className="rounded-3xl bg-surface-2/90 shadow-lg border border-glass">
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-glass px-6 py-5">
        <div>
          <div className="text-xs uppercase tracking-wide text-slate-400">Журнал лиги</div>
          <div className="text-2xl font-bold text-white">Аналитика и тенденции</div>
        </div>
        <button className="inline-flex items-center gap-2 rounded-full bg-white/15 px-4 py-2 text-sm font-semibold text-white border border-white/10">
          ✦ Журнал лиги
        </button>
      </div>
      <div className="grid gap-6 px-6 py-6 lg:grid-cols-[320px_minmax(0,1fr)]">
        <aside className="space-y-4 rounded-2xl border border-glass bg-surface-1/80 p-5 shadow-sm">
          <div className="text-xs font-semibold uppercase tracking-wide text-slate-400">Статистика</div>
          <div className="space-y-3">
            {MAG_STATS.map((item) => (
              <div key={item.label} className="rounded-2xl bg-surface-2/80 px-4 py-3 border border-glass">
                <div className="text-xs uppercase tracking-wide text-slate-400">{item.label}</div>
                <div className="text-2xl font-bold text-white">{item.value}</div>
                <div className="text-xs text-slate-400">{item.desc}</div>
              </div>
            ))}
          </div>
          <div className="rounded-2xl bg-gradient-to-r from-rose-500 to-rose-400 px-4 py-5 text-white shadow">
            <div className="text-xs uppercase tracking-wide text-white/80">Следующий тур</div>
            <div className="mt-2 text-lg font-semibold">Arsenal vs Liverpool</div>
            <div className="text-sm text-white/80">Суббота, 21:45</div>
            <button className="mt-3 inline-flex items-center gap-2 rounded-full bg-white/20 px-3 py-1 text-xs uppercase tracking-wide text-white">
              Подробнее
            </button>
          </div>
        </aside>
        <div className="space-y-6">
          <div className="rounded-3xl bg-surface-1/70 px-6 py-5 shadow-inner border border-glass">
            <div className="text-xs uppercase tracking-wide text-slate-400">Главная история</div>
            <div className="mt-2 text-2xl font-bold text-white">Дерби Манчестера: тактика, тренды и ключевые игроки</div>
            <p className="mt-3 text-sm text-slate-300">
              Глубокий анализ последнего матча: давление в средней зоне, карта ударов, разбор замен и ключевые тенденции по xG.
            </p>
            <button className="mt-4 inline-flex items-center gap-2 rounded-full border border-glass px-4 py-2 text-sm text-slate-200 hover:bg-surface-2/80">
              Читать обзор
            </button>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            {MAG_FEATURES.map((card) => (
              <div key={card.title} className="rounded-2xl border border-glass bg-surface-2/80 p-4 shadow-sm">
                <div className="text-sm font-semibold text-slate-100">{card.title}</div>
                <p className="mt-2 text-sm text-slate-300">{card.excerpt}</p>
                <button className="mt-3 text-xs font-semibold uppercase tracking-wide text-rose-500">Открыть →</button>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

export default function LeagueTabsHeaderMockups() {
  return (
    <div className="space-y-10">
      <Section title="Комбинированная шапка" subtitle="Галерея топ-лиг + быстрый переход в каталог">
        <HeaderBar />
        <div className="mt-4 space-y-6">
          <TopGallery />
          <TopLeagueCards />
        </div>
      </Section>

      <Section title="Каталог по странам" subtitle="Высшие дивизионы и кубки каждой страны">
        <CountryCatalogue />
      </Section>

      <Section title="Международные кубки" subtitle="Все еврокубки с быстрым доступом">
        <EuroCupsSection />
      </Section>

      <Section title="Журнал лиги" subtitle="Аналитика, метрики и истории дня">
        <MagazineLayout />
      </Section>
    </div>
  );
}
