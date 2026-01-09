// src/components/RightRail.jsx
export default function RightRail() {
  return (
    <div className="w-[280px] space-y-5">
      {/* ACTIONS */}
      <section className="rounded-3xl border border-white/15 bg-slate-950/70 shadow-[0_18px_60px_rgba(15,23,42,0.95)] backdrop-blur-2xl">
        <header className="border-b border-white/10 px-4 py-3 text-sm font-semibold text-slate-50">
          Действия
        </header>

        <div className="p-4 grid grid-cols-2 gap-3 text-sm">
          {["Поделиться", "Копировать ссылку", "Экспорт CSV", "Шорткаты"].map(
            (label) => (
              <button
                key={label}
                className="rounded-2xl border border-white/15 bg-white/5 px-2 py-2 text-[13px] text-slate-100/90 shadow-[0_10px_30px_rgba(15,23,42,0.9)] transition hover:border-cyan-300/70 hover:bg-white/10 hover:text-white"
              >
                {label}
              </button>
            )
          )}
        </div>
      </section>

      {/* HISTORY */}
      <section className="rounded-3xl border border-white/15 bg-slate-950/70 shadow-[0_18px_60px_rgba(15,23,42,0.95)] backdrop-blur-2xl">
        <header className="border-b border-white/10 px-4 py-3 text-sm font-semibold text-slate-50">
          Недавние
        </header>
        <ul className="p-4 text-sm text-slate-300/80">
          <li>Нет просмотров</li>
        </ul>
      </section>
    </div>
  );
}
