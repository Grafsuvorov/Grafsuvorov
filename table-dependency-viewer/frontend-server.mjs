import { createServer } from "node:http";
import { request as httpRequest } from "node:http";
import { request as httpsRequest } from "node:https";
import { createReadStream, existsSync } from "node:fs";
import { stat } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const rootDir = join(__dirname, "dist");
const port = Number(process.env.PORT || 8080);
const apiOrigin = process.env.API_ORIGIN || "http://api:8000";

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".ico": "image/x-icon",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".map": "application/json; charset=utf-8",
};

function isStaticAsset(pathname) {
  return Boolean(extname(pathname));
}

function safeResolve(pathname) {
  const cleaned = pathname === "/" ? "/index.html" : pathname;
  const normalized = normalize(cleaned).replace(/^(\.\.[/\\])+/, "");
  return join(rootDir, normalized);
}

function setCacheHeaders(res, pathname) {
  if (isStaticAsset(pathname) && pathname !== "/index.html") {
    res.setHeader("Cache-Control", "public, max-age=604800, immutable");
  } else {
    res.setHeader("Cache-Control", "no-cache");
  }
}

function sendNotFound(res) {
  res.statusCode = 404;
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.end("Not found");
}

function proxyRequest(req, res) {
  const targetUrl = new URL(req.url, apiOrigin);
  const requestImpl = targetUrl.protocol === "https:" ? httpsRequest : httpRequest;
  const upstream = requestImpl(
    targetUrl,
    {
      method: req.method,
      headers: {
        ...req.headers,
        host: targetUrl.host,
        connection: "close",
      },
    },
    (upstreamRes) => {
      res.writeHead(upstreamRes.statusCode || 502, upstreamRes.headers);
      upstreamRes.pipe(res);
    }
  );

  upstream.on("error", (err) => {
    res.statusCode = 502;
    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.end(JSON.stringify({ error: "proxy_error", message: err.message }));
  });

  req.pipe(upstream);
}

async function serveFile(res, pathname) {
  let filePath = safeResolve(pathname);
  if (!existsSync(filePath)) {
    filePath = join(rootDir, "index.html");
  }
  let fileStat;
  try {
    fileStat = await stat(filePath);
  } catch {
    sendNotFound(res);
    return;
  }
  if (!fileStat.isFile()) {
    sendNotFound(res);
    return;
  }
  const contentType = MIME_TYPES[extname(filePath)] || "application/octet-stream";
  res.statusCode = 200;
  res.setHeader("Content-Type", contentType);
  res.setHeader("Content-Length", fileStat.size);
  setCacheHeaders(res, pathname);
  createReadStream(filePath).pipe(res);
}

const server = createServer(async (req, res) => {
  const pathname = new URL(req.url, `http://${req.headers.host || "localhost"}`).pathname;
  if (pathname.startsWith("/api/") || pathname.startsWith("/auth/")) {
    proxyRequest(req, res);
    return;
  }
  await serveFile(res, pathname);
});

server.listen(port, "0.0.0.0", () => {
  console.log(`frontend server listening on ${port}`);
});
