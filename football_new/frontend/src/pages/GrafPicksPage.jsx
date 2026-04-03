// src/pages/GrafPicksPage.jsx
import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import TeamLogoLink from "@/components/TeamLogoLink";
import { HOME_URL } from "../routes/home";

/* ===== utils ===== */
const fmtPct = (x, d = 1) =>
  x == null || Number.isNaN(Number(x)) ? "—" : `${(Number(x) * 100).toFixed(d)}%`;
const fmtNum = (x, d = 2) =>
  x == null || Number.isNaN(Number(x)) ? "—" : Number(x).toFixed(d);
const impliedFromOdds = (odds) => (odds && odds > 0 ? 1 / Number(odds) : null);
const kellyFraction = (p, odds) => {
  if (p == null || odds == null) return null;
  const b = Number(odds) - 1;
  if (b <= 0) return null;
  const q = 1 - Number(p);
  return (b * Number(p) - q) / b;
};
const teamLogoSrc = (id) => (id ? `/icons/team_logos/${id}.png` : "");

const Img = ({ src, alt, size = 28, className = "" }) => (
  <img
    src={src}
    alt={alt}
    width={size}
    height={size}
    className={className}
    onError={(e) => (e.currentTarget.style.display = "none")}
  />
);

function Badge({ children, color = "slate", className = "" }) {
  const map = {
    green: "bg-emerald-500/20 text-emerald-200",
    amber: "bg-amber-500/20 text-amber-200",
    slate: "bg-white/10 text-slate-200",
    blue: "bg-sky-500/20 text-sky-200",
    violet: "bg-violet-500/20 text-violet-200",
    red: "bg-rose-500/20 text-rose-200",
    whiteSoft: "bg-white/30 text-white ring-1 ring-white/25",
  };
  return (
    <span className={`inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-medium ${map[color] || map.slate} ${className}`}>
      {children}
    </span>
  );
}
const EVBadge = ({ ev }) => {
  const e = Number(ev || 0);
  let color = "slate";
  if (e >= 0.15) color = "green";
  else if (e >= 0.05) color = "amber";
  return <Badge color={color}>EV {fmtPct(e)}</Badge>;
};
const StatBox = ({ label, value, sub }) => (
  <div className="min-h-[86px] px-1 py-1">
    <div className="text-slate-400 text-xs">{label}</div>
    <div className="text-lg font-semibold text-slate-100">{value}</div>
    {sub && <div className="text-xs text-slate-400 mt-0.5">{sub}</div>}
  </div>
);

/* ===== evidence helpers ===== */
function getForm(formDict, teamId) {
  if (!formDict || !teamId) return null;
  const f = formDict[teamId];
  if (!f) return null;
  const w = f.w5 ?? 0, d = f.d5 ?? 0, l = f.l5 ?? 0;
  return { pts: f.pts5 ?? null, w, d, l, gf: f.gf5 ?? null, ga: f.ga5 ?? null };
}
function parseKeyToPair(k) {
  if (typeof k !== "string") return null;
  const m = k.match(/(\d+)[,\s]+(\d+)/);
  if (!m) return null;
  return [Number(m[1]), Number(m[2])];
}
function getH2H(h2hDict, homeId, awayId) {
  if (!h2hDict || !homeId || !awayId) return null;
  const directKey = Object.keys(h2hDict).find((k) => {
    const pair = parseKeyToPair(k);
    return pair && pair[0] === homeId && pair[1] === awayId;
  });
  if (directKey) return h2hDict[directKey];
  const swappedKey = Object.keys(h2hDict).find((k) => {
    const pair = parseKeyToPair(k);
    return pair && pair[0] === awayId && pair[1] === homeId;
  });
  return swappedKey ? h2hDict[swappedKey] : null;
}

/* ===== Single card (сглаженная палитра) ===== */
function SingleCard({ card, evidence, kellyCoef, customNote = "", overrideBanter = false }) {
  const implied = impliedFromOdds(card.odds);
  const kelly = kellyFraction(card.p, card.odds) ?? 0;
  const kRec = Math.max(0, kelly * kellyCoef);

  const formHome = getForm(evidence?.form_last5, card.home_team_id);
  const formAway = getForm(evidence?.form_last5, card.away_team_id);
  const h2h = getH2H(evidence?.h2h_last5, card.home_team_id, card.away_team_id);

  return (
    <div className="glass-card relative overflow-hidden">
      {/* Мягкая акцентная полоска и лёгкое свечение */}
      <div className="absolute left-0 top-0 h-full w-px bg-gradient-to-b from-indigo-400 via-violet-400 to-sky-400" />
      <div className="absolute -inset-24 bg-[radial-gradient(ellipse_at_center,rgba(99,102,241,0.06),transparent_60%)] pointer-events-none" />

      {/* Шапка — приглушённый градиент */}
      <div className="relative flex items-center justify-between px-6 py-4 border-b bg-gradient-to-r from-indigo-600/90 via-violet-600/85 to-sky-600/90 text-white shadow-sm">
        <div className="flex items-center gap-2">
          <Badge color="whiteSoft">{card.label}</Badge>
          {card.agreement === "contrarian" && <Badge color="whiteSoft">против модели</Badge>}
          {card.agreement === "top2" && <Badge color="whiteSoft">top-2</Badge>}
        </div>
        <div className="text-xs/5 opacity-90">🗓 {card.date}</div>
      </div>

      <div className="p-6 grid grid-cols-1 lg:grid-cols-3 gap-6 text-slate-200">
        {/* Match & odds */}
        <div className="lg:col-span-2">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <TeamLogoLink teamId={card.home_team_id} className="block">
                <Img src={teamLogoSrc(card.home_team_id)} alt={card.home_team} size={40} className="rounded" />
              </TeamLogoLink>
              <div className="text-xl font-bold text-slate-100">{card.home_team}</div>
            </div>
            <div className="text-slate-500 font-semibold">vs</div>
            <div className="flex items-center gap-3">
              <div className="text-xl font-bold text-slate-100 text-right">{card.away_team}</div>
              <TeamLogoLink teamId={card.away_team_id} className="block">
                <Img src={teamLogoSrc(card.away_team_id)} alt={card.away_team} size={40} className="rounded" />
              </TeamLogoLink>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-4 py-2">
            <StatBox label="Коэфф." value={<span className="text-2xl">{fmtNum(card.odds, 2)}</span>} />
            <StatBox
              label="Вероятность / имплайд"
              value={
                <span className="font-mono">
                  {fmtPct(card.p, 1)} <span className="text-slate-400">/</span> {fmtPct(implied, 1)}
                </span>
              }
            />
            <StatBox label="EV" value={<span className="font-mono">{fmtPct(card.ev, 1)}</span>} />
          </div>

          <div className="grid grid-cols-3 gap-4 mt-4">
            <StatBox label="Kelly (full)" value={fmtPct(kelly, 1)} />
            <StatBox label={`Реком. доля (×${Math.round(kellyCoef * 100)}%)`} value={fmtPct(kRec, 1)} />
            <StatBox
              label="Согласование"
              value={{ aligned: "по модели", top2: "top-2", contrarian: "контра", neutral: "нейтр." }[card.agreement || "neutral"]}
            />
          </div>

          {(card.banter || customNote) && (
            <div className="mt-5 grid gap-3">
              {!overrideBanter && card.banter && (
                <div className="border-l border-indigo-400/40 pl-4 text-sm text-slate-100">
                  <div className="font-semibold mb-1">👑 Прогноз от Графа Суворова</div>
                  <div>{card.banter}</div>
                  <div className="text-xs text-slate-400 mt-2">Не является фин. советом. Развлекательный контент.</div>
                </div>
              )}
              {customNote && (
                <div className="border-l border-amber-400/40 pl-4 text-sm text-slate-200">
                  <div className="font-semibold mb-1">✍️ От редактора</div>
                  <div>{customNote}</div>
                </div>
              )}
              {overrideBanter && !customNote && (
                <div className="text-xs text-slate-400">* Включена опция «заменять текст модели», но поле пустое.</div>
              )}
            </div>
          )}
        </div>

        {/* Evidence */}
        <div className="lg:border-l lg:border-white/8 lg:pl-6">
          <div className="text-sm font-semibold text-slate-100 mb-3">📈 Доказуха (последние 5)</div>
          <div className="flex flex-col gap-0 divide-y divide-white/8">
            <div className="py-3">
              <div className="text-xs text-slate-400 mb-1">{card.home_team}</div>
              {formHome ? (
                <div className="flex items-center justify-between">
                  <Badge color="green">{formHome.w}-{formHome.d}-{formHome.l}</Badge>
                  <div className="text-xs text-slate-300">Голы: {formHome.gf}:{formHome.ga}</div>
                </div>
              ) : (
                <div className="text-xs text-slate-400">Нет данных</div>
              )}
            </div>
            <div className="py-3">
              <div className="text-xs text-slate-400 mb-1">{card.away_team}</div>
              {formAway ? (
                <div className="flex items-center justify-between">
                  <Badge color="green">{formAway.w}-{formAway.d}-{formAway.l}</Badge>
                  <div className="text-xs text-slate-300">Голы: {formAway.gf}:{formAway.ga}</div>
                </div>
              ) : (
                <div className="text-xs text-slate-400">Нет данных</div>
              )}
            </div>
            <div className="py-3">
              <div className="text-xs text-slate-400 mb-1">Личные встречи</div>
              {h2h ? (
                <div className="flex flex-wrap items-center gap-2 text-xs text-slate-300">
                  <Badge color="blue">матчей {h2h.m5 ?? "—"}</Badge>
                  <Badge color="green">дом: {h2h.hW ?? "—"}</Badge>
                  <Badge color="amber">ничьи: {h2h.d5 ?? "—"}</Badge>
                  <Badge color="red">гости: {h2h.aW ?? "—"}</Badge>
                </div>
              ) : (
                <div className="text-xs text-slate-400">Нет данных</div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ===== Parlay card (сглаженная палитра) ===== */
function ParlayCard({ card, evidence, kellyCoef, customNote = "", overrideBanter = false }) {
  const agg = card.parlay_metrics || {};
  const kRec = Math.max(0, (agg.kelly ?? 0) * kellyCoef);

  return (
    <div className="glass-card relative overflow-hidden">
      <div className="absolute left-0 top-0 h-full w-px bg-gradient-to-b from-rose-400 via-orange-400 to-amber-400" />
      <div className="absolute -inset-24 bg-[radial-gradient(ellipse_at_center,rgba(244,63,94,0.06),transparent_60%)] pointer-events-none" />

      <div className="relative flex items-center justify-between px-6 py-4 border-b bg-gradient-to-r from-rose-600/90 via-orange-600/85 to-amber-600/90 text-white shadow-sm">
        <div className="flex items-center gap-2">
          <Badge color="whiteSoft">Экспресс</Badge>
        </div>
        <div className="text-xs/5 opacity-90">⚡ {card.title}</div>
      </div>

      <div className="p-6">
        <div className="mb-4">
          {card.legs.map((leg) => (
            <div key={leg.fixture_id} className="flex items-center justify-between px-2 py-3">
              <div className="flex items-center gap-3">
                <Badge color="blue">{leg.label}</Badge>
                <span className="text-slate-100 font-medium">{leg.title}</span>
              </div>
              <div className="text-sm font-mono text-slate-300">
                {fmtPct(leg.p, 1)} · {fmtNum(leg.odds, 2)}
              </div>
            </div>
          ))}
        </div>

        <div className="grid grid-cols-4 gap-4">
          <StatBox label="Совм. p" value={<span className="font-mono">{fmtPct(agg.p, 2)}</span>} />
          <StatBox label="Коэфф." value={<span className="text-2xl">{fmtNum(agg.odds, 2)}</span>} />
          <StatBox label="EV" value={<span className="font-mono">{fmtPct(agg.ev, 1)}</span>} />
          <StatBox label={`Реком. доля (×${Math.round(kellyCoef * 100)}%)`} value={fmtPct(kRec, 1)} />
        </div>

        {(card.banter || customNote) && (
          <div className="mt-5 grid gap-3">
            {!overrideBanter && card.banter && (
              <div className="border-l border-rose-400/40 pl-4 text-sm text-slate-100">
                <div className="font-semibold mb-1">👑 Прогноз от Графа Суворова</div>
                <div>{card.banter}</div>
                <div className="text-xs text-slate-400 mt-2">Не является фин. советом. Развлекательный контент.</div>
              </div>
            )}
            {customNote && (
              <div className="border-l border-amber-400/40 pl-4 text-sm text-slate-200">
                <div className="font-semibold mb-1">✍️ От редактора</div>
                <div>{customNote}</div>
              </div>
            )}
            {overrideBanter && !customNote && (
              <div className="text-xs text-slate-400">* Включена опция «заменять текст модели», но поле пустое.</div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

/* ===== Page ===== */
export default function GrafPicksPage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState("");
  const [cards, setCards] = useState([]);
  const [evidence, setEvidence] = useState(null);
  const [kellyCoef, setKellyCoef] = useState(0.25);

  // пользовательский текст к карточкам
  const [customNote, setCustomNote] = useState("");
  const [overrideBanter, setOverrideBanter] = useState(false);

  const fetchData = async () => {
    setLoading(true);
    setErr("");
    try {
      const qs = new URLSearchParams({
        days_ahead: "5",
        target_cards: "3",
        attach_evidence: "true",
      });
      const r = await fetch(`/api/graf-picks?${qs.toString()}`);
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      const data = await r.json();
      setCards(data?.cards || []);
      setEvidence(data?.evidence || null);
    } catch (e) {
      setErr(e.message || String(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const singles = useMemo(() => cards.filter((c) => c.type === "single"), [cards]);
  const parlays = useMemo(() => cards.filter((c) => c.type === "parlay"), [cards]);

  return (
    <>
      <div className="type-page w-full px-4 py-8 text-slate-200">
        {/* back */}
        <div className="mb-4">
          <button
            onClick={() => navigate(HOME_URL)}
            className="inline-flex items-center gap-2 text-sm text-slate-300 hover:text-slate-100"
          >
            <span>←</span> <span>На главную</span>
          </button>
        </div>

        {/* hero */}
        <div className="type-title-block glass-card relative overflow-hidden p-7 mb-8 text-white">
          <div className="absolute right-0 top-0 bottom-0 w-64 bg-[radial-gradient(ellipse_at_center,rgba(255,255,255,0.16),transparent)]" />
          <h1 className="type-page-title">Прогнозы от Графа Суворова</h1>
          <p className="type-subtitle text-slate-200/90">
            2–3 карточки на ближайшие 5 дней: ординары и/или двойники с умной фильтрацией рисков.
          </p>

          <div className="mt-4 flex flex-wrap items-center gap-3">
            <label className="text-sm text-slate-200/90">Kelly ×</label>
            <input
              type="range"
              min={0.1}
              max={0.5}
              step={0.05}
              value={kellyCoef}
              onChange={(e) => setKellyCoef(Number(e.target.value))}
              className="w-48 accent-sky-300"
            />
            <div className="w-12 text-right text-sm font-mono">{Math.round(kellyCoef * 100)}%</div>

            <button
              onClick={fetchData}
              className="ml-auto inline-flex items-center gap-2 rounded-xl bg-white/10 px-3 py-2 text-sm hover:bg-white/15 border border-white/20"
            >
              🔄 Обновить
            </button>
          </div>

          {/* редактор комментария */}
          <div className="mt-5 grid gap-2">
            <label className="text-sm text-slate-200/90">Ваш комментарий для карточек (опционально):</label>
            <textarea
              value={customNote}
              onChange={(e) => setCustomNote(e.target.value)}
              rows={2}
              placeholder="Например: «Беру осторожно пол-юнита. Жду рост линии к вечеру»"
              className="w-full rounded-xl bg-white/10 border border-white/20 px-3 py-2 text-sm placeholder:text-slate-300"
            />
            <label className="flex items-center gap-2 text-sm text-slate-200/90">
              <input
                type="checkbox"
                checked={overrideBanter}
                onChange={(e) => setOverrideBanter(e.target.checked)}
              />
              Заменять текст модели моим комментарием
            </label>
          </div>
        </div>

        {loading && <div className="text-slate-400">Загружаем…</div>}
        {err && <div className="text-rose-300">Ошибка: {err}</div>}

        {!loading && !err && (
          <>
            {/* singles */}
            {singles.length > 0 && (
              <div className="mb-8">
                <h2 className="type-section-title mb-3">🔥 Ординары</h2>
                <div className="grid grid-cols-1 gap-6">
                  {singles.map((c) => (
                    <SingleCard
                      key={`s-${c.fixture_id}-${c.label}`}
                      card={c}
                      evidence={evidence}
                      kellyCoef={kellyCoef}
                      customNote={customNote}
                      overrideBanter={overrideBanter}
                    />
                  ))}
                </div>
              </div>
            )}

            {/* parlays */}
            {parlays.length > 0 && (
              <div className="mb-8">
                <h2 className="type-section-title mb-3">⚡ Экспресс</h2>
                <div className="grid grid-cols-1 gap-6">
                  {parlays.map((c, idx) => (
                    <ParlayCard
                      key={`p-${idx}`}
                      card={c}
                      evidence={evidence}
                      kellyCoef={kellyCoef}
                      customNote={customNote}
                      overrideBanter={overrideBanter}
                    />
                  ))}
                </div>
              </div>
            )}

            {cards.length === 0 && (
              <div className="rounded-3xl border border-glass bg-surface-2/70 p-6 text-slate-300">
                <div className="type-card-title">
                  Сейчас нет ставок с ценностью
                </div>
                <div className="mt-2 type-body">
                  Мы не показываем ставки ради активности.
                  Подборки появляются только когда модель и рынок расходятся.
                </div>
                <div className="mt-2 text-xs text-slate-500">
                  Попробуй изменить лигу, сезон или порог EV.
                </div>
                <div className="mt-4 flex flex-wrap gap-2">
                  <button
                    onClick={() => window.scrollTo({ top: 0, behavior: "smooth" })}
                    className="rounded-full border border-glass bg-surface-1/80 px-4 py-2 text-xs font-semibold text-slate-200 hover:bg-surface-2"
                  >
                    Изменить фильтры
                  </button>
                  <button
                    onClick={() => navigate("/matches-v3")}
                    className="rounded-full border border-glass bg-surface-1/80 px-4 py-2 text-xs font-semibold text-slate-200 hover:bg-surface-2"
                  >
                    Смотреть результаты
                  </button>
                </div>
              </div>
            )}

            <div className="mt-10 text-xs text-slate-500">
              Развлекательный контент. Вероятности и коэффициенты могут меняться. Проверяй актуальные котировки.
            </div>
          </>
        )}
      </div>
    </>
  );
}
