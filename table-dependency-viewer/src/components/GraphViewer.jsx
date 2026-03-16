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
  "dm_view",
  "other",
  "dm",
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
  hoveredNodeId = null
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
    const nodes = presetNodes.map((node) => {
      const fqn = node.id;
      const isCentral = fqn === centralNode;
      const layer = layerOf(fqn);
      const width = node.width || (isCentral ? CENTRAL_STYLE.width : NODE_WIDTH_BY_LAYER[layer]);
      const height = node.height || 56;
      const style = isCentral
        ? CENTRAL_STYLE
        : {
            width,
            border: "1px solid rgba(255,255,255,.18)",
            ...NODE_STYLE_BY_LAYER[layer],
          };
      const pos = presetLayout?.[fqn] || { x: 0, y: 0 };
      const entityName = node.entity || entities?.[fqn];

      return {
        id: fqn,
        position: {
          x: pos.x - width / 2,
          y: pos.y - height / 2,
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
        style: { ...baseNodeStyle, ...style },
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
          stroke: e.target === centralNode ? "#60a5fa" : e.source === centralNode ? "#fb923c" : "#94a3b8",
          strokeWidth: e.source === centralNode || e.target === centralNode ? 1.8 : 1.35,
          opacity: 0.78,
          strokeDasharray:
            Math.abs(layerIndexOf(e.source) - layerIndexOf(e.target)) >= 3 ? "6 6" : "0",
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
          style: { ...baseNodeStyle, ...style },
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
        stroke: isDict(e.source) ? "#64748b" : "#6b7280",
        strokeWidth: 1.4,
        opacity: 0.6,
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
  const hoveredNodeId = null;
  const flowRef = useRef(null);
  const fitKeyRef = useRef("");
  const usePreset = Array.isArray(nodes) && nodes.length > 0 && layout;
  const graph = useMemo(
    () => buildGraph(centralNode, edges, entities, showAll ? null : depthLimit, nodes, layout, hoveredNodeId),
    [centralNode, edges, entities, depthLimit, showAll, nodes, layout, hoveredNodeId]
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
    if (!onNodeClick) return;
    const parts = node.id.split(".");
    const table = parts.pop();
    const schema = parts.join(".");
    onNodeClick(schema, table);
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
        <div className="dep-graph-hint">Синие стрелки входят в текущую таблицу, оранжевые выходят из нее. Клик по узлу открывает карточку.</div>
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
