// src/components/ErrorDashboard.jsx
import { useEffect, useState } from 'react';
import '../style/app.css';

export default function ErrorDashboard({ onSelectTable }) {
  const [errors, setErrors] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("http://localhost:8000/api/failures")
      .then((res) => res.json())
      .then((data) => {
        setErrors(data);
        setLoading(false);
      })
      .catch((err) => {
        console.error("Ошибка при загрузке ошибок:", err);
        setLoading(false);
      });
  }, []);

  if (loading) {
    return <div className="center">Загрузка ошибок...</div>;
  }

  if (errors.length === 0) {
    return <div className="center">Ошибки загрузки не обнаружены.</div>;
  }

  return (
    <div className="error-dashboard">
      <h2>⚠ Ошибки загрузки</h2>
      <table>
        <thead>
          <tr>
            <th>Схема</th>
            <th>Таблица</th>
            <th>Тип</th>
            <th>Сообщение об ошибке</th>
            <th>Время ошибки</th>
            <th>Последняя успешная загрузка</th>
          </tr>
        </thead>
        <tbody>
          {errors.map((err, idx) => (
            <tr
              key={idx}
              onClick={() => onSelectTable(`${err.schema}.${err.table_name}`, true)}
              style={{ cursor: 'pointer' }}
            >
              <td>{err.schema}</td>
              <td className="monospace">{err.table_name}</td>
              <td>{err.object_type}</td>
              <td className="muted">{err.error_message}</td>
              <td>{err.error_time}</td>
              <td>{err.last_success_time || '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
