import { useEffect, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function DependencyViewer({ table, onBack }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!table) {
      setRows([]);
      return;
    }

    const controller = new AbortController();
    setLoading(true);
    setError(null);

    fetch(`${API_BASE}/api/dependencies?table=${encodeURIComponent(table)}`, {
      signal: controller.signal,
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.json();
      })
      .then((data) => {
        setRows(Array.isArray(data) ? data : []);
      })
      .catch((err) => {
        if (err.name === "AbortError") return;
        setError("Не удалось загрузить зависимости. Попробуйте позже.");
        console.error("DependencyViewer error", err);
      })
      .finally(() => setLoading(false));

    return () => controller.abort();
  }, [table]);

  const total = rows.length;

  return (
    <div className="incident-page">
      <div className="dep-header">
        <button className="btn" onClick={onBack}>← Назад</button>
        <div>
          <div className="dep-title">Что блокируется</div>
          <div className="dep-subtitle mono">{table || "—"}</div>
        </div>

        <div className="dep-summary">
          <div className="dep-summary-value">{total}</div>
          <div className="dep-summary-label">таблиц</div>
        </div>
      </div>

      {loading && <div className="card muted">Загрузка зависимостей...</div>}

      {error && (
        <div className="card dep-error">
          <div className="dep-error-title">Ошибка загрузки</div>
          <div className="muted">{error}</div>
        </div>
      )}

      {!loading && !error && total === 0 && (
        <div className="card dep-empty">
          <div className="dep-empty-title">Нет зависимых таблиц</div>
          <div className="dep-empty-text muted">
            Для этой таблицы зависимости не найдены.
          </div>
        </div>
      )}

      {!loading && !error && total > 0 && (
        <>
          <div className="section-title">Зависимые таблицы</div>
          <div className="dep-grid dep-grid-detailed">
            {rows.map((r) => {
              const fqn = `${r.schema}.${r.table_name}`;
              return (
                <div key={fqn} className="dep-card dep-card-rich">
                  <div className="dep-card-title mono">{fqn}</div>
                  <div className="dep-card-meta">
                    <span>{r.entity_name || "—"}</span>
                    <span>Среднее: {r.avg_duration_minutes ?? "—"} мин</span>
                  </div>
                </div>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}
