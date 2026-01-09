// src/components/EntityTablesPage.jsx
import { useEffect, useMemo, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';

const API_BASE = import.meta.env.VITE_API_BASE_URL;

export default function EntityTablesPage() {
  const location = useLocation();
  const navigate = useNavigate();

  // Берём entityId из URL (regex, т.к. реального Route нет)
  const entityId = useMemo(() => {
    const m = location.pathname.match(/^\/entity\/(\d+)\/tables$/);
    return m ? m[1] : null;
  }, [location.pathname]);

  const [entityName] = useState(new URLSearchParams(location.search).get('name') || '');

  // Данные
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState(null);

  // === Фильтр ТОЛЬКО по схеме ===
  const [schemaQuery, setSchemaQuery] = useState('');
  const [showSug, setShowSug] = useState(false);
  const [activeIdx, setActiveIdx] = useState(-1); // для клавиатуры
  const boxRef = useRef(null);
  const inputRef = useRef(null);

  // Загрузка таблиц по сущности
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
        setErr('Не удалось загрузить таблицы сущности');
      })
      .finally(() => setLoading(false));
  }, [entityId]);

  // Полный список схем
  const allSchemas = useMemo(() => {
    const s = new Set(rows.map(r => r.schema_name ?? r.table_schema).filter(Boolean));
    return Array.from(s).sort((a,b) => a.localeCompare(b));
  }, [rows]);

  // Подсказки (typeahead). Пустой поиск — показываем топ-12 схем
  const suggestions = useMemo(() => {
    const q = schemaQuery.trim().toLowerCase();
    let arr = allSchemas;
    if (q) {
      // ранжирование: сначала "начинается с", затем "содержит"
      const starts = arr.filter(s => s.toLowerCase().startsWith(q));
      const contains = arr.filter(s => !s.toLowerCase().startsWith(q) && s.toLowerCase().includes(q));
      arr = [...starts, ...contains];
    }
    return arr.slice(0, 12);
  }, [allSchemas, schemaQuery]);

  // Фильтрация строк
  const filtered = useMemo(() => {
    const q = schemaQuery.trim().toLowerCase();
    if (!q) return rows;
    return rows.filter(r => (r.schema_name ?? r.table_schema ?? '').toLowerCase().includes(q));
  }, [rows, schemaQuery]);

  // Клик вне блока — закрыть подсказки
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

  // Навигация по подсказкам с клавиатуры
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
    setSchemaQuery('');
    setShowSug(false);
    setActiveIdx(-1);
    inputRef.current?.focus();
  };

  return (
    <div className="container p-4">
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-2xl font-semibold">
          Таблицы сущности {entityName ? <span className="text-blue-700">«{entityName}»</span> : (entityId ? `#${entityId}` : '')}
        </h1>
        <button
          onClick={() => navigate('/entity_schedule')}
          className="px-3 py-1 border rounded-md hover:bg-gray-50"
        >
          ← К сущностям
        </button>
      </div>

      {/* Единый фильтр по схеме — красивый typeahead без стрелок и чекбоксов */}
      <div className="mb-4">
        <label className="block text-xs text-gray-600 mb-1">Фильтр по схеме</label>
        <div ref={boxRef} className="relative">
          <div className="relative">
            <input
              ref={inputRef}
              type="text"
              className="w-full border rounded-lg px-3 py-2 pr-9 focus:outline-none focus:ring-2 focus:ring-blue-200"
              placeholder=""
              value={schemaQuery}
              onChange={(e) => { setSchemaQuery(e.target.value); setShowSug(true); setActiveIdx(-1); }}
              onFocus={() => setShowSug(true)}
              onKeyDown={onKeyDown}
            />
            {schemaQuery && (
              <button
                type="button"
                onClick={clearFilter}
                className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                title="Сбросить"
              >
                ×
              </button>
            )}
          </div>



        </div>
      </div>

      {loading && <div className="text-sm text-gray-500 mb-2">Загрузка…</div>}
      {err && <div className="text-red-600 mb-2">{err}</div>}

      {/* Таблица результатов */}
      <div className="overflow-auto border rounded-lg">
        <table className="min-w-full text-sm">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left">schema_name</th>
              <th className="px-3 py-2 text-left">table_name</th>
              <th className="px-3 py-2 text-left">last_load</th>
              <th className="px-3 py-2 text-left">entity_name</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((r, i) => {
              const schema = r.schema_name ?? r.table_schema ?? '—';
              const table  = r.tables_name ?? r.table_name ?? '—';
              const last   = r.last_load ?? r.table_last_load ?? '—';
              return (
                <tr key={`${schema}.${table}.${i}`} className="border-t">
                  <td className="px-3 py-2">{schema}</td>
                  <td className="px-3 py-2">{table}</td>
                  <td className="px-3 py-2">{last}</td>
                  <td className="px-3 py-2">{r.entity_name ?? '—'}</td>
                </tr>
              );
            })}
            {filtered.length === 0 && !loading && (
              <tr>
                <td className="px-3 py-4 text-gray-500" colSpan={4}>
                  Нет строк, подходящих под фильтр
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
