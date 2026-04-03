import React, { useState, useEffect } from 'react';
import { useAuth } from '@/auth/AuthContext.jsx';
import { useNavigate } from 'react-router-dom';
import { http } from '@/lib/http.js';

export default function ProfilePage() {
  const { user, logout } = useAuth();
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
      <div className="rounded-3xl border border-white/10 bg-white/5 p-6 shadow-[0_18px_55px_rgba(0,0,0,0.5)] backdrop-blur-xl">
        <div className="flex items-center gap-4">
          <div className="h-20 w-20 rounded-3xl border border-white/10 bg-gradient-to-br from-slate-900/80 to-slate-950/60 grid place-items-center text-3xl font-bold text-white">
            {user?.username?.charAt(0).toUpperCase()}
          </div>
          <div className="min-w-0">
            <div className="text-2xl font-semibold text-white">{user?.username}</div>
            <div className="text-sm text-slate-400">{user?.email}</div>
            <div className="mt-2 inline-flex items-center gap-2 rounded-full border border-white/10 bg-black/30 px-3 py-1 text-xs text-slate-300">
              <span className={`h-2 w-2 rounded-full ${user?.is_verified ? "bg-emerald-400" : "bg-amber-400"}`} />
              {user?.is_verified ? "Email подтвержден" : "Нужно подтвердить email"}
            </div>
          </div>
        </div>

        <div className="mt-6 grid gap-4 md:grid-cols-2">
          <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
            <div className="text-xs uppercase tracking-[0.2em] text-slate-400">Баланс</div>
            <div className="mt-2 text-3xl font-semibold text-white">{userBalance} ₽</div>
            <div className="mt-2 text-xs text-slate-400">Доступно для подписок и апгрейдов</div>
          </div>
          <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
            <div className="text-xs uppercase tracking-[0.2em] text-slate-400">Подписки</div>
            <div className="mt-2 text-3xl font-semibold text-white">{userSubscriptions.length}</div>
            <div className="mt-2 text-xs text-slate-400">Активные планы</div>
          </div>
          <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
            <div className="text-xs uppercase tracking-[0.2em] text-slate-400">Дата регистрации</div>
            <div className="mt-2 text-lg font-semibold text-white">
              {user?.created_at ? new Date(user.created_at).toLocaleDateString('ru-RU') : "—"}
            </div>
            <div className="mt-2 text-xs text-slate-500">Профиль EdgeScore</div>
          </div>
          <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
            <div className="text-xs uppercase tracking-[0.2em] text-slate-400">Статус</div>
            <div className="mt-2 text-lg font-semibold text-white">
              {user?.subscription_status ? user.subscription_status.toUpperCase() : "FREE"}
            </div>
            <div className="mt-2 text-xs text-slate-500">Подключи подписку для доступа к инсайтам</div>
          </div>
        </div>

        <div className="mt-6 flex flex-wrap gap-3">
          <button onClick={handleLogout} className="btn-primary">
            Выйти
          </button>
          <button onClick={() => setActiveTab('settings')} className="btn-glass">
            Настройки
          </button>
          <button onClick={() => navigate('/subscriptions')} className="btn-glass">
            Подписки
          </button>
        </div>
      </div>

      <div className="space-y-4">
        <div className="rounded-3xl border border-white/10 bg-gradient-to-br from-slate-900/70 to-slate-950/50 p-6">
          <div className="text-sm font-semibold text-white">EdgeScore Insider</div>
          <div className="mt-2 text-sm text-slate-300">
            Получай лучшие сигналы и объяснения ставок прямо в матче. Нажми и включи продвинутые подсказки.
          </div>
          <button className="mt-4 rounded-full bg-white px-4 py-2 text-xs font-semibold text-slate-900">
            Включить инсайты
          </button>
        </div>

        <div className="rounded-3xl border border-white/10 bg-white/5 p-6">
          <div className="text-sm font-semibold text-white">Быстрые действия</div>
          <div className="mt-4 grid gap-3">
            <button onClick={() => navigate('/matches-v3')} className="btn-glass text-left">
              Перейти к результатам
            </button>
            <button onClick={() => navigate('/schedule')} className="btn-glass text-left">
              Открыть календарь
            </button>
            <button onClick={() => navigate('/best-picks')} className="btn-glass text-left">
              Посмотреть подборки
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  const renderSettingsTab = () => (
    <div className="panel rounded-2xl p-6">
      <h3 className="text-xl font-bold text-slate-100 mb-4">Настройки аккаунта</h3>
      <div className="space-y-4">
        <div className="p-4 bg-surface-2 border border-glass rounded-lg">
          <h4 className="font-medium text-slate-100 mb-2">Уведомления</h4>
          <p className="text-slate-400 text-sm">Настройки уведомлений будут доступны в следующих версиях</p>
        </div>
        <div className="p-4 bg-surface-2 border border-glass rounded-lg">
          <h4 className="font-medium text-slate-100 mb-2">Безопасность</h4>
          <p className="text-slate-400 text-sm">Функции безопасности будут доступны в следующих версиях</p>
        </div>
        <div className="p-4 bg-surface-2 border border-glass rounded-lg">
          <h4 className="font-medium text-slate-100 mb-2">Приватность</h4>
          <p className="text-slate-400 text-sm">Настройки приватности будут доступны в следующих версиях</p>
        </div>
      </div>
    </div>
  );

  const renderSubscriptionsTab = () => (
    <div className="panel rounded-2xl p-6">
      <h3 className="text-xl font-bold text-slate-100 mb-6">Мои подписки</h3>
      
      {/* Информация о балансе */}
      <div className="bg-surface-2 border border-glass rounded-lg p-6 mb-6">
        <h4 className="text-lg font-medium text-slate-100 mb-4">Финансовая информация</h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <p className="text-sm text-slate-400">Текущий баланс:</p>
            <p className="text-3xl font-bold text-slate-100">{userBalance} ₽</p>
          </div>
          <div>
            <p className="text-sm text-slate-400">Активных подписок:</p>
            <p className="text-3xl font-bold text-slate-100">{userSubscriptions.length}</p>
          </div>
        </div>
      </div>

      {/* Список активных подписок */}
      {subscriptionsLoading ? (
        <div className="text-center py-8">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
          <p className="mt-2 text-slate-400">Загрузка подписок...</p>
        </div>
      ) : userSubscriptions.length > 0 ? (
        <div>
          <h4 className="text-lg font-medium text-slate-100 mb-4">Активные подписки</h4>
          <div className="space-y-4">
            {userSubscriptions.map((sub) => (
              <div key={sub.id} className="bg-surface-2 border border-glass rounded-lg p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <h5 className="font-medium text-slate-100 text-lg">{sub.plan_name}</h5>
                    <p className="text-sm text-slate-400">Код плана: {sub.plan_code}</p>
                    <p className="text-sm text-slate-400">Цена при покупке: {sub.price_at_purchase} ₽</p>
                  </div>
                  <div className="text-right">
                    <div className="text-sm text-slate-400">Действует до:</div>
                    <div className="font-medium text-slate-100">
                      {new Date(sub.end_at).toLocaleDateString('ru-RU')}
                    </div>
                    <div className="text-xs text-slate-400 mt-1">
                      {new Date(sub.start_at).toLocaleDateString('ru-RU')} - {new Date(sub.end_at).toLocaleDateString('ru-RU')}
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div className="text-center py-8">
          <div className="text-slate-500 mb-4">
            <svg className="mx-auto h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          </div>
          <h4 className="text-lg font-medium text-slate-100 mb-2">У вас пока нет активных подписок</h4>
          <p className="text-slate-400 mb-4">Оформите подписку, чтобы получить доступ к расширенным возможностям</p>
          <button
            onClick={() => navigate('/subscriptions')}
            className="btn-primary"
          >
            Перейти к планам подписок
          </button>
        </div>
      )}
    </div>
  );

  const renderStatsTab = () => (
    <div className="panel rounded-2xl p-6">
      <h3 className="text-xl font-bold text-slate-100 mb-4">Статистика</h3>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="text-center p-4 bg-surface-2 rounded-lg border border-glass">
          <div className="text-2xl font-bold text-slate-100">0</div>
          <div className="text-slate-400">Просмотренных матчей</div>
        </div>
        <div className="text-center p-4 bg-surface-2 rounded-lg border border-glass">
          <div className="text-2xl font-bold text-slate-100">0</div>
          <div className="text-slate-400">Избранных команд</div>
        </div>
        <div className="text-center p-4 bg-surface-2 rounded-lg border border-glass">
          <div className="text-2xl font-bold text-slate-100">0</div>
          <div className="text-slate-400">Сохраненных прогнозов</div>
        </div>
      </div>
      <div className="mt-6 p-4 bg-surface-2 rounded-lg border border-glass">
        <p className="text-slate-400 text-center">Статистика будет собираться по мере использования приложения</p>
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
          <h1 className="text-2xl font-bold text-slate-100 mb-4">Доступ запрещен</h1>
          <p className="text-slate-400 mb-4">Для доступа к личному кабинету необходимо войти в систему</p>
          <button
            onClick={() => navigate('/login')}
            className="btn-primary"
          >
            Войти
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
              <h1 className="text-2xl font-semibold text-white">Личный кабинет</h1>
            </div>
            <div className="flex items-center gap-3">
              <button
                onClick={() => navigate('/')}
                className="rounded-full border border-white/10 px-4 py-2 text-xs text-slate-300 hover:text-white hover:border-white/20"
              >
                ← На главную
              </button>
            </div>
          </div>
          <div className="mt-4 flex flex-wrap gap-3">
            {renderTab('profile', 'Профиль')}
            {renderTab('subscriptions', 'Подписки')}
            {renderTab('settings', 'Настройки')}
            {renderTab('stats', 'Статистика')}
          </div>
        </div>
      </div>

      <div className="max-w-6xl mx-auto px-4 py-8">
        {renderContent()}
      </div>
    </div>
  );
}
