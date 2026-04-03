const fs = require("fs");
const dagre = require("dagre");

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function writeJson(filePath, data) {
  fs.writeFileSync(filePath, JSON.stringify(data));
}

function main() {
  const inputPath = process.argv[2];
  const outputPath = process.argv[3];

  if (!inputPath || !outputPath) {
    console.error("Usage: node dagre_layout.js <input.json> <output.json>");
    process.exit(1);
  }

  const payload = readJson(inputPath);
  const nodes = Array.isArray(payload.nodes) ? payload.nodes : [];
  const edges = Array.isArray(payload.edges) ? payload.edges : [];

  const g = new dagre.graphlib.Graph();
  g.setGraph({
    rankdir: payload.rankdir || "LR",
    nodesep: Number(payload.nodesep || 50),
    ranksep: Number(payload.ranksep || 120),
    marginx: Number(payload.marginx || 20),
    marginy: Number(payload.marginy || 20),
  });
  g.setDefaultEdgeLabel(() => ({}));

  nodes.forEach((n) => {
    if (!n || !n.id) return;
    g.setNode(n.id, {
      width: Number(n.width || 200),
      height: Number(n.height || 60),
    });
  });

  edges.forEach((e) => {
    if (!e || !e.source || !e.target) return;
    g.setEdge(e.source, e.target);
  });

  dagre.layout(g);

  const out = { nodes: {} };
  g.nodes().forEach((id) => {
    const node = g.node(id);
    out.nodes[id] = { x: node.x, y: node.y };
  });

  writeJson(outputPath, out);
}

main();
