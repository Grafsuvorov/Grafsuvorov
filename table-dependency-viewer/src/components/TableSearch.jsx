import { useState, useEffect, useMemo } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function TableSearch({ onSelectTable }) {
  const [query, setQuery] = useState("");
  const [tables, setTables] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);

    fetch(`${API_BASE}/api/tables`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Failed to load tables")))
      .then((data) => {
        if (!cancelled) {
          setTables(Array.isArray(data) ? data : []);
        }
      })
      .catch((err) => {
        if (!cancelled) setError(err);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, []);

  const filtered = useMemo(() => {
    const lower = query.trim().toLowerCase();
    if (!lower) return tables;
    return tables.filter((t) => t.toLowerCase().includes(lower));
  }, [query, tables]);

  const handleSelect = (table) => {
    if (!table) return;
    onSelectTable(table);
  };

  return (
    <div className="table-search-page">
      <div className="table-search-panel">
        <div className="table-search-head">
          <div>
            <p className="table-search-label">Tables</p>
            <h2 className="table-search-title">Find the table you need</h2>
          </div>
          <div className="table-search-count">
            <span className="table-search-count-value">{tables.length}</span>
            <span className="table-search-count-hint">in catalog</span>
          </div>
        </div>
        <div className="table-search-input-wrapper">
          <input
            type="text"
            className="table-search-input"
            placeholder="For example, stg.lips or ods.sales"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>
      </div>

      <div className="table-search-results">
        {loading && <div className="muted">Loading table list...</div>}
        {!loading && error && (
          <div className="table-search-empty">Failed to load tables</div>
        )}
        {!loading && !error && filtered.length === 0 && (
          <div className="table-search-empty">No tables match the query</div>
        )}

        {!loading && !error && filtered.length > 0 && (
          <div className="table-search-list">
            {filtered.map((name) => (
              <button
                key={name}
                className="table-search-item"
                onClick={() => handleSelect(name)}
              >
                <span className="table-search-name mono">{name}</span>
                <span className="table-search-action">Open</span>
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
