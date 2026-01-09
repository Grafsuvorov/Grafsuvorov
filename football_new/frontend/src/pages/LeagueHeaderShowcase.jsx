// src/pages/LeagueHeaderShowcase.jsx
import React from "react";
import LeagueTabsHeaderMockups from "@/components/LeagueTabsHeaderMockups";

export default function LeagueHeaderShowcase() {
  return (
    <div className="mx-auto max-w-6xl space-y-8 px-4 py-8">
      <header className="space-y-2">
        <h1 className="text-3xl font-bold tracking-tight text-slate-900">Макеты шапки лиг</h1>
        <p className="text-sm text-slate-500">
          Здесь можно сравнить несколько вариантов внешнего вида хедера с выбором лиги,
          сезона и вкладок. Компонент использует статичные данные, поэтому клик по элементам
          ни на что не влияет — цель только визуальная оценка.
        </p>
      </header>

      <LeagueTabsHeaderMockups />
    </div>
  );
}
