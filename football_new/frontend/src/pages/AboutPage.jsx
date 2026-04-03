import React from "react";

export default function AboutPage() {
  const cards = [
    {
      title: "Что такое EdgeScore",
      text:
        "EdgeScore — аналитическая платформа по футболу. Сервис собирает статистику матчей, формы команд, xG и рыночные коэффициенты, чтобы показывать более понятную картину матча и подсвечивать интересные сценарии.",
    },
    {
      title: "Как это работает",
      text:
        "Модель оценивает силу сторон, темп игры, структуру моментов и расхождения с линией букмекера. На основе этого формируются сигналы по исходам, тоталам и объяснения, почему матч выглядит именно так.",
    },
    {
      title: "Что получает пользователь",
      text:
        "Результаты, календарь, инсайты, карточки команд и игроков, сравнение формы, очные встречи и подборки матчей. Сервис создан как рабочий инструмент для анализа, а не как витрина с сухими числами.",
    },
    {
      title: "Важно понимать",
      text:
        "EdgeScore — это аналитика и модельная оценка, а не обещание результата. Любой сигнал — это вероятностный сценарий, а не гарантия. Решение пользователь принимает сам.",
    },
  ];

  return (
    <div className="type-page w-full px-4 py-8 space-y-8 text-slate-100">
      <section className="glass-card px-6 py-6 md:px-8 md:py-8">
        <div className="text-[10px] uppercase tracking-[0.18em] text-white/45">
          EdgeScore
        </div>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white md:text-4xl">
          О проекте
        </h1>
        <p className="mt-4 max-w-3xl text-sm leading-7 text-slate-300 md:text-[15px]">
          Платформа футбольной аналитики, которая помогает быстрее понимать матч,
          форму команд и силу рыночного сигнала.
        </p>
      </section>

      <section className="grid gap-4 lg:grid-cols-2">
        {cards.map((card) => (
          <article
            key={card.title}
            className="rounded-3xl border border-glass bg-surface-2/75 p-6 shadow-[0_12px_34px_rgba(0,0,0,0.28)]"
          >
            <h2 className="text-lg font-semibold text-white">{card.title}</h2>
            <p className="mt-3 text-sm leading-7 text-slate-300">{card.text}</p>
          </article>
        ))}
      </section>

      <section className="relative overflow-hidden rounded-3xl border border-glass bg-surface-2/80 p-6 shadow-[0_14px_45px_rgba(0,0,0,0.35)] md:p-8">
        <div className="pointer-events-none absolute -right-20 -top-16 h-48 w-48 rounded-full bg-violet-500/10 blur-3xl" />
        <div className="text-[11px] uppercase tracking-[0.18em] text-slate-400">
          Контакты
        </div>
        <div className="mt-3 text-2xl font-semibold text-white">
          support@edgescore.pro
        </div>
        <p className="mt-3 max-w-2xl text-sm leading-7 text-slate-300">
          Если хочешь связаться по вопросам проекта, сотрудничества или обратной
          связи по продукту, используй этот адрес.
        </p>
      </section>
    </div>
  );
}
