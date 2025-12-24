// src/components/TableCard.jsx
import { useEffect, useState } from "react";
import "../style/app.css";
import GraphViewer from './GraphViewer.jsx';
import GanttChart from './GanttChart.jsx';
const API_BASE = import.meta.env.VITE_API_BASE_URL;

export default function TableCard({ schema, tableName, onBack, setSchema, setTableName }) {
  const [meta, setMeta] = useState(null);
  const [error, setError] = useState(null);
  const [edges, setEdges] = useState([]);
  const [centralNode, setCentralNode] = useState("");
  const [loadingDeps, setLoadingDeps] = useState(false);
  const [showDeps, setShowDeps] = useState(false);
  const [showList, setShowList] = useState(false);
  const [showGantt, setShowGantt] = useState(false);

  useEffect(() => {
    if (!schema || !tableName) return;

    fetch(`${API_BASE}/api/card/${schema}/${tableName}`)
      .then((res) => {
        if (!res.ok) throw new Error("Ошибка загрузки метаданных");
        return res.json();
      })
      .then((data) => {
        setMeta(data);
      })
      .catch((err) => {
        console.error(err);
        setError(err.message);
      });
  }, [schema, tableName]);

  const loadDownstream = () => {
    setLoadingDeps(true);
    fetch(`${API_BASE}/api/dependencies-graph/${schema}/${tableName}`)
      .then((res) => res.ok ? res.json() : Promise.reject("Ошибка загрузки зависимостей"))
      .then(data => {
        setEdges(data.edges || []);
        setCentralNode(data.central_node || `${schema}.${tableName}`);
        setShowDeps(true);
      })
      .catch(console.error)
      .finally(() => setLoadingDeps(false));
  };

  const handleNodeClick = (newSchema, newTable) => {
    setShowDeps(false);
    setEdges([]);
    setCentralNode("");
    setSchema(newSchema);
    setTableName(newTable);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const getTableList = () => {
    const allTables = new Set([centralNode]);
    edges.forEach(e => {
      allTables.add(e.source);
      allTables.add(e.target);
    });
    return Array.from(allTables).sort();
  };

  const copyToClipboard = () => {
    const list = getTableList().join('\n');
    navigator.clipboard.writeText(list).then(() => {
      alert("Список таблиц скопирован в буфер обмена!");
    });
  };

  if (error) return <div className="error">Ошибка: {error}</div>;
  if (!meta) return <div className="loading">Загрузка...</div>;

  return (
    <div className="table-card">
      <button onClick={onBack} className="back-button">← Назад</button>
      <h2>📄 Карточка таблицы</h2>
      <p className="muted">
        Схема: <strong>{meta.table_schema}</strong> | Таблица: <strong>{meta.table_name}</strong>
      </p>

      <div className="card-section">
        <div><strong>Тип загрузки:</strong> {meta.table_load_mode}</div>
        <div><strong>Последняя успешная загрузка:</strong> {meta.last_success_time ?? "—"}</div>
        <div><strong>Среднее время загрузки:</strong> {meta.avg_duration_minutes !== null ? `${meta.avg_duration_minutes} мин` : "—"}</div>
        <div><strong>Размер таблицы:</strong> {meta.table_size_mb !== null ? `${meta.table_size_mb} MB` : "—"}</div>
        <div><strong>Ошибки:</strong> —</div>
      </div>

      <div className="card-section">
        <h3>📜 Скрипт: insert</h3>
        <pre className="script-block">{meta.sql_query_insert_init_sql || "—"}</pre>
      </div>

      <div className="card-section">
        <h3>📜 Скрипт: recreate</h3>
        <pre className="script-block">{meta.sql_query_recreate_init_sql || "—"}</pre>
      </div>

      <div className="card-section">
        <h3>📜 Скрипт: truncate</h3>
        <pre className="script-block">{meta.sql_query_truncate_sql || "—"}</pre>
      </div>

      <div className="card-section">
        <button className="btn-secondary" onClick={loadDownstream}>🔁 Построить график зависимостей</button>
        {showDeps && (
          <div>
            <h3>📈 Входящие зависимости</h3>
            {loadingDeps ? (
              <p>Загрузка...</p>
            ) : edges.length > 0 ? (
              <>
                <GraphViewer
                  centralNode={centralNode}
                  edges={edges}
                  onNodeClick={handleNodeClick}
                />
                <div style={{ marginTop: 20 }}>
                  <button
                    className="btn-secondary"
                    onClick={() => setShowList(!showList)}
                    style={{ marginRight: 10 }}
                  >
                    {showList ? "🔼 Скрыть список" : "🔽 Показать список"}
                  </button>
                  <button className="btn-secondary" onClick={copyToClipboard}>📋 Скопировать список</button>
                  {showList && (
                    <pre style={{
                      marginTop: 12,
                      background: '#f6f6f6',
                      padding: 10,
                      maxHeight: 300,
                      overflow: 'auto'
                    }}>
                      {getTableList().join('\n')}
                    </pre>
                  )}
                </div>
              </>
            ) : (
              <p>Нет зависимостей</p>
            )}
          </div>
        )}
      </div>

      <div className="card-section">
        <button className="btn-secondary" onClick={() => setShowGantt(!showGantt)}>
          📅 {showGantt ? "Скрыть диаграмму Ганта" : "Показать диаграмму Ганта"}
        </button>
        {showGantt && (
          <div style={{ marginTop: 20 }}>
            <GanttChart schema={schema} table={tableName} />
          </div>
        )}
      </div>
    </div>
  );
}
