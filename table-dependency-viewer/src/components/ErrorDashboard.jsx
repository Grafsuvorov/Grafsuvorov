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
        console.error("Failed to load failures:", err);
        setLoading(false);
      });
  }, []);

  if (loading) {
    return <div className="center">Loading failures...</div>;
  }

  if (errors.length === 0) {
    return <div className="center">No load failures detected.</div>;
  }

  return (
    <div className="error-dashboard">
      <h2>⚠ Load failures</h2>
      <table>
        <thead>
          <tr>
            <th>Schema</th>
            <th>Table</th>
            <th>Type</th>
            <th>Error message</th>
            <th>Error time</th>
            <th>Last successful load</th>
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
