import { useState, useEffect } from 'react';
import '../style/app.css';
const API_BASE = import.meta.env.VITE_API_BASE_URL;

export default function SearchPage({ onSelectTable }) {
  const [query, setQuery] = useState('');
  const [tables, setTables] = useState([]);
  const [filtered, setFiltered] = useState([]);

  useEffect(() => {
    fetch(`${API_BASE}/api/tables`)
      .then(res => res.json())
      .then(data => {
        setTables(data);
        setFiltered(data);
      })
      .catch(err => {
        console.error('Ошибка загрузки таблиц:', err);
      });
  }, []);

  useEffect(() => {
    const lower = query.toLowerCase();
    setFiltered(tables.filter(t => t.toLowerCase().includes(lower)));
  }, [query, tables]);

  return (
    <div className="table-search">
      <h2 className="search-header">🔍 Поиск зависимостей</h2>
      <input
        type="text"
        placeholder="Введите имя таблицы..."
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        className="search-input"
      />
      <ul className="search-results">
        {filtered.map((name, idx) => (
          <li key={idx} onClick={() => onSelectTable(name)}>{name}</li>
        ))}
      </ul>
    </div>
  );
}
