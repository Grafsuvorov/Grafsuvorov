import { useEffect, useMemo, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function SearchPage({ onSelectTable }) {
  const [query, setQuery] = useState("");
  const [tables, setTables] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch(`${API_BASE}/api/tables?detailed=true`)
      .then((res) => res.json())
      .then((data) => {
        setTables(Array.isArray(data) ? data : []);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  const filtered = useMemo(() => {
    if (query.length < 2) return [];
    const q = query.toLowerCase();
    return tables
      .filter((item) =>
        [item.fqn, item.label, item.description, item.entity_name]
          .filter(Boolean)
          .join(" ")
          .toLowerCase()
          .includes(q)
      )
      .slice(0, 50);
  }, [query, tables]);

  return (
    <div className="page">
      <div className="card">
        <div className="card-title">Поиск зависимостей</div>

        <input
          className="input"
          type="text"
          placeholder="Введите имя таблицы..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />

        {loading && (
          <div className="muted" style={{ marginTop: 12 }}>
            Загрузка списка таблиц...
          </div>
        )}

        {!loading && query.length < 2 && (
          <div className="muted" style={{ marginTop: 12 }}>
            Введите минимум 2 символа
          </div>
        )}

        {!loading && filtered.length === 0 && query.length >= 2 && (
          <div className="muted" style={{ marginTop: 12 }}>
            Ничего не найдено
          </div>
        )}

        {filtered.length > 0 && (
          <ul className="search-results">
            {filtered.map((item) => (
              <li
                key={`${item.source}:${item.fqn}`}
                className="search-item"
                onClick={() => onSelectTable(item)}
              >
                <span className="mono">{item.fqn}</span>
                <span className="muted"> {item.source === "ohd" ? "OHD / dbt" : "Current"}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
