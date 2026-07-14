import React, { useState, useEffect } from 'react';
import { useAuth } from '@/auth/AuthContext.jsx';
import { useNavigate } from 'react-router-dom';
import { http } from '@/lib/http.js';
import { useLanguage } from '@/context/LanguageContext.jsx';

const PROFILE_COPY = {
  insiderTitle: { ru: 'EdgeScore Insider', en: 'EdgeScore Insider' },
  quickActions: { ru: 'Быстрые действия', en: 'Quick actions' },
  financialInfo: { ru: 'Финансовая информация', en: 'Financial info' },
  currentBalance: { ru: 'Текущий баланс:', en: 'Current balance:' },
  activeSubscriptions: { ru: 'Активных подписок:', en: 'Active subscriptions:' },
  loadingSubscriptions: { ru: 'Загрузка подписок...', en: 'Loading subscriptions...' },
  activePlansTitle: { ru: 'Активные подписки', en: 'Active subscriptions' },
  subscriptionPrompt: { ru: 'Подключи подписку для доступа к инсайтам', en: 'Get a subscription to unlock insights' },
};

const getSubscriptionStatusLabel = (status, language) => {
  const normalized = String(status || '').toUpperCase();
  const isRu = language === 'ru';
  if (!normalized || normalized === 'FREE') return isRu ? 'Без подписки' : 'Free';
  if (normalized === 'START') return 'Start';
  if (normalized === 'PRO') return 'Pro';
  if (normalized === 'ELITE') return 'Elite';
  if (normalized === 'ACTIVE') return isRu ? 'Активна' : 'Active';
  if (normalized === 'EXPIRED') return isRu ? 'Истекла' : 'Expired';
  return normalized;
};

function SoftEmptyState({ title, text, actionLabel, onAction }) {
  return (
    <div className="glass-card px-5 py-8 text-center">
      <div className="mx-auto grid h-12 w-12 place-items-center rounded-2xl border border-white/[0.07] bg-white/[0.035] text-white/55">
        <svg className="h-5 w-5" viewBox="0 0 20 20" fill="none" aria-hidden="true">
          <path d="M6 10h8M6 6h8M6 14h5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
          <circle cx="10" cy="10" r="7.25" stroke="currentColor" strokeOpacity="0.55" />
        </svg>
      </div>
      <h4 className="mt-4 text-lg font-medium text-slate-100">{title}</h4>
      <p className="mt-2 text-sm text-slate-400">{text}</p>
      {actionLabel && onAction ? (
        <button onClick={onAction} className="mt-5 rounded-full bg-white px-4 py-2 text-xs font-semibold text-slate-900">
          {actionLabel}
        </button>
      ) : null}
    </div>
  );
}

export default function ProfilePage() {
  const { user, logout } = useAuth();
  const { language, t } = useLanguage();
  const isRu = language === 'ru';
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('profile');
  const [userSubscriptions, setUserSubscriptions] = useState([]);
  const [userBalance, setUserBalance] = useState('0.00');
  const [subscriptionsLoading, setSubscriptionsLoading] = useState(true);

  const handleLogout = () => {
    logout();
    navigate('/');
  };

  useEffect(() => {
    if (user) {
      fetchUserSubscriptions();
    }
  }, [user]);

  const fetchUserSubscriptions = async () => {
    try {
      setSubscriptionsLoading(true);
      const response = await http.get('/api/subscriptions/me');
      let userData;
      if (response.data) {
        userData = response.data;
      } else if (response.json) {
        userData = await response.json();
      }
      
      if (userData) {
        setUserBalance(userData.balance || '0.00');
        setUserSubscriptions(userData.active_subscriptions || []);
      }
    } catch (err) {
      console.error('Error fetching user subscriptions:', err);
    } finally {
      setSubscriptionsLoading(false);
    }
  };

  const renderTab = (tab, label) => {
    const isActive = activeTab === tab;
    return (
      <button
        key={tab}
        onClick={() => setActiveTab(tab)}
        className={`px-4 py-2 rounded-full text-xs font-semibold tracking-wide transition ${
          isActive
            ? "bg-white text-slate-900 shadow-[0_12px_30px_rgba(255,255,255,0.15)]"
            : "text-slate-300 border border-white/10 hover:text-white hover:border-white/20"
        }`}
      >
        {label}
      </button>
    );
  };

  const renderProfileTab = () => (
    <div className="grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
      <div className="surface-hero p-6">
        <div className="flex items-center gap-4">
          <div className="h-20 w-20 rounded-3xl border border-white/10 bg-gradient-to-br from-slate-900/80 to-slate-950/60 grid place-items-center text-3xl font-bold text-white">
            {user?.username?.charAt(0).toUpperCase()}
          </div>
          <div className="min-w-0">
            <div className="text-2xl font-semibold text-white">{user?.username}</div>
            <div className="text-sm text-slate-400">{user?.email}</div>
            <div className="surface-chip mt-2 py-1 text-xs text-slate-300">
              <span className={`h-2 w-2 rounded-full ${user?.is_verified ? "bg-emerald-400" : "bg-amber-400"}`} />
              {user?.is_verified ? t("verifiedEmail") : t("verifyEmailNeeded")}
            </div>
          </div>
        </div>

        <div className="mt-6 grid gap-4 md:grid-cols-2">
          <div className="glass-card p-4">
            <div className="text-xs uppercase tracking-[0.2em] text-slate-400">{language === "ru" ? "Баланс" : "Balance"}</div>
            <div className="mt-2 text-3xl font-semibold text-white">{userBalance} ₽</div>
            <div className="mt-2 text-xs text-slate-400">{language === "ru" ? "Доступно для подписок и апгрейдов" : "Available for subscriptions and upgrades"}</div>
          </div>
          <div className="glass-card p-4">
            <div className="text-xs uppercase tracking-[0.2em] text-slate-400">{language === "ru" ? "Подписки" : "Subscriptions"}</div>
            <div className="mt-2 text-3xl font-semibold text-white">{userSubscriptions.length}</div>
            <div className="mt-2 text-xs text-slate-400">{language === "ru" ? "Активные планы" : "Active plans"}</div>
          </div>
          <div className="glass-card p-4">
            <div className="text-xs uppercase tracking-[0.2em] text-slate-400">{language === "ru" ? "Дата регистрации" : "Registration date"}</div>
            <div className="mt-2 text-lg font-semibold text-white">
              {user?.created_at ? new Date(user.created_at).toLocaleDateString(language === "ru" ? 'ru-RU' : 'en-GB') : "—"}
            </div>
            <div className="mt-2 text-xs text-slate-500">{language === "ru" ? "Профиль EdgeScore" : "EdgeScore profile"}</div>
          </div>
          <div className="glass-card p-4">
            <div className="text-xs uppercase tracking-[0.2em] text-slate-400">{language === "ru" ? "Статус" : "Status"}</div>
            <div className="mt-2 text-lg font-semibold text-white">
              {getSubscriptionStatusLabel(user?.subscription_status, language)}
            </div>
            <div className="mt-2 text-xs text-slate-500">{isRu ? PROFILE_COPY.subscriptionPrompt.ru : PROFILE_COPY.subscriptionPrompt.en}</div>
          </div>
        </div>

        <div className="mt-6 flex flex-wrap gap-3">
          <button onClick={handleLogout} className="btn-primary">
            {t("logOut")}
          </button>
          <button onClick={() => setActiveTab('settings')} className="btn-glass">
            {language === "ru" ? "Настройки" : "Settings"}
          </button>
          <button onClick={() => navigate('/subscriptions')} className="btn-glass">
            {language === "ru" ? "Подписки" : "Subscriptions"}
          </button>
        </div>
      </div>

      <div className="space-y-4">
        <div className="surface-hero p-6">
          <div className="text-sm font-semibold text-white">{isRu ? PROFILE_COPY.insiderTitle.ru : PROFILE_COPY.insiderTitle.en}</div>
          <div className="mt-2 text-sm text-slate-300">
            {language === "ru" ? "Получай лучшие сигналы и объяснения ставок прямо в матче. Нажми и включи продвинутые подсказки." : "Get the strongest signals and betting explanations directly inside the match. Turn on advanced insights."}
          </div>
          <button className="mt-4 rounded-full bg-white px-4 py-2 text-xs font-semibold text-slate-900">
            {language === "ru" ? "Включить инсайты" : "Enable insights"}
          </button>
        </div>

        <div className="glass-card p-6">
          <div className="text-sm font-semibold text-white">{isRu ? PROFILE_COPY.quickActions.ru : PROFILE_COPY.quickActions.en}</div>
          <div className="mt-4 grid gap-3">
            <button onClick={() => navigate('/matches-v3')} className="btn-glass text-left">
              {language === "ru" ? "Перейти к результатам" : "Go to results"}
            </button>
            <button onClick={() => navigate('/schedule')} className="btn-glass text-left">
              {language === "ru" ? "Открыть календарь" : "Open schedule"}
            </button>
            <button onClick={() => navigate('/best-picks')} className="btn-glass text-left">
              {language === "ru" ? "Посмотреть подборки" : "View picks"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  const renderSettingsTab = () => (
    <div className="panel rounded-2xl p-6">
      <h3 className="text-xl font-bold text-slate-100 mb-4">{language === "ru" ? "Настройки аккаунта" : "Account settings"}</h3>
      <div className="space-y-4">
        <div className="glass-card p-4">
          <h4 className="font-medium text-slate-100 mb-2">{language === "ru" ? "Уведомления" : "Notifications"}</h4>
          <p className="text-slate-400 text-sm">{language === "ru" ? "Настройки уведомлений будут доступны в следующих версиях" : "Notification settings will be available in future versions"}</p>
        </div>
        <div className="glass-card p-4">
          <h4 className="font-medium text-slate-100 mb-2">{language === "ru" ? "Безопасность" : "Security"}</h4>
          <p className="text-slate-400 text-sm">{language === "ru" ? "Функции безопасности будут доступны в следующих версиях" : "Security features will be available in future versions"}</p>
        </div>
        <div className="glass-card p-4">
          <h4 className="font-medium text-slate-100 mb-2">{language === "ru" ? "Приватность" : "Privacy"}</h4>
          <p className="text-slate-400 text-sm">{language === "ru" ? "Настройки приватности будут доступны в следующих версиях" : "Privacy settings will be available in future versions"}</p>
        </div>
      </div>
    </div>
  );

  const renderSubscriptionsTab = () => (
    <div className="panel rounded-2xl p-6">
      <h3 className="text-xl font-bold text-slate-100 mb-6">{language === "ru" ? "Мои подписки" : "My subscriptions"}</h3>
      
      {/* Информация о балансе */}
      <div className="glass-card mb-6 p-6">
        <h4 className="text-lg font-medium text-slate-100 mb-4">{isRu ? PROFILE_COPY.financialInfo.ru : PROFILE_COPY.financialInfo.en}</h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <p className="text-sm text-slate-400">{isRu ? PROFILE_COPY.currentBalance.ru : PROFILE_COPY.currentBalance.en}</p>
            <p className="text-3xl font-bold text-slate-100">{userBalance} ₽</p>
          </div>
          <div>
            <p className="text-sm text-slate-400">{isRu ? PROFILE_COPY.activeSubscriptions.ru : PROFILE_COPY.activeSubscriptions.en}</p>
            <p className="text-3xl font-bold text-slate-100">{userSubscriptions.length}</p>
          </div>
        </div>
      </div>

      {/* Список активных подписок */}
      {subscriptionsLoading ? (
        <div className="surface-loading px-5 py-8">
          <div className="surface-spinner"></div>
          <p className="mt-3 text-sm text-slate-400">{isRu ? PROFILE_COPY.loadingSubscriptions.ru : PROFILE_COPY.loadingSubscriptions.en}</p>
        </div>
      ) : userSubscriptions.length > 0 ? (
        <div>
          <h4 className="text-lg font-medium text-slate-100 mb-4">{isRu ? PROFILE_COPY.activePlansTitle.ru : PROFILE_COPY.activePlansTitle.en}</h4>
          <div className="space-y-4">
            {userSubscriptions.map((sub) => (
              <div key={sub.id} className="glass-card p-4">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                  <div className="min-w-0">
                    <h5 className="font-medium text-slate-100 text-lg">{sub.plan_name}</h5>
                    <div className="mt-2 flex flex-wrap gap-2 text-xs text-slate-300">
                      <span className="rounded-full border border-white/[0.07] bg-white/[0.04] px-2.5 py-1">
                        {language === "ru" ? "Код плана" : "Plan code"}: {sub.plan_code}
                      </span>
                      <span className="rounded-full border border-white/[0.07] bg-white/[0.04] px-2.5 py-1">
                        {language === "ru" ? "Цена" : "Price"}: {sub.price_at_purchase} ₽
                      </span>
                    </div>
                  </div>
                  <div className="rounded-2xl border border-white/[0.06] bg-black/20 px-4 py-3 text-left sm:min-w-[180px] sm:text-right">
                    <div className="text-[11px] uppercase tracking-[0.16em] text-slate-500">{language === "ru" ? "Действует до" : "Active until"}</div>
                    <div className="mt-1 font-medium text-slate-100">
                      {new Date(sub.end_at).toLocaleDateString(language === "ru" ? 'ru-RU' : 'en-GB')}
                    </div>
                    <div className="mt-1 text-xs text-slate-400">
                      {new Date(sub.start_at).toLocaleDateString(language === "ru" ? 'ru-RU' : 'en-GB')} - {new Date(sub.end_at).toLocaleDateString(language === "ru" ? 'ru-RU' : 'en-GB')}
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <SoftEmptyState
          title={language === "ru" ? "У вас пока нет активных подписок" : "You don't have active subscriptions yet"}
          text={language === "ru" ? "Оформите подписку, чтобы получить доступ к расширенным возможностям" : "Get a subscription to unlock advanced features"}
          actionLabel={language === "ru" ? "Перейти к планам подписок" : "View subscription plans"}
          onAction={() => navigate('/subscriptions')}
        />
      )}
    </div>
  );

  const renderStatsTab = () => (
    <div className="panel rounded-2xl p-6">
      <h3 className="text-xl font-bold text-slate-100 mb-4">{language === "ru" ? "Статистика" : "Stats"}</h3>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="text-center p-4 bg-surface-2 rounded-lg border border-glass">
          <div className="text-2xl font-bold text-slate-100">0</div>
          <div className="text-slate-400">{language === "ru" ? "Просмотренных матчей" : "Viewed matches"}</div>
        </div>
        <div className="text-center p-4 bg-surface-2 rounded-lg border border-glass">
          <div className="text-2xl font-bold text-slate-100">0</div>
          <div className="text-slate-400">{language === "ru" ? "Избранных команд" : "Favorite teams"}</div>
        </div>
        <div className="text-center p-4 bg-surface-2 rounded-lg border border-glass">
          <div className="text-2xl font-bold text-slate-100">0</div>
          <div className="text-slate-400">{language === "ru" ? "Сохраненных прогнозов" : "Saved picks"}</div>
        </div>
      </div>
      <div className="mt-6 p-4 bg-surface-2 rounded-lg border border-glass">
        <p className="text-slate-400 text-center">{language === "ru" ? "Статистика будет собираться по мере использования приложения" : "Stats will appear as you use the app"}</p>
      </div>
    </div>
  );

  const renderContent = () => {
    switch (activeTab) {
      case 'profile':
        return renderProfileTab();
      case 'subscriptions':
        return renderSubscriptionsTab();
      case 'settings':
        return renderSettingsTab();
      case 'stats':
        return renderStatsTab();
      default:
        return renderProfileTab();
    }
  };

  if (!user) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-8">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-slate-100 mb-4">{language === "ru" ? "Доступ запрещен" : "Access denied"}</h1>
          <p className="text-slate-400 mb-4">{language === "ru" ? "Для доступа к личному кабинету необходимо войти в систему" : "You need to sign in to access your account"}</p>
          <button
            onClick={() => navigate('/login')}
            className="btn-primary"
          >
            {t("signInAction")}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen text-slate-200">
      <div className="sticky top-0 z-10 border-b border-white/10 bg-black/30 backdrop-blur-2xl">
        <div className="max-w-6xl mx-auto px-4 py-5">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <div className="text-[11px] uppercase tracking-[0.25em] text-slate-400">EdgeScore</div>
              <h1 className="text-2xl font-semibold text-white">{language === "ru" ? "Личный кабинет" : "Account"}</h1>
            </div>
            <div className="flex items-center gap-3">
              <button
                onClick={() => navigate('/')}
                className="rounded-full border border-white/10 px-4 py-2 text-xs text-slate-300 hover:text-white hover:border-white/20"
              >
                ← {t("backHome")}
              </button>
            </div>
          </div>
          <div className="mt-4 flex flex-wrap gap-3">
            {renderTab('profile', language === "ru" ? 'Профиль' : 'Profile')}
            {renderTab('subscriptions', language === "ru" ? 'Подписки' : 'Subscriptions')}
            {renderTab('settings', language === "ru" ? 'Настройки' : 'Settings')}
            {renderTab('stats', language === "ru" ? 'Статистика' : 'Stats')}
          </div>
        </div>
      </div>

      <div className="max-w-6xl mx-auto px-4 py-8">
        {renderContent()}
      </div>
    </div>
  );
}
