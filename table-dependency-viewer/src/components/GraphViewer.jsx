import React, { useMemo } from "react";
import ReactFlow, {
  Background,
  Controls,
  MiniMap,
  MarkerType,
} from "reactflow";
import "reactflow/dist/style.css";
import "../style/app.css";

const X_GAP = 320;
const EXTRA_GAP = 220;
const Y_GAP = 110;

const NODE_WIDTH_BY_LAYER = {
  landing: 220,
  raw_ext: 230,
  dict_stg: 210,
  dict_dds: 210,
  stg: 240,
  ods: 260,
  dds: 300,
  dm_calc: 360,
  dm: 420,
  dm_view: 320,
  other: 240,
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
  boxShadow: "0 18px 40px rgba(3,7,18,0.45)",
};

const NODE_STYLE_BY_LAYER = {
  landing: { background: "#0f766e", color: "#ecfeff" },
  raw_ext: { background: "#155e75", color: "#ecfeff" },
  dict_stg: {
    background: "#020617",
    color: "#9ca3af",
    border: "1px dashed rgba(255,255,255,.35)",
  },
  dict_dds: {
    background: "#1e1b4b",
    color: "#c7d2fe",
    border: "1px dashed rgba(129,140,248,.4)",
  },
  stg: { background: "#334155", color: "#e5e7eb" },
  ods: { background: "#0d9488", color: "#ecfeff" },
  dds: { background: "#1d4ed8", color: "#e0f2fe" },
  dm_calc: { background: "#1f2937", color: "#e5e7eb" },
  dm: { background: "#2563eb", color: "#ffffff" },
  dm_view: { background: "#020617", color: "#e5e7eb" },
  other: { background: "#475569", color: "#f8fafc" },
};

const CENTRAL_STYLE = {
  background: "#1d4ed8",
  color: "#ffffff",
  border: "3px solid #93c5fd",
  width: 420,
  fontWeight: 700,
  textTransform: "uppercase",
};

const LEGEND_ITEMS = [
  { label: "Landing/Raw", color: NODE_STYLE_BY_LAYER.raw_ext.background },
  { label: "STG", color: NODE_STYLE_BY_LAYER.stg.background },
  { label: "ODS", color: NODE_STYLE_BY_LAYER.ods.background },
  { label: "DDS", color: NODE_STYLE_BY_LAYER.dds.background },
  { label: "DM", color: NODE_STYLE_BY_LAYER.dm.background },
  { label: "Dict", color: NODE_STYLE_BY_LAYER.dict_stg.background, dashed: true },
];

function buildGraph(centralNode, edges = [], entities = {}) {
  if (!centralNode) {
    return { nodes: [], rfEdges: [], hasUpstream: false, hasDownstream: false };
  }

  const adj = {};
  const rev = {};
  edges.forEach(({ source, target }) => {
    (adj[source] ??= []).push(target);
    (rev[target] ??= []).push(source);
  });

  const levelMap = { [centralNode]: 0 };

  const upQueue = [centralNode];
  while (upQueue.length) {
    const node = upQueue.shift();
    (rev[node] || []).forEach((parent) => {
      const nextLevel = (levelMap[node] ?? 0) - 1;
      if (!(parent in levelMap) || levelMap[parent] > nextLevel) {
        levelMap[parent] = nextLevel;
        upQueue.push(parent);
      }
    });
  }

  const downQueue = [centralNode];
  while (downQueue.length) {
    const node = downQueue.shift();
    (adj[node] || []).forEach((child) => {
      const nextLevel = (levelMap[node] ?? 0) + 1;
      if (!(child in levelMap) || levelMap[child] < nextLevel) {
        levelMap[child] = nextLevel;
        downQueue.push(child);
      }
    });
  }

  const uniqueLevels = [...new Set(Object.values(levelMap))].sort((a, b) => a - b);
  if (!uniqueLevels.includes(0)) uniqueLevels.push(0);
  uniqueLevels.sort((a, b) => a - b);
  const zeroIndex = uniqueLevels.indexOf(0);

  const levelToX = {};
  uniqueLevels.forEach((lvl, idx) => {
    const base = (idx - zeroIndex) * X_GAP;
    levelToX[lvl] = base + (lvl > 0 ? EXTRA_GAP : 0);
  });

  const columns = {};
  Object.entries(levelMap).forEach(([fqn, lvl]) => {
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
        strokeWidth: e.target === centralNode ? 2.6 : 1.4,
      },
    }));

  const hasUpstream = uniqueLevels.some((lvl) => lvl < 0);
  const hasDownstream = uniqueLevels.some((lvl) => lvl > 0);

  return { nodes, rfEdges, hasUpstream, hasDownstream };
}

export default function GraphViewer({ centralNode, edges = [], entities = {}, onNodeClick }) {
  const graph = useMemo(
    () => buildGraph(centralNode, edges, entities),
    [centralNode, edges, entities]
  );
  const isLargeGraph = graph.nodes.length > 220 || graph.rfEdges.length > 500;

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
        <span className={!graph.hasUpstream ? "dep-zone-muted" : ""}>Источники</span>
        <span>Текущая таблица</span>
        <span className={!graph.hasDownstream ? "dep-zone-muted" : ""}>Потребители</span>
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
        <div className="dep-graph-hint">Клик по узлу открывает карточку</div>
      </div>
      <div className="dep-graph-canvas">
        <ReactFlow
          nodes={graph.nodes}
          edges={graph.rfEdges}
          onNodeClick={handleNodeClick}
          nodesDraggable={false}
          zoomOnDoubleClick={false}
          onlyRenderVisibleElements
          nodesFocusable={false}
          edgesFocusable={false}
          zoomOnScroll
          panOnScroll
          panOnDrag
          minZoom={0.35}
          maxZoom={1.6}
          fitView
          fitViewOptions={{ padding: 0.35 }}
        >
          {!isLargeGraph && <MiniMap />}
          {!isLargeGraph && <Controls showInteractive={false} />}
          {!isLargeGraph && <Background gap={32} color="#0f172a" />}
        </ReactFlow>
      </div>
    </div>
  );
}
