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
      title: "Матчи лиги",
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
    <div className="space-y-6">
      <section className="space-y-2">
        <h1 className="text-2xl font-semibold text-slate-900">Обзор лиги</h1>
        <p className="text-sm text-slate-500">
          Актуальные данные по лиге {league}. Сезон {season}.
        </p>
      </section>

      <Card className="border-0 shadow-none bg-transparent">
        <CardContent className="p-0 space-y-4">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-rose-600">
            Быстрые действия
          </h2>
          <div className="grid gap-3 md:grid-cols-2">
            {quickLinks.map((link) => (
              <Link
                key={link.to}
                to={link.to}
                className="group block rounded-2xl border border-slate-200 bg-white px-4 py-5 transition hover:border-rose-300 hover:bg-rose-50/50"
              >
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="text-base font-semibold text-slate-900 group-hover:text-rose-600">
                      {link.title}
                    </div>
                    <p className="mt-1 text-sm text-slate-500">{link.description}</p>
                  </div>
                  <span className="mt-1 text-rose-500 transition group-hover:translate-x-1">→</span>
                </div>
              </Link>
            ))}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="space-y-3">
          <h2 className="text-base font-semibold text-slate-900">Как использовать</h2>
          <p className="text-sm text-slate-600">
            Выбирайте интересующую лигу в левой панели, переключайте сезон и переходите к разделам с помощью карточек выше.
            Для сохранения последних выборов используйте избранное и остальные разделы приложения.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
