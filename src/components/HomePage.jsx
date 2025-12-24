import { useEffect, useState } from 'react';
import '../style/app.css';
const API_BASE = import.meta.env.VITE_API_BASE_URL;

export default function HomePage({ onSelectTable }) {
  const [metrics, setMetrics] = useState([
    { label: 'Всего таблиц', value: '—' },
    { label: 'Ошибки загрузки', value: '—' },
    { label: 'Среднее время загрузки', value: '—' },
    { label: 'Активных сущностей', value: '—' },
  ]);

  useEffect(() => {
    fetch(`${API_BASE}/api/metrics`)
      .then((res) => res.json())
      .then((data) => {
        setMetrics([
          { label: 'Всего таблиц', value: data.total_tables },
          { label: 'Ошибки загрузки', value: data.error_count },
          {
            label: 'Среднее время загрузки',
            value: data.avg_duration_minutes ? `${data.avg_duration_minutes} мин` : '—',
          },
          { label: 'Активных сущностей', value: data.active_entities },
        ]);
      })
      .catch((err) => {
        console.error('Ошибка при загрузке метрик:', err);
      });
  }, []);

  const actions = [
    {
      title: '🔗 Мониторинг зависимостей',
      description: 'Просмотр графа и связей таблиц',
      onClick: () => onSelectTable('search'),
    },
    {
      title: '⚠ Ошибки загрузки',
      description: 'Список таблиц с проблемами',
      onClick: () => onSelectTable('__show_errors__'),
    },
    {
      title: '🔍 Найти таблицу',
      description: 'Ручной поиск по имени',
      onClick: () => onSelectTable('table_search'),
    },
    {
      title: '🔁 Проверка нарушений',
      description: 'Показать несогласованные обновления таблиц',
      onClick: () => onSelectTable('__check_inconsistencies__'),
    },
    {
      title: '⏱ Самые долгие таблицы',
      description: 'Показать топ-20 таблиц по длительности загрузки',
      onClick: () => onSelectTable('__slowest_tables__'),
    },
  ];

  return (
    <div className="home-page">
      <h2 className="home-title">📊 Мониторинг данных</h2>
      <p className="home-subtitle">
        Отслеживайте зависимости, ошибки и ключевые показатели загрузки.
      </p>

      <div className="metrics-section">
        {metrics.map((m, idx) => (
          <div className="metric-card" key={idx}>
            <div className="metric-value">{m.value}</div>
            <div className="metric-label">{m.label}</div>
          </div>
        ))}
      </div>

      <div className="action-cards">
        {actions.map((action, idx) => (
          <div className="action-card" key={idx} onClick={action.onClick}>
            <h3>{action.title}</h3>
            <p>{action.description}</p>
          </div>
        ))}
      </div>

    </div>
  );
}