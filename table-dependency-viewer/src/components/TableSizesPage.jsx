import { useEffect, useMemo, useState } from "react";

import "../style/app.css";
import { performanceApi } from "../api/performance.js";
import { sortSchemaNames } from "../utils/schemaOrder.js";

const formatBytes = (value) => {
  const bytes = Number(value || 0);
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let size = bytes;
  let unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  const digits = size >= 100 || unitIndex === 0 ? 0 : size >= 10 ? 1 : 2;
  return `${size.toFixed(digits)} ${units[unitIndex]}`;
};

export default function TableSizesPage({ onSelectTable }) {
  const [rows, setRows] = useState([]);
  const [schemas, setSchemas] = useState([]);
  const [selectedSchema, setSelectedSchema] = useState("all");
  const [limit, setLimit] = useState(30);
  const [meta, setMeta] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    setLoading(true);
    setError(null);
    performanceApi.tableSizes(limit, selectedSchema === "all" ? "" : selectedSchema)
      .then((data) => {
        setRows(Array.isArray(data?.rows) ? data.rows : []);
        setSchemas(sortSchemaNames(Array.isArray(data?.schemas) ? data.schemas : []));
        setMeta(data?.meta || null);
      })
      .catch(() => setError("Не удалось загрузить размеры таблиц"))
      .finally(() => setLoading(false));
  }, [limit, selectedSchema]);

  const summary = useMemo(() => {
    const owners = new Set(rows.map((row) => row.owner_name).filter(Boolean));
    const schemasInRows = new Set(rows.map((row) => row.table_schema).filter(Boolean));
    const totalSize = rows.reduce((sum, row) => sum + Number(row.size_bytes || 0), 0);
    return {
      owners: owners.size,
      schemas: schemasInRows.size,
      totalSize,
    };
  }, [rows]);

  const openTable = (schema, table) => {
    if (!schema || !table) return;
    onSelectTable?.({ view: "table_info", table: `${schema}.${table}` });
  };

  return (
    <div className="container cc-page slow-page">
      <section className="cc-header-zone">
        <h1>Топ таблиц по размеру</h1>
        <div className="cc-subtitle">
          Показывает самые тяжелые таблицы с указанием схемы и владельца.
        </div>
      </section>

      <section className="slow-summary">
        <div className="slow-summary-card">
          <div className="label">Таблиц в выдаче</div>
          <div className="value">{meta?.returned_rows ?? rows.length}</div>
        </div>
        <div className="slow-summary-card">
          <div className="label">Схем в выдаче</div>
          <div className="value">{summary.schemas}</div>
        </div>
        <div className="slow-summary-card">
          <div className="label">Владельцев</div>
          <div className="value">{summary.owners}</div>
        </div>
        <div className="slow-summary-card">
          <div className="label">Суммарный размер</div>
          <div className="value">{formatBytes(meta?.total_size_bytes ?? summary.totalSize)}</div>
        </div>
      </section>

      <section className="slow-controls">
        <div className="section-title">Параметры</div>
        <div className="slow-controls-row slow-entity-controls">
          <div className="slow-select-group">
            <span className="slow-select-label">Схема</span>
            <select
              className="slow-entity-select"
              value={selectedSchema}
              onChange={(event) => setSelectedSchema(event.target.value)}
            >
              <option value="all">Все схемы</option>
              {schemas.map((schemaName) => (
                <option key={schemaName} value={schemaName}>
                  {schemaName}
                </option>
              ))}
            </select>
          </div>
          <div className="slow-select-group">
            <span className="slow-select-label">TOP</span>
            {[30, 50, 100].map((size) => (
              <button
                key={size}
                className={size === limit ? "active" : ""}
                onClick={() => setLimit(size)}
              >
                {size}
              </button>
            ))}
          </div>
        </div>
      </section>

      {loading && <div className="page-loading">Загрузка размеров таблиц...</div>}
      {error && <div className="page-error">{error}</div>}
      {!loading && !error && rows.length === 0 && (
        <div className="card muted">Нет таблиц для выбранной схемы.</div>
      )}

      {!loading && !error && rows.length > 0 && (
        <section className="cc-surface">
          <div className="section-title">
            Таблицы
            <span className="section-meta">{rows.length}</span>
          </div>
          <div className="table-wrapper">
            <table className="incidents-table slow-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Схема</th>
                  <th>Таблица</th>
                  <th>Владелец</th>
                  <th>Размер</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row, index) => (
                  <tr
                    key={`${row.table_schema}.${row.table_name}.${index}`}
                    className="slow-row-click"
                    onClick={() => openTable(row.table_schema, row.table_name)}
                  >
                    <td>{index + 1}</td>
                    <td className="mono">{row.table_schema || "—"}</td>
                    <td className="mono slow-table-name" title={`${row.table_schema}.${row.table_name}`}>
                      {row.table_name || "—"}
                    </td>
                    <td>{row.owner_name || "—"}</td>
                    <td>{formatBytes(row.size_bytes)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </div>
  );
}
