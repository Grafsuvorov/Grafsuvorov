// src/components/Sidebar.jsx
import React from 'react';
import '../style/app.css';

export default function Sidebar({ currentView, onChangeView }) {
  return (
    <aside className="sidebar">
      <div className="sidebar-title">📊 Data Monitor</div>
      <nav>
        <button
          className={currentView === 'home' ? 'active' : ''}
          onClick={() => onChangeView(null)}
        >
          Главная
        </button>

        <button
          className={currentView === 'errors' ? 'active' : ''}
          onClick={() => onChangeView('__show_errors__')}
        >
          Ошибки загрузки
        </button>

        <button
          className={currentView === 'search' ? 'active' : ''}
          onClick={() => onChangeView('search')}
        >
         Мониторинг зависимостей
        </button>

        <button
          className={currentView === 'table_search' ? 'active' : ''}
          onClick={() => onChangeView('table_search')}
        >
         Поиск таблицы
        </button>
        <button
          className={currentView === '__check_inconsistencies__' ? 'active' : ''}
          onClick={() => onChangeView('__check_inconsistencies__')}
        >
         Проверка нарушений
        </button>
        <button
          className={currentView === 'slowest_tables' ? 'active' : ''}
          onClick={() => onChangeView('__slowest_tables__')}
        >
        ⏱ Самые долгие
        </button>
      </nav>
    </aside>
  );
}