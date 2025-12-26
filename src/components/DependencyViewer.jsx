import { useEffect, useState } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function DependencyViewer({ table, onBack }) {
  const [rows, setRows] = useState([]);

  useEffect(() => {
    if (!table) return;
    fetch(`${API_BASE}/api/dependencies?table=${table}`)
      .then(r => r.json())
      .then(setRows);
  }, [table]);

  return (
    <div className="incident-page">
      <button className="btn" onClick={onBack}>← Назад</button>

      <h2>Зависимости для {table}</h2>

      <div className="dep-grid">
        {rows.map(r => (
          <div key={`${r.schema}.${r.table_name}`} className="dep-card">
            <div className="mono">{r.schema}.{r.table_name}</div>
            <div className="muted">{r.entity_name || "—"}</div>
            <div className="muted">⏱ {r.avg_duration_minutes ?? "—"} мин</div>
          </div>
        ))}
      </div>
    </div>
  );
}
