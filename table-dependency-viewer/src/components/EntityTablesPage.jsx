// src/components/EntityTablesPage.jsx
import { useEffect, useMemo, useRef, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export default function EntityTablesPage() {
  const location = useLocation();
  const navigate = useNavigate();

  // Resolve entityId from the URL path.
  const entityId = useMemo(() => {
    const m = location.pathname.match(/^\/entity\/(\d+)\/tables$/);
    return m ? m[1] : null;
  }, [location.pathname]);

  const [entityName] = useState(new URLSearchParams(location.search).get("name") || "");

  // Data
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState(null);

  // Filters
  const [schemaQuery, setSchemaQuery] = useState("");
  const [tableQuery, setTableQuery] = useState("");
  const [staleOnly, setStaleOnly] = useState(false);
  const [showSug, setShowSug] = useState(false);
  const [activeIdx, setActiveIdx] = useState(-1); // keyboard navigation
  const boxRef = useRef(null);
  const inputRef = useRef(null);

  // Load tables for the entity
  useEffect(() => {
    if (!entityId) return;
    setLoading(true);
    setErr(null);
    fetch(`${API_BASE}/api/entities/${entityId}/table-info`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((data) => setRows(Array.isArray(data) ? data : []))
      .catch((e) => {
        console.error(e);
        setErr("Не удалось загрузить таблицы сущности");
      })
      .finally(() => setLoading(false));
  }, [entityId]);

  // Schema list
  const allSchemas = useMemo(() => {
    const s = new Set(rows.map((r) => r.schema_name ?? r.table_schema).filter(Boolean));
    return Array.from(s).sort((a,b) => a.localeCompare(b));
  }, [rows]);

  // Typeahead suggestions
  const suggestions = useMemo(() => {
    const q = schemaQuery.trim().toLowerCase();
    let arr = allSchemas;
    if (q) {
      // rank: starts-with first, then contains
      const starts = arr.filter(s => s.toLowerCase().startsWith(q));
      const contains = arr.filter(s => !s.toLowerCase().startsWith(q) && s.toLowerCase().includes(q));
      arr = [...starts, ...contains];
    }
    return arr.slice(0, 12);
  }, [allSchemas, schemaQuery]);

  // Filter rows
  const filtered = useMemo(() => {
    const q = schemaQuery.trim().toLowerCase();
    const t = tableQuery.trim().toLowerCase();
    return rows.filter((r) => {
      const schema = (r.schema_name ?? r.table_schema ?? "").toLowerCase();
      const table = (r.tables_name ?? r.table_name ?? "").toLowerCase();
      if (q && !schema.includes(q)) return false;
      if (t && !table.includes(t)) return false;
      return true;
    });
  }, [rows, schemaQuery, tableQuery]);

  const normalizedRows = useMemo(() => {
    const now = Date.now();
    const staleHours = 24;
    return filtered.map((r) => {
      const schema = r.schema_name ?? r.table_schema ?? "—";
      const table = r.tables_name ?? r.table_name ?? "—";
      const fqn = `${schema}.${table}`;
      const lastRaw = r.last_load ?? r.table_last_load ?? null;
      const lastDate = lastRaw ? new Date(lastRaw) : null;
      const ageHours = lastDate ? Math.round((now - lastDate.getTime()) / 36e5) : null;
      const stale = ageHours !== null && ageHours > staleHours;
      return {
        ...r,
        schema,
        table,
        fqn,
        lastRaw,
        lastDate,
        ageHours,
        stale,
      };
    });
  }, [filtered]);

  const grouped = useMemo(() => {
    const map = {};
    normalizedRows.forEach((r) => {
      if (staleOnly && !r.stale) return;
      map[r.schema] ??= [];
      map[r.schema].push(r);
    });
    return Object.entries(map)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([schema, list]) => ({
        schema,
        rows: list.sort((a, b) => (b.lastDate?.getTime() || 0) - (a.lastDate?.getTime() || 0)),
      }));
  }, [normalizedRows, staleOnly]);

  const summary = useMemo(() => {
    const total = normalizedRows.length;
    const schemas = new Set(normalizedRows.map((r) => r.schema)).size;
    const staleCount = normalizedRows.filter((r) => r.stale).length;
    const freshCount = total - staleCount;
    return { total, schemas, staleCount, freshCount };
  }, [normalizedRows]);

  // Close suggestions on outside click
  useEffect(() => {
    const onClick = (e) => {
      if (boxRef.current && !boxRef.current.contains(e.target)) {
        setShowSug(false);
        setActiveIdx(-1);
      }
    };
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, []);

  // Keyboard navigation for suggestions
  const onKeyDown = (e) => {
    if (!showSug || suggestions.length === 0) {
      if (e.key === 'Escape') setShowSug(false);
      return;
    }
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActiveIdx((i) => (i + 1) % suggestions.length);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActiveIdx((i) => (i - 1 + suggestions.length) % suggestions.length);
    } else if (e.key === 'Enter') {
      if (activeIdx >= 0 && suggestions[activeIdx]) {
        e.preventDefault();
        applySuggestion(suggestions[activeIdx]);
      }
    } else if (e.key === 'Escape') {
      setShowSug(false);
      setActiveIdx(-1);
    }
  };

  const applySuggestion = (val) => {
    setSchemaQuery(val);
    setShowSug(false);
    setActiveIdx(-1);
    inputRef.current?.focus();
  };

  const clearFilter = () => {
    setSchemaQuery("");
    setTableQuery("");
    setShowSug(false);
    setActiveIdx(-1);
    inputRef.current?.focus();
  };

  return (
    <div className="container entity-page">
      <div className="entity-hero">
        <div>
          <div className="entity-title">
            {entityName ? `Сущность ${entityName}` : "Таблицы сущности"}
          </div>
          <div className="entity-subtitle">
            {entityId ? `ID: ${entityId}` : "Таблицы и последние загрузки"}
          </div>
        </div>
        <div className="entity-toolbar">
          <button className="btn btn-ghost" onClick={() => navigate("/entity_schedule")}>
            Назад к сущностям →
          </button>
        </div>
      </div>

      <section className="cc-surface">
        <div className="section-title">Сводка</div>
        <div className="entity-kpis">
          <div className="entity-kpi-card">
            <div className="entity-kpi-label">Таблицы</div>
            <div className="entity-kpi-value">{summary.total}</div>
          </div>
          <div className="entity-kpi-card">
            <div className="entity-kpi-label">Просрочены</div>
            <div className="entity-kpi-value">{summary.staleCount}</div>
          </div>
          <div className="entity-kpi-card">
            <div className="entity-kpi-label">Схемы</div>
            <div className="entity-kpi-value">{summary.schemas}</div>
          </div>
          <div className="entity-kpi-card">
            <div className="entity-kpi-label">Актуальны</div>
            <div className="entity-kpi-value">{summary.freshCount}</div>
          </div>
        </div>
      </section>

      <section className="cc-surface">
        <div className="section-title">Поиск и фильтры</div>
        <div className="entity-filter-grid">
          <input
            className="entity-search"
            placeholder="Фильтр по таблице"
            value={tableQuery}
            onChange={(e) => setTableQuery(e.target.value)}
          />
          <div ref={boxRef} className="entity-filter-suggest">
            <input
              ref={inputRef}
              type="text"
              className="entity-search"
              placeholder="Фильтр по схеме"
              value={schemaQuery}
              onChange={(e) => { setSchemaQuery(e.target.value); setShowSug(true); setActiveIdx(-1); }}
              onFocus={() => setShowSug(true)}
              onKeyDown={onKeyDown}
            />
            {schemaQuery && (
              <button
                type="button"
                onClick={clearFilter}
                className="entity-filter-clear"
                title="Очистить"
              >
                ×
              </button>
            )}
            {showSug && suggestions.length > 0 && (
              <div className="entity-filter-dropdown">
                {suggestions.map((sug, idx) => (
                  <button
                    key={sug}
                    className={`entity-filter-item ${idx === activeIdx ? "active" : ""}`}
                    onMouseDown={(e) => { e.preventDefault(); applySuggestion(sug); }}
                  >
                    {sug}
                  </button>
                ))}
              </div>
            )}
          </div>
          <div className="entity-filter-toggle">
            <button
              className={`pill ${staleOnly ? "pill-active" : ""}`}
              onClick={() => setStaleOnly((prev) => !prev)}
            >
              Только просроченные
            </button>
          </div>
        </div>

        {loading && <div className="muted">Loading…</div>}
        {err && <div className="dep-error-title">{err}</div>}

        {grouped.length === 0 && !loading && (
          <div className="muted">Ничего не найдено</div>
        )}

        {grouped.map((group) => (
          <div key={group.schema} className="entity-schema-block">
            <div className="entity-schema-header">
              <div className="entity-schema-title">{group.schema}</div>
              <div className="entity-schema-count">{group.rows.length} таблиц</div>
            </div>
            <div className="entity-table-list">
              {group.rows.map((r) => (
                <div key={r.fqn} className={`entity-table-row ${r.stale ? "entity-table-row-stale" : ""}`}>
                  <div className="entity-table-info">
                    <div className="entity-table-name mono">{r.fqn}</div>
                    <div className="muted">Загрузка: {r.lastRaw || "—"}</div>
                  </div>
                  <div className="entity-table-meta">
                    {r.stale ? (
                      <span className="stale-pill">Просрочена</span>
                    ) : (
                      <span className="ok-pill">OK</span>
                    )}
                    <span className="muted">{r.ageHours !== null ? `${r.ageHours} ч` : "нет данных"}</span>
                  </div>
                  <button
                    className="btn btn-ghost entity-table-action"
                    onClick={() => navigate(`/table/${r.schema}/${r.table}`)}
                  >
                    Карточка
                  </button>
                </div>
              ))}
            </div>
          </div>
        ))}
      </section>
    </div>
  );
}
