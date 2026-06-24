import React, { useMemo, useRef, useState, useEffect } from "react";
import ReactFlow, {
  Background,
  Controls,
  MiniMap,
  MarkerType,
} from "reactflow";
import "reactflow/dist/style.css";
import "../style/app.css";

const X_GAP = 560;
const EXTRA_GAP = 320;
const Y_GAP = 210;
const DEFAULT_DEPTH = 2;

const NODE_WIDTH_BY_LAYER = {
  landing: 220,
  raw_ext: 230,
  dict_stg: 210,
  dict_ods: 220,
  dict_dds: 210,
  stg: 240,
  ods: 260,
  dds: 300,
  dm_calc: 360,
  dm: 420,
  dm_view: 320,
  other: 240,
};

const LAYER_ORDER = [
  "raw_ext",
  "landing",
  "dict_stg",
  "dict_ods",
  "dict_dds",
  "stg",
  "ods",
  "dds",
  "dm_calc",
  "dm",
  "dm_view",
  "other",
];

const layerIndexOf = (fqn) => {
  const layer = layerOf(fqn);
  const idx = LAYER_ORDER.indexOf(layer);
  return idx === -1 ? LAYER_ORDER.indexOf("other") : idx;
};

const layerOf = (fqn) => {
  if (!fqn) return "other";
  const clean = fqn.split(".")[0];
  if (clean === "dict" && fqn.includes("dict_dds")) return "dict_dds";
  if (clean === "dict") return "dict_stg";
  return Object.keys(NODE_WIDTH_BY_LAYER).find((layer) => fqn.startsWith(`${layer}.`)) || clean || "other";
};

const isDict = (fqn) => fqn?.startsWith("dict_") || fqn?.includes(".dict_");

const formatFqn = (fqn) => {
  const parts = fqn.split(".");
  if (parts.length <= 2) return fqn;
  return `${parts.slice(0, -1).join(".")}.${parts.at(-1)}`;
};

const baseNodeStyle = {
  borderRadius: 12,
  fontSize: 13,
  padding: "12px 14px",
  whiteSpace: "nowrap",
  overflow: "hidden",
  textOverflow: "ellipsis",
  cursor: "pointer",
  backdropFilter: "blur(18px)",
  boxShadow: "0 18px 40px rgba(3,7,18,0.24)",
};

const NODE_STYLE_BY_LAYER = {
  landing: { background: "linear-gradient(160deg, rgba(15,118,110,0.82), rgba(13,148,136,0.62))", color: "#ecfeff" },
  raw_ext: { background: "linear-gradient(160deg, rgba(8,145,178,0.8), rgba(14,116,144,0.62))", color: "#ecfeff" },
  dict_stg: {
    background: "linear-gradient(160deg, rgba(14,80,92,0.72), rgba(15,23,42,0.52))",
    color: "#e0f2fe",
    border: "1px dashed rgba(148,163,184,.5)",
  },
  dict_ods: {
    background: "linear-gradient(160deg, rgba(30,64,175,0.72), rgba(30,58,138,0.52))",
    color: "#e0f2fe",
    border: "1px dashed rgba(125, 211, 252, .45)",
  },
  dict_dds: {
    background: "linear-gradient(160deg, rgba(79,70,229,0.72), rgba(49,46,129,0.52))",
    color: "#c7d2fe",
    border: "1px dashed rgba(129,140,248,.4)",
  },
  stg: { background: "linear-gradient(160deg, rgba(71,85,105,0.78), rgba(51,65,85,0.56))", color: "#e5e7eb" },
  ods: { background: "linear-gradient(160deg, rgba(20,184,166,0.82), rgba(13,148,136,0.58))", color: "#ecfeff" },
  dds: { background: "linear-gradient(160deg, rgba(37,99,235,0.82), rgba(29,78,216,0.58))", color: "#e0f2fe" },
  dm_calc: { background: "linear-gradient(160deg, rgba(51,65,85,0.78), rgba(30,41,59,0.58))", color: "#e5e7eb" },
  dm: { background: "linear-gradient(160deg, rgba(251,146,60,0.88), rgba(249,115,22,0.66))", color: "#0f172a" },
  dm_view: { background: "linear-gradient(160deg, rgba(15,23,42,0.82), rgba(30,41,59,0.6))", color: "#e5e7eb" },
  other: { background: "linear-gradient(160deg, rgba(100,116,139,0.82), rgba(71,85,105,0.58))", color: "#f8fafc" },
};

const CENTRAL_STYLE = {
  background: "linear-gradient(160deg, rgba(37,99,235,0.92), rgba(59,130,246,0.72))",
  color: "#ffffff",
  border: "3px solid #93c5fd",
  width: 420,
  fontWeight: 700,
  textTransform: "uppercase",
};

const LEGEND_ITEMS = [
  { label: "Landing/Raw", color: NODE_STYLE_BY_LAYER.raw_ext.background },
  { label: "STG", color: NODE_STYLE_BY_LAYER.stg.background },
  { label: "Dict ODS", color: NODE_STYLE_BY_LAYER.dict_ods.background, dashed: true },
  { label: "ODS", color: NODE_STYLE_BY_LAYER.ods.background },
  { label: "DDS", color: NODE_STYLE_BY_LAYER.dds.background },
  { label: "DM", color: NODE_STYLE_BY_LAYER.dm.background },
  { label: "Dict", color: NODE_STYLE_BY_LAYER.dict_stg.background, dashed: true },
];

function buildGraph(
  centralNode,
  edges = [],
  entities = {},
  depthLimit = null,
  presetNodes = null,
  presetLayout = null,
  focusNodeId = null
) {
  if (!centralNode) {
    return {
      nodes: [],
      rfEdges: [],
      hasUpstream: false,
      hasDownstream: false,
      totalNodes: 0,
      totalEdges: 0,
      visibleNodes: 0,
      visibleEdges: 0,
    };
  }

  if (Array.isArray(presetNodes) && presetNodes.length && presetLayout) {
    const nodeById = Object.fromEntries(presetNodes.map((node) => [node.id, node]));
    const directUpstream = new Set();
    const directDownstream = new Set();
    if (focusNodeId) {
      edges.forEach((edge) => {
        if (edge.target === focusNodeId) directUpstream.add(edge.source);
        if (edge.source === focusNodeId) directDownstream.add(edge.target);
      });
    }
    const nodes = presetNodes.map((node) => {
      const nodeId = node.id;
      const nodeFqn = node.fqn || `${node.schema}.${node.table}`;
      const isCentral = nodeId === centralNode;
      const isFocused = nodeId === focusNodeId;
      const isNeighbor = directUpstream.has(nodeId) || directDownstream.has(nodeId);
      const layer = layerOf(nodeFqn);
      const width = node.width || (isCentral ? CENTRAL_STYLE.width : NODE_WIDTH_BY_LAYER[layer]);
      const height = node.height || 56;
      const style = isCentral
        ? CENTRAL_STYLE
        : {
            width,
            border: "1px solid rgba(255,255,255,.18)",
            ...NODE_STYLE_BY_LAYER[layer],
          };
      const emphasisStyle = focusNodeId
        ? isFocused
          ? {
              border: "2px solid rgba(250, 204, 21, 0.95)",
              boxShadow: "0 0 0 1px rgba(250, 204, 21, 0.28), 0 18px 42px rgba(3,7,18,0.34)",
            }
          : isNeighbor
            ? {
                border: directUpstream.has(fqn)
                  ? "2px solid rgba(96, 165, 250, 0.9)"
                  : "2px solid rgba(251, 146, 60, 0.9)",
                opacity: 1,
              }
            : { opacity: 0.22, filter: "saturate(0.55)" }
        : {};
      const pos = presetLayout?.[nodeId] || { x: 0, y: 0 };
      const entityName = node.entity || entities?.[nodeId];

      return {
        id: nodeId,
        position: {
          x: pos.x - width / 2,
          y: pos.y - height / 2,
        },
        draggable: false,
        selectable: false,
        sourcePosition: "right",
        targetPosition: "left",
        data: {
          schema: node.schema,
          table: node.table,
          tableId: node.table_id,
          fqn: node.fqn || `${node.schema}.${node.table}`,
          label: (
            <div title={nodeFqn}>
              <div style={{ fontWeight: 700 }}>{formatFqn(nodeFqn)}</div>
              {entityName && (
                <div style={{ marginTop: 6, fontSize: 11, opacity: 0.75 }}>{entityName}</div>
              )}
            </div>
          ),
        },
        style: { ...baseNodeStyle, ...style, ...emphasisStyle },
      };
    });

    const validIds = new Set(nodes.map((n) => n.id));
    const rfEdges = edges
      .filter((e) => validIds.has(e.source) && validIds.has(e.target))
      .map((e) => ({
        id: `${e.source}->${e.target}`,
        source: e.source,
        target: e.target,
        type: "smoothstep",
        markerEnd: { type: MarkerType.ArrowClosed },
        style: {
          stroke: focusNodeId
            ? e.target === focusNodeId
              ? "#60a5fa"
              : e.source === focusNodeId
                ? "#fb923c"
                : "#64748b"
            : e.target === centralNode
              ? "#60a5fa"
              : e.source === centralNode
                ? "#fb923c"
                : "#94a3b8",
          strokeWidth: focusNodeId
            ? e.source === focusNodeId || e.target === focusNodeId
              ? 2.2
              : 1.1
            : e.source === centralNode || e.target === centralNode
              ? 1.8
              : 1.35,
          opacity: focusNodeId
            ? e.source === focusNodeId || e.target === focusNodeId
              ? 0.96
              : 0.14
            : 0.78,
          strokeDasharray:
            Math.abs(
              layerIndexOf(nodeById[e.source]?.fqn || e.source) - layerIndexOf(nodeById[e.target]?.fqn || e.target)
            ) >= 3
              ? "6 6"
              : "0",
        },
      }));

    return {
      nodes,
      rfEdges,
      hasUpstream: true,
      hasDownstream: true,
      totalNodes: nodes.length,
      totalEdges: rfEdges.length,
      visibleNodes: nodes.length,
      visibleEdges: rfEdges.length,
    };
  }

  const adj = {};
  const rev = {};
  edges.forEach(({ source, target }) => {
    (adj[source] ??= []).push(target);
    (rev[target] ??= []).push(source);
  });

  const levelMap = { [centralNode]: 0 };

  const upQueue = [centralNode];
  for (let idx = 0; idx < upQueue.length; idx += 1) {
    const node = upQueue[idx];
    (rev[node] || []).forEach((parent) => {
      const nextLevel = (levelMap[node] ?? 0) - 1;
      if (!(parent in levelMap) || levelMap[parent] > nextLevel) {
        levelMap[parent] = nextLevel;
        upQueue.push(parent);
      }
    });
  }

  const downQueue = [centralNode];
  for (let idx = 0; idx < downQueue.length; idx += 1) {
    const node = downQueue[idx];
    (adj[node] || []).forEach((child) => {
      const nextLevel = (levelMap[node] ?? 0) + 1;
      if (!(child in levelMap) || levelMap[child] < nextLevel) {
        levelMap[child] = nextLevel;
        downQueue.push(child);
      }
    });
  }

  const totalNodes = Object.keys(levelMap).length;
  const totalEdges = edges.length;
  const inRange = (lvl) => depthLimit === null || Math.abs(lvl) <= depthLimit;
  const visibleLevelMap = Object.fromEntries(
    Object.entries(levelMap).filter(([, lvl]) => inRange(lvl))
  );
  const uniqueLevels = [...new Set(Object.values(visibleLevelMap))].sort((a, b) => a - b);
  if (!uniqueLevels.includes(0)) uniqueLevels.push(0);
  uniqueLevels.sort((a, b) => a - b);
  const zeroIndex = uniqueLevels.indexOf(0);

  const levelToX = {};
  uniqueLevels.forEach((lvl, idx) => {
    const base = (idx - zeroIndex) * X_GAP;
    levelToX[lvl] = base + (lvl > 0 ? EXTRA_GAP : 0);
  });

  const columns = {};
  Object.entries(visibleLevelMap).forEach(([fqn, lvl]) => {
    (columns[lvl] ??= []).push(fqn);
  });

  const nodes = Object.entries(columns)
    .sort(([a], [b]) => Number(a) - Number(b))
    .flatMap(([lvl, list]) => {
      const sorted = list.sort((a, b) => a.localeCompare(b));
      return sorted.map((fqn, index) => {
        const isCentral = fqn === centralNode;
        const isFocused = fqn === focusNodeId;
        const directUpstream = new Set((rev[focusNodeId] || []));
        const directDownstream = new Set((adj[focusNodeId] || []));
        const isNeighbor = directUpstream.has(fqn) || directDownstream.has(fqn);
        const layer = layerOf(fqn);
        const entityName = entities?.[fqn];
        const width = isCentral
          ? CENTRAL_STYLE.width
          : NODE_WIDTH_BY_LAYER[layer] ?? NODE_WIDTH_BY_LAYER.other;
        const style = isCentral
          ? CENTRAL_STYLE
          : {
              width,
              border: "1px solid rgba(255,255,255,.18)",
              ...NODE_STYLE_BY_LAYER[layer],
            };
        const emphasisStyle = focusNodeId
          ? isFocused
            ? {
                border: "2px solid rgba(250, 204, 21, 0.95)",
                boxShadow: "0 0 0 1px rgba(250, 204, 21, 0.28), 0 18px 42px rgba(3,7,18,0.34)",
              }
            : isNeighbor
              ? {
                  border: directUpstream.has(fqn)
                    ? "2px solid rgba(96, 165, 250, 0.9)"
                    : "2px solid rgba(251, 146, 60, 0.9)",
                  opacity: 1,
                }
              : { opacity: 0.22, filter: "saturate(0.55)" }
          : {};

        return {
          id: fqn,
          position: {
            x: levelToX[lvl] ?? 0,
            y: index * Y_GAP,
          },
          draggable: false,
          selectable: false,
          sourcePosition: "right",
          targetPosition: "left",
          data: {
            label: (
              <div title={fqn}>
                <div style={{ fontWeight: 700 }}>{formatFqn(fqn)}</div>
                {entityName && (
                  <div style={{ marginTop: 6, fontSize: 11, opacity: 0.75 }}>{entityName}</div>
                )}
              </div>
            ),
          },
          style: { ...baseNodeStyle, ...style, ...emphasisStyle },
        };
      });
    });

  const validIds = new Set(nodes.map((n) => n.id));
  const rfEdges = edges
    .filter((e) => validIds.has(e.source) && validIds.has(e.target))
    .map((e) => ({
      id: `${e.source}->${e.target}`,
      source: e.source,
      target: e.target,
      type: "smoothstep",
      markerEnd: { type: MarkerType.ArrowClosed },
      style: {
        stroke: focusNodeId
          ? e.target === focusNodeId
            ? "#60a5fa"
            : e.source === focusNodeId
              ? "#fb923c"
              : isDict(e.source)
                ? "#64748b"
                : "#6b7280"
          : isDict(e.source)
            ? "#64748b"
            : "#6b7280",
        strokeWidth: focusNodeId
          ? e.source === focusNodeId || e.target === focusNodeId
            ? 2.2
            : 1.0
          : 1.4,
        opacity: focusNodeId
          ? e.source === focusNodeId || e.target === focusNodeId
            ? 0.95
            : 0.12
          : 0.6,
        strokeDasharray:
          Math.abs(layerIndexOf(e.source) - layerIndexOf(e.target)) >= 3 ? "6 6" : "0",
      },
    }));

  const hasUpstream = uniqueLevels.some((lvl) => lvl < 0);
  const hasDownstream = uniqueLevels.some((lvl) => lvl > 0);

  return {
    nodes,
    rfEdges,
    hasUpstream,
    hasDownstream,
    totalNodes,
    totalEdges,
    visibleNodes: nodes.length,
    visibleEdges: rfEdges.length,
  };
}

export default function GraphViewer({
  centralNode,
  edges = [],
  entities = {},
  onNodeClick,
  onRequestFull,
  nodes = null,
  layout = null,
}) {
  const [depthLimit, setDepthLimit] = useState(DEFAULT_DEPTH);
  const [showAll, setShowAll] = useState(false);
  const [clickMode, setClickMode] = useState("open");
  const [focusNodeId, setFocusNodeId] = useState(null);
  const flowRef = useRef(null);
  const fitKeyRef = useRef("");
  const usePreset = Array.isArray(nodes) && nodes.length > 0 && layout;
  const graph = useMemo(
    () => buildGraph(centralNode, edges, entities, showAll ? null : depthLimit, nodes, layout, focusNodeId),
    [centralNode, edges, entities, depthLimit, showAll, nodes, layout, focusNodeId]
  );
  const isLargeGraph = graph.nodes.length > 220 || graph.rfEdges.length > 500;

  useEffect(() => {
    if (!graph.nodes.length) return;
    const key = `${centralNode}:${graph.nodes.length}:${graph.rfEdges.length}`;
    if (fitKeyRef.current === key) return;
    fitKeyRef.current = key;
    requestAnimationFrame(() => {
      flowRef.current?.fitView({ padding: 0.35, duration: 300 });
    });
  }, [centralNode, graph.nodes.length, graph.rfEdges.length]);

  const handleNodeClick = (_, node) => {
    if (clickMode === "focus") {
      setFocusNodeId((current) => (current === node.id ? null : node.id));
      return;
    }
    if (!onNodeClick) return;
    const schema = node?.data?.schema;
    const table = node?.data?.table;
    const tableId = node?.data?.tableId;
    if (schema && table) {
      onNodeClick(schema, table, tableId);
      return;
    }
    const fqn = node?.data?.fqn || node.id;
    const parts = String(fqn || "").split(".");
    const fallbackTable = parts.pop();
    const fallbackSchema = parts.join(".");
    onNodeClick(fallbackSchema, fallbackTable, tableId);
  };

  return (
    <div className="dep-graph-wrapper">
      <div className="dep-graph-zones">
        <span className={!graph.hasUpstream ? "dep-zone-muted" : ""}>Источники →</span>
        <span>Текущая таблица</span>
        <span className={!graph.hasDownstream ? "dep-zone-muted" : ""}>→ Потребители</span>
      </div>
      <div className="dep-graph-controls">
        <div className="dep-graph-count muted">
          Показано {graph.visibleNodes}/{graph.totalNodes} узлов · {graph.visibleEdges}/{graph.totalEdges} связей
        </div>
        <div className="dep-graph-actions">
          <button
            className={`btn btn-ghost ${clickMode === "focus" ? "active" : ""}`}
            onClick={() => {
              setClickMode((mode) => (mode === "open" ? "focus" : "open"));
              setFocusNodeId(null);
            }}
          >
            {clickMode === "open" ? "Клик: открыть карточку" : "Клик: подсветить связи"}
          </button>
          {focusNodeId && (
            <button className="btn btn-ghost" onClick={() => setFocusNodeId(null)}>
              Сбросить подсветку
            </button>
          )}
          {!usePreset && !showAll && (
            <button className="btn btn-ghost" onClick={() => setDepthLimit((d) => d + 1)}>
              +1 уровень
            </button>
          )}
          {!usePreset && !showAll && onRequestFull && (
            <button
              className="btn btn-secondary"
              onClick={() => {
                if (onRequestFull) onRequestFull();
                setShowAll(true);
              }}
            >
              Показать все
            </button>
          )}
          {!usePreset && showAll && (
            <button
              className="btn btn-ghost"
              onClick={() => {
                setShowAll(false);
                setDepthLimit(DEFAULT_DEPTH);
              }}
            >
              Свернуть
            </button>
          )}
        </div>
      </div>
      <div className="dep-graph-legend">
        <div className="dep-graph-legend-items">
          {LEGEND_ITEMS.map((item) => (
            <span key={item.label} className="dep-legend-item">
              <span
                className={`dep-legend-dot ${item.dashed ? "dashed" : ""}`}
                style={{ background: item.color }}
              />
              {item.label}
            </span>
          ))}
        </div>
        <div className="dep-graph-hint">
          Синие стрелки входят в выбранный узел, оранжевые выходят из него. В режиме подсветки клик выделяет только прямые связи.
        </div>
      </div>
      <div className="dep-graph-canvas">
        <ReactFlow
          nodes={graph.nodes}
          edges={graph.rfEdges}
          onNodeClick={handleNodeClick}
          onInit={(instance) => {
            flowRef.current = instance;
            instance.fitView({ padding: 0.35, duration: 0 });
          }}
          nodesDraggable={false}
          zoomOnDoubleClick={false}
          onlyRenderVisibleElements
          nodesFocusable={false}
          edgesFocusable={false}
          zoomOnScroll
          panOnScroll
          panOnDrag
          minZoom={0.2}
          maxZoom={2.0}
        >
          {!isLargeGraph && <MiniMap />}
          <Controls showInteractive={false} />
          {!isLargeGraph && <Background gap={32} color="rgba(148, 163, 184, 0.16)" />}
        </ReactFlow>
      </div>
    </div>
  );
}
