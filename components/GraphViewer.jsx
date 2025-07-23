// src/components/GraphViewer.jsx
import React, { useEffect } from 'react';
import ReactFlow, {
  Background,
  Controls,
  MiniMap,
  useNodesState,
  useEdgesState,
  MarkerType
} from 'reactflow';
import 'reactflow/dist/style.css';
import '../style/app.css';

const getLayer = (tableName) => {
  if (tableName.startsWith("raw_ext")) return 0;
  if (tableName.startsWith("stg")) return 1;
  if (tableName.startsWith("ods")) return 2;
  if (tableName.startsWith("dds")) return 3;
  if (tableName.startsWith("dict_stg")) return 4;
  if (tableName.startsWith("dict_dds")) return 5;
  if (tableName.startsWith("dm_calc")) return 6;
  if (tableName.startsWith("dm")) return 7;
  return 8;
};

const getColor = (layer, isCentral) => {
  if (isCentral) return '#245ca6';
  const colors = [
    '#e3f2fd', '#c8e6c9', '#ffe0b2', '#f8bbd0', '#d1c4e9',
    '#f0f4c3', '#b2ebf2', '#ffcdd2', '#cfd8dc'
  ];
  return colors[layer] || '#f0f0f0';
};

export default function GraphViewer({ centralNode, edges, onNodeClick }) {
  const [rfNodes, setNodes, onNodesChange] = useNodesState([]);
  const [rfEdges, setEdges, onEdgesChange] = useEdgesState([]);

  useEffect(() => {
    const allTables = new Set();
    const grouped = {};

    edges.forEach(({ source, target }) => {
      allTables.add(source);
      allTables.add(target);
    });

    const tableList = Array.from(allTables);

    tableList.forEach((table) => {
      const layer = getLayer(table);
      if (!grouped[layer]) grouped[layer] = [];
      grouped[layer].push(table);
    });

    const nodeElements = [];
    const layerSpacingY = 140;
    const nodeSpacingX = 200;

    Object.entries(grouped).forEach(([layerStr, tables]) => {
      const layer = parseInt(layerStr, 10);
      tables.forEach((table, idx) => {
        const isCentral = table === centralNode;
        const shortLabel = table.length > 25 ? table.slice(0, 22) + '…' : table;

        nodeElements.push({
          id: table,
          data: {
            label: shortLabel
          },
          position: {
            x: layer * nodeSpacingX,
            y: idx * layerSpacingY
          },
          style: {
            background: getColor(layer, isCentral),
            color: isCentral ? 'white' : 'black',
            borderRadius: 6,
            padding: 8,
            fontWeight: isCentral ? 'bold' : 'normal',
            border: isCentral ? '2px solid #1d3a63' : '1px solid #ccc',
            cursor: 'pointer',
            fontSize: 12,
            width: 140
          },
          sourcePosition: 'right',
          targetPosition: 'left',
          draggable: false,
          selectable: false,
          className: 'graph-node',
          type: 'default',
          title: table
        });
      });
    });

    const edgeElements = edges.map(({ source, target }) => ({
      id: `${source}->${target}`,
      source,
      target,
      animated: true,
      style: { stroke: '#3578e5' },
      type: 'smoothstep',
      markerEnd: {
        type: MarkerType.ArrowClosed,
        color: '#3578e5'
      }
    }));

    setNodes(nodeElements);
    setEdges(edgeElements);
  }, [centralNode, edges]);

  const handleNodeClick = (_, node) => {
    if (onNodeClick) {
      const [schema, tableName] = node.id.split('.');
      onNodeClick(schema, tableName);
    }
  };

  return (
    <div style={{ height: 640, marginTop: 20, border: '1px solid #ccc', borderRadius: 12 }}>
      <ReactFlow
        nodes={rfNodes}
        edges={rfEdges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onNodeClick={handleNodeClick}
        defaultViewport={{ zoom: 0.75 }}
        fitViewOptions={{ padding: 0.15, includeHiddenNodes: true }}
        fitView
      >
        <MiniMap zoomable pannable />
        <Controls showInteractive={false} />
        <Background color="#eee" gap={16} />
      </ReactFlow>
    </div>
  );
}