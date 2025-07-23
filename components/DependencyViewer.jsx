import { useEffect, useState } from 'react';

export default function DependencyViewer({ table, onBack }) {
  const [results, setResults] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const fetchDependencies = async () => {
    if (!table) return;
    setLoading(true);
    setError(null);
    try {
      const response = await fetch(`http://127.0.0.1:8000/api/dependencies?table=${table}`);
      if (!response.ok) throw new Error(`Ошибка: ${response.status}`);
      const data = await response.json();

      data.sort((a, b) => {
        const parseTime = (t) => {
          if (!t) return 0;
          const [h, m, s] = t.split(':').map(Number);
          return h * 3600 + m * 60 + s;
        };
        const timeA = parseTime(a.start_time);
        const timeB = parseTime(b.start_time);
        return (timeA < 75600 ? timeA + 86400 : timeA) - (timeB < 75600 ? timeB + 86400 : timeB);
      });

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

  const uniqueEntities = [];
  const entitySet = new Set();
  results.forEach((item) => {
    const key = `${item.schema}-${item.entity_id}`;
    if (!entitySet.has(key)) {
      entitySet.add(key);
      uniqueEntities.push(item);
    }
  });

  if (!table) return null;

  return (
    <div>
      <button onClick={onBack} style={{ marginBottom: 10 }}>← Назад</button>
      <h2 className="center">Зависимости для: <span className="monospace">{table}</span></h2>

      {loading && <p className="center muted">Загрузка...</p>}
      {error && <p className="center error">Ошибка: {error}</p>}

      {uniqueEntities.length > 0 && (
        <>
          <h3>Сущности, которые надо перезапустить:</h3>
          <table>
            <thead>
              <tr>
                <th>Шаг</th>
                <th>Схема</th>
                <th>Entity ID</th>
                <th>Entity Name</th>
                <th>Время запуска</th>
              </tr>
            </thead>
            <tbody>
              {uniqueEntities.map((item, i) => (
                <tr key={i}>
                  <td>{i + 1}</td>
                  <td>{item.schema}</td>
                  <td>{item.entity_id}</td>
                  <td>{item.entity_name || '-'}</td>
                  <td>{item.start_time || '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}

      {results.length > 0 && (
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
              {results.map((item, i) => (
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
