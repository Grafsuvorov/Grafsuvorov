import React, { useMemo, useState, useEffect } from "react";

/* ========================================================
   League Selector — Improved mockups (colors + layout)
   Варианты:
   - A) Top Ribbon (цветная плашка сверху)
   - B) Side Rail (левый сайдбар с логотипами)
   - C) Grid (страница выбора лиг)
   Минимум фич, максимум скорости: избранные + недавние, без перегруза поиском.
   ======================================================== */

const LEAGUES = [
  { id: 39,  name: "Premier League",       country: "England",      short: "EPL",  color: "#38003C" },
  { id: 140, name: "LaLiga",               country: "Spain",        short: "LL",   color: "#C4002F" },
  { id: 135, name: "Serie A",              country: "Italy",        short: "SA",   color: "#008FD5" },
  { id: 78,  name: "Bundesliga",           country: "Germany",      short: "BL",   color: "#D20614" },
  { id: 61,  name: "Ligue 1",              country: "France",       short: "L1",   color: "#12263A" },
  { id: 88,  name: "Eredivisie",           country: "Netherlands",  short: "NED",  color: "#FF6A00" },
  { id: 144, name: "Jupiler Pro League",   country: "Belgium",      short: "BEL",  color: "#D51E2E" },
  { id: 94,  name: "Primeira Liga",        country: "Portugal",     short: "POR",  color: "#006847" },
  { id: 2,   name: "UEFA Champions League",country: "Europe",       short: "UCL",  color: "#0A2A66" },
  { id: 307, name: "Saudi Pro League",     country: "Saudi Arabia", short: "KSA",  color: "#006C35" },
  { id: 253, name: "MLS",                  country: "USA",          short: "MLS",  color: "#002D62" },
];

const TOP_PLAYERS_MOCK = [
  { pos: 1,  name: "Mohamed Salah",   club: "Liverpool",    goals: 29, pens: 9 },
  { pos: 2,  name: "A. Isak",         club: "Newcastle",    goals: 23, pens: 4 },
  { pos: 3,  name: "E. Haaland",      club: "Man City",     goals: 22, pens: 3 },
  { pos: 4,  name: "C. Wood",         club: "Nottm Forest", goals: 20, pens: 3 },
  { pos: 5,  name: "B. Mbeumo",       club: "Brentford",    goals: 20, pens: 5 },
  { pos: 6,  name: "Y. Wissa",        club: "Brentford",    goals: 19, pens: 0 },
  { pos: 7,  name: "O. Watkins",      club: "Aston Villa",  goals: 16, pens: 2 },
  { pos: 8,  name: "Matheus Cunha",   club: "Wolves",       goals: 15, pens: 0 },
  { pos: 9,  name: "C. Palmer",       club: "Chelsea",      goals: 15, pens: 4 },
  { pos: 10, name: "J. Strand Larsen",club: "Wolves",       goals: 14, pens: 0 },
];

/* === Utils === */
function tint(hex, amt = 0.25) {
  // простая подмешка белого к цвету (0..1)
  const c = (hex || "#000000").replace("#", "");
  const n = parseInt(c, 16);
  const r = (n >> 16) & 255,
    g = (n >> 8) & 255,
    b = n & 255;
  const mix = (v) => Math.round(v + (255 - v) * amt);
  return `rgb(${mix(r)}, ${mix(g)}, ${mix(b)})`;
}

/* === Small primitives === */
function ColorDot({ color }) {
  return (
    <span
      className="inline-block h-2.5 w-2.5 rounded-full"
      style={{ background: color }}
    />
  );
}

function Logo({ label, active, color }) {
  return (
    <div
      className={`h-7 w-7 shrink-0 rounded-full grid place-items-center text-[10px] font-semibold border ${
        active ? "text-white border-transparent" : "text-slate-300 border-glass"
      }`}
      style={{
        background: active
          ? `linear-gradient(135deg, ${color} 0%, ${tint(color, 0.35)} 100%)`
          : `linear-gradient(135deg, #0b1220 0%, #111827 100%)`,
      }}
      title={label}
    >
      {label}
    </div>
  );
}

function Chip({ active, color, children, onClick }) {
  return (
    <button
      onClick={onClick}
      className={`flex items-center gap-2 rounded-full px-3 py-1.5 text-sm border transition whitespace-nowrap bg-surface-2/70 ${
        active
          ? "text-white border-transparent shadow-sm"
          : "text-slate-200 border-glass hover:bg-white/5"
      }`}
      style={
        active
          ? {
              background: `linear-gradient(135deg, ${color} 0%, ${tint(
                color,
                0.35
              )} 100%)`,
            }
          : {}
      }
    >
      {children}
    </button>
  );
}

function Section({ title, subtitle, children, right }) {
  return (
    <section className="rounded-2xl border border-glass bg-surface-1/90 shadow-sm text-slate-100">
      <header className="flex items-start justify-between gap-2 border-b border-glass p-4">
        <div>
          <h3 className="text-lg font-semibold text-white">{title}</h3>
          {subtitle && <p className="text-sm text-slate-400">{subtitle}</p>}
        </div>
        {right}
      </header>
      <div className="p-4">{children}</div>
    </section>
  );
}

function PlayersTable() {
  return (
    <div className="overflow-hidden rounded-xl border border-glass">
      <table className="w-full border-separate border-spacing-0">
        <thead>
          <tr className="bg-surface-2/80 text-left text-sm text-slate-300">
            <th className="w-10 px-4 py-3">#</th>
            <th className="px-4 py-3">Игрок</th>
            <th className="px-4 py-3">Голы</th>
            <th className="px-4 py-3">Пенальти</th>
          </tr>
        </thead>
        <tbody className="text-sm text-slate-100">
          {TOP_PLAYERS_MOCK.map((r, i) => (
            <tr key={i} className={i % 2 ? "bg-surface-2/60" : "bg-surface-1/60"}>
              <td className="px-4 py-3 text-slate-400">{r.pos}</td>
              <td className="px-4 py-3">
                <div className="flex items-center gap-3">
                  <div className="h-8 w-8 rounded-full bg-surface-2 border border-glass" />
                  <div>
                    <div className="font-medium">{r.name}</div>
                    <div className="text-xs text-slate-400">{r.club}</div>
                  </div>
                </div>
              </td>
              <td className="px-4 py-3 font-medium">{r.goals}</td>
              <td className="px-4 py-3">{r.pens}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/* === Variants === */
function TopRibbon({ active, onSelect, onOpenPalette }) {
  const league = LEAGUES.find((l) => l.id === active) || LEAGUES[0];
  const bg = `linear-gradient(90deg, ${league.color} 0%, ${tint(
    league.color,
    0.45
  )} 60%, ${tint(league.color, 0.75)} 100%)`;

  return (
    <div>
      {/* Colored header stripe */}
      <div
        className="rounded-2xl p-4 text-white shadow-sm"
        style={{ background: bg }}
      >
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <Logo label={league.short} active color={league.color} />
            <div>
              <div className="text-sm/4 opacity-80">Текущая лига</div>
              <div className="text-xl font-bold tracking-tight">
                {league.name}
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button className="rounded-lg bg-white/15 px-3 py-1.5 text-sm hover:bg-white/20">
              2024
            </button>
            <button className="rounded-lg bg-white/15 px-3 py-1.5 text-sm hover:bg-white/20">
              2023
            </button>
            <button
              className="rounded-lg bg-surface-1/80 px-3 py-1.5 text-sm text-slate-100 hover:bg-surface-2"
              title="Все лиги"
              onClick={onOpenPalette}
            >
              Все лиги
            </button>
          </div>
        </div>
      </div>

      {/* Favorite chips row */}
      <div className="no-scrollbar mt-3 flex items-center gap-2 overflow-x-auto pb-1">
        {LEAGUES.map((l) => (
          <Chip
            key={l.id}
            active={active === l.id}
            color={l.color}
            onClick={() => onSelect(l.id)}
          >
            <Logo label={l.short} active={active === l.id} color={l.color} />
            <span>{l.name}</span>
          </Chip>
        ))}
      </div>
    </div>
  );
}

function SideRail({ active, onSelect, onOpenPalette }) {
  const league = LEAGUES.find((l) => l.id === active);

  return (
    <div className="flex gap-4">
      <nav className="sticky top-4 h-fit w-16 rounded-2xl border border-glass bg-surface-2/90 p-2 shadow-sm">
        <div className="flex flex-col items-center gap-2">
          {LEAGUES.map((l) => (
            <button
              key={l.id}
              onClick={() => onSelect(l.id)}
              className="group relative"
              title={l.name}
            >
              <Logo label={l.short} active={active === l.id} color={l.color} />
              <span className="pointer-events-none absolute left-9 top-1/2 -translate-y-1/2 whitespace-nowrap rounded-md bg-surface-1 px-2 py-1 text-xs text-white opacity-0 shadow-sm transition group-hover:opacity-100 border border-glass">
                {l.name}
              </span>
            </button>
          ))}
        </div>
      </nav>

      <div className="min-w-0 flex-1">
        {/* mini header for context */}
        <div className="mb-3 flex items-center gap-3">
          <div
            className="h-8 w-1.5 rounded-full"
            style={{ background: league?.color || "#ddd" }}
          />
          <div className="text-lg font-semibold text-white">
            {league?.name || "Choose a league"}
          </div>
          <div className="text-sm text-slate-400">{league?.country || ""}</div>
          <div className="ml-auto space-x-2">
            <button
              className="rounded-lg border border-glass bg-surface-2/70 px-3 py-1.5 text-sm text-slate-100 hover:bg-surface-2"
              onClick={onOpenPalette}
            >
              Выбрать лигу
            </button>
          </div>
        </div>

        <PlayersTable />
      </div>
    </div>
  );
}

/* === Modal (минимализм) === */
function CommandModal({ open, onClose, onSelect }) {
  const [q, setQ] = useState("");
  const filtered = LEAGUES.filter((l) =>
    (l.name + " " + l.country + " " + l.short)
      .toLowerCase()
      .includes(q.toLowerCase())
  );

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50">
      <div className="absolute inset-0 bg-black/40" onClick={onClose}></div>
      <div className="absolute left-1/2 top-24 w-[min(760px,92vw)] -translate-x-1/2 rounded-2xl border border-glass bg-surface-1/95 shadow-2xl">
        <div className="border-b border-glass p-3">
          <input
            autoFocus
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Найти лигу… (Ctrl/⌘+K)"
            className="w-full rounded-lg border border-glass bg-surface-2 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/40"
          />
        </div>
        <div className="max-h-[60vh] overflow-auto p-2">
          <ul className="grid grid-cols-1 gap-1">
            {filtered.map((l) => (
              <li key={l.id}>
                <button
                  onClick={() => {
                    onSelect(l.id);
                    onClose();
                  }}
                  className="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-left hover:bg-surface-2/80"
                >
                  <Logo label={l.short} color={l.color} />
                  <div>
                    <div className="text-sm font-medium">{l.name}</div>
                    <div className="text-xs text-slate-400 flex items-center gap-2">
                      <ColorDot color={l.color} /> {l.country}
                    </div>
                  </div>
                </button>
              </li>
            ))}
          </ul>
        </div>
        <div className="flex items-center justify-between border-t border-glass p-3 text-xs text-slate-400">
          <span>
            Tip: Ctrl/⌘+K — быстрый выбор
          </span>
          <button
            className="rounded-lg border border-glass px-3 py-1.5 hover:bg-surface-2/80 text-slate-100"
            onClick={onClose}
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}

export default function LeagueSelectorShowcase() {
  const [active, setActive] = useState(39);
  const [variant, setVariant] = useState("top"); // top | side | grid
  const [open, setOpen] = useState(false);

  // хоткей для модалки
  useEffect(() => {
    const onKey = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen(true);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  return (
    <div className="min-h-[100vh] bg-surface-1 p-5 text-slate-100">
      <div className="mx-auto max-w-6xl">
        {/* Header with switch */}
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="grid h-9 w-9 place-items-center rounded-xl bg-surface-2/90 text-white border border-glass">
              ⚽
            </div>
            <div>
              <div className="text-lg font-semibold text-white">
                Селектор лиг — улучшенные макеты
              </div>
              <div className="text-xs text-slate-400">
                Цвета от лиги, минимум кликов, без лишних фильтров
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2 rounded-xl bg-surface-2/80 p-1 shadow-sm border border-glass">
            {[
              { key: "top", label: "Верхняя плашка" },
              { key: "side", label: "Левый сайдбар" },
              { key: "grid", label: "Страница лиг" },
            ].map((t) => (
              <button
                key={t.key}
                onClick={() => setVariant(t.key)}
                className={`rounded-lg px-3 py-1.5 text-sm ${
                  variant === t.key
                    ? "bg-primary/80 text-white"
                    : "text-slate-300 hover:bg-surface-2/80"
                }`}
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>

        {variant === "top" && (
          <Section
            title="Вариант A — Верхняя цветная плашка"
            subtitle="Лучше для мобильного/широких экранов, быстрое сканирование избранных"
            right={
              <button
                onClick={() => setOpen(true)}
                className="rounded-lg border border-glass bg-surface-2/70 px-3 py-2 text-sm text-slate-100 hover:bg-surface-2"
              >
                Выбрать
              </button>
            }
          >
            <TopRibbon
              active={active}
              onSelect={setActive}
              onOpenPalette={() => setOpen(true)}
            />
            <div className="mt-4">
              <PlayersTable />
            </div>
          </Section>
        )}

        {variant === "side" && (
          <Section
            title="Вариант B — Левый сайдбар"
            subtitle="Отлично на десктопе: всегда под рукой, экономит высоту"
          >
            <SideRail
              active={active}
              onSelect={setActive}
              onOpenPalette={() => setOpen(true)}
            />
          </Section>
        )}

        {variant === "grid" && (
          <Section
            title="Вариант C — Страница «Лиги» сеткой"
            subtitle="Первичная настройка избранных / редкий переход"
          >
            <GridLeagues active={active} onSelect={setActive} />
            <div className="mt-6">
              <PlayersTable />
            </div>
          </Section>
        )}

        <CommandModal
          open={open}
          onClose={() => setOpen(false)}
          onSelect={setActive}
        />

        <p className="mt-6 text-center text-xs text-slate-400">
          Реком. паттерн: десктоп — левый сайдбар; мобайл — верхняя плашка.
          Кнопка «Все лиги» открывает модалку по Ctrl/⌘+K.
        </p>
      </div>
    </div>
  );
}

function GridLeagues({ active, onSelect }) {
  const [q, setQ] = useState("");
  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase();
    return LEAGUES.filter((l) =>
      (l.name + " " + l.country + " " + l.short)
        .toLowerCase()
        .includes(s)
    );
  }, [q]);

  const grouped = useMemo(() => {
    return filtered.reduce((acc, l) => {
      (acc[l.country] ||= []).push(l);
      return acc;
    }, /** @type{Record<string, typeof LEAGUES[number][]>} */ ({}));
  }, [filtered]);

  const countries = Object.keys(grouped).sort();

  return (
    <div>
      <div className="mb-3 flex items-center gap-2">
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Найти лигу…"
          className="w-full rounded-lg border border-glass bg-surface-2 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/40"
        />
      </div>

      <div className="space-y-6">
        {countries.map((country) => (
          <div key={country}>
            <div className="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-400">
              {country}
            </div>
            <div className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
              {grouped[country].map((l) => (
                <button
                  key={l.id}
                  onClick={() => onSelect(l.id)}
                  className={`flex items-center gap-3 rounded-xl border p-3 text-left shadow-sm transition hover:shadow bg-surface-2/80 ${
                    active === l.id ? "border-primary" : "border-glass"
                  }`}
                >
                  <Logo
                    label={l.short}
                    active={active === l.id}
                    color={l.color}
                  />
                  <div>
                    <div className="text-sm font-semibold">{l.name}</div>
                    <div className="text-xs text-slate-400 flex items-center gap-2">
                      <ColorDot color={l.color} /> {l.country}
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
