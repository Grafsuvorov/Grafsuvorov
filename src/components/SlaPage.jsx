import { useEffect, useState } from "react";
const API_BASE = import.meta.env.VITE_API_BASE_URL;

export default function SlaPage() {
  const [data, setData] = useState([]);
  const [filter, setFilter] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch(`${API_BASE}/api/sla`)
      .then((res) => {
        if (!res.ok) throw new Error("Ошибка при загрузке SLA данных");
        return res.json();
      })
      .then((data) => {
        setData(data);
        setLoading(false);
      })
      .catch((err) => {
        setError(err.message);
        setLoading(false);
      });
  }, []);

  const highlight = (text, query) => {
    if (!query) return text;
    const parts = text.split(new RegExp(`(${query})`, "gi"));
    return parts.map((part, i) =>
      part.toLowerCase() === query.toLowerCase()
        ? <mark key={i}>{part}</mark>
        : part
    );
  };

  const filteredData = data
    .filter((row) =>
      row.report?.toLowerCase().includes(filter.toLowerCase()) ||
      row.original_table_name?.toLowerCase().includes(filter.toLowerCase()) ||
      row.owner_report?.toLowerCase().includes(filter.toLowerCase())
    )
    .sort((a, b) => Number(a.sla_ok) - Number(b.sla_ok));

  if (loading) return <div className="p-4">Загрузка...</div>;
  if (error) return <div className="p-4 text-red-500">Ошибка: {error}</div>;

  return (
    <div className="p-4">
      <h1 className="text-2xl font-bold mb-4">SLA мониторинг</h1>
      <input
        type="text"
        placeholder="Фильтр по таблице, отчёту или владельцу..."
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
        className="mb-4 p-2 border border-gray-300 rounded w-full"
      />
      <div className="overflow-x-auto">
        <table className="w-full table-auto border border-collapse">
          <thead className="bg-gray-100">
            <tr>
              <th className="border p-2">Отчёт</th>
              <th className="border p-2">Таблицы</th>
              <th className="border p-2">Источник</th>
              <th className="border p-2">Ответственный</th>
              <th className="border p-2">Время загрузки</th>
              <th className="border p-2">Использование</th>
              <th className="border p-2">Интервал</th>
              <th className="border p-2">SLA</th>
            </tr>
          </thead>
          <tbody>
            {filteredData.map((row, idx) => (
              <tr key={idx} className={row.sla_ok ? "" : "bg-red-100"}>
                <td className="border p-2">{highlight(row.report, filter)}</td>
                <td className="border p-2">
                  {row.tables_info.map((t, i) => (
                    <div key={i} className={t.sla_ok ? "" : "text-red-500 font-bold"}>
                      {highlight(t.table_name, filter)} — {t.table_last_load}
                    </div>
                  ))}
                </td>
                <td className="border p-2">{row.source_table}</td>
                <td className="border p-2">{highlight(row.owner_report, filter)}</td>
                <td className="border p-2">{row.load_update_table}</td>
                <td className="border p-2">{row.load_update_report}</td>
                <td className="border p-2">{row.load_interval}</td>
                <td className="border p-2 text-center font-bold">
                  <span className={row.sla_ok ? "text-green-600" : "text-red-600"}>
                    {row.sla_ok ? "✓" : "✗"}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
