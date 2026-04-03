import { useMemo } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { Card, CardContent } from "@/components/ui/card";

function buildQuickLinks(league, season) {
  const makePath = (path, extra = {}) => {
    const params = new URLSearchParams();
    if (league) params.set("league", league);
    if (season) params.set("season", season);
    Object.entries(extra).forEach(([key, value]) => {
      if (value === undefined || value === null || value === "") return;
      params.set(key, String(value));
    });
    const search = params.toString();
    return search ? `${path}?${search}` : path;
  };

  return [
    {
      title: "Турнирная таблица",
      description: "Позиции команд, очки и форма в выбранной лиге.",
      to: makePath("/table", { view: "total" }),
    },
    {
      title: "Результаты лиги",
      description: "Расписание и результаты предстоящих туров.",
      to: makePath("/matches-v3"),
    },
    {
      title: "Лучшие прогнозы",
      description: "Подборка рекомендаций и аналитика по турам.",
      to: makePath("/best-picks"),
    },
    {
      title: "Сравнение команд",
      description: "Сводная статистика, очные встречи и форма.",
      to: makePath("/compare"),
    },
  ];
}

export default function DashboardPage() {
  const [search] = useSearchParams();
  const league = search.get("league") || "Premier League";
  const season = search.get("season") || "2025";

  const quickLinks = useMemo(() => buildQuickLinks(league, season), [league, season]);

  return (
    <div className="type-page">
      <section className="type-title-block panel px-6 py-5">
        <h1 className="type-page-title">Обзор лиги</h1>
        <p className="type-subtitle">
          Актуальные данные по лиге {league}. Сезон {season}.
        </p>
      </section>

      <Card className="border-0 shadow-none bg-transparent">
        <CardContent className="p-0 type-section">
          <h2 className="type-eyebrow">
            Быстрые действия
          </h2>
          <div className="grid gap-3 md:grid-cols-2">
            {quickLinks.map((link) => (
              <Link
                key={link.to}
                to={link.to}
                className="group block rounded-2xl border border-glass bg-surface-2/80 px-4 py-5 transition hover:bg-surface-1/60"
              >
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="type-card-title">
                      {link.title}
                    </div>
                    <p className="mt-1 type-caption">{link.description}</p>
                  </div>
                  <span className="mt-1 text-slate-300 transition group-hover:translate-x-1">→</span>
                </div>
              </Link>
            ))}
          </div>
        </CardContent>
      </Card>

      <Card className="panel">
        <CardContent className="type-section p-5">
          <h2 className="type-section-title">Как использовать</h2>
          <p className="type-body">
            Выбирайте интересующую лигу в левой панели, переключайте сезон и
            переходите к разделам с помощью карточек выше. Для сохранения
            последних выборов используйте избранное и остальные разделы
            приложения.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
