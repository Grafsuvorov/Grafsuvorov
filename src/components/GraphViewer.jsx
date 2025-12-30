import React, { useMemo } from "react";
import ReactFlow, {
  Background,
  Controls,
  MiniMap,
  MarkerType,
} from "reactflow";
import "reactflow/dist/style.css";

/* =========================================================
   CONFIG
   ========================================================= */

const LAYER_ORDER = [
  "landing",
  "raw_ext",
  "dict_stg",
  "stg",
  "ods",
  "dds",
  "dm_calc",
  "dm",
  "dm_view",
];

const X_GAP = 340;
const EXTRA_GAP_AFTER_DM_CALC = 180; // увеличенный разрыв dm_calc → dm
const Y_GAP = 96;

const NODE_WIDTH_BY_LAYER = {
  landing: 220,
  raw_ext: 230,
  dict_stg: 210,
  stg: 230,
  ods: 260,
  dds: 280,
  dm_calc: 360,
  dm: 420,
  dm_view: 320,
  other: 240,
};

/* =========================================================
   HELPERS
   ========================================================= */

const layerOf = (fqn) =>
  LAYER_ORDER.find((l) => fqn === l || fqn.startsWith(`${l}.`)) || "other";

const isDict = (fqn) =>
  fqn.startsWith("dict_") || fqn.includes(".dict_");

/* вывод строго как в БД */
const formatFqn = (fqn) => {
  const parts = fqn.split(".");
  if (parts.length <= 1) return fqn;
  return `${parts.slice(0, -1).join(".")}.${parts.at(-1)}`;
};

/* =========================================================
   STYLES
   ========================================================= */

const baseNodeStyle = {
  borderRadius: 12,
  fontSize: 13,
  padding: "12px 14px",
  whiteSpace: "nowrap",
  cursor: "pointer",
};

const NODE_STYLE_BY_LAYER = {
  landing: { background: "#0f766e", color: "#ecfeff" },
  raw_ext: { background: "#155e75", color: "#ecfeff" },
  dict_stg: {
    background: "#020617",
    color: "#9ca3af",
    border: "1px dashed rgba(255,255,255,.35)",
  },
  stg: { background: "#334155", color: "#e5e7eb" },
  ods: { background: "#3f4a5a", color: "#e5e7eb" },
  dds: { background: "#475569", color: "#e5e7eb" },
  dm_calc: { background: "#1f2937", color: "#e5e7eb" },
  dm: { background: "#2563eb", color: "#ffffff" },
  dm_view: { background: "#020617", color: "#e5e7eb" },
};

const CENTRAL_STYLE = {
  background: "#2563eb",
  color: "#ffffff",
  border: "2px solid #3b82f6",
  width: 460,
  fontWeight: 700,
};

/* =========================================================
   GRAPH BUILDER
   ========================================================= */

function buildGraph(centralNode, edges, entities) {
  if (!centralNode) {
    return { nodes: [], rfEdges: [] };
  }

  const adj = {};
  const rev = {};

  edges?.forEach(({ source, target }) => {
    adj[source] ??= [];
    rev[target] ??= [];
    adj[source].push(target);
    rev[target].push(source);
  });

  const collected = new Set([centralNode]);

  const dfsUp = (n) => {
    (rev[n] || []).forEach((p) => {
      if (!collected.has(p)) {
        collected.add(p);
        dfsUp(p);
      }
    });
  };

  const dfsDown = (n) => {
    (adj[n] || []).forEach((c) => {
      if (!collected.has(c)) {
        collected.add(c);
        dfsDown(c);
      }
    });
  };

  dfsUp(centralNode);
  dfsDown(centralNode);

  const layers = {};
  [...collected].forEach((fqn) => {
    const layer = layerOf(fqn);
    layers[layer] ??= [];
    layers[layer].push(fqn);
  });

  /* X координаты с увеличенным разрывом после dm_calc */
  const layerX = {};
  let accX = 0;

  LAYER_ORDER.forEach((layer) => {
    layerX[layer] = accX;
    accX += X_GAP;
    if (layer === "dm_calc") {
      accX += EXTRA_GAP_AFTER_DM_CALC;
    }
  });

  const nodeMap = {};

  Object.entries(layers).forEach(([layer, list]) => {
    list.forEach((fqn, idx) => {
      const isCentral = fqn === centralNode;
      const entityName = entities?.[fqn];

      const width = isCentral
        ? CENTRAL_STYLE.width
        : NODE_WIDTH_BY_LAYER[layer] ?? 240;

      const style = isCentral
        ? CENTRAL_STYLE
        : {
            width,
            border: "1px solid rgba(255,255,255,.18)",
            ...NODE_STYLE_BY_LAYER[layer],
          };

      nodeMap[fqn] = {
        id: fqn,
        position: {
          x: layerX[layer] ?? 0,
          y: idx * Y_GAP,
        },
        draggable: false,
        selectable: false,
        sourcePosition: "right",
        targetPosition: "left",
        data: {
          label: (
            <div title={fqn}>
              <div style={{ fontWeight: 700 }}>
                {formatFqn(fqn)}
              </div>

              {entityName && (
                <div
                  style={{
                    marginTop: 6,
                    fontSize: 10,
                    opacity: 0.7,
                  }}
                >
                  {entityName}
                </div>
              )}
            </div>
          ),
        },
        style: { ...baseNodeStyle, ...style },
      };
    });
  });

  const nodes = Object.values(nodeMap);
  const validIds = new Set(nodes.map((n) => n.id));

  const rfEdges = (edges || [])
    .filter((e) => validIds.has(e.source) && validIds.has(e.target))
    .map((e) => ({
      id: `${e.source}->${e.target}`,
      source: e.source,
      target: e.target,
      type: "smoothstep",
      markerEnd: { type: MarkerType.ArrowClosed },
      style: {
        stroke: isDict(e.source) ? "#64748b" : "#6b7280",
        strokeWidth: e.target === centralNode ? 2.4 : 1.3,
      },
    }));

  return { nodes, rfEdges };
}

/* =========================================================
   COMPONENT
   ========================================================= */

export default function GraphViewer({
  centralNode,
  edges = [],
  entities = {},
  onNodeClick,
}) {
  const graph = useMemo(
    () => buildGraph(centralNode, edges, entities),
    [centralNode, edges, entities]
  );

  const handleNodeClick = (_, node) => {
    if (!onNodeClick) return;

    const parts = node.id.split(".");
    const table = parts.pop();
    const schema = parts.join(".");

    onNodeClick(schema, table);
  };

  return (
    <div style={{ height: 740, borderRadius: 16, overflow: "hidden" }}>
      <ReactFlow
        nodes={graph.nodes}
        edges={graph.rfEdges}
        onNodeClick={handleNodeClick}
        nodesDraggable={false}
        zoomOnDoubleClick={false}

        zoomOnScroll
        panOnScroll
        panOnDrag
        minZoom={0.3}
        maxZoom={1.6}

        fitView
        fitViewOptions={{ padding: 0.35 }}
      >
        <MiniMap />
        <Controls showInteractive={false} />
        <Background gap={26} color="#1f2937" />
      </ReactFlow>
    </div>
  );
}
