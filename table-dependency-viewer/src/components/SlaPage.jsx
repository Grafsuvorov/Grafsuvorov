// 📁 src/components/SlaPage.jsx
import { useEffect, useState } from "react";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function SlaPage() {
  const [data, setData] = useState([]);
  const [filter, setFilter] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch(`${API_BASE}/api/sla`)
      .then((res) => {
        if (!res.ok) throw new Error("Failed to load SLA data");
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

  const formatDate = (value) => {
    if (!value) return "-";
    const date = new Date(value);
    return date.toLocaleString("en-GB");
  };

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
      row.table_name?.toLowerCase().includes(filter.toLowerCase()) ||
      row.owner_report?.toLowerCase().includes(filter.toLowerCase())
    )
    .sort((a, b) => Number(a.sla_ok) - Number(b.sla_ok)); // failed first

  if (loading) return <div className="p-4">Loading...</div>;
  if (error) return <div className="p-4 text-red-500">Error: {error}</div>;

  return (
    <div className="p-4">
      <h1 className="text-2xl font-bold mb-4">SLA Monitoring</h1>

      <input
        type="text"
        placeholder="Filter by table, report, or owner..."
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
        className="mb-4 p-2 border border-gray-300 rounded w-full"
      />

      <div className="overflow-x-auto">
        <table className="w-full table-auto border border-collapse">
          <thead className="bg-gray-100">
            <tr>
              <th className="border p-2 sticky top-0 bg-gray-100">Report</th>
              <th className="border p-2 sticky top-0 bg-gray-100">Table</th>
              <th className="border p-2 sticky top-0 bg-gray-100">Source</th>
              <th className="border p-2 sticky top-0 bg-gray-100">Owner</th>
              <th className="border p-2 sticky top-0 bg-gray-100">Load time</th>
              <th className="border p-2 sticky top-0 bg-gray-100">Usage</th>
              <th className="border p-2 sticky top-0 bg-gray-100">Interval</th>
              <th className="border p-2 sticky top-0 bg-gray-100">Last load</th>
              <th className="border p-2 sticky top-0 bg-gray-100">SLA</th>
            </tr>
          </thead>
          <tbody>
            {filteredData.map((row, idx) => (
              <tr key={idx} className={row.sla_ok ? "" : "bg-red-100"}>
                <td className="border p-2">{highlight(row.report, filter)}</td>
                <td className="border p-2">{highlight(row.table_name, filter)}</td>
                <td className="border p-2">{row.source_table}</td>
                <td className="border p-2">{highlight(row.owner_report, filter)}</td>
                <td className="border p-2">{formatDate(row.load_update_table)}</td>
                <td className="border p-2">{formatDate(row.load_update_report)}</td>
                <td className="border p-2">{row.load_interval}</td>
                <td className="border p-2">{formatDate(row.table_last_load)}</td>
                <td className={`border p-2 font-bold text-center ${row.sla_ok ? "text-green-600" : "text-red-600"}`}>
                  {row.sla_ok ? "✅ Within SLA" : "❌ Breached"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
