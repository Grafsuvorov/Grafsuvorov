const API_BASE = import.meta.env.VITE_API_BASE_URL || "";
const CACHE_PREFIX = "tdv:api:";

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

function cacheKey(path, params) {
  const suffix = params ? JSON.stringify(params) : "";
  return `${CACHE_PREFIX}${path}::${suffix}`;
}

function loadCachedValue(key) {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.sessionStorage.getItem(key);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed?.expiresAt || Date.now() > parsed.expiresAt) {
      window.sessionStorage.removeItem(key);
      return null;
    }
    return parsed.value;
  } catch {
    return null;
  }
}

function saveCachedValue(key, value, ttlMs) {
  if (typeof window === "undefined" || !ttlMs) return;
  try {
    window.sessionStorage.setItem(
      key,
      JSON.stringify({
        expiresAt: Date.now() + ttlMs,
        value,
      }),
    );
  } catch {
    // ignore cache errors
  }
}

export const apiClient = {
  get: (path, options) => request("GET", path, options),
  getCached: async (path, { ttlMs = 0, params, force = false, ...options } = {}) => {
    const key = cacheKey(path, params);
    if (!force && ttlMs > 0) {
      const cached = loadCachedValue(key);
      if (cached !== null) return cached;
    }
    const value = await request("GET", path, { ...options, params });
    if (ttlMs > 0) saveCachedValue(key, value, ttlMs);
    return value;
  },
  post: (path, body, options) => request("POST", path, { ...(options || {}), body }),
  put: (path, body, options) => request("PUT", path, { ...(options || {}), body }),
  del: (path, options) => request("DELETE", path, options),
};
