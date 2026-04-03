import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { shouldHideMonetization } from '@/lib/pilotAccess.js';

export default function Navigation() {
  const location = useLocation();
  const hideMonetization = shouldHideMonetization();

  const isActive = (path) => {
    return location.pathname === path;
  };

  return (
    <nav className="bg-surface-1/90 border-b border-glass shadow-[0_16px_35px_rgba(0,0,0,0.45)] backdrop-blur">
      <div className="max-w-7xl mx-auto px-4">
        <div className="flex justify-between h-16">
          <div className="flex">
            <div className="flex-shrink-0 flex items-center">
              <Link to="/" className="text-xl font-bold text-white">
                Football App
              </Link>
            </div>
            <div className="hidden sm:ml-6 sm:flex sm:space-x-8">
              <Link
                to="/table"
                className={`${
                  isActive('/table')
                    ? 'border-primary text-white'
                    : 'border-transparent text-slate-400 hover:border-white/30 hover:text-white'
                } inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium`}
              >
                Таблица
              </Link>
              <Link
                to="/matches"
                className={`${
                  isActive('/matches')
                    ? 'border-primary text-white'
                    : 'border-transparent text-slate-400 hover:border-white/30 hover:text-white'
                } inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium`}
              >
                Результаты
              </Link>
              <Link
                to="/schedule"
                className={`${
                  isActive('/schedule')
                    ? 'border-primary text-white'
                    : 'border-transparent text-slate-400 hover:border-white/30 hover:text-white'
                } inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium`}
              >
                Расписание
              </Link>
              <Link
                to="/best-picks"
                className={`${
                  isActive('/best-picks')
                    ? 'border-primary text-white'
                    : 'border-transparent text-slate-400 hover:border-white/30 hover:text-white'
                } inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium`}
              >
                Подборки
              </Link>
              {!hideMonetization && (
                <Link
                  to="/subscriptions"
                  className={`${
                    isActive('/subscriptions')
                      ? 'border-primary text-white'
                      : 'border-transparent text-slate-400 hover:border-white/30 hover:text-white'
                  } inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium`}
                >
                  Подписки
                </Link>
              )}
            </div>
          </div>
          <div className="hidden sm:ml-6 sm:flex sm:items-center">
            <Link
              to="/profile"
              className="text-slate-400 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
            >
              Профиль
            </Link>
          </div>
        </div>
      </div>
    </nav>
  );
}
