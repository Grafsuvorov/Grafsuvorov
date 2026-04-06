import { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import GraphViewer from "./GraphViewer.jsx";
import "../style/app.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

const layerLabelFromSchema = (schema) => {
  if (!schema) return "OTHER";
  const s = schema.toLowerCase();
  if (s.startsWith("dict_")) return "DICT";
  if (s === "stg") return "STG";
  if (s === "ods") return "ODS";
  if (s === "dds") return "DDS";
  if (s === "dm_calc") return "DM_CALC";
  if (s.startsWith("dm")) return "DM";
  return s.toUpperCase();
};

export default function ImpactGraphPage() {
  const navigate = useNavigate();
  const params = useParams();
  const schema = params.schema;
  const table = params.table;
  const central = `${schema}.${table}`;

  const [depth, setDepth] = useState(3);
  const [graph, setGraph] = useState(null);
  const [summary, setSummary] = useState(null);
  const [loadingGraph, setLoadingGraph] = useState(true);
  const [loadingSummary, setLoadingSummary] = useState(true);
  const [error, setError] = useState(null);
  const [activeLayers, setActiveLayers] = useState([]);
  const [search, setSearch] = useState("");
  const [showAllTables, setShowAllTables] = useState(false);
  const [exporting, setExporting] = useState(false);

  useEffect(() => {
    if (!schema || !table) return;
    let cancelled = false;
    setLoadingGraph(true);
    setError(null);

    fetch(`${API_BASE}/api/graph/impact/${encodeURIComponent(schema)}/${encodeURIComponent(table)}?depth=${depth}`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить граф влияния")))
      .then((data) => {
        if (cancelled) return;
        setGraph(data);
        const layers = Array.from(
          new Set(
            (data.nodes || []).map((n) => layerLabelFromSchema(n.schema || n.id?.split(".")[0]))
          )
        ).sort();
        setActiveLayers(layers);
      })
      .catch((err) => {
        if (!cancelled) setError(typeof err === "string" ? err : "Не удалось загрузить граф влияния");
      })
      .finally(() => {
        if (!cancelled) setLoadingGraph(false);
      });

    return () => {
      cancelled = true;
    };
  }, [schema, table, depth]);

  useEffect(() => {
    if (!schema || !table) return;
    let cancelled = false;
    setLoadingSummary(true);

    fetch(`${API_BASE}/api/impact/summary/${encodeURIComponent(schema)}/${encodeURIComponent(table)}?depth=${depth}&limit=160`)
      .then((res) => (res.ok ? res.json() : Promise.reject("Не удалось загрузить сводку влияния")))
      .then((data) => {
        if (!cancelled) setSummary(data);
      })
      .catch(() => {
        if (!cancelled) setSummary(null);
      })
      .finally(() => {
        if (!cancelled) setLoadingSummary(false);
      });

    return () => {
      cancelled = true;
    };
  }, [schema, table, depth]);

  const availableLayers = useMemo(() => {
    if (!graph?.nodes?.length) return [];
    const layers = new Set(
      graph.nodes.map((n) => layerLabelFromSchema(n.schema || n.id?.split(".")[0]))
    );
    return Array.from(layers).sort();
  }, [graph]);

  const handleLayerToggle = (layer) => {
    setActiveLayers((prev) => {
      if (prev.includes(layer)) {
        return prev.filter((l) => l !== layer);
      }
      return [...prev, layer];
    });
  };

  const filteredGraph = useMemo(() => {
    if (!graph?.nodes?.length) return { nodes: [], edges: [] };
    const term = search.trim().toLowerCase();
    const allowedLayers = new Set(activeLayers);
    const nodes = graph.nodes.filter((n) => {
      if (n.id === central) return true;
      const layer = layerLabelFromSchema(n.schema || n.id?.split(".")[0]);
      if (allowedLayers.size && !allowedLayers.has(layer)) return false;
      if (!term) return true;
      const entityLabel = (n.entities || []).join(" ").toLowerCase();
      return (
        String(n.id || "").toLowerCase().includes(term) ||
        String(n.entity || "").toLowerCase().includes(term) ||
        entityLabel.includes(term)
      );
    });
    const nodeIds = new Set(nodes.map((n) => n.id));
    const edges = (graph.edges || []).filter(
      (e) => nodeIds.has(e.source) && nodeIds.has(e.target)
    );
    return { nodes, edges };
  }, [graph, activeLayers, search, central]);

  const exportCsv = async () => {
    if (!schema || !table || exporting) return;
    setExporting(true);
    try {
      const res = await fetch(`${API_BASE}/api/impact/list/${encodeURIComponent(schema)}/${encodeURIComponent(table)}?depth=${depth}`);
      if (!res.ok) throw new Error("Не удалось выгрузить список");
      const data = await res.json();
      const rows = Array.isArray(data.tables) ? data.tables : [];
      const header = ["table_fqn", "layer", "entities", "depth"];
      const lines = [header.join(",")];
      rows.forEach((row) => {
        const fqn = row.id || `${row.schema}.${row.table}`;
        const entities = (row.entities || []).join("|");
        const values = [
          fqn,
          row.layer || "",
          entities,
          row.depth ?? "",
        ].map((val) => `"${String(val).replaceAll("\"", "\"\"")}"`);
        lines.push(values.join(","));
      });
      const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8;" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = `impact_${schema}_${table}.csv`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    } catch (e) {
      console.error(e);
    } finally {
      setExporting(false);
    }
  };

  return (
    <div className="container cc-page">
      <section className="cc-header-zone">
        <div className="table-head-meta">
          <button
            className="btn"
            onClick={() => navigate(`/table/${encodeURIComponent(schema)}/${encodeURIComponent(table)}`)}
          >
            ← Назад к таблице
          </button>
        </div>
        <h1>Граф влияния</h1>
        <div className="cc-subtitle mono">{central}</div>
      </section>

      <section className="cc-surface">
        <div className="section-title">Сводка влияния</div>
        {loadingSummary && <div className="muted">Загрузка сводки...</div>}
        {!loadingSummary && summary && (
          <div className="impact-summary">
            <div className="impact-kpis">
              <div className="impact-kpi-card">
                <div className="impact-kpi-label">Затронутые таблицы</div>
                <div className="impact-kpi-value">{summary.total_tables ?? 0}</div>
                {summary.truncated && <div className="impact-kpi-hint">Усечено</div>}
              </div>
              <div className="impact-kpi-card">
                <div className="impact-kpi-label">Затронутые сущности</div>
                <div className="impact-kpi-value">{summary.total_entities ?? 0}</div>
                <div className="impact-kpi-hint">Глубина {summary.depth}</div>
              </div>
            </div>
            <div className="impact-lists">
              <div className="impact-list-card">
                <div className="impact-list-title">Топ сущностей</div>
                <div className="impact-tags">
                  {(summary.entities || []).slice(0, 8).map((e) => (
                    <span key={e.entity} className="impact-tag">
                      {e.entity} · {e.count}
                    </span>
                  ))}
                  {!summary.entities?.length && <span className="muted">Нет сущностей</span>}
                </div>
              </div>
              <div className="impact-list-card">
                <div className="impact-list-title">Топ слоев</div>
                <div className="impact-tags">
                  {(summary.layers || []).slice(0, 8).map((l) => (
                    <span key={l.layer} className="impact-tag">
                      {l.layer} · {l.count}
                    </span>
                  ))}
                  {!summary.layers?.length && <span className="muted">Нет слоев</span>}
                </div>
              </div>
            </div>
          </div>
        )}
        {!loadingSummary && !summary && (
          <div className="muted">Сводка недоступна.</div>
        )}
      </section>

      <section className="cc-surface">
        <div className="section-title">Управление графом</div>
        <div className="impact-controls">
          <div className="impact-control">
            <div className="impact-control-label">Глубина</div>
            <select
              className="impact-control-select"
              value={depth}
              onChange={(e) => setDepth(Number(e.target.value))}
            >
              {[2, 3, 4, 5].map((d) => (
                <option key={d} value={d}>{d}</option>
              ))}
            </select>
          </div>
          <div className="impact-control">
            <div className="impact-control-label">Слои</div>
            <div className="impact-layer-grid">
              {availableLayers.map((layer) => (
                <button
                  key={layer}
                  className={`btn btn-ghost ${activeLayers.includes(layer) ? "active" : ""}`}
                  onClick={() => handleLayerToggle(layer)}
                >
                  {layer}
                </button>
              ))}
            </div>
          </div>
          <div className="impact-control">
            <div className="impact-control-label">Фильтр</div>
            <input
              className="impact-control-input"
              placeholder="Фильтр по таблице или сущности..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <div className="impact-control">
            <div className="impact-control-label">Экспорт</div>
            <button className="btn btn-secondary" onClick={exportCsv} disabled={exporting}>
              {exporting ? "Экспорт..." : "Скачать список (CSV)"}
            </button>
          </div>
        </div>
      </section>

      <section className="cc-surface">
        <div className="section-title">
          Граф влияния
          <span className="section-meta">
            {filteredGraph.nodes.length}/{graph?.nodes?.length || 0} узлов
          </span>
        </div>
        {loadingGraph && <div className="muted">Загрузка графа...</div>}
        {error && <div className="dep-error-title">{error}</div>}
        {!loadingGraph && !error && graph?.nodes?.length ? (
          <>
            {graph.truncated && (
              <div className="card dep-error" style={{ marginBottom: 12 }}>
                <div className="dep-error-title">Граф усечён</div>
                <div className="muted">Увеличьте глубину или выгрузите список.</div>
              </div>
            )}
            <GraphViewer
              centralNode={central}
              edges={filteredGraph.edges}
              nodes={filteredGraph.nodes}
              layout={graph.layout || {}}
              onNodeClick={(s, t) =>
                navigate(
                  `/table/${encodeURIComponent(s)}/${encodeURIComponent(t)}`,
                  { state: { from: `/impact/${encodeURIComponent(schema)}/${encodeURIComponent(table)}` } }
                )
              }
            />
          </>
        ) : null}
      </section>

      {summary?.tables?.length ? (
        <section className="cc-surface">
          <div className="section-title">
            Затронутые таблицы (срез)
            <span className="section-meta">{summary.tables.length}</span>
          </div>
          <div className="impact-table-actions">
            <button className="btn btn-ghost" onClick={() => setShowAllTables((v) => !v)}>
              {showAllTables ? "Свернуть" : "Показать ещё"}
            </button>
          </div>
          <div className="impact-table">
            <div className="impact-table-head">
              <span>Таблица</span>
              <span>Сущности</span>
              <span>Глубина</span>
            </div>
            {(showAllTables ? summary.tables : summary.tables.slice(0, 30)).map((row) => (
              <div key={row.id} className="impact-table-row">
                <button
                  className="impact-table-link mono"
                  onClick={() =>
                    navigate(`/table/${encodeURIComponent(row.schema)}/${encodeURIComponent(row.table)}`)
                  }
                >
                  {row.id}
                </button>
                <span className="impact-table-entities muted">
                  {(row.entities || []).join(", ") || "—"}
                </span>
                <span className="impact-table-depth">D{row.depth ?? 0}</span>
              </div>
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}
