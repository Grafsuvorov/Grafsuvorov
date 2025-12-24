import { useEffect, useState } from 'react';
import '../style/app.css';
const API_BASE = import.meta.env.VITE_API_BASE_URL;

export default function DependencyViewer({ table, onBack }) {
  const [results, setResults] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const fetchDependencies = async () => {
    if (!table) return;
    setLoading(true);
    setError(null);
    try {
      const response = await fetch(`${API_BASE}/api/dependencies?table=${table}`);
      if (!response.ok) throw new Error(`Ошибка: ${response.status}`);
      const data = await response.json();

      setResults(data);
    } catch (err) {
      setError(err.message);
      setResults([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (table) fetchDependencies();
  }, [table]);

  // Уникальные сущности
  const uniqueEntities = [];
  const entitySet = new Set();
  results.forEach((item) => {
    const key = `${item.entity_id}-${item.entity_name}`;
    if (!entitySet.has(key)) {
      entitySet.add(key);
      uniqueEntities.push(item);
    }
  });

  // Уникальные таблицы
  const uniqueTables = [];
  const tableSet = new Set();
  results.forEach((item) => {
    const key = `${item.schema}.${item.table_name}`;
    if (!tableSet.has(key)) {
      tableSet.add(key);
      uniqueTables.push(item);
    }
  });

  // Сортировка после фильтрации
  const parseTime = (t) => {
    if (!t) return 0;
    const timePart = t.split(' ')[1];
    const [h, m, s] = timePart.split(':').map(Number);
    return h * 3600 + m * 60 + s;
  };

  uniqueEntities.sort((a, b) => {
    const aSec = parseTime(a.start_time);
    const bSec = parseTime(b.start_time);
    const isALate = aSec >= 21 * 3600;
    const isBLate = bSec >= 21 * 3600;
    if (isALate && !isBLate) return -1;
    if (!isALate && isBLate) return 1;
    return aSec - bSec;
  });



  if (!table) return null;

  return (
    <div>
      <button onClick={onBack} style={{ marginBottom: 10 }}>← Назад</button>
      <h2 className="center">
        Зависимости для: <span className="monospace">{table.split('.')[1]}</span>
      </h2>

      {loading && (
        <div className="loading-bar-container">
          <div className="loading-bar" />
          <p className="center muted">Ищем зависимости... расслабься и ожидай 🙂</p>
        </div>
      )}

      {error && <p className="center error">Ошибка: {error}</p>}

      {uniqueEntities.length > 0 && (
        <>
          <h3>Сущности, которые надо перезапустить:</h3>
          <table>
            <thead>
              <tr>
                <th>Шаг</th>
                <th>Entity ID</th>
                <th>Entity Name</th>
                <th>Время запуска</th>
              </tr>
            </thead>
            <tbody>
              {uniqueEntities.map((item, i) => (
                <tr key={i}>
                  <td>{i + 1}</td>
                  <td>{item.entity_id}</td>
                  <td>{item.entity_name || '-'}</td>
                  <td>{item.start_time || '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}

      {uniqueTables.length > 0 && (
        <>
          <h3>Зависимые таблицы:</h3>
          <table>
            <thead>
              <tr>
                <th>Схема</th>
                <th>Таблица</th>
                <th>Entity ID</th>
                <th>Entity Name</th>
                <th>Время запуска</th>
                <th>⏱ Среднее время загрузки (мин)</th>
              </tr>
            </thead>
            <tbody>
              {uniqueTables.map((item, i) => (
                <tr key={`${item.schema}.${item.table_name}-${i}`}>
                  <td>{item.schema}</td>
                  <td className="monospace">{item.table_name}</td>
                  <td>{item.entity_id}</td>
                  <td>{item.entity_name || '-'}</td>
                  <td>{item.start_time || '-'}</td>
                  <td>
                    {typeof item.avg_duration_minutes === 'number'
                      ? item.avg_duration_minutes.toFixed(1)
                      : '-'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
    </div>
  );
}
