import { useEffect, useState } from 'react';

export default function SlowestTables() {
  const [tables, setTables] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch('http://localhost:8000/api/slowest-tables')
      .then((res) => res.json())
      .then(setTables)
      .catch(() => setError('Не удалось загрузить данные'));
  }, []);

  return (
    <div className="container">
      <h1>⏱ Топ 20 самых долгих загрузок</h1>
      {error && <div className="error">{error}</div>}
      <table>
        <thead>
          <tr>
            <th>Дата</th>
            <th>Сущность</th>
            <th>Схема</th>
            <th>Таблица</th>
            <th>Длительность (мин)</th>
          </tr>
        </thead>
        <tbody>
          {tables.map((row, i) => (
            <tr key={i}>
              <td>{row.date_id}</td>
              <td>{row.entity_name}</td>
              <td>{row.table_schema}</td>
              <td>{row.table_name}</td>
              <td>{row.duration}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}