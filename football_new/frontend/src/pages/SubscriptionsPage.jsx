// src/pages/SubscriptionsPage.jsx
// EdgeScore Premium Subscriptions — тёмная премиальная страница без дублирующей шапки лиг.

import React, { useEffect, useMemo, useRef, useState } from "react";
import { useAuth } from "../auth/AuthContext";
import { http } from "../lib/http.js";

const THEME_GRAD = "from-rose-600 via-fuchsia-500 to-violet-500";

/* ===================== COPY / ТЕКСТЫ ===================== */
const COPY = {
  heroBadge: "Новинка сезона 24/25",
  heroTitle:
    "Подписки EdgeScore: живой ROI, понятные инсайты, уверенный рост банка",
  heroSubtitle:
    "Используем те же модели, что и на главной: прематч, live-аналитика и подборки по лигам. Получайте чистые сигналы, отчёты и уведомления — от бесплатного доступа до PRO.",
  heroChips: [
    "20+ чемпионатов",
    "Анализ xG и live-линий каждые 30 сек",
    "Win-rate PRO-подборок 73%",
  ],
  heroBtnPrimaryPrefix: "Выбрать",
  heroBtnSecondary: "Сравнить планы",
  balanceTitle: "Ваш баланс",
  balanceHint:
    "Пополните перед покупкой PRO, чтобы не пропускать ROI-алерты и премиум-подборки.",
  balanceBtn: "Пополнить баланс",
  roiCasesTitle: "ROI-кейсы сезона 2024/25",
  roiCasesSubtitle:
    "1800+ ставок в базе. Цифры построены на тех же моделях, что и подборки и календарь.",
  roiCasesCta: "К тарифам",
  plansTitle: "Выберите подписку",
  plansSubtitle:
    "Тарифы обновляются автоматически и синхронизированы с реальной статистикой моделей.",
  plansHintPrefix: "ROI по планам — последние 90 дней • Обновлено",
  promoTitle: "Поднимайте ROI каждую неделю",
  promoText:
    "Мы фиксируем каждую рекомендацию, считаем результат и отдаём всё в понятном формате: графики, сводки и пуш-уведомления.",
  promoPoints: [
    "Дашборды под вашу лигу",
    "Live-алерты с ROI > 12% в Telegram",
    "Еженедельный отчёт с динамикой банка",
  ],
  promoDealBadge: "Комбо-предложение",
  promoDealTitle: "–20% на PRO при оплате за квартал",
  promoDealText:
    "Сэкономьте и получите доступ ко всем премиум-функциям: live-инсайтам, подборкам и push по тоталам.",
  promoDealBtnPlans: "Посмотреть планы",
  promoDealBtnCompare: "Открыть сравнение",
  stickyTextPrefix: "Готовы повысить ROI? Посмотрите тарифы и выберите",
  compareTitle: "Сравнение планов",
  compareClose: "Закрыть",
  tableParams: [
    "Цена",
    "Срок действия",
    "Отчётов в месяц",
    "Уведомлений в день",
  ],
  planHeader: "Тариф",
  planBadges: { best: "Лучший ROI", active: "Активна" },
  planDesc: {
    start: "Знакомство с расширенными инструментами и подборками.",
    pro: "Для продвинутых игроков и аккуратного банкролл-менеджмента.",
    elite: "Максимум данных, live-инсайтов и кастомных отчётов.",
    free: "Базовый доступ к данным и части подборок.",
  },
  planBtn: {
    connect: "Подключить",
    purchase: "Оформить",
    connected: "Уже подключено",
    purchased: "Уже оформлено",
  },
  planMeta: {
    reports: "Отчётов в месяц:",
    alerts: "Уведомлений в день:",
  },
  personalRoiTitle: "Ваш текущий ROI за 30 дней",
  updated: "Обновлено",
};

/* ===================== ROI виджеты ===================== */
const ROI_HIGHLIGHTS = [
  {
    id: "outcomes",
    label: "ROI на исходах",
    value: 18.7,
    subLabel: "+4.3% за последний квартал",
    description:
      "Модель на базе xG, составов и формы. Обновления — каждый тур.",
    series: [2, 3, 6, 4, 8, 10, 12, 15, 16, 18.7],
  },
  {
    id: "totals",
    label: "ROI по тоталам",
    value: 14.2,
    subLabel: "71% точности на 500+ ставках",
    description: "Сверяем live-линию с симуляциями и темпом матча.",
    series: [1, 4, 3, 6, 8, 9, 10, 12, 12.5, 14.2],
  },
  {
    id: "alerts",
    label: "ROI push-алертов",
    value: 21.9,
    subLabel: "до 6 уведомлений в день",
    description: "Автопоиск валуйных коэффициентов и перекосов линии.",
    series: [5, 6, 8, 9, 12, 15, 17, 18, 20, 21.9],
  },
];

const VALUE_PILLARS = [
  {
    id: "reports",
    title: "Глубокие отчёты",
    description:
      "Развёрнутый анализ 20+ лиг: тренды, форма, xG/xPTS и отдельные метрики по рынкам.",
    tone: "emerald",
    icon: "📊",
  },
  {
    id: "alerts",
    title: "Live value",
    description:
      "Push-уведомления по ключевым рынкам и тоталам — пока линия не успела среагировать.",
    tone: "sky",
    icon: "⚡",
  },
  {
    id: "community",
    title: "Коммьюнити PRO",
    description:
      "Разборы кейсов, ROI-подборки и еженедельные созвоны в закрытом Telegram.",
    tone: "violet",
    icon: "🤝",
  },
];

/* ===================== Вспомогательные компоненты ===================== */
function Sparkline({ data = [], width = 160, height = 44 }) {
  if (!data.length) return null;
  const min = Math.min(...data);
  const max = Math.max(...data);
  const norm = (v) =>
    height - 6 - ((v - min) / (max - min || 1)) * (height - 12);
  const step = (width - 12) / (data.length - 1);
  const d = data
    .map((v, i) => `${i === 0 ? "M" : "L"} ${6 + i * step} ${norm(v)}`)
    .join(" ");
  return (
    <svg viewBox={`0 0 ${width} ${height}`} className="w-full h-[44px]">
      <path
        d={`M6 ${height - 6} L${width - 6} ${height - 6}`}
        stroke="currentColor"
        strokeOpacity={0.15}
        strokeWidth="2"
        fill="none"
      />
      <path
        d={d}
        stroke="currentColor"
        strokeOpacity={0.9}
        strokeWidth="2.5"
        fill="none"
      />
      <circle
        cx={6 + (data.length - 1) * step}
        cy={norm(data[data.length - 1])}
        r="3.5"
        fill="white"
        stroke="currentColor"
        strokeOpacity={0.9}
        strokeWidth="2"
      />
    </svg>
  );
}

function useCounter(target = 0, duration = 900) {
  const [val, setVal] = useState(0);
  useEffect(() => {
    let raf;
    let start;
    const step = (t) => {
      if (!start) start = t;
      const p = Math.min((t - start) / duration, 1);
      setVal(target * (0.1 + 0.9 * p * (2 - p))); // easeOut
      if (p < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [target, duration]);
  return val;
}

function ROIHighlightCard({ item, lastUpdated }) {
  const animated = useCounter(item.value, 900);
  return (
    <div className="rounded-2xl border border-white/12 bg-surface-3/90 px-4 py-4 shadow-[0_0_28px_rgba(15,23,42,0.9)]">
      <div className="flex items-center justify-between gap-3">
        <div className="text-[11px] uppercase tracking-wide text-slate-200/70">
          {item.label}
        </div>
        <span className="text-[10px] rounded-full border border-white/15 px-2 py-0.5 text-slate-200/70 font-mono tracking-tight">
          {COPY.updated} {lastUpdated.toLocaleDateString("ru-RU")}
        </span>
      </div>
      <div className="mt-2 text-3xl font-black text-slate-50">{`+$${0}` && `+${animated.toFixed(1)}%`}</div>
      <div className="mt-1 text-[12px] text-slate-200/80">
        {item.subLabel}
      </div>
      <div className="mt-2 text-fuchsia-300/80">
        <Sparkline data={item.series} />
      </div>
      <p className="mt-2 text-[13px] leading-relaxed text-slate-200/85">
        {item.description}
      </p>
    </div>
  );
}

function ROICaseCard({ item }) {
  const animated = useCounter(item.value, 800);
  return (
    <div className="rounded-2xl border border-slate-200/70 bg-white/90 p-5 shadow-md">
      <div className="text-xs uppercase tracking-wide text-slate-500">
        {item.label}
      </div>
      <div className="mt-2 text-[28px] font-black text-slate-900">
        {`+${animated.toFixed(1)}%`}
      </div>
      <div className="mt-1 text-xs text-emerald-600">{item.subLabel}</div>
      <Sparkline data={item.series} />
      <p className="mt-3 text-sm text-slate-600">{item.description}</p>
    </div>
  );
}

/* ===================== Основной компонент ===================== */
function SubscriptionsPage() {
  const { isAuthenticated } = useAuth();

  const [plans, setPlans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [purchaseLoading, setPurchaseLoading] = useState({});
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const [userSubs, setUserSubs] = useState([]);
  const [balance, setBalance] = useState(0);
  const [userRoi, setUserRoi] = useState(null);

  const [addFundsOpen, setAddFundsOpen] = useState(false);
  const [compareOpen, setCompareOpen] = useState(false);

  const [showStickyCta, setShowStickyCta] = useState(false);
  const plansRef = useRef(null);
  const [lastUpdated, setLastUpdated] = useState(new Date());

  const num = (v) => Number(v ?? 0);
  const fmtPrice = (p) =>
    num(p) === 0 ? "Бесплатно" : `${num(p).toLocaleString("ru-RU")} ₽`;

  useEffect(() => {
    fetchPlans();
  }, []);

  useEffect(() => {
    if (isAuthenticated) fetchMe();
  }, [isAuthenticated]);

  async function fetchPlans() {
    try {
      setLoading(true);
      const res = await http.get(
        "http://localhost:8001/api/subscriptions/plans"
      );
      const data = Array.isArray(res) ? res : res?.data || [];
      setPlans(data);
      setError("");
      setLastUpdated(new Date());
    } catch {
      setError(
        "Не удалось загрузить планы подписок. Попробуйте ещё раз чуть позже."
      );
    } finally {
      setLoading(false);
    }
  }

  async function fetchMe() {
    try {
      const res = await http.get(
        "http://localhost:8001/api/subscriptions/me"
      );
      const payload = res?.data || res;
      setUserSubs(payload?.active_subscriptions || []);
      setBalance(Number(payload?.balance || 0));
    } catch {
      setUserSubs([]);
    }
    try {
      const roiRes = await http.get(
        "http://localhost:8001/api/subscriptions/user-roi"
      );
      const r = roiRes?.data || roiRes;
      if (typeof r?.roi === "number") setUserRoi(r.roi);
    } catch {
      // необязательно
    }
  }

  useEffect(() => {
    const onScroll = () => {
      if (!plansRef.current) return;
      const top = plansRef.current.getBoundingClientRect().top;
      setShowStickyCta(top < 0);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const activeByCode = useMemo(() => {
    const map = new Map();
    userSubs.forEach((s) => {
      if (s?.is_active) map.set(s.plan_code, s);
    });
    return map;
  }, [userSubs]);

  async function handlePurchase(plan) {
    if (!isAuthenticated)
      return setError("Для оформления подписки войдите в систему.");
    if (activeByCode.has(plan.code))
      return setError("У вас уже активна эта подписка.");

    setPurchaseLoading((m) => ({ ...m, [plan.id]: true }));
    setError("");
    setSuccess("");

    try {
      await http.post(
        "http://localhost:8001/api/subscriptions/purchase",
        { plan_code: plan.code }
      );
      setSuccess(`Подписка «${plan.name}» успешно оформлена.`);
      await Promise.all([fetchMe(), fetchPlans()]);
      setTimeout(() => setSuccess(""), 3500);
    } catch (e) {
      const status = e?.status;
      const msg =
        e?.data?.detail ||
        e?.message ||
        "Ошибка при оформлении подписки.";
      if (status === 402) setAddFundsOpen(true);
      setError(msg);
    } finally {
      setPurchaseLoading((m) => ({ ...m, [plan.id]: false }));
    }
  }

  /* ===== UI atoms ===== */
  const Badge = ({ tone = "gray", children }) => (
    <span
      className={`inline-flex items-center gap-1 rounded-full border px-2.5 py-1 text-[11px] font-medium
      ${
        tone === "rose"
          ? "border-rose-300/70 bg-rose-500/20 text-rose-50"
          : tone === "green"
          ? "border-emerald-300/70 bg-emerald-500/20 text-emerald-50"
          : "border-slate-500/70 bg-slate-800/60 text-slate-100"
      }`}
    >
      {children}
    </span>
  );

  const Check = () => (
    <svg
      viewBox="0 0 20 20"
      className="h-4 w-4 flex-none text-emerald-400"
      aria-hidden="true"
    >
      <path
        fill="currentColor"
        d="M7.629 13.233 3.9 9.504l1.2-1.2 2.529 2.528 6.37-6.37 1.2 1.2-7.57 7.571z"
      />
    </svg>
  );

  const Feature = ({ children, title }) => (
    <div
      className="flex items-center gap-2 text-sm text-slate-200/90"
      title={title}
    >
      <Check />
      <span>{children}</span>
    </div>
  );

  const CardShell = ({ accent, children }) => (
    <div
      className={`relative flex h-full flex-col rounded-3xl p-[1px] transition-transform duration-300
      ${
        accent
          ? "bg-gradient-to-r from-fuchsia-500/80 via-violet-500/80 to-sky-500/80 hover:-translate-y-1.5"
          : "bg-slate-700/80 hover:-translate-y-1"
      }`}
    >
      <div className="flex h-full flex-col rounded-[calc(1.5rem-1px)] bg-surface-3/95 shadow-[0_0_40px_rgba(15,23,42,0.9)] ring-1 ring-slate-700/80">
        {children}
      </div>
    </div>
  );

  const planRoiHint = (plan) => {
    const price = num(plan.price);
    if (price === 0)
      return { value: "+7.8%", label: "ROI базовых подборок" };
    if (price <= 1990)
      return { value: "+11.6%", label: "ROI стартовых моделей" };
    if (price <= 3990)
      return { value: "+15.4%", label: "ROI прематч-аналитики" };
    if (price <= 6990)
      return { value: "+18.9%", label: "ROI PRO-рекомендаций" };
    return { value: "+22.7%", label: "ROI live-инсайтов" };
  };

  const PlanCard = ({ plan, accent = false, isFree = false }) => {
    const active = activeByCode.get(plan.code);
    const buying = !!purchaseLoading[plan.id];
    const roiHint = planRoiHint(plan);

    const roiBoxClass = isFree
      ? "bg-gradient-to-br from-emerald-500/15 via-surface-3/90 to-emerald-500/20 text-emerald-50 border-emerald-400/40"
      : "bg-gradient-to-br from-slate-950 via-slate-900 to-slate-900/90 text-slate-50 border-slate-600/60";

    const lower = (plan.code || "").toLowerCase();
    const desc = isFree
      ? COPY.planDesc.free
      : lower.includes("elite")
      ? COPY.planDesc.elite
      : lower.includes("pro")
      ? COPY.planDesc.pro
      : COPY.planDesc.start;

    return (
      <CardShell accent={accent}>
        <div className="flex h-full flex-col gap-6 p-6">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              <p className="text-[11px] uppercase tracking-[0.28em] text-slate-400">
                {COPY.planHeader}
              </p>
              <h3 className="truncate text-2xl font-black tracking-tight text-slate-50">
                {plan.name}
              </h3>
              <p className="mt-2 min-h-[48px] text-sm leading-6 text-slate-200/85">
                {plan.description || desc}
              </p>
            </div>
            <div className="flex flex-col items-end gap-1">
              {accent && <Badge tone="green">{COPY.planBadges.best}</Badge>}
              <Badge tone={isFree ? "green" : "rose"}>{plan.code}</Badge>
              {active && <Badge tone="green">{COPY.planBadges.active}</Badge>}
            </div>
          </div>

          <div
            className={`rounded-2xl border p-4 text-center shadow-inner ${roiBoxClass}`}
          >
            <div className="text-[30px] font-black tracking-tight">
              {fmtPrice(plan.price)}
            </div>
            <div className="mt-1 text-[12px] text-slate-200/80">
              {isFree ? "без оплаты" : <>на {plan.duration_days} дней</>}
            </div>
            <div className="mt-4">
              <div className="text-2xl font-black text-slate-50">
                {roiHint.value}
              </div>
              <div className="text-[11px] uppercase tracking-wide text-slate-200/80">
                {roiHint.label}
              </div>
            </div>
          </div>

          <div className="grid gap-2 text-[13px]">
            <Feature title="Сколько отчётов вы можете построить за месяц">
              {COPY.planMeta.reports}
              <b className="ml-1">
                {plan.limit_reports_per_month ?? "—"}
              </b>
            </Feature>
            <Feature title="Сколько push/почтовых уведомлений в день">
              {COPY.planMeta.alerts}
              <b className="ml-1">
                {plan.limit_alerts_per_day ?? "—"}
              </b>
            </Feature>
            {active?.end_at && (
              <div className="mt-1 rounded-xl border border-emerald-500/40 bg-emerald-500/10 px-3 py-2 text-xs font-semibold text-emerald-100">
                Активна до:{" "}
                <span>
                  {new Date(active.end_at).toLocaleDateString("ru-RU")}
                </span>
              </div>
            )}
          </div>

          <div className="mt-auto pt-2">
            <button
              disabled={!!active || buying}
              onClick={() => handlePurchase(plan)}
              className={`h-11 w-full rounded-2xl text-sm font-semibold text-white shadow-lg transition
                ${
                  active || buying
                    ? "bg-slate-600 cursor-not-allowed"
                    : isFree
                    ? "bg-emerald-500 hover:bg-emerald-600"
                    : `bg-gradient-to-r ${THEME_GRAD} hover:brightness-110`
                }`}
            >
              {active
                ? isFree
                  ? COPY.planBtn.connected
                  : COPY.planBtn.purchased
                : buying
                ? isFree
                  ? "Подключаем…"
                  : "Оформление…"
                : isFree
                ? COPY.planBtn.connect
                : COPY.planBtn.purchase}
            </button>
          </div>
        </div>
      </CardShell>
    );
  };

  /* ===== LOADING ===== */
  if (loading) {
    return (
      <div className="min-h-screen bg-surface-1 text-slate-50">
        <div className="mx-auto max-w-6xl px-4 pt-6 pb-16 space-y-8">
          <div className="h-[260px] animate-pulse rounded-3xl bg-surface-2/90 border border-glass" />
          <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
            {[...Array(3)].map((_, i) => (
              <div
                key={i}
                className="h-[320px] animate-pulse rounded-3xl border border-slate-700/70 bg-surface-2/80"
              />
            ))}
          </div>
        </div>
      </div>
    );
  }

  /* ===== DATA PREP ===== */
  const paid = plans
    .filter((p) => num(p.price) > 0)
    .sort((a, b) => num(a.price) - num(b.price));
  const free = plans.filter((p) => num(p.price) === 0);
  const accentId = paid[Math.floor(paid.length / 2)]?.id;
  const heroPlanName =
    paid[paid.length - 1]?.name ||
    paid[0]?.name ||
    free[0]?.name ||
    "подписку";

  const toneMap = {
    emerald:
      "border-emerald-300/60 bg-gradient-to-br from-emerald-500/20 via-surface-2/80 to-emerald-500/15 text-emerald-50",
    sky: "border-sky-300/60 bg-gradient-to-br from-sky-500/20 via-surface-2/80 to-sky-500/15 text-sky-50",
    violet:
      "border-violet-300/60 bg-gradient-to-br from-violet-500/20 via-surface-2/80 to-violet-500/15 text-violet-50",
  };

  const scrollToPlans = () => {
    const node = document.getElementById("subscriptions-plans");
    if (node) node.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  /* ===== RENDER ===== */
  return (
    <div className="min-h-screen bg-surface-1 text-slate-50">
      <div className="mx-auto max-w-6xl px-3 sm:px-4 lg:px-6 pt-6 pb-24 space-y-10">
        {/* HERO */}
        <section className="relative overflow-hidden rounded-3xl bg-surface-2/95 text-white shadow-2xl ring-1 ring-white/10">
          <div className="pointer-events-none absolute -right-32 -top-24 h-96 w-96 rounded-full bg-fuchsia-500/25 blur-3xl" />
          <div className="pointer-events-none absolute -left-24 bottom-[-80px] h-80 w-80 rounded-full bg-violet-500/20 blur-3xl" />
          <div className="relative grid gap-10 p-8 md:p-10 lg:grid-cols-[1.15fr_0.95fr] lg:items-center">
            <div className="space-y-6 max-w-xl">
              <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/5 px-3 py-1 text-[11px] uppercase tracking-[0.28em] text-white/70">
                {COPY.heroBadge}
              </span>
              <h1 className="text-3xl sm:text-4xl font-black leading-tight">
                {COPY.heroTitle}
              </h1>
              <p className="text-sm sm:text-[15px] text-slate-100/80">
                {COPY.heroSubtitle}
              </p>

              {isAuthenticated && userRoi != null && (
                <div className="rounded-2xl border border-emerald-400/40 bg-emerald-500/10 p-4 text-sm shadow-[0_0_28px_rgba(16,185,129,0.35)]">
                  <div className="flex items-center justify-between gap-3">
                    <div className="text-slate-50/90">
                      {COPY.personalRoiTitle}
                    </div>
                    <div className="text-lg font-bold text-emerald-200">
                      {userRoi >= 0
                        ? `+${userRoi.toFixed(1)}%`
                        : `${userRoi.toFixed(1)}%`}
                    </div>
                  </div>
                  <div className="mt-1 text-[11px] text-emerald-100/80 font-mono tracking-tight">
                    {COPY.updated}: {lastUpdated.toLocaleDateString("ru-RU")}{" "}
                    {lastUpdated.toLocaleTimeString("ru-RU").slice(0, 5)}
                  </div>
                </div>
              )}

              <div className="flex flex-wrap gap-3 text-xs sm:text-sm text-slate-100/80">
                {COPY.heroChips.map((c) => (
                  <span
                    key={c}
                    className="rounded-full border border-white/15 bg-white/5 px-3 py-1"
                  >
                    {c}
                  </span>
                ))}
              </div>

              <div className="flex flex-col gap-3 pt-3 sm:flex-row sm:items-center sm:gap-4">
                <button
                  onClick={scrollToPlans}
                  className="h-11 rounded-2xl bg-white px-6 text-sm font-semibold text-slate-900 shadow-lg transition hover:translate-y-[-1px] hover:bg-slate-100"
                >
                  {COPY.heroBtnPrimaryPrefix} {heroPlanName}
                </button>
                <button
                  onClick={() => setCompareOpen(true)}
                  className="h-11 rounded-2xl border border-white/20 px-6 text-sm font-semibold text-white/80 transition hover:text-white hover:border-white/40"
                >
                  {COPY.heroBtnSecondary}
                </button>
              </div>
            </div>

            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-1">
              {ROI_HIGHLIGHTS.map((it) => (
                <ROIHighlightCard
                  key={it.id}
                  item={it}
                  lastUpdated={lastUpdated}
                />
              ))}
            </div>
          </div>
        </section>

        {/* Баланс */}
        {isAuthenticated && (
          <section className="flex flex-wrap items-center justify-between gap-4 rounded-3xl border border-glass bg-surface-2/95 p-6 shadow-[0_0_24px_rgba(15,23,42,0.9)]">
            <div className="space-y-1">
              <div className="text-xs uppercase tracking-wide text-slate-400">
                {COPY.balanceTitle}
              </div>
              <div className="text-2xl font-bold text-slate-50">
                {balance.toLocaleString("ru-RU")} ₽
              </div>
              <div className="text-sm text-slate-400">
                {COPY.balanceHint}
              </div>
            </div>
            <button
              onClick={() => setAddFundsOpen(true)}
              className="h-10 rounded-2xl bg-gradient-to-r from-slate-50 to-slate-200 px-6 text-sm font-semibold text-slate-900 shadow-lg hover:brightness-105"
            >
              {COPY.balanceBtn}
            </button>
          </section>
        )}

        {success && (
          <div className="rounded-3xl border border-emerald-400/50 bg-emerald-500/15 px-6 py-4 text-sm font-semibold text-emerald-100 shadow-[0_0_22px_rgba(16,185,129,0.35)]">
            {success}
          </div>
        )}
        {error && (
          <div className="rounded-3xl border border-rose-400/50 bg-rose-500/15 px-6 py-4 text-sm font-semibold text-rose-100 shadow-[0_0_22px_rgba(244,63,94,0.35)]">
            {error}
          </div>
        )}

        {/* Ценность */}
        <section className="grid gap-4 md:grid-cols-3">
          {VALUE_PILLARS.map((p) => (
            <div
              key={p.id}
              className={`rounded-3xl border p-6 shadow-[0_0_26px_rgba(15,23,42,0.9)] ${
                toneMap[p.tone]
              }`}
            >
              <div className="text-3xl">{p.icon}</div>
              <div className="mt-4 text-lg font-semibold">{p.title}</div>
              <p className="mt-2 text-sm text-slate-900/80">
                {p.description}
              </p>
            </div>
          ))}
        </section>

        {/* ROI-кейсы */}
        <section className="rounded-3xl border border-slate-200/80 bg-white/95 p-6 shadow-2xl">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <h2 className="text-lg font-semibold text-slate-900">
                {COPY.roiCasesTitle}
              </h2>
              <p className="text-sm text-slate-500">
                {COPY.roiCasesSubtitle}
              </p>
            </div>
            <button
              onClick={scrollToPlans}
              className="h-10 rounded-2xl border border-slate-200 px-4 text-xs font-semibold uppercase tracking-wide text-slate-600 transition hover:border-slate-300 hover:text-slate-900"
            >
              {COPY.roiCasesCta}
            </button>
          </div>
          <div className="mt-6 grid gap-4 md:grid-cols-3">
            {ROI_HIGHLIGHTS.map((it) => (
              <ROICaseCard key={it.id} item={it} />
            ))}
          </div>
        </section>

        {/* Планы */}
        <section id="subscriptions-plans" ref={plansRef} className="space-y-6">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <h2 className="text-2xl font-black text-slate-50">
                {COPY.plansTitle}
              </h2>
              <p className="text-sm text-slate-400">
                {COPY.plansSubtitle}
              </p>
            </div>
            {!!plans.length && (
              <div className="flex items-center gap-3 text-sm text-slate-400">
                <span className="inline-flex h-2 w-2 rounded-full bg-emerald-400 shadow-[0_0_12px_rgba(16,185,129,0.8)]" />
                {COPY.plansHintPrefix}{" "}
                {lastUpdated.toLocaleDateString("ru-RU")}
              </div>
            )}
          </div>

          {paid.length > 0 && (
            <div className="grid items-stretch gap-6 md:grid-cols-2 xl:grid-cols-3">
              {paid.map((p) => (
                <PlanCard
                  key={p.id}
                  plan={p}
                  accent={p.id === (accentId || paid[paid.length - 1]?.id)}
                />
              ))}
            </div>
          )}

          {free.length > 0 && (
            <div className="grid items-stretch gap-6 md:grid-cols-2 xl:grid-cols-3">
              {free.map((p) => (
                <PlanCard key={p.id} plan={p} isFree />
              ))}
            </div>
          )}

          {!paid.length && !free.length && (
            <div className="rounded-3xl border border-slate-700/70 bg-surface-2/90 p-10 text-center text-slate-200 shadow-[0_0_26px_rgba(15,23,42,0.9)]">
              Планы подписок не найдены.
              <div className="mt-4">
                <button
                  onClick={fetchPlans}
                  className="rounded-2xl bg-gradient-to-r from-slate-50 to-slate-200 px-4 py-2 text-sm font-semibold text-slate-900 shadow hover:brightness-105"
                >
                  Попробовать снова
                </button>
              </div>
            </div>
          )}
        </section>

        {/* Промо-блок */}
        <section className="rounded-3xl bg-surface-2/95 p-8 text-white shadow-[0_0_40px_rgba(15,23,42,0.95)] border border-white/10">
          <div className="grid gap-6 lg:grid-cols-[1.2fr_1fr]">
            <div className="space-y-4">
              <h3 className="text-2xl font-black">{COPY.promoTitle}</h3>
              <p className="text-sm text-slate-100/85">
                {COPY.promoText}
              </p>
              <ul className="space-y-2 text-sm text-slate-100/85">
                {COPY.promoPoints.map((t) => (
                  <li key={t} className="flex items-center gap-2">
                    <Check />
                    {t}
                  </li>
                ))}
              </ul>
            </div>
            <div className="rounded-3xl border border-white/15 bg-white/5 p-6">
              <div className="text-xs uppercase tracking-wide text-slate-100/70">
                {COPY.promoDealBadge}
              </div>
              <div className="mt-3 text-3xl font-black text-slate-50">
                {COPY.promoDealTitle}
              </div>
              <p className="mt-3 text-sm text-slate-100/85">
                {COPY.promoDealText}
              </p>
              <div className="mt-6 flex flex-col gap-3">
                <button
                  onClick={scrollToPlans}
                  className="h-11 rounded-2xl bg-white px-6 text-sm font-semibold text-slate-900 shadow hover:bg-slate-100"
                >
                  {COPY.promoDealBtnPlans}
                </button>
                <button
                  onClick={() => setCompareOpen(true)}
                  className="h-11 rounded-2xl border border-white/25 px-6 text-sm font-semibold text-white/85 transition hover:border-white/40 hover:text-white"
                >
                  {COPY.promoDealBtnCompare}
                </button>
              </div>
            </div>
          </div>
        </section>
      </div>

      {/* Липкая панель CTA */}
      {showStickyCta && (
        <div className="fixed inset-x-0 bottom-3 z-40 px-3">
          <div className="mx-auto max-w-4xl rounded-2xl border border-slate-700/80 bg-surface-2/95 p-3 shadow-2xl backdrop-blur">
            <div className="flex items-center justify-between gap-3">
              <div className="text-sm text-slate-100">
                {COPY.stickyTextPrefix} {heroPlanName}.
              </div>
              <div className="flex gap-2">
                <button
                  onClick={scrollToPlans}
                  className="h-10 rounded-xl bg-gradient-to-r from-slate-50 to-slate-200 px-4 text-sm font-semibold text-slate-900 hover:brightness-105"
                >
                  К тарифам
                </button>
                <button
                  onClick={() => setCompareOpen(true)}
                  className="h-10 rounded-xl border border-slate-500 px-4 text-sm text-slate-100 hover:bg-surface-3"
                >
                  Сравнить
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Модалки */}
      {addFundsOpen && (
        <AddFundsModal
          onClose={() => setAddFundsOpen(false)}
          onAdded={(amount) => {
            setBalance((b) => b + Number(amount || 0));
            setSuccess("Баланс пополнен.");
            setTimeout(() => setSuccess(""), 2500);
          }}
        />
      )}

      {compareOpen && (
        <ComparePlansModal
          plans={plans}
          onClose={() => setCompareOpen(false)}
        />
      )}
    </div>
  );
}

export default SubscriptionsPage;

/* ===================== Add Funds Modal ===================== */
function AddFundsModal({ onClose, onAdded }) {
  const [amount, setAmount] = useState("100");
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState("");

  async function submit() {
    const val = Number(amount);
    if (!Number.isFinite(val) || val <= 0)
      return setErr("Введите корректную сумму.");
    setErr("");
    setLoading(true);
    try {
      await http.post("http://localhost:8001/api/subscriptions/add-funds", {
        amount: val,
        reason: "manual_credit",
      });
      onAdded?.(val);
      onClose?.();
    } catch (e) {
      setErr(e?.data?.detail || "Не удалось пополнить баланс.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    const onKey = (e) => e.key === "Escape" && onClose?.();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-50">
      <div className="absolute inset-0 bg-black/45" onClick={onClose} />
      <div className="absolute left-1/2 top-20 w-[min(420px,92vw)] -translate-x-1/2 rounded-2xl bg-white p-5 shadow-2xl">
        <div className="mb-3 flex items-center justify-between">
          <div className="text-lg font-bold text-slate-900">
            Пополнить баланс
          </div>
          <button
            onClick={onClose}
            className="h-8 w-8 rounded-full bg-slate-100 text-slate-600 hover:bg-slate-200"
            title="Закрыть"
          >
            ×
          </button>
        </div>

        <label className="mb-1 block text-sm text-slate-600">
          Сумма, ₽
        </label>
        <input
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          inputMode="numeric"
          className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-slate-200"
          placeholder="100"
        />

        {err && (
          <div className="mt-3 rounded-md border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-800">
            {err}
          </div>
        )}

        <div className="mt-5 flex items-center justify-end gap-2">
          <button
            onClick={onClose}
            className="h-10 rounded-xl border border-slate-300 px-4 text-sm hover:bg-slate-50"
          >
            Отмена
          </button>
          <button
            onClick={submit}
            disabled={loading}
            className="h-10 rounded-xl bg-slate-900 px-4 text-sm font-semibold text-white hover:bg-black disabled:bg-slate-400"
          >
            {loading ? "Обработка…" : "Пополнить"}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ===================== Compare Plans Modal ===================== */
function ComparePlansModal({ plans, onClose }) {
  const paid = plans
    .filter((p) => Number(p.price) > 0)
    .sort((a, b) => Number(a.price) - Number(b.price));
  const free = plans.filter((p) => Number(p.price) === 0);
  const cols = [...paid, ...free];

  const rows = [
    {
      key: "price",
      label: COPY.tableParams[0],
      fmt: (p) =>
        Number(p) === 0
          ? "Бесплатно"
          : `${Number(p).toLocaleString("ru-RU")} ₽`,
    },
    {
      key: "duration_days",
      label: COPY.tableParams[1],
      fmt: (v) => `${v} дней`,
    },
    {
      key: "limit_reports_per_month",
      label: COPY.tableParams[2],
    },
    {
      key: "limit_alerts_per_day",
      label: COPY.tableParams[3],
    },
  ];

  useEffect(() => {
    const onKey = (e) => {
      if (e.key === "Escape") onClose?.();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-[60]">
      <div className="absolute inset-0 bg-black/50" onClick={onClose} />
      <div className="absolute left-1/2 top-16 w-[min(980px,96vw)] -translate-x-1/2 rounded-2xl bg-white shadow-2xl ring-1 ring-black/5">
        <div className="flex items-center justify-between p-4">
          <div className="text-lg font-bold text-slate-900">
            {COPY.compareTitle}
          </div>
          <button
            onClick={onClose}
            className="h-9 rounded-xl border border-slate-300 bg-white px-3 text-sm text-slate-700 hover:bg-slate-50"
          >
            {COPY.compareClose}
          </button>
        </div>
        <div className="overflow-auto px-4 pb-5">
          <table className="w-full border-separate border-spacing-y-2">
            <thead>
              <tr>
                <th className="w-44 rounded-l-lg bg-slate-50 p-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-600">
                  Параметр
                </th>
                {cols.map((c) => (
                  <th
                    key={c.id}
                    className="rounded-lg bg-slate-50 p-3 text-left text-sm font-bold text-slate-800"
                  >
                    {c.name}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.key}>
                  <td className="rounded-l-lg bg-white p-3 text-sm text-slate-600">
                    {r.label}
                  </td>
                  {cols.map((c) => {
                    const v = c[r.key];
                    const formatted = r.fmt ? r.fmt(v) : v;
                    const max = Math.max(
                      ...cols.map((x) => Number(x[r.key] || 0))
                    );
                    const highlight =
                      ["limit_reports_per_month", "limit_alerts_per_day"].includes(
                        r.key
                      ) &&
                      Number(v) === max &&
                      max > 0;
                    return (
                      <td
                        key={c.id}
                        className={`rounded-lg bg-white p-3 text-sm ${
                          highlight
                            ? "font-semibold text-emerald-700"
                            : "text-slate-800"
                        }`}
                      >
                        {formatted}
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
