import { useEffect, useState, useMemo } from "react";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL;

export default function DependencyViewer({ table, onBack }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const [rootSchema, rootTable] = table.split(".");

  useEffect(() => {
    if (!table) return;

    setLoading(true);
    fetch(`${API_BASE}/api/dependencies?table=${table}`)
      .then((res) => {
        if (!res.ok) throw new Error(`API error ${res.status}`);
        return res.json();
      })
      .then((data) => {
        setRows(Array.isArray(data) ? data : []);
        setLoading(false);
      })
      .catch((err) => {
        setError(err.message);
        setLoading(false);
      });
  }, [table]);

  /* ===========================
     ЗАТРОНУТЫЕ СУЩНОСТИ
     =========================== */
  const entities = useMemo(() => {
    const map = {};
    for (const r of rows) {
      if (!r.entity_id) continue;
      if (!map[r.entity_id]) {
        map[r.entity_id] = {
          entity_id: r.entity_id,
          entity_name: r.entity_name,
          start_time: r.start_time,
        };
      }
    }
    return Object.values(map);
  }, [rows]);

  /* ===========================
     CRITICAL PATH
     =========================== */
  const tables = useMemo(() => {
    return [...rows].sort((a, b) => a.step - b.step);
  }, [rows]);

  return (
    <div className="page">
      {/* BACK */}
      <button className="btn btn-secondary" onClick={onBack}>
        ← Назад к инцидентам
      </button>

      {/* HEADER */}
      <div style={{ marginTop: 20 }}>
        <h1>Инцидент: анализ последствий</h1>
        <div className="muted">
          Определение затронутых данных и рекомендуемого порядка восстановления
        </div>
      </div>

      {/* ROOT CAUSE */}
      <div
        className="card"
        style={{
          marginTop: 20,
          borderColor: "rgba(239,68,68,0.6)",
        }}
      >
        <strong>Источник инцидента</strong>
        <div className="mono" style={{ marginTop: 6 }}>
          {rootSchema}.{rootTable}
        </div>
        <div className="muted" style={{ marginTop: 4 }}>
          Таблица, на которой зафиксирована ошибка загрузки
        </div>
      </div>

      {loading && (
        <div className="muted" style={{ marginTop: 16 }}>
          Загрузка зависимостей…
        </div>
      )}

      {error && (
        <div className="card" style={{ borderColor: "var(--danger)" }}>
          <strong>Ошибка получения зависимостей</strong>
          <div className="muted">{error}</div>
        </div>
      )}

      {!loading && rows.length === 0 && !error && (
        <div className="card">
          <strong>Зависимости не обнаружены</strong>
          <div className="muted">
            Для данной таблицы downstream-зависимости отсутствуют
          </div>
        </div>
      )}

      {/* ENTITIES */}
      {entities.length > 0 && (
        <div className="card" style={{ marginTop: 20 }}>
          <strong>Что потребуется перезапустить</strong>
          <div className="muted" style={{ marginBottom: 8 }}>
            Сущности, затронутые данным инцидентом
          </div>

          <table className="table">
            <thead>
              <tr>
                <th>#</th>
                <th>Entity</th>
                <th>Последняя загрузка</th>
              </tr>
            </thead>
            <tbody>
              {entities.map((e, idx) => (
                <tr key={e.entity_id}>
                  <td>{idx + 1}</td>
                  <td>{e.entity_name}</td>
                  <td className="mono">{e.start_time ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* CRITICAL PATH */}
      {tables.length > 0 && (
        <div className="card" style={{ marginTop: 20 }}>
          <strong>Последовательность восстановления данных</strong>
          <div className="muted" style={{ marginBottom: 8 }}>
            Critical path — порядок, в котором таблицы должны быть обработаны
          </div>

          <table className="table">
            <thead>
              <tr>
                <th>Шаг</th>
                <th>Таблица</th>
                <th>Entity</th>
                <th>Среднее время</th>
              </tr>
            </thead>
            <tbody>
              {tables.map((t) => {
                let tone = "var(--text)";
                if (t.step === 1) tone = "var(--danger)";
                else if (t.step <= 3) tone = "var(--warning)";

                return (
                  <tr key={`${t.schema}.${t.table_name}`}>
                    <td style={{ color: tone, fontWeight: 600 }}>
                      {t.step}
                    </td>
                    <td className="mono" style={{ color: tone }}>
                      {t.schema}.{t.table_name}
                    </td>
                    <td>{t.entity_name ?? "—"}</td>
                    <td>
                      {t.avg_duration_minutes
                        ? `${t.avg_duration_minutes} мин`
                        : "—"}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
