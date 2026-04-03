// src/pages/SubscriptionsPage.jsx
// EdgeScore Premium Subscriptions — тёмная премиальная страница без дублирующей шапки лиг.

import React, { useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { http } from "../lib/http.js";

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

/* ===================== Вспомогательные компоненты ===================== */
/* ===================== Основной компонент ===================== */
function SubscriptionsPage() {
  const { isAuthenticated } = useAuth();
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

  const num = (v) => Number(v ?? 0);
  const fmtPrice = (p) =>
    num(p) === 0 ? "Бесплатно" : `${num(p).toLocaleString("ru-RU")} ₽`;

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
        "Не удалось загрузить планы подписок. Попробуйте ещё раз чуть позже."
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
      setError("Для оформления подписки войдите в систему.");
      setPurchaseErrors((m) => ({ ...m, [plan.id]: "Нужно войти в систему." }));
      window.scrollTo({ top: 0, behavior: "smooth" });
      return;
    }
    if (activeByCode.has(plan.code))
      return setError("У вас уже активна эта подписка.");

    setPurchaseLoading((m) => ({ ...m, [plan.id]: true }));
    setPurchaseErrors((m) => ({ ...m, [plan.id]: "" }));
    setError("");
    setSuccess("");

    try {
      await http.post(
        "/api/subscriptions/purchase",
        { plan_code: plan.code }
      );
      setSuccess(`Подписка «${plan.name}» успешно оформлена.`);
      setPurchaseErrors((m) => ({ ...m, [plan.id]: "" }));
      await Promise.all([fetchMe(), fetchPlans()]);
      setTimeout(() => setSuccess(""), 3500);
    } catch (e) {
      const status = e?.status;
      const msg =
        e?.data?.detail ||
        e?.message ||
        "Ошибка при оформлении подписки.";
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
      className={`relative flex h-full flex-col rounded-2xl border border-glass bg-surface-2/80 shadow-[0_12px_30px_rgba(0,0,0,0.35)] ${
        highlight || accent
          ? "ring-1 ring-violet-400/40 shadow-[0_0_24px_rgba(124,58,237,0.25)]"
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
        ? "Годовой доступ"
        : durationDays >= 180
        ? "Доступ на полгода"
        : durationDays >= 90
        ? "Доступ на 3 месяца"
        : durationDays >= 30
        ? "Доступ на месяц"
        : `Доступ на ${durationDays} дней`;
    const monthlyPrice =
      durationDays > 0 ? Math.round((num(plan.price) / durationDays) * 30) : null;
    const accentLabel =
      durationDays >= 180 ? "Лучшая цена" : durationDays >= 90 ? "Выгоднее месяца" : null;

    return (
      <CardShell
        id={`plan-${lower || plan.id}`}
        innerRef={(node) => {
          if (node && lower) planRefs.current.set(lower.toUpperCase(), node);
        }}
        highlight={highlight}
        accent={accent}
      >
          <div className="flex h-full flex-col gap-5 p-6">
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
              {accentLabel && <Badge tone="gray">{accentLabel}</Badge>}
              {active && <Badge tone="green">{COPY.planBadges.active}</Badge>}
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
                Около {monthlyPrice.toLocaleString("ru-RU")} ₽ в месяц
              </div>
            ) : null}
          </div>

          <div className="grid gap-2 text-[13px]">
            <Feature>Все премиальные инсайты и аналитика</Feature>
            <Feature>Подборки и расширенные карточки матчей</Feature>
            <Feature>Один и тот же функционал на любом платном сроке</Feature>
            {active?.end_at && (
              <div className="mt-1 rounded-xl border border-violet-400/25 bg-violet-500/10 px-3 py-2 text-xs font-semibold text-violet-100">
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
              className={`h-11 w-full rounded-2xl text-sm font-semibold text-white transition
                ${
                  active || buying
                    ? "bg-slate-600 cursor-not-allowed"
                    : "border border-violet-400/35 bg-[linear-gradient(135deg,rgba(124,58,237,0.9),rgba(99,102,241,0.82))] shadow-[0_14px_34px_rgba(124,58,237,0.24),inset_0_1px_0_rgba(255,255,255,0.18)] hover:brightness-110"
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
            {purchaseErr && !active && (
              <div className="mt-2 rounded-xl border border-rose-400/40 bg-rose-500/10 px-3 py-2 text-[12px] text-rose-100">
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
          <div className="h-[120px] animate-pulse rounded-[18px] bg-surface-2/90 border border-white/10" />
          <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
            {[...Array(3)].map((_, i) => (
              <div
                key={i}
                className="h-[320px] animate-pulse rounded-2xl border border-white/10 bg-surface-2/80"
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
      <div className="mx-auto max-w-[1240px] w-full px-4 py-8 space-y-8">
        {/* HEADER */}
        <section className="px-2 md:px-4">
          <div className="grid gap-5 lg:grid-cols-[1.6fr_1fr]">
            <div className="panel rounded-2xl border border-glass px-6 py-6 bg-[radial-gradient(120%_120%_at_10%_0%,rgba(124,58,237,0.18),transparent_60%),radial-gradient(120%_120%_at_100%_0%,rgba(14,165,233,0.16),transparent_60%),rgba(15,18,26,0.65)]">
              <div className="type-title-block">
              <div className="type-eyebrow">
                {COPY.heroBadge}
              </div>
              <h1 className="type-page-title">
                {COPY.heroTitle}
              </h1>
              <p className="type-body max-w-[620px]">
                {COPY.heroSubtitle}
              </p>
              <p className="type-caption">
                {leagueTitle} · сезон {seasonTitle}
              </p>
              <p className="mt-3 text-sm text-slate-300">
                После регистрации доступен пробный период 7 дней.
              </p>
              </div>
              <div className="mt-4 flex items-center gap-3">
                <button
                  onClick={scrollToPlans}
                  className="h-10 rounded-2xl border border-violet-400/35 bg-[linear-gradient(135deg,rgba(124,58,237,0.92),rgba(99,102,241,0.88))] px-5 text-sm font-semibold text-white shadow-[0_14px_34px_rgba(124,58,237,0.24),inset_0_1px_0_rgba(255,255,255,0.18)] transition hover:brightness-110"
                >
                  Выбрать тариф
                </button>
                <button
                  onClick={() => setCompareOpen(true)}
                  className="h-10 rounded-2xl border border-glass bg-surface-2/80 px-5 text-sm font-semibold text-white/90 shadow-[0_10px_26px_rgba(0,0,0,0.22),inset_0_1px_0_rgba(255,255,255,0.12)] transition hover:bg-surface-2"
                >
                  Сравнить
                </button>
              </div>
            </div>
            <div className="panel bg-surface-2/70 rounded-2xl border border-glass px-5 py-5">
              <div className="text-[11px] uppercase tracking-[0.18em] text-muted">
                Статус доступа
              </div>
              <div className="mt-3 flex items-center justify-between">
                <div className="text-lg font-semibold text-white">
                  {isAuthenticated ? "Активен" : "Гость"}
                </div>
                <span className="text-xs text-slate-400">
                  {COPY.updated} {lastUpdated.toLocaleDateString("ru-RU")}
                </span>
              </div>
              <div className="mt-3 text-sm text-slate-400 leading-relaxed">
                {isAuthenticated
                  ? "Доступ к расширенным функциям зависит от выбранного тарифа."
                  : "Войдите, чтобы оформить подписку и открыть функции."}
              </div>
              <div className="mt-4 text-sm text-slate-300">
                Пробный период на 7 дней активируется после регистрации.
              </div>
            </div>
          </div>
        </section>

        {/* Баланс */}
        {isAuthenticated && (
        <section className="px-2 md:px-4">
          <div className="panel bg-surface-2/70 rounded-2xl border border-glass p-6">
            <div className="flex flex-wrap items-center justify-between gap-4">
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
                className="h-10 rounded-2xl border border-violet-400/35 bg-[linear-gradient(135deg,rgba(124,58,237,0.9),rgba(99,102,241,0.82))] px-6 text-sm font-semibold text-white shadow-[0_14px_34px_rgba(124,58,237,0.24),inset_0_1px_0_rgba(255,255,255,0.18)] transition hover:brightness-110"
              >
                {COPY.balanceBtn}
              </button>
            </div>
          </div>
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

        {/* Что входит */}
        <section className="space-y-4">
          <div className="px-2 md:px-4">
            <div className="type-eyebrow">
              ВОЗМОЖНОСТИ
            </div>
            <div className="type-section-title">
              Что входит в подписку
            </div>
          </div>
          <div className="grid gap-4 md:grid-cols-3">
            {VALUE_PILLARS.map((p) => (
              <div
                key={p.id}
                className="panel bg-surface-2/70 rounded-2xl border border-glass p-6"
              >
                <div className="text-xl text-slate-300">{p.icon}</div>
                <div className="mt-4 type-card-title">{p.title}</div>
                <p className="mt-2 type-body text-slate-200/80">
                  {p.description}
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
                {COPY.plansTitle}
              </h2>
              <p className="type-caption">
                {COPY.plansSubtitle}
              </p>
            </div>
            {!!plans.length && (
              <div className="flex items-center gap-3 text-sm text-slate-400">
                <span className="inline-flex h-2 w-2 rounded-full bg-violet-400/80" />
                Обновлено {lastUpdated.toLocaleDateString("ru-RU")}
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
            <div className="rounded-2xl border border-white/10 bg-surface-2/90 p-10 text-center text-slate-200">
              Планы подписок не найдены.
              <div className="mt-4">
                <button
                  onClick={fetchPlans}
                  className="rounded-2xl border border-white/10 bg-surface-2/90 px-4 py-2 text-sm font-semibold text-white hover:bg-surface-2"
                >
                  Попробовать снова
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
      await http.post("/api/subscriptions/add-funds", {
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
      <div className="absolute left-1/2 top-20 w-[min(420px,92vw)] -translate-x-1/2 rounded-2xl border border-glass bg-surface-1/95 p-5 shadow-2xl">
        <div className="mb-3 flex items-center justify-between">
          <div className="text-lg font-bold text-slate-100">
            Пополнить баланс
          </div>
          <button
            onClick={onClose}
            className="h-8 w-8 rounded-full border border-glass bg-surface-2 text-slate-200 hover:bg-surface-1/80"
            title="Закрыть"
          >
            ×
          </button>
        </div>

        <label className="mb-1 block text-sm text-slate-400">
          Сумма, ₽
        </label>
        <input
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          inputMode="numeric"
          className="w-full rounded-xl border border-glass bg-surface-2 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/40"
          placeholder="100"
        />

        {err && (
          <div className="mt-3 rounded-md border border-rose-400/50 bg-rose-500/15 px-3 py-2 text-sm text-rose-100">
            {err}
          </div>
        )}

        <div className="mt-5 flex items-center justify-end gap-2">
          <button
            onClick={onClose}
            className="h-10 rounded-xl border border-glass px-4 text-sm text-slate-100 hover:bg-surface-2/80"
          >
            Отмена
          </button>
          <button
            onClick={submit}
            disabled={loading}
            className="h-10 rounded-xl border border-primary/40 bg-primary/80 px-4 text-sm font-semibold text-white hover:bg-primary disabled:opacity-50"
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
  const cols = [...paid];

  const rows = [
    {
      key: "price",
      label: COPY.tableParams[0],
      fmt: (p) => `${Number(p).toLocaleString("ru-RU")} ₽`,
    },
    {
      key: "duration_days",
      label: COPY.tableParams[1],
      fmt: (v) => `${v} дней`,
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
      <div className="absolute left-1/2 top-16 w-[min(980px,96vw)] -translate-x-1/2 rounded-2xl border border-glass bg-surface-1/95 shadow-2xl">
        <div className="flex items-center justify-between p-4">
          <div className="text-lg font-bold text-slate-100">
            {COPY.compareTitle}
          </div>
          <button
            onClick={onClose}
            className="h-9 rounded-xl border border-glass bg-surface-2 px-3 text-sm text-slate-200 hover:bg-surface-1/80"
          >
            {COPY.compareClose}
          </button>
        </div>
        <div className="px-4 -mt-1 pb-2 text-xs text-slate-400">
          Сравнение планов: лимиты, доступные функции и частота обновлений.
        </div>
        <div className="overflow-auto px-4 pb-5">
          <table className="w-full border-separate border-spacing-y-2">
            <thead>
              <tr>
                <th className="w-44 rounded-l-lg bg-surface-2/80 p-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-300">
                  Параметр
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
