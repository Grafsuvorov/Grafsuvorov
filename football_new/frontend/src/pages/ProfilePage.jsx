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
        className={`px-4 py-2 border-b-2 ${
          isActive
            ? "text-red-600 border-red-600 font-bold"
            : "text-gray-500 border-transparent hover:text-black transition-colors"
        }`}
      >
        {label}
      </button>
    );
  };

  const renderProfileTab = () => (
    <div className="bg-white rounded-lg shadow p-6">
      <div className="text-center mb-6">
        <div className="mx-auto w-24 h-24 bg-red-100 rounded-full flex items-center justify-center mb-4">
          <span className="text-3xl font-bold text-red-600">
            {user?.username?.charAt(0).toUpperCase()}
          </span>
        </div>
        <h2 className="text-2xl font-bold text-gray-800">{user?.username}</h2>
        <p className="text-gray-600">{user?.email}</p>
      </div>

      <div className="space-y-4">
        <div className="flex justify-between items-center py-3 border-b">
          <span className="text-gray-600">ID пользователя:</span>
          <span className="font-medium">{user?.id}</span>
        </div>
        <div className="flex justify-between items-center py-3 border-b">
          <span className="text-gray-600">Статус:</span>
          <span className={`px-2 py-1 rounded text-sm font-medium ${
            user?.is_verified 
              ? 'bg-green-100 text-green-800' 
              : 'bg-yellow-100 text-yellow-800'
          }`}>
            {user?.is_verified ? 'Подтвержден' : 'Ожидает подтверждения'}
          </span>
        </div>
        <div className="flex justify-between items-center py-3 border-b">
          <span className="text-gray-600">Дата регистрации:</span>
          <span className="font-medium">
            {new Date(user?.created_at).toLocaleDateString('ru-RU')}
          </span>
        </div>
      </div>

      <div className="mt-6 flex gap-3">
        <button
          onClick={handleLogout}
          className="flex-1 bg-red-600 text-white py-2 px-4 rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 transition-colors"
        >
          Выйти
        </button>
        <button
          onClick={() => setActiveTab('settings')}
          className="flex-1 bg-gray-600 text-white py-2 px-4 rounded-md hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors"
        >
          Настройки
        </button>
      </div>
    </div>
  );

  const renderSettingsTab = () => (
    <div className="bg-white rounded-lg shadow p-6">
      <h3 className="text-xl font-bold text-gray-800 mb-4">Настройки аккаунта</h3>
      <div className="space-y-4">
        <div className="p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <h4 className="font-medium text-blue-800 mb-2">Уведомления</h4>
          <p className="text-blue-700 text-sm">Настройки уведомлений будут доступны в следующих версиях</p>
        </div>
        <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
          <h4 className="font-medium text-green-800 mb-2">Безопасность</h4>
          <p className="text-green-700 text-sm">Функции безопасности будут доступны в следующих версиях</p>
        </div>
        <div className="p-4 bg-purple-50 border border-purple-200 rounded-lg">
          <h4 className="font-medium text-purple-800 mb-2">Приватность</h4>
          <p className="text-purple-700 text-sm">Настройки приватности будут доступны в следующих версиях</p>
        </div>
      </div>
    </div>
  );

  const renderSubscriptionsTab = () => (
    <div className="bg-white rounded-lg shadow p-6">
      <h3 className="text-xl font-bold text-gray-800 mb-6">Мои подписки</h3>
      
      {/* Информация о балансе */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-6 mb-6">
        <h4 className="text-lg font-medium text-blue-900 mb-4">Финансовая информация</h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <p className="text-sm text-blue-700">Текущий баланс:</p>
            <p className="text-3xl font-bold text-blue-900">{userBalance} ₽</p>
          </div>
          <div>
            <p className="text-sm text-blue-700">Активных подписок:</p>
            <p className="text-3xl font-bold text-blue-900">{userSubscriptions.length}</p>
          </div>
        </div>
      </div>

      {/* Список активных подписок */}
      {subscriptionsLoading ? (
        <div className="text-center py-8">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          <p className="mt-2 text-gray-600">Загрузка подписок...</p>
        </div>
      ) : userSubscriptions.length > 0 ? (
        <div>
          <h4 className="text-lg font-medium text-gray-800 mb-4">Активные подписки</h4>
          <div className="space-y-4">
            {userSubscriptions.map((sub) => (
              <div key={sub.id} className="bg-green-50 border border-green-200 rounded-lg p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <h5 className="font-medium text-green-900 text-lg">{sub.plan_name}</h5>
                    <p className="text-sm text-green-600">Код плана: {sub.plan_code}</p>
                    <p className="text-sm text-green-600">Цена при покупке: {sub.price_at_purchase} ₽</p>
                  </div>
                  <div className="text-right">
                    <div className="text-sm text-green-600">Действует до:</div>
                    <div className="font-medium text-green-900">
                      {new Date(sub.end_at).toLocaleDateString('ru-RU')}
                    </div>
                    <div className="text-xs text-green-600 mt-1">
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
          <div className="text-gray-400 mb-4">
            <svg className="mx-auto h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          </div>
          <h4 className="text-lg font-medium text-gray-900 mb-2">У вас пока нет активных подписок</h4>
          <p className="text-gray-600 mb-4">Оформите подписку, чтобы получить доступ к расширенным возможностям</p>
          <button
            onClick={() => navigate('/subscriptions')}
            className="bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors"
          >
            Перейти к планам подписок
          </button>
        </div>
      )}
    </div>
  );

  const renderStatsTab = () => (
    <div className="bg-white rounded-lg shadow p-6">
      <h3 className="text-xl font-bold text-gray-800 mb-4">Статистика</h3>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="text-center p-4 bg-red-50 rounded-lg">
          <div className="text-2xl font-bold text-red-600">0</div>
          <div className="text-gray-600">Просмотренных матчей</div>
        </div>
        <div className="text-center p-4 bg-blue-50 rounded-lg">
          <div className="text-2xl font-bold text-blue-600">0</div>
          <div className="text-gray-600">Избранных команд</div>
        </div>
        <div className="text-center p-4 bg-green-50 rounded-lg">
          <div className="text-2xl font-bold text-green-600">0</div>
          <div className="text-gray-600">Сохраненных прогнозов</div>
        </div>
      </div>
      <div className="mt-6 p-4 bg-gray-50 rounded-lg">
        <p className="text-gray-600 text-center">Статистика будет собираться по мере использования приложения</p>
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
          <h1 className="text-2xl font-bold text-gray-800 mb-4">Доступ запрещен</h1>
          <p className="text-gray-600 mb-4">Для доступа к личному кабинету необходимо войти в систему</p>
          <button
            onClick={() => navigate('/login')}
            className="bg-red-600 text-white py-2 px-4 rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 transition-colors"
          >
            Войти
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-gray-50 min-h-screen">
      {/* Заголовок в том же стиле что и LeagueTabsHeader */}
      <div className="bg-white sticky top-0 z-10 border-b shadow-sm">
        <div className="max-w-5xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center space-x-3">
              <div className="w-12 h-12 bg-red-100 rounded-full flex items-center justify-center">
                <span className="text-xl font-bold text-red-600">
                  {user.username.charAt(0).toUpperCase()}
                </span>
              </div>
              <h1 className="text-2xl font-bold text-gray-800">Личный кабинет</h1>
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-sm text-gray-500">
                Пользователь: {user.username}
              </div>
              <button
                onClick={() => navigate('/')}
                className="text-sm text-gray-500 hover:text-blue-600 transition-colors font-medium"
              >
                ← Вернуться на главную
              </button>
            </div>
          </div>

          {/* Навигация по вкладкам в том же стиле */}
          <div className="flex gap-4 mt-2">
            {renderTab('profile', 'Профиль')}
            {renderTab('subscriptions', 'Подписки')}
            {renderTab('settings', 'Настройки')}
            {renderTab('stats', 'Статистика')}
          </div>
        </div>
      </div>

      {/* Основной контент */}
      <div className="max-w-5xl mx-auto px-4 py-8">
        {renderContent()}
      </div>
    </div>
  );
}
