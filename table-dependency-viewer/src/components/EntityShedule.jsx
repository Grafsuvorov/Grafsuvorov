import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';

const API_BASE = import.meta.env.VITE_API_BASE_URL;

export default function EntityShedule() {
  const [entities, setEntities] = useState([]);
  const [error, setError] = useState(null);
  const [loadingEntities, setLoadingEntities] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    setLoadingEntities(true);
    fetch(`${API_BASE}/api/entities`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((data) => setEntities(Array.isArray(data) ? data : []))
      .catch(() => setError('Не удалось загрузить список сущностей'))
      .finally(() => setLoadingEntities(false));
  }, []);

  const openEntityTables = (row) => {
    const q = new URLSearchParams({ name: row.entity_name ?? '' }).toString();
    navigate(`/entity/${row.entity_id}/tables?${q}`);
  };

  return (
    <div className="container p-4">
      <h1 className="text-2xl font-semibold mb-4">Сущности</h1>
      {loadingEntities && <div className="text-sm text-gray-500 mb-2">Загрузка…</div>}
      {error && <div className="text-red-600 mb-2">{error}</div>}

      <div className="overflow-auto border rounded-lg">
        <table className="min-w-full text-sm">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left">entity_id</th>
              <th className="px-3 py-2 text-left">entity_last_load</th>
              <th className="px-3 py-2 text-left">entity_name</th>
              <th className="px-3 py-2 text-left">entity_load_interval</th>
              <th className="px-3 py-2 text-left">entity_load_status</th>
            </tr>
          </thead>
          <tbody>
            {entities.map((row, i) => (
              <tr
                key={i}
                className="border-t hover:bg-gray-50 cursor-pointer"
                onClick={() => openEntityTables(row)}
                title="Открыть таблицы сущности"
              >
                <td className="px-3 py-2">{row.entity_id}</td>
                <td className="px-3 py-2">{row.entity_last_load}</td>
                <td className="px-3 py-2">{row.entity_name}</td>
                <td className="px-3 py-2">{row.entity_load_interval}</td>
                <td className="px-3 py-2">{row.entity_load_status}</td>
              </tr>
            ))}
            {entities.length === 0 && !loadingEntities && (
              <tr>
                <td className="px-3 py-4 text-gray-500" colSpan={5}>
                  Нет данных
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}