// src/pages/SubscriptionsPage.jsx
// EdgeScore Premium Subscriptions — тёмная премиальная страница без дублирующей шапки лиг.

import React, { useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { http } from "../lib/http.js";
import { useLanguage } from "@/context/LanguageContext.jsx";

/* ===================== COPY / ТЕКСТЫ ===================== */
const COPY = {
  heroBadge: "EdgeScore Premium",
  heroTitle: "Подписки EdgeScore",
  heroSubtitle: "Единый премиум-доступ к аналитике, инсайтам и подборкам. Отличается только срок и цена.",
  balanceTitle: "Ваш баланс",
  balanceHint:
    "Пополните баланс перед оформлением, чтобы сразу активировать доступ.",
  balanceBtn: "Пополнить баланс",
  plansTitle: "Тарифы доступа",
  plansSubtitle:
    "Функциональность одинаковая. Меняется только срок доступа и выгодность тарифа.",
  compareTitle: "Сравнение планов",
  compareClose: "Закрыть",
  tableParams: ["Цена", "Срок действия"],
  planHeader: "Тариф",
  planBadges: { best: "Рекомендуем", active: "Активна", max: "Максимум" },
  planDesc: {
    start: "Знакомство с расширенными инструментами и обзорной аналитикой.",
    pro: "Для тех, кому нужны глубокие метрики и регулярные отчёты.",
    elite: "Максимум данных, live‑инсайтов и кастомных отчётов.",
    free: "Базовый доступ к данным и обзорным разделам.",
  },
  planBtn: {
    connect: "Подключить",
    purchase: "Оформить",
    connected: "Уже подключено",
    purchased: "Уже оформлено",
  },
  updated: "Обновлено",
};

const VALUE_PILLARS = [
  {
    id: "reports",
    title: "Глубокие отчёты",
    description:
      "Развёрнутый анализ 20+ лиг: тренды, форма, xG/xPTS и динамика туров.",
    icon: "●",
  },
  {
    id: "alerts",
    title: "Live‑инсайты",
    description:
      "Оперативные подсказки по матчам и линиям, когда ситуация меняется.",
    icon: "●",
  },
  {
    id: "community",
    title: "Коммьюнити PRO",
    description:
      "Разборы кейсов, фокус‑матчи недели и регулярные созвоны с аналитикой.",
    icon: "●",
  },
];

const VALUE_PILLARS_EN = {
  reports: {
    title: "Deep reports",
    description: "Expanded analysis across 20+ leagues: trends, form, xG/xPTS, and round dynamics.",
  },
  alerts: {
    title: "Live insights",
    description: "Fast prompts on matches and markets when the situation changes.",
  },
  community: {
    title: "PRO community",
    description: "Case reviews, focus matches of the week, and regular analytics calls.",
  },
};

const ACCESS_STATUS_COPY = {
  active: { ru: "Активен", en: "Active" },
  guest: { ru: "Гость", en: "Guest" },
  updated: { ru: "Обновлено", en: "Updated" },
  features: { ru: "ВОЗМОЖНОСТИ", en: "FEATURES" },
};

/* ===================== Вспомогательные компоненты ===================== */
/* ===================== Основной компонент ===================== */
function SubscriptionsPage() {
  const { isAuthenticated } = useAuth();
  const { language } = useLanguage();
  const [searchParams] = useSearchParams();
  const leagueTitle = searchParams.get("league") || "Bundesliga";
  const seasonTitle = searchParams.get("season") || "2025";

  const [plans, setPlans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [purchaseLoading, setPurchaseLoading] = useState({});
  const [purchaseErrors, setPurchaseErrors] = useState({});
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const [userSubs, setUserSubs] = useState([]);
  const [balance, setBalance] = useState(0);

  const [addFundsOpen, setAddFundsOpen] = useState(false);
  const [compareOpen, setCompareOpen] = useState(false);

  const plansRef = useRef(null);
  const planRefs = useRef(new Map());
  const [highlightPlan, setHighlightPlan] = useState("");
  const [lastUpdated, setLastUpdated] = useState(new Date());
  const isRu = language === "ru";

  const num = (v) => Number(v ?? 0);
  const fmtPrice = (p) =>
    num(p) === 0 ? (isRu ? "Бесплатно" : "Free") : `${num(p).toLocaleString("ru-RU")} ₽`;

  useEffect(() => {
    fetchPlans();
  }, []);

  useEffect(() => {
    if (isAuthenticated) fetchMe();
  }, [isAuthenticated]);

  useEffect(() => {
    const focusPlan = (searchParams.get("plan") || "").toUpperCase();
    if (!focusPlan) return;
    const node = planRefs.current.get(focusPlan);
    if (node) {
      node.scrollIntoView({ behavior: "smooth", block: "center" });
      setHighlightPlan(focusPlan);
    }
  }, [searchParams, plans]);

  async function fetchPlans() {
    try {
      setLoading(true);
      const res = await http.get(
        "/api/subscriptions/plans"
      );
      const data = Array.isArray(res) ? res : res?.data || [];
      setPlans(data);
      setError("");
      setLastUpdated(new Date());
    } catch {
      setError(
        isRu
          ? "Не удалось загрузить планы подписок. Попробуйте ещё раз чуть позже."
          : "Could not load subscription plans. Please try again a bit later."
      );
    } finally {
      setLoading(false);
    }
  }

  async function fetchMe() {
    try {
      const res = await http.get(
        "/api/subscriptions/me"
      );
      const payload = res?.data || res;
      setUserSubs(payload?.active_subscriptions || []);
      setBalance(Number(payload?.balance || 0));
    } catch {
      setUserSubs([]);
    }
  }

  useEffect(() => {
    if (window.location.hash === "#plans") {
      setTimeout(() => {
        const node = document.getElementById("plans");
        if (node) node.scrollIntoView({ behavior: "smooth", block: "start" });
      }, 120);
    }
  }, []);

  const activeByCode = useMemo(() => {
    const map = new Map();
    userSubs.forEach((s) => {
      if (s?.is_active) map.set(s.plan_code, s);
    });
    return map;
  }, [userSubs]);

  async function handlePurchase(plan) {
    if (!isAuthenticated) {
      setError(isRu ? "Для оформления подписки войдите в систему." : "Sign in to purchase a subscription.");
      setPurchaseErrors((m) => ({ ...m, [plan.id]: isRu ? "Нужно войти в систему." : "You need to sign in." }));
      window.scrollTo({ top: 0, behavior: "smooth" });
      return;
    }
    if (activeByCode.has(plan.code))
      return setError(isRu ? "У вас уже активна эта подписка." : "You already have this subscription active.");

    setPurchaseLoading((m) => ({ ...m, [plan.id]: true }));
    setPurchaseErrors((m) => ({ ...m, [plan.id]: "" }));
    setError("");
    setSuccess("");

    try {
      await http.post(
        "/api/subscriptions/purchase",
        { plan_code: plan.code }
      );
      setSuccess(
        isRu
          ? `Подписка «${plan.name}» успешно оформлена.`
          : `Subscription "${plan.name}" was activated successfully.`
      );
      setPurchaseErrors((m) => ({ ...m, [plan.id]: "" }));
      await Promise.all([fetchMe(), fetchPlans()]);
      setTimeout(() => setSuccess(""), 3500);
    } catch (e) {
      const status = e?.status;
      const msg =
        e?.data?.detail ||
        e?.message ||
        (isRu ? "Ошибка при оформлении подписки." : "Subscription purchase failed.");
      if (status === 402) setAddFundsOpen(true);
      if (status === 401) window.location.href = "/login";
      setPurchaseErrors((m) => ({ ...m, [plan.id]: msg }));
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
          ? "border-violet-300/70 bg-violet-500/20 text-violet-50"
          : "border-slate-500/70 bg-slate-800/60 text-slate-100"
      }`}
    >
      {children}
    </span>
  );

  const Check = () => (
    <svg
      viewBox="0 0 20 20"
      className="h-4 w-4 flex-none text-slate-300"
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

  const CardShell = ({ children, innerRef, id, highlight, accent }) => (
    <div
      id={id}
      ref={innerRef}
      className={`glass-card relative flex h-full flex-col ${
        highlight || accent
          ? "ring-1 ring-violet-400/28 shadow-[0_0_18px_rgba(124,58,237,0.14)]"
          : ""
      }`}
    >
      {children}
    </div>
  );

  const PlanCard = ({ plan, isFree = false, highlight, accent }) => {
    const active = activeByCode.get(plan.code);
    const buying = !!purchaseLoading[plan.id];
    const purchaseErr = purchaseErrors[plan.id];

    const lower = (plan.code || "").toLowerCase();
    const desc = isFree
      ? COPY.planDesc.free
      : lower.includes("elite")
      ? COPY.planDesc.elite
      : lower.includes("pro")
      ? COPY.planDesc.pro
      : COPY.planDesc.start;

    const durationDays = Number(plan.duration_days || 0);
    const durationLabel =
      durationDays >= 365
        ? (isRu ? "Годовой доступ" : "Annual access")
        : durationDays >= 180
        ? (isRu ? "Доступ на полгода" : "6-month access")
        : durationDays >= 90
        ? (isRu ? "Доступ на 3 месяца" : "3-month access")
        : durationDays >= 30
        ? (isRu ? "Доступ на месяц" : "1-month access")
        : isRu ? `Доступ на ${durationDays} дней` : `${durationDays}-day access`;
    const monthlyPrice =
      durationDays > 0 ? Math.round((num(plan.price) / durationDays) * 30) : null;
    const accentLabel =
      durationDays >= 180 ? (isRu ? "Лучшая цена" : "Best value") : durationDays >= 90 ? (isRu ? "Выгоднее месяца" : "Better than monthly") : null;

    return (
      <CardShell
        id={`plan-${lower || plan.id}`}
        innerRef={(node) => {
          if (node && lower) planRefs.current.set(lower.toUpperCase(), node);
        }}
        highlight={highlight}
        accent={accent}
      >
          <div className="flex h-full flex-col gap-5 p-5 sm:p-6">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
              <p className="text-[11px] uppercase tracking-[0.28em] text-slate-400">
                {isRu ? COPY.planHeader : "Plan"}
              </p>
              <h3 className="truncate text-2xl font-black tracking-tight text-slate-50">
                {plan.name}
              </h3>
              <p className="mt-2 min-h-[48px] text-sm leading-6 text-slate-200/85">
                {plan.description || desc}
              </p>
            </div>
            <div className="flex flex-col items-end gap-1">
              {accentLabel && <Badge tone="gray">{accentLabel}</Badge>}
              {active && <Badge tone="green">{isRu ? COPY.planBadges.active : "Active"}</Badge>}
            </div>
          </div>

          <div className="glass-card p-4 text-left">
            <div className="text-[30px] font-semibold tracking-tight text-white">
              {fmtPrice(plan.price)}
            </div>
            <div className="mt-1 text-sm text-slate-300">
              {durationLabel}
            </div>
            {monthlyPrice ? (
              <div className="mt-2 text-xs text-slate-400">
                {isRu ? "Около" : "About"} {monthlyPrice.toLocaleString("ru-RU")} ₽ {isRu ? "в месяц" : "per month"}
              </div>
            ) : null}
          </div>

          <div className="grid gap-2 text-[13px]">
            <Feature>{isRu ? "Все премиальные инсайты и аналитика" : "All premium insights and analytics"}</Feature>
            <Feature>{isRu ? "Подборки и расширенные карточки матчей" : "Best picks and extended match cards"}</Feature>
            <Feature>{isRu ? "Один и тот же функционал на любом платном сроке" : "The same feature set on every paid plan"}</Feature>
            {active?.end_at && (
              <div className="mt-1 rounded-xl border border-violet-400/25 bg-violet-500/10 px-3 py-2 text-xs font-semibold text-violet-100">
                {isRu ? "Активна до" : "Active until"}:{" "}
                <span>
                  {new Date(active.end_at).toLocaleDateString(isRu ? "ru-RU" : "en-GB")}
                </span>
              </div>
            )}
          </div>

          <div className="mt-auto pt-2">
            <button
              disabled={!!active || buying}
              onClick={() => handlePurchase(plan)}
              className={`h-11 w-full rounded-2xl text-sm font-semibold text-white transition
                ${
                  active || buying
                    ? "bg-slate-600/70 cursor-not-allowed"
                    : "border border-violet-400/24 bg-[linear-gradient(135deg,rgba(124,58,237,0.82),rgba(99,102,241,0.76))] shadow-[0_12px_24px_rgba(124,58,237,0.16),inset_0_1px_0_rgba(255,255,255,0.14)] hover:brightness-105"
                }`}
            >
              {active
                ? isFree
                  ? (isRu ? COPY.planBtn.connected : "Already connected")
                  : (isRu ? COPY.planBtn.purchased : "Already purchased")
                : buying
                ? isFree
                  ? (isRu ? "Подключаем…" : "Connecting…")
                  : (isRu ? "Оформление…" : "Purchasing…")
                : isFree
                ? (isRu ? COPY.planBtn.connect : "Connect")
                : (isRu ? COPY.planBtn.purchase : "Purchase")}
            </button>
            {purchaseErr && !active && (
              <div className="surface-error mt-2 px-3 py-2 text-[12px]">
                {purchaseErr}
              </div>
            )}
          </div>
        </div>
      </CardShell>
    );
  };

  /* ===== LOADING ===== */
  if (loading) {
    return (
      <div className="min-h-screen bg-surface-1 text-slate-50">
        <div className="mx-auto max-w-[1428px] w-full px-4 py-8 space-y-8">
          <div className="surface-hero h-[120px] animate-pulse" />
          <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
            {[...Array(3)].map((_, i) => (
              <div
                key={i}
                className="glass-card h-[320px] animate-pulse"
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
  const accentId = paid[Math.floor(paid.length / 2)]?.id;

  const scrollToPlans = () => {
    const node = document.getElementById("plans");
    if (node) node.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  /* ===== RENDER ===== */
  return (
    <div className="min-h-screen bg-surface-1 text-slate-50">
      <div className="mx-auto max-w-[1240px] w-full px-3 py-6 space-y-7 sm:px-4 sm:py-8 sm:space-y-8">
        {/* HEADER */}
        <section className="px-1 sm:px-2 md:px-4">
          <div className="grid gap-5 lg:grid-cols-[1.6fr_1fr]">
            <div className="panel rounded-3xl border border-glass bg-[radial-gradient(120%_120%_at_10%_0%,rgba(124,58,237,0.14),transparent_58%),radial-gradient(120%_120%_at_100%_0%,rgba(14,165,233,0.12),transparent_58%),rgba(15,18,26,0.62)] px-5 py-5 sm:px-6 sm:py-6">
              <div className="type-title-block">
              <div className="type-eyebrow">
                {COPY.heroBadge}
              </div>
              <h1 className="type-page-title">
                {isRu ? COPY.heroTitle : "EdgeScore subscriptions"}
              </h1>
              <p className="type-body max-w-[620px]">
                {isRu ? COPY.heroSubtitle : "One premium layer for analytics, insights, and picks. Only the duration and price change."}
              </p>
              <p className="type-caption">
                {leagueTitle} · {isRu ? "сезон" : "season"} {seasonTitle}
              </p>
              <p className="mt-3 text-sm text-slate-300">
                {isRu ? "После регистрации доступен пробный период 7 дней." : "A 7-day trial is available after registration."}
              </p>
              </div>
              <div className="mt-4 flex flex-wrap items-center gap-3">
                <button
                  onClick={scrollToPlans}
                  className="h-10 rounded-2xl border border-violet-400/24 bg-[linear-gradient(135deg,rgba(124,58,237,0.82),rgba(99,102,241,0.76))] px-5 text-sm font-semibold text-white shadow-[0_12px_24px_rgba(124,58,237,0.16),inset_0_1px_0_rgba(255,255,255,0.14)] transition hover:brightness-105"
                >
                  {isRu ? "Выбрать тариф" : "Choose a plan"}
                </button>
                <button
                  onClick={() => setCompareOpen(true)}
                  className="surface-button h-10 rounded-2xl px-5 text-sm font-semibold text-white/90 shadow-[0_10px_22px_rgba(0,0,0,0.18)]"
                >
                  {isRu ? "Сравнить" : "Compare"}
                </button>
              </div>
            </div>
            <div className="panel rounded-3xl bg-surface-2/68 px-5 py-5">
              <div className="text-[11px] uppercase tracking-[0.18em] text-muted">
                {isRu ? "Статус доступа" : "Access status"}
              </div>
              <div className="mt-3 flex items-center justify-between">
                <div className="text-lg font-semibold text-white">
                  {isAuthenticated ? (isRu ? ACCESS_STATUS_COPY.active.ru : ACCESS_STATUS_COPY.active.en) : (isRu ? ACCESS_STATUS_COPY.guest.ru : ACCESS_STATUS_COPY.guest.en)}
                </div>
                <span className="text-xs text-slate-400">
                  {isRu ? ACCESS_STATUS_COPY.updated.ru : ACCESS_STATUS_COPY.updated.en} {lastUpdated.toLocaleDateString(isRu ? "ru-RU" : "en-GB")}
                </span>
              </div>
              <div className="mt-3 text-sm text-slate-400 leading-relaxed">
                {isAuthenticated
                  ? (isRu ? "Доступ к расширенным функциям зависит от выбранного тарифа." : "Access to advanced features depends on your selected plan.")
                  : (isRu ? "Войдите, чтобы оформить подписку и открыть функции." : "Sign in to purchase a subscription and unlock features.")}
              </div>
              <div className="mt-4 text-sm text-slate-300">
                {isRu ? "Пробный период на 7 дней активируется после регистрации." : "The 7-day trial activates after registration."}
              </div>
            </div>
          </div>
        </section>

        {/* Баланс */}
        {isAuthenticated && (
        <section className="px-1 sm:px-2 md:px-4">
          <div className="panel rounded-3xl bg-surface-2/68 p-5 sm:p-6">
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div className="space-y-1">
                <div className="text-xs uppercase tracking-wide text-slate-400">
                  {isRu ? COPY.balanceTitle : "Your balance"}
                </div>
                <div className="text-2xl font-bold text-slate-50">
                  {balance.toLocaleString("ru-RU")} ₽
                </div>
                <div className="text-sm text-slate-400">
                  {isRu ? COPY.balanceHint : "Add balance before purchase to activate access immediately."}
                </div>
              </div>
              <button
                onClick={() => setAddFundsOpen(true)}
                className="h-10 rounded-2xl border border-violet-400/24 bg-[linear-gradient(135deg,rgba(124,58,237,0.82),rgba(99,102,241,0.76))] px-6 text-sm font-semibold text-white shadow-[0_12px_24px_rgba(124,58,237,0.16),inset_0_1px_0_rgba(255,255,255,0.14)] transition hover:brightness-105"
              >
                {isRu ? COPY.balanceBtn : "Add funds"}
              </button>
            </div>
          </div>
          </section>
        )}

        {success && (
          <div className="surface-success px-6 py-4 font-semibold">
            {success}
          </div>
        )}
        {error && (
          <div className="surface-error px-6 py-4 font-semibold">
            {error}
          </div>
        )}

        {/* Что входит */}
        <section className="space-y-4">
          <div className="px-1 sm:px-2 md:px-4">
            <div className="type-eyebrow">
              {isRu ? ACCESS_STATUS_COPY.features.ru : ACCESS_STATUS_COPY.features.en}
            </div>
            <div className="type-section-title">
              {isRu ? "Что входит в подписку" : "What is included"}
            </div>
          </div>
          <div className="grid gap-4 md:grid-cols-3">
            {VALUE_PILLARS.map((p) => (
              <div
                key={p.id}
                className="panel rounded-3xl bg-surface-2/68 p-5 sm:p-6"
              >
                <div className="text-xl text-slate-300">{p.icon}</div>
                <div className="mt-4 type-card-title">
                  {isRu ? p.title : VALUE_PILLARS_EN[p.id]?.title || p.title}
                </div>
                <p className="mt-2 type-body text-slate-200/80">
                  {isRu ? p.description : VALUE_PILLARS_EN[p.id]?.description || p.description}
                </p>
              </div>
            ))}
          </div>
        </section>

        {/* Планы */}
        <section id="plans" ref={plansRef} className="space-y-6">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <h2 className="type-section-title text-slate-50">
                {isRu ? COPY.plansTitle : "Access plans"}
              </h2>
              <p className="type-caption">
                {isRu ? COPY.plansSubtitle : "The feature set is the same. Only the access duration and value change."}
              </p>
            </div>
            {!!plans.length && (
              <div className="flex items-center gap-3 text-sm text-slate-400">
                <span className="inline-flex h-2 w-2 rounded-full bg-violet-400/80" />
                {isRu ? ACCESS_STATUS_COPY.updated.ru : ACCESS_STATUS_COPY.updated.en} {lastUpdated.toLocaleDateString(isRu ? "ru-RU" : "en-GB")}
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
                    highlight={highlightPlan === (p.code || "").toUpperCase()}
                  />
                ))}
            </div>
          )}

          {!paid.length && (
            <div className="surface-empty p-10 text-slate-200">
              {isRu ? "Планы подписок не найдены." : "No subscription plans found."}
              <div className="mt-4">
                <button
                  onClick={fetchPlans}
                  className="surface-button h-auto rounded-2xl px-4 py-2 text-sm font-semibold text-white hover:bg-surface-2"
                >
                  {isRu ? "Попробовать снова" : "Try again"}
                </button>
              </div>
            </div>
          )}
        </section>

      </div>

      {/* Модалки */}
      {addFundsOpen && (
        <AddFundsModal
          onClose={() => setAddFundsOpen(false)}
          onAdded={(amount) => {
            setBalance((b) => b + Number(amount || 0));
            setSuccess(isRu ? "Баланс пополнен." : "Balance added.");
            setTimeout(() => setSuccess(""), 2500);
          }}
          language={language}
        />
      )}

      {compareOpen && (
        <ComparePlansModal
          plans={plans}
          language={language}
          onClose={() => setCompareOpen(false)}
        />
      )}
    </div>
  );
}

export default SubscriptionsPage;

/* ===================== Add Funds Modal ===================== */
function AddFundsModal({ onClose, onAdded, language = "ru" }) {
  const isRu = language === "ru";
  const [amount, setAmount] = useState("100");
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState("");

  async function submit() {
    const val = Number(amount);
    if (!Number.isFinite(val) || val <= 0)
      return setErr(isRu ? "Введите корректную сумму." : "Enter a valid amount.");
    setErr("");
    setLoading(true);
    try {
      await http.post("/api/subscriptions/add-funds", {
        amount: val,
        reason: "manual_credit",
      });
      onAdded?.(val);
      onClose?.();
    } catch (e) {
      setErr(e?.data?.detail || (isRu ? "Не удалось пополнить баланс." : "Could not add funds."));
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
      <div className="surface-toolbar absolute left-1/2 top-20 w-[min(420px,92vw)] -translate-x-1/2 p-5 shadow-[0_18px_50px_rgba(0,0,0,0.45)]">
        <div className="mb-3 flex items-center justify-between">
          <div className="text-lg font-bold text-slate-100">
            {isRu ? "Пополнить баланс" : "Add funds"}
          </div>
          <button
            onClick={onClose}
            className="surface-button h-8 w-8 justify-center px-0 text-slate-200"
            title={isRu ? "Закрыть" : "Close"}
          >
            ×
          </button>
        </div>

        <label className="mb-1 block text-sm text-slate-400">
          {isRu ? "Сумма, ₽" : "Amount, ₽"}
        </label>
        <input
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          inputMode="numeric"
          className="surface-input w-full rounded-xl px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500"
          placeholder="100"
        />

        {err && (
          <div className="surface-error mt-3 px-3 py-2">
            {err}
          </div>
        )}

        <div className="mt-5 flex items-center justify-end gap-2">
          <button
            onClick={onClose}
            className="surface-button h-10 rounded-xl px-4 text-sm text-slate-100"
          >
            {isRu ? "Отмена" : "Cancel"}
          </button>
          <button
            onClick={submit}
            disabled={loading}
            className="h-10 rounded-xl border border-violet-400/24 bg-[linear-gradient(135deg,rgba(124,58,237,0.82),rgba(99,102,241,0.76))] px-4 text-sm font-semibold text-white shadow-[0_12px_24px_rgba(124,58,237,0.16)] hover:brightness-105 disabled:opacity-50"
          >
            {loading ? (isRu ? "Обработка…" : "Processing…") : (isRu ? "Пополнить" : "Add funds")}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ===================== Compare Plans Modal ===================== */
function ComparePlansModal({ plans, onClose, language = "ru" }) {
  const isRu = language === "ru";
  const paid = plans
    .filter((p) => Number(p.price) > 0)
    .sort((a, b) => Number(a.price) - Number(b.price));
  const cols = [...paid];

  const rows = [
    {
      key: "price",
      label: isRu ? COPY.tableParams[0] : "Price",
      fmt: (p) => `${Number(p).toLocaleString("ru-RU")} ₽`,
    },
    {
      key: "duration_days",
      label: isRu ? COPY.tableParams[1] : "Duration",
      fmt: (v) => isRu ? `${v} дней` : `${v} days`,
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
      <div className="surface-toolbar absolute left-1/2 top-16 w-[min(980px,96vw)] -translate-x-1/2 shadow-[0_18px_50px_rgba(0,0,0,0.45)]">
        <div className="flex items-center justify-between p-4">
          <div className="text-lg font-bold text-slate-100">
            {isRu ? COPY.compareTitle : "Compare plans"}
          </div>
          <button
            onClick={onClose}
            className="surface-button h-9 rounded-xl px-3 text-sm text-slate-200"
          >
            {isRu ? COPY.compareClose : "Close"}
          </button>
        </div>
        <div className="px-4 -mt-1 pb-2 text-xs text-slate-400">
          {isRu ? "Сравнение планов: лимиты, доступные функции и частота обновлений." : "Plan comparison: limits, available features, and update frequency."}
        </div>
        <div className="overflow-auto px-4 pb-5">
          <table className="w-full border-separate border-spacing-y-2">
            <thead>
              <tr>
                <th className="w-44 rounded-l-lg bg-surface-2/80 p-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-300">
                  {isRu ? "Параметр" : "Parameter"}
                </th>
                {cols.map((c) => (
                  <th
                    key={c.id}
                    className="rounded-lg bg-surface-2/80 p-3 text-left text-sm font-bold text-slate-100"
                  >
                    {c.name}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.key}>
                  <td className="rounded-l-lg bg-surface-2/60 p-3 text-sm text-slate-300">
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
                        className={`rounded-lg bg-surface-2/60 p-3 text-sm ${
                          highlight
                            ? "font-semibold text-emerald-300"
                            : "text-slate-100"
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
