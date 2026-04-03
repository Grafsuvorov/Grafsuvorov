import { useState, useEffect, useMemo, useRef } from "react";
import { useAuth } from "@/auth/AuthContext.jsx";
import { useNavigate, useSearchParams } from "react-router-dom";
import { http } from "@/lib/http.js";
import SafeImg from "@/components/SafeImg";
import { loadFavorites, saveFavorites } from "@/lib/favoritesStorage.js";
import SegmentedTabs from "@/components/ui/SegmentedTabs";
import { hasPilotFullAccess, shouldHideMonetization } from "@/lib/pilotAccess.js";

const teamLogo = (id) => `/icons/team_logos/${id}.png`;
const playerPhoto = (id) => `/icons/player_photos/${id}.png`;

const emitFavUpdate = () => {
  try {
    window.dispatchEvent(new CustomEvent("favorites:update"));
  } catch {}
};

const formatDate = (value) => {
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(+d)) return "—";
  return d.toLocaleDateString("ru-RU");
};
const formatBalance = (value) => {
  const n = Number(String(value ?? "").replace(",", "."));
  if (Number.isNaN(n)) return "0";
  return String(Math.round(n));
};

function FavoriteCard({ type, item, onOpen, onRemove }) {
  const title = item?.name || item?.title || "Без названия";
  const subtitle = item?.league ? `${item.league} · ${item.season || ""}` : item?.team || "";

  return (
    <div className="glass-card p-4">
      <div className="flex items-center gap-3">
        <div className="h-12 w-12 rounded-2xl border border-glass bg-surface-1/70 grid place-items-center">
          {type === "team" ? (
            <SafeImg src={teamLogo(item.id)} className="h-8 w-8 object-contain" alt="" fallback="team" />
          ) : (
            <SafeImg src={playerPhoto(item.id)} className="h-9 w-9 rounded-xl object-cover" alt="" fallback="player" />
          )}
        </div>
        <div className="min-w-0 flex-1">
          <div className="text-sm font-semibold text-white leading-tight break-words">{title}</div>
          <div className="text-xs text-slate-400 truncate">{subtitle || "—"}</div>
        </div>
      </div>
      <div className="mt-3 flex items-center gap-3">
        <button onClick={onOpen} className="text-sm font-medium text-violet-300 transition hover:text-violet-200">
          Перейти в карточку
        </button>
        <button
          onClick={() => {
            if (window.confirm("Удалить из избранного?")) onRemove();
          }}
          className="text-sm font-medium text-slate-400 transition hover:text-white"
        >
          Удалить
        </button>
      </div>
    </div>
  );
}

export default function ProfilePagePremium() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const hideMonetization = shouldHideMonetization();
  const pilotFullAccess = hasPilotFullAccess(user);
  const [searchParams, setSearchParams] = useSearchParams();
  const requestedTab = searchParams.get("tab") || "overview";
  const initialTab =
    hideMonetization && requestedTab === "subscriptions" ? "overview" : requestedTab;
  const [activeTab, setActiveTab] = useState(initialTab);
  const [userSubscriptions, setUserSubscriptions] = useState([]);
  const [userBalance, setUserBalance] = useState("0.00");
  const [subscriptionsLoading, setSubscriptionsLoading] = useState(true);
  const [plansLoading, setPlansLoading] = useState(true);
  const [plans, setPlans] = useState([]);
  const [purchaseLoading, setPurchaseLoading] = useState({});
  const [purchaseErrors, setPurchaseErrors] = useState({});
  const [addFundsOpen, setAddFundsOpen] = useState(false);
  const [addFundsError, setAddFundsError] = useState("");
  const [highlightPlan, setHighlightPlan] = useState("");
  const plansRef = useRef(null);
  const planRefs = useRef(new Map());

  const [favTeams, setFavTeams] = useState(() => loadFavorites("favorites_teams"));
  const [favPlayers, setFavPlayers] = useState(() => loadFavorites("favorites_players"));

  useEffect(() => {
    if (hideMonetization) {
      setSubscriptionsLoading(false);
      return;
    }
    if (user) fetchUserSubscriptions();
  }, [hideMonetization, user]);

  useEffect(() => {
    if (hideMonetization) {
      setPlansLoading(false);
      return;
    }
    fetchPlans();
  }, [hideMonetization]);

  useEffect(() => {
    const sync = () => {
      setFavTeams(loadFavorites("favorites_teams"));
      setFavPlayers(loadFavorites("favorites_players"));
    };
    window.addEventListener("storage", sync);
    window.addEventListener("favorites:update", sync);
    window.addEventListener("focus", sync);
    const onVisibility = () => {
      if (document.visibilityState === "visible") sync();
    };
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      window.removeEventListener("storage", sync);
      window.removeEventListener("favorites:update", sync);
      window.removeEventListener("focus", sync);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, []);

  useEffect(() => {
    if (activeTab === "favorites") {
      setFavTeams(loadFavorites("favorites_teams"));
      setFavPlayers(loadFavorites("favorites_players"));
    }
  }, [activeTab]);

  useEffect(() => {
    const tab = searchParams.get("tab");
    if (!tab) return;
    const nextTab = hideMonetization && tab === "subscriptions" ? "overview" : tab;
    if (nextTab !== activeTab) setActiveTab(nextTab);
  }, [searchParams, activeTab, hideMonetization]);

  const goTab = (tab) => {
    setActiveTab(tab);
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev);
      next.set("tab", tab);
      return next;
    }, { replace: true });
  };

  const scrollToPlans = (code) => {
    goTab("subscriptions");
    setTimeout(() => {
      const node =
        (code && planRefs.current.get(String(code).toUpperCase())) ||
        plansRef.current;
      if (node) node.scrollIntoView({ behavior: "smooth", block: "start" });
      if (code) setHighlightPlan(String(code).toUpperCase());
    }, 0);
  };

  const fetchUserSubscriptions = async () => {
    try {
      setSubscriptionsLoading(true);
      const response = await http.get("/api/subscriptions/me");
      const userData = response.data || response.json || {};
      setUserBalance(userData.balance || "0.00");
      setUserSubscriptions(userData.active_subscriptions || []);
    } catch (err) {
      console.error("Error fetching user subscriptions:", err);
    } finally {
      setSubscriptionsLoading(false);
    }
  };

  const fetchPlans = async () => {
    try {
      setPlansLoading(true);
      const res = await http.get("/api/subscriptions/plans");
      const data = Array.isArray(res) ? res : res?.data || [];
      setPlans(data);
    } catch (err) {
      console.error("Error fetching plans:", err);
      setPlans([]);
    } finally {
      setPlansLoading(false);
    }
  };

  const handlePurchase = async (plan) => {
    try {
      setPurchaseErrors((m) => ({ ...m, [plan.id]: "" }));
      setPurchaseLoading((m) => ({ ...m, [plan.id]: true }));
      await http.post("/api/subscriptions/purchase", {
        plan_id: plan.id,
      });
      await fetchUserSubscriptions();
    } catch (err) {
      if (err?.status === 402) {
        setAddFundsOpen(true);
        setAddFundsError(
          err?.data?.detail || "Недостаточно средств. Пополните баланс."
        );
      }
      const msg =
        err?.data?.detail ||
        err?.message ||
        "Не удалось оформить подписку.";
      setPurchaseErrors((m) => ({ ...m, [plan.id]: msg }));
    } finally {
      setPurchaseLoading((m) => ({ ...m, [plan.id]: false }));
    }
  };

  const stats = useMemo(
    () => [
      { label: "Избранные команды", value: favTeams.length },
      { label: "Избранные игроки", value: favPlayers.length },
      ...(!hideMonetization
        ? [{ label: "Активных подписок", value: userSubscriptions.length }]
        : []),
    ],
    [favTeams.length, favPlayers.length, hideMonetization, userSubscriptions.length]
  );

  const nextEndAt = useMemo(() => {
    if (!userSubscriptions.length) return null;
    const active = userSubscriptions
      .filter((s) => s?.end_at)
      .map((s) => new Date(s.end_at))
      .filter((d) => !Number.isNaN(+d));
    if (!active.length) return null;
    active.sort((a, b) => a - b);
    return active[0];
  }, [userSubscriptions]);

  const activeSub = useMemo(() => {
    const now = new Date();
    const active = userSubscriptions.filter((s) => {
      const end = s?.end_at ? new Date(s.end_at) : null;
      return end && !Number.isNaN(+end) && end > now;
    });
    if (!active.length) return null;
    const priority = { ELITE: 3, PRO: 2, START: 1 };
    return active
      .slice()
      .sort((a, b) => {
        const pa = priority[(a.plan_code || "").toUpperCase()] || 0;
        const pb = priority[(b.plan_code || "").toUpperCase()] || 0;
        return pb - pa;
      })[0];
  }, [userSubscriptions]);

  const activeCode = (activeSub?.plan_code || "").toUpperCase();
  const hasActiveSubscription = hideMonetization ? pilotFullAccess : !!activeSub;
  const isStartPlan = activeCode === "START";
  const hasPremium = useMemo(() => hasActiveSubscription, [hasActiveSubscription]);
  const statusLine = hideMonetization
    ? `${favTeams.length} команды · ${favPlayers.length} игрока в избранном`
    : `Статус: ${hasActiveSubscription ? activeCode : "Без подписки"} · ${favTeams.length} команды · ${favPlayers.length} игрока`;

  const activeByCode = useMemo(() => {
    const map = new Map();
    userSubscriptions.forEach((s) => {
      if (s?.is_active) map.set(String(s.plan_code || "").toUpperCase(), s);
    });
    return map;
  }, [userSubscriptions]);

  const paidPlans = useMemo(
    () => plans.filter((p) => Number(p.price) > 0).sort((a, b) => Number(a.price) - Number(b.price)),
    [plans]
  );
  const freePlans = useMemo(
    () => plans.filter((p) => Number(p.price) === 0),
    [plans]
  );
  const renderOverview = () => (
    <div className="grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
      <div className="rounded-3xl border border-glass bg-surface-2/70 p-6 shadow-[0_18px_60px_rgba(0,0,0,0.45)] backdrop-blur">
        <div className="flex items-center gap-4">
          <div
            className={`h-[88px] w-[88px] rounded-3xl border border-glass bg-surface-2/80 grid place-items-center text-3xl font-bold text-white shadow-sm ${
              user?.is_verified ? "shadow-[0_0_24px_rgba(16,185,129,0.25)]" : ""
            }`}
          >
            {user?.username?.charAt(0).toUpperCase()}
          </div>
          <div className="min-w-0">
            <div className="text-2xl font-semibold text-white truncate">{user?.username}</div>
            <div className="text-sm text-slate-500 truncate">{user?.email}</div>
            <div className="mt-2 inline-flex items-center gap-2">
              {user?.is_verified ? (
                <span
                  className="inline-flex h-7 w-7 items-center justify-center rounded-full border border-violet-400/40 bg-violet-400/10 text-violet-200"
                  title="Email подтверждён"
                >
                  ✓
                </span>
              ) : (
                <span
                  className="inline-flex h-7 w-7 items-center justify-center rounded-full border border-cyan-400/40 bg-cyan-400/10 text-cyan-200"
                  title="Нужно подтвердить email"
                >
                  !
                </span>
              )}
            </div>
            <div className="mt-2 text-sm text-slate-400">{statusLine}</div>
          </div>
        </div>

        <div className="mt-6">
          <div className="grid gap-4 md:grid-cols-2">
            <div className="glass-card p-4">
              <div className="text-[11px] uppercase tracking-[0.18em] text-slate-400">Избранное</div>
              <div className="mt-3 text-3xl font-semibold text-white">
                {favTeams.length + favPlayers.length}
              </div>
              <div className="mt-1 text-sm text-slate-400">
                {favTeams.length} команды · {favPlayers.length} игрока
              </div>
              <button
                onClick={() => setActiveTab("favorites")}
                className="mt-3 text-sm font-medium text-violet-300 transition hover:text-violet-200"
              >
                Перейти в избранное
              </button>
            </div>

            {hideMonetization ? (
              <div className="glass-card p-4">
                <div className="text-[11px] uppercase tracking-[0.18em] text-slate-400">Активность</div>
                <div className="mt-3 text-3xl font-semibold text-white">
                  {user?.created_at ? new Date(user.created_at).toLocaleDateString("ru-RU") : "—"}
                </div>
                <div className="mt-1 text-sm text-slate-400">Дата регистрации в EdgeScore.</div>
              </div>
            ) : (
              <div className="glass-card p-4">
                <div className="flex items-center gap-2 text-[11px] uppercase tracking-[0.18em] text-slate-400">
                  Баланс счёта
                  <span
                    className="inline-flex h-4 w-4 items-center justify-center rounded-full border border-glass text-[10px] text-slate-400"
                    title="Используется для оплаты подписок"
                  >
                    i
                  </span>
                </div>
                <div className="mt-3 text-[34px] font-semibold text-white">
                  {formatBalance(userBalance)} ₽
                </div>
                <button
                  onClick={() => setAddFundsOpen(true)}
                  className="mt-3 inline-flex items-center rounded-2xl border border-violet-400/35 bg-[linear-gradient(135deg,rgba(124,58,237,0.9),rgba(99,102,241,0.82))] px-4 py-2 text-xs font-semibold text-white shadow-[0_14px_34px_rgba(124,58,237,0.24),inset_0_1px_0_rgba(255,255,255,0.18)] transition hover:brightness-110"
                >
                  Пополнить
                </button>
              </div>
            )}
          </div>
        </div>

      </div>

      <div className="space-y-4">
        <div className="relative overflow-hidden rounded-3xl border border-glass bg-surface-2/80 p-6 shadow-[0_14px_45px_rgba(0,0,0,0.4)]">
          <div className="pointer-events-none absolute -right-20 -top-16 h-48 w-48 rounded-full bg-violet-500/10 blur-3xl" />
          <div className="text-base font-semibold text-white">Инсайты EdgeScore</div>
          <div className="mt-2 text-sm leading-6 text-slate-300">
            Получайте объяснения прогнозов и факторов.
          </div>
          <button
            onClick={() => navigate("/insights")}
            className="mt-4 rounded-2xl border border-violet-400/35 bg-[linear-gradient(135deg,rgba(124,58,237,0.9),rgba(99,102,241,0.82))] px-4 py-2 text-xs font-semibold text-white shadow-[0_14px_34px_rgba(124,58,237,0.24),inset_0_1px_0_rgba(255,255,255,0.18)] transition hover:brightness-110"
          >
            Открыть инсайты
          </button>
        </div>

      <div className="rounded-3xl border border-glass bg-surface-2/70 p-6">
        <div className="text-base font-semibold text-white">Быстрые переходы</div>
        <div className="mt-4 grid gap-3">
            <button
              onClick={() => navigate("/matches-v3")}
              className="group flex items-center justify-between rounded-2xl border border-glass bg-surface-2/70 px-4 py-3 text-left text-sm text-slate-200 shadow-[0_10px_26px_rgba(0,0,0,0.2),inset_0_1px_0_rgba(255,255,255,0.12)] transition hover:border-white/25 hover:bg-surface-2"
            >
              <span className="flex items-center gap-2">
                <span className="text-lg text-slate-400">🏁</span>
                Результаты матчей
              </span>
              <span className="text-slate-500 group-hover:text-slate-200">→</span>
            </button>
            <button
              onClick={() => navigate("/schedule")}
              className="group flex items-center justify-between rounded-2xl border border-glass bg-surface-2/70 px-4 py-3 text-left text-sm text-slate-200 shadow-[0_10px_26px_rgba(0,0,0,0.2),inset_0_1px_0_rgba(255,255,255,0.12)] transition hover:border-white/25 hover:bg-surface-2"
            >
              <span className="flex items-center gap-2">
                <span className="text-lg text-slate-400">🗓️</span>
                Календарь и прогнозы
              </span>
              <span className="text-slate-500 group-hover:text-slate-200">→</span>
            </button>
              <button
                onClick={() => navigate("/best-picks")}
                className="group flex items-center justify-between rounded-2xl border border-glass bg-surface-2/70 px-4 py-3 text-left text-sm text-slate-200 shadow-[0_10px_26px_rgba(0,0,0,0.2),inset_0_1px_0_rgba(255,255,255,0.12)] transition hover:border-white/25 hover:bg-surface-2"
              >
                <span className="flex items-center gap-2">
                  <span className="text-lg text-slate-400">✨</span>
                  Подборки и лучшие ставки
                </span>
                <span className="text-slate-500 group-hover:text-slate-200">→</span>
              </button>
              <button
                onClick={() => navigate("/about")}
                className="group flex items-center justify-between rounded-2xl border border-glass bg-surface-2/70 px-4 py-3 text-left text-sm text-slate-200 shadow-[0_10px_26px_rgba(0,0,0,0.2),inset_0_1px_0_rgba(255,255,255,0.12)] transition hover:border-white/25 hover:bg-surface-2"
              >
                <span className="flex items-center gap-2">
                  <span className="text-lg text-slate-400">ℹ️</span>
                  О проекте и контакты
                </span>
                <span className="text-slate-500 group-hover:text-slate-200">→</span>
              </button>
          </div>
        </div>

      </div>
    </div>
  );

  const renderFavorites = () => (
    <div className="space-y-6">
      <div className="rounded-3xl border border-glass bg-surface-1/80 p-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <div className="text-[11px] uppercase tracking-[0.18em] text-slate-400">Избранное</div>
            <div className="mt-2 text-xl font-semibold text-white">Команды и игроки</div>
            <div className="mt-1 text-sm leading-6 text-slate-400">Команды и игроки, которые всегда под рукой.</div>
          </div>
          <div className="flex gap-2">
            <button onClick={() => navigate("/schedule")} className="btn-glass text-xs">
              Календарь избранных
            </button>
            <button onClick={() => navigate("/matches-v3")} className="btn-glass text-xs">
              Результаты избранных
            </button>
          </div>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <div className="space-y-4">
          <div className="text-sm font-semibold text-white">Команды</div>
          {favTeams.length ? (
            <div className="grid gap-3">
              {favTeams.map((t) => (
                <FavoriteCard
                  key={`team-${t.id}`}
                  type="team"
                  item={t}
                  onOpen={() => navigate(`/team/${t.id}?league=${encodeURIComponent(t.league || "Premier League")}&season=${t.season || "2025"}`)}
                  onRemove={() => {
                    const next = favTeams.filter((x) => x.id !== t.id);
                    setFavTeams(next);
                    saveFavorites("favorites_teams", next);
                    emitFavUpdate();
                  }}
                />
              ))}
            </div>
          ) : (
            <div className="rounded-2xl border border-glass bg-surface-1/70 p-6 text-sm text-slate-400">
              Вы ещё не добавили команды в избранное.
              Добавляйте команды и следите за их формой и результатами.
            </div>
          )}
        </div>

        <div className="space-y-4">
          <div className="text-sm font-semibold text-white">Игроки</div>
          {favPlayers.length ? (
            <div className="grid gap-3">
              {favPlayers.map((p) => (
                <FavoriteCard
                  key={`player-${p.id}`}
                  type="player"
                  item={p}
                  onOpen={() => navigate(`/player/${p.id}?league=${encodeURIComponent(p.league || "Premier League")}&season=${p.season || "2025"}`)}
                  onRemove={() => {
                    const next = favPlayers.filter((x) => x.id !== p.id);
                    setFavPlayers(next);
                    saveFavorites("favorites_players", next);
                    emitFavUpdate();
                  }}
                />
              ))}
            </div>
          ) : (
            <div className="rounded-2xl border border-glass bg-surface-1/70 p-6 text-sm text-slate-400">
              Вы ещё не добавили игроков в избранное.
              Добавляйте игроков и следите за их формой и результатами.
            </div>
          )}
        </div>
      </div>
    </div>
  );

  const renderSubscriptions = () => (
    <div className="space-y-6">
      <div className="rounded-3xl border border-glass bg-surface-2/80 p-6 shadow-[0_18px_60px_rgba(0,0,0,0.45)]">
        <div className="text-[11px] uppercase tracking-[0.18em] text-slate-400">Подписки</div>
        <div className="mt-2 text-xl font-semibold text-white">Управление доступом</div>
        <div className="mt-1 text-sm leading-6 text-slate-300">
          Доступ к аналитике матчей, оценке value и расширенным метрикам.
        </div>
      </div>

      {subscriptionsLoading ? (
        <div className="rounded-3xl border border-glass bg-surface-1/70 p-10 text-center text-slate-400">
          Загрузка подписок…
        </div>
      ) : userSubscriptions.length > 0 ? (
        <div className="grid gap-4">
          {userSubscriptions.map((sub) => (
            <div key={sub.id} className="rounded-3xl border border-glass bg-surface-1/80 p-6">
              {(() => {
                const end = sub?.end_at ? new Date(sub.end_at) : null;
                const now = new Date();
                let status = "активна";
                if (!end || Number.isNaN(+end)) status = "активна";
                else if (end < now) status = "истекла";
                else if ((end - now) / 86400000 <= 7) status = "истекает";
                return (
                  <div className="mb-3 text-xs uppercase tracking-[0.2em] text-slate-400">
                    Статус: {status}
                  </div>
                );
              })()}
              <div className="flex flex-wrap items-center justify-between gap-4">
                <div>
                  <div className="text-lg font-semibold text-white">{sub.plan_name}</div>
                  <div className="text-sm text-slate-400">Код: {sub.plan_code}</div>
                  <div className="mt-2 text-xs text-slate-400">
                    Цена при покупке: {sub.price_at_purchase ?? "—"} ₽
                  </div>
                  <div className="mt-3 text-sm text-slate-300">
                    {plans.find((p) => String(p.code || "").toUpperCase() === String(sub.plan_code || "").toUpperCase())?.description ||
                      "Доступ к аналитике матчей, оценке value и расширенным метрикам."}
                  </div>
                </div>
                <div className="rounded-2xl border border-glass bg-surface-2/70 px-4 py-3 text-sm text-slate-200">
                  Активна до {formatDate(sub.end_at)}
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="rounded-3xl border border-glass bg-surface-1/70 p-8 text-center">
          <div className="text-lg font-semibold text-white">Подписок пока нет</div>
          <div className="mt-2 text-sm text-slate-400">Оформи план, чтобы получить продвинутые инсайты.</div>
          <button onClick={() => scrollToPlans()} className="mt-4 rounded-2xl border border-violet-400/35 bg-[linear-gradient(135deg,rgba(124,58,237,0.9),rgba(99,102,241,0.82))] px-4 py-2 text-sm font-semibold text-white shadow-[0_14px_34px_rgba(124,58,237,0.24),inset_0_1px_0_rgba(255,255,255,0.18)] transition hover:brightness-110">
            Перейти к планам
          </button>
        </div>
      )}

      {plansLoading ? (
        <div className="rounded-3xl border border-glass bg-surface-1/70 p-8 text-center text-slate-400">
          Загрузка планов…
        </div>
      ) : (
        <div ref={plansRef} className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {[...paidPlans, ...freePlans].map((plan) => {
            const code = String(plan.code || "").toUpperCase();
            const active = activeByCode.get(code);
            const buying = !!purchaseLoading[plan.id];
            const err = purchaseErrors[plan.id];
            return (
              <div
                key={plan.id}
                ref={(node) => {
                  if (node) planRefs.current.set(code, node);
                }}
                className={`rounded-3xl border border-glass bg-surface-2/80 p-6 shadow-[0_12px_40px_rgba(0,0,0,0.35)] flex flex-col ${
                  active ? "ring-1 ring-violet-400/40" : ""
                } ${highlightPlan === code ? "ring-1 ring-cyan-400/40" : ""}`}
              >
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="text-[11px] uppercase tracking-[0.22em] text-slate-400">
                      Тариф
                    </div>
                    <div className="mt-1 text-xl font-semibold text-white">
                      {plan.name}
                    </div>
                    <div className="mt-2 text-sm text-slate-300 min-h-[48px]">
                      {plan.description || "Расширенный доступ к аналитике."}
                    </div>
                  </div>
                  {active && (
                    <span className="inline-flex rounded-full border border-violet-400/40 bg-violet-500/20 px-2.5 py-1 text-[11px] text-white">
                      Активна
                    </span>
                  )}
                </div>

                  <div className="mt-4 px-1 py-2 text-center">
                    <div className="text-2xl font-semibold text-white">
                      {Number(plan.price) === 0
                        ? "Бесплатно"
                      : `${Number(plan.price).toLocaleString("ru-RU")} ₽`}
                  </div>
                  <div className="text-xs text-slate-400">
                    {Number(plan.price) === 0 ? "доступ ограничен" : `на ${plan.duration_days} дней`}
                  </div>
                </div>

                <div className="mt-4 grid gap-2 text-xs text-slate-400">
                  <div>Отчётов в месяц: {plan.limit_reports_per_month ?? "—"}</div>
                  <div>Уведомлений в день: {plan.limit_alerts_per_day ?? "—"}</div>
                </div>

                <div className="mt-4 mt-auto">
                  <button
                    disabled={!!active || buying}
                    onClick={() => handlePurchase(plan)}
                    className={`h-10 w-full rounded-2xl text-sm font-semibold text-white transition ${
                      active || buying
                        ? "border border-white/10 bg-slate-600/70 cursor-not-allowed"
                        : "border border-violet-400/35 bg-[linear-gradient(135deg,rgba(124,58,237,0.9),rgba(99,102,241,0.82))] shadow-[0_14px_34px_rgba(124,58,237,0.24),inset_0_1px_0_rgba(255,255,255,0.18)] hover:brightness-110"
                    }`}
                  >
                    {active ? "Уже подключено" : buying ? "Оформление…" : "Подключить"}
                  </button>
                  {err && (
                    <div className="mt-2 rounded-xl border border-rose-400/40 bg-rose-500/10 px-3 py-2 text-[12px] text-rose-100">
                      {err}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );

  if (!user) {
    return (
      <div className="min-h-screen flex items-center justify-center px-4 text-slate-200">
        <div className="rounded-3xl border border-glass bg-surface-1/80 p-10 text-center">
          <div className="text-2xl font-semibold text-white">Доступ закрыт</div>
          <div className="mt-2 text-sm text-slate-400">Войдите, чтобы открыть личный кабинет.</div>
          <button onClick={() => navigate("/login")} className="mt-4 rounded-2xl border border-violet-400/35 bg-[linear-gradient(135deg,rgba(124,58,237,0.9),rgba(99,102,241,0.82))] px-4 py-2 text-sm font-semibold text-white shadow-[0_14px_34px_rgba(124,58,237,0.24),inset_0_1px_0_rgba(255,255,255,0.18)] transition hover:brightness-110">
            Войти
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-surface-1 text-slate-200">
      <div className="fixed inset-0 -z-10 overflow-hidden">
        <div className="absolute -top-24 -left-28 h-[380px] w-[380px] rounded-full bg-violet-500/10 blur-[180px]" />
        <div className="absolute -top-32 right-[-160px] h-[420px] w-[420px] rounded-full bg-cyan-500/10 blur-[200px]" />
        <div className="absolute bottom-[-220px] left-[-120px] h-[480px] w-[480px] rounded-full bg-slate-400/10 blur-[200px]" />
      </div>

      <div className="type-page max-w-6xl mx-auto px-5 py-10">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="type-title-block">
            <div className="type-eyebrow">EdgeScore • Account</div>
            <h1 className="type-page-title text-slate-100">Личный кабинет</h1>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => navigate("/")}
              className="rounded-full border border-glass bg-surface-2/70 px-4 py-2 text-xs text-slate-300 hover:text-white hover:bg-surface-2"
            >
              ← На главную
            </button>
          </div>
        </div>

        <SegmentedTabs
          className="mt-6"
          items={[
            { key: "overview", label: "Обзор" },
            { key: "favorites", label: "Избранное" },
            ...(!hideMonetization ? [{ key: "subscriptions", label: "Подписки" }] : []),
          ]}
          value={activeTab}
          onChange={(key) => goTab(key)}
          listClassName="gap-6"
          buttonClassName="tracking-wide"
          activeClassName="text-white"
        />

        <div className="mt-8">
          {activeTab === "overview" && renderOverview()}
          {activeTab === "favorites" && renderFavorites()}
          {!hideMonetization && activeTab === "subscriptions" && renderSubscriptions()}
        </div>
      </div>

      {!hideMonetization && addFundsOpen && (
        <AddFundsModal
          errorText={addFundsError}
          onClose={() => {
            setAddFundsOpen(false);
            setAddFundsError("");
          }}
          onAdded={(amount) => {
            setUserBalance((b) =>
              Number(b || 0) + Number(amount || 0)
            );
            fetchUserSubscriptions();
          }}
        />
      )}
    </div>
  );
}

function AddFundsModal({ onClose, onAdded, errorText }) {
  const [amount, setAmount] = useState("100");
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState(errorText || "");

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
