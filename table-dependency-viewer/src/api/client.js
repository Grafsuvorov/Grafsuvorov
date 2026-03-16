const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

function buildUrl(path, params) {
  const url = new URL(`${API_BASE}${path}`, window.location.origin);
  if (params) {
    Object.entries(params).forEach(([key, value]) => {
      if (value === null || value === undefined || value === "") return;
      url.searchParams.set(key, String(value));
    });
  }
  return `${url.pathname}${url.search}`;
}

async function request(method, path, { params, body, headers, expect = "json" } = {}) {
  const response = await fetch(buildUrl(path, params), {
    method,
    headers: {
      ...(body ? { "Content-Type": "application/json" } : {}),
      ...(headers || {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });

  if (!response.ok) {
    let detail = `HTTP ${response.status}`;
    try {
      const data = await response.json();
      detail = data?.detail || data?.error || detail;
    } catch {
      try {
        const text = await response.text();
        if (text) detail = text;
      } catch {
        // ignore
      }
    }
    throw new Error(detail);
  }

  if (expect === "text") return response.text();
  if (expect === "response") return response;
  return response.json();
}

export const apiClient = {
  get: (path, options) => request("GET", path, options),
  post: (path, body, options) => request("POST", path, { ...(options || {}), body }),
  put: (path, body, options) => request("PUT", path, { ...(options || {}), body }),
  del: (path, options) => request("DELETE", path, options),
};

