import React, { useEffect, useRef } from "react";
import ReactFlow, {
  Background,
  Controls,
  MiniMap,
  useNodesState,
  useEdgesState,
  MarkerType,
  useReactFlow,
} from "reactflow";
import "reactflow/dist/style.css";

/* =========================
   CONFIG
========================= */

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

const X_GAP = 300;
const Y_GAP = 84;

/* =========================
   HELPERS
========================= */

const layerOf = (name) =>
  LAYER_ORDER.find((l) => name.startsWith(l)) || "other";

const isDict = (name) =>
  name.startsWith("dict_") || name.includes(".dict_");

/* =========================
   STYLES
========================= */

const baseNodeStyle = {
  borderRadius: 10,
  fontSize: 12,
  padding: "8px 12px",
  overflow: "hidden",
  whiteSpace: "nowrap",
  textOverflow: "ellipsis",
};

const NODE_STYLE_BY_LAYER = {
  landing: { background: "#0f766e", color: "#ecfeff" },
  raw_ext: { background: "#155e75", color: "#ecfeff" },
  stg: { background: "#334155", color: "#e5e7eb" },
  ods: { background: "#3f4a5a", color: "#e5e7eb" },
  dds: { background: "#475569", color: "#e5e7eb" },
  dm_calc: { background: "#1f2937", color: "#e5e7eb" },
  dm: { background: "#1f2937", color: "#e5e7eb" },
  dm_view: { background: "#020617", color: "#e5e7eb" },
  dict_stg: {
    background: "#020617",
    color: "#9ca3af",
    border: "1px dashed rgba(255,255,255,.35)",
  },
};

const CENTRAL_STYLE = {
  background: "#2563eb",
  color: "#ffffff",
  border: "2px solid #3b82f6",
  width: 260,
  fontWeight: 700,
};

/* =========================
   COMPONENT
========================= */

export default function GraphViewerInner({
  centralNode,
  edges,
  entities = {},
  onNodeClick,
}) {
  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [rfEdges, setEdges, onEdgesChange] = useEdgesState([]);

  const { fitView } = useReactFlow();
  const didFitRef = useRef(false);

  useEffect(() => {
    if (!centralNode) return;

    didFitRef.current = false;

    const adj = {};
    const rev = {};

    edges.forEach(({ source, target }) => {
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
    [...collected].forEach((n) => {
      const l = layerOf(n);
      layers[l] ??= [];
      layers[l].push(n);
    });

    const nodeMap = {};
    const layerX = {};

    LAYER_ORDER.forEach((l, i) => {
      layerX[l] = i * X_GAP;
    });

    Object.entries(layers).forEach(([layer, list]) => {
      list.forEach((n, idx) => {
        const isCentral = n === centralNode;
        const style = isCentral
          ? CENTRAL_STYLE
          : {
              width: isDict(n) ? 190 : 210,
              border: "1px solid rgba(255,255,255,.12)",
              ...NODE_STYLE_BY_LAYER[layer],
            };

        const entityName = entities[n];

        nodeMap[n] = {
          id: n,
          position: { x: layerX[layer] ?? 0, y: idx * Y_GAP },
          draggable: false,
          selectable: false,
          sourcePosition: "right",
          targetPosition: "left",
          data: {
            label: (
              <div title={n}>
                <div>{n}</div>
                {entityName && (
                  <div style={{ fontSize: 10, opacity: 0.65 }}>
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

    const nextEdges = edges
      .filter((e) => nodeMap[e.source] && nodeMap[e.target])
      .map((e) => ({
        id: `${e.source}->${e.target}`,
        source: e.source,
        target: e.target,
        type: "smoothstep",
        markerEnd: { type: MarkerType.ArrowClosed },
        style: {
          stroke: isDict(e.source) ? "#64748b" : "#6b7280",
          strokeWidth: e.target === centralNode ? 2 : 1,
        },
      }));

    setNodes(Object.values(nodeMap));
    setEdges(nextEdges);

    requestAnimationFrame(() => {
      if (!didFitRef.current) {
        fitView({ padding: 0.25 });
        didFitRef.current = true;
      }
    });
  }, [centralNode, edges, entities, fitView]);

  const handleNodeClick = (_, node) => {
    if (!onNodeClick) return;
    const [schema, table] = node.id.split(".");
    onNodeClick(schema, table);
  };

  return (
    <div style={{ height: 660, borderRadius: 14, overflow: "hidden" }}>
      <ReactFlow
        nodes={nodes}
        edges={rfEdges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onNodeClick={handleNodeClick}
      >
        <MiniMap />
        <Controls />
        <Background gap={22} color="#1f2937" />
      </ReactFlow>
    </div>
  );
}
