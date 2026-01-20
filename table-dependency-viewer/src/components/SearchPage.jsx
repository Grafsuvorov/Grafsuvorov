import { useEffect, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL;

export default function SearchPage({ onSelectTable }) {
  const [query, setQuery] = useState("");
  const [tables, setTables] = useState([]);
  const [filtered, setFiltered] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch(`${API_BASE}/api/tables`)
      .then((res) => res.json())
      .then((data) => {
        setTables(data);
        setFiltered([]);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (query.length < 2) {
      setFiltered([]);
      return;
    }

    const q = query.toLowerCase();
    setFiltered(
      tables.filter((t) => t.toLowerCase().includes(q)).slice(0, 50)
    );
  }, [query, tables]);

  return (
    <div className="page">
      <div className="card">
        <div className="card-title">🔍 Dependency Search</div>

        <input
          className="input"
          type="text"
          placeholder="Enter table name..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />

        {loading && (
          <div className="muted" style={{ marginTop: 12 }}>
            Loading table list...
          </div>
        )}

        {!loading && query.length < 2 && (
          <div className="muted" style={{ marginTop: 12 }}>
            Type at least 2 characters
          </div>
        )}

        {!loading && filtered.length === 0 && query.length >= 2 && (
          <div className="muted" style={{ marginTop: 12 }}>
            No matches found
          </div>
        )}

        {filtered.length > 0 && (
          <ul className="search-results">
            {filtered.map((name, idx) => (
              <li
                key={idx}
                className="search-item"
                onClick={() => onSelectTable(name)}
              >
                {name}
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
