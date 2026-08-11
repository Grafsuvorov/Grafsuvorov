import { useDeferredValue, useEffect, useMemo, useState } from "react";
import "../style/app.css";
import { apiClient } from "../api/client.js";

const INITIAL_VISIBLE = 250;
const VISIBLE_STEP = 250;

export default function TableSearch({ onSelectTable }) {
  const [query, setQuery] = useState("");
  const [tables, setTables] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [visibleCount, setVisibleCount] = useState(INITIAL_VISIBLE);
  const deferredQuery = useDeferredValue(query);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);

    apiClient.getCached("/api/tables", {
      ttlMs: 10 * 60 * 1000,
      params: { detailed: true },
    })
      .then((data) => {
        if (!cancelled) {
          const normalized = (Array.isArray(data) ? data : []).map((item) => ({
            ...item,
            __search: [
              item.fqn,
              item.label,
              item.entity_name,
              item.description,
              ...(Array.isArray(item.tags) ? item.tags : []),
            ]
              .filter(Boolean)
              .join(" ")
              .toLowerCase(),
          }));
          setTables(normalized);
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
    const lower = deferredQuery.trim().toLowerCase();
    if (!lower) return tables;
    return tables.filter((item) => String(item.__search || "").includes(lower));
  }, [deferredQuery, tables]);

  useEffect(() => {
    setVisibleCount(INITIAL_VISIBLE);
  }, [deferredQuery]);

  const visibleRows = useMemo(
    () => filtered.slice(0, visibleCount),
    [filtered, visibleCount],
  );

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
            <span className="table-search-count-value">{deferredQuery.trim() ? filtered.length : tables.length}</span>
            <span className="table-search-count-hint">
              {deferredQuery.trim() ? "найдено" : "в каталоге"}
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
          <>
            <div className="table-search-list">
            {visibleRows.map((item) => (
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
            {visibleRows.length < filtered.length ? (
              <div className="table-search-actions">
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setVisibleCount((prev) => prev + VISIBLE_STEP)}
                >
                  Показать ещё {Math.min(VISIBLE_STEP, filtered.length - visibleRows.length)}
                </button>
                <div className="muted">
                  Показано {visibleRows.length} из {filtered.length}
                </div>
              </div>
            ) : null}
          </>
        )}
      </div>
    </div>
  );
}
