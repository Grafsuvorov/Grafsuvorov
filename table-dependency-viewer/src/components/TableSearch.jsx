import { useEffect, useMemo, useState } from "react";
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

    fetch(`${API_BASE}/api/tables?detailed=true`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить таблицы")))
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
    return tables.filter((item) => {
      const haystack = [
        item.fqn,
        item.label,
        item.entity_name,
        item.description,
        ...(Array.isArray(item.tags) ? item.tags : []),
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return haystack.includes(lower);
    });
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
            <p className="table-search-label">Таблицы</p>
            <h2 className="table-search-title">Найдите нужную таблицу</h2>
            <p className="table-search-subtitle">
              Поиск по имени таблицы, сущности, описанию и тегам.
            </p>
          </div>
          <div className="table-search-count">
            <span className="table-search-count-value">{query.trim() ? filtered.length : tables.length}</span>
            <span className="table-search-count-hint">
              {query.trim() ? "найдено" : "в каталоге"}
            </span>
          </div>
        </div>
        <div className="table-search-input-wrapper">
          <input
            type="text"
            className="table-search-input"
            placeholder="Например: dict_dds.plant_and_subsidiary или counterparty"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>
      </div>

      <div className="table-search-results">
        {loading && <div className="muted">Загрузка списка таблиц...</div>}
        {!loading && error && <div className="table-search-empty">Не удалось загрузить таблицы</div>}
        {!loading && !error && filtered.length === 0 && (
          <div className="table-search-empty">По запросу ничего не найдено</div>
        )}

        {!loading && !error && filtered.length > 0 && (
          <div className="table-search-list">
            {filtered.map((item) => (
              <button
                key={`${item.source}:${item.fqn}`}
                className="table-search-item"
                onClick={() => handleSelect(item)}
              >
                <div className="table-search-main">
                  <div className="table-search-title-block">
                    <span className="table-search-name mono">{item.fqn}</span>
                    <div className="table-search-meta">
                      <span className={`table-search-badge ${item.source === "ohd" ? "ohd" : "current"}`}>
                        {item.source === "ohd" ? "OHD / dbt" : "Current"}
                      </span>
                      <span className="table-search-entity">{item.entity_name || "—"}</span>
                    </div>
                  </div>
                  <span className="table-search-action">Открыть</span>
                </div>
                {item.description ? (
                  <div className="table-search-description">
                    {item.description}
                  </div>
                ) : null}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
