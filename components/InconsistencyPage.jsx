import { useEffect, useState } from 'react';
export default function InconsistencyPage({ onBack }) {
  const [violations, setViolations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  useEffect(() => {
    fetch('http://localhost:8000/api/inconsistencies')
      .then(res => {
        if (!res.ok) throw new Error('Ошибка при загрузке данных');
        return res.json();
      })
      .then(data => setViolations(data))
      .catch(err => setError(err.message))
      .finally(() => setLoading(false));
  }, []);
  return (
    <div className="inconsistency-page">
      <button onClick={onBack} style={{ marginBottom: 10 }}>← Назад</button>
      <h2 className="center"> Нарушения последовательности загрузки</h2>
      {loading && <p className="center muted">Загрузка...</p>}
      {error && <p className="center error">Ошибка: {error}</p>}
      {violations.length === 0 && !loading && (
        <p className="center"> Нарушений не найдено</p>
      )}
      {violations.length > 0 && (
        <table>
          <thead>
            <tr>
              <th>Источник</th>
              <th>⏱ Последняя загрузка источника</th>
              <th>Зависимая таблица</th>
              <th>⏱ Последняя загрузка зависимой</th>
            </tr>
          </thead>
          <tbody>
            {violations.map((v, idx) => (
              <tr key={idx}>
                <td className="monospace">{v.source_schema}.{v.source_table}</td>
                <td>{v.source_last_load}</td>
                <td className="monospace">{v.dependent_schema}.{v.dependent_table}</td>
                <td>{v.dependent_last_load}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}