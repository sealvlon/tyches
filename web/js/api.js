// js/api.js
// Centralized API client with CSRF, error handling, and caching

const API_BASE = 'api/';

// Get CSRF token from meta tag
function getCsrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';
}

// Simple in-memory cache with TTL
const cache = new Map();
const CACHE_TTL = 30000; // 30 seconds default

function getCached(key) {
  const item = cache.get(key);
  if (!item) return null;
  if (Date.now() > item.expires) {
    cache.delete(key);
    return null;
  }
  return item.data;
}

function setCache(key, data, ttl = CACHE_TTL) {
  cache.set(key, { data, expires: Date.now() + ttl });
}

export function clearCache(pattern = null) {
  if (!pattern) {
    cache.clear();
    return;
  }
  for (const key of cache.keys()) {
    if (key.includes(pattern)) {
      cache.delete(key);
    }
  }
}

// Main API request function
export async function api(endpoint, options = {}) {
  const {
    method = 'GET',
    body = null,
    useCache = false,
    cacheTTL = CACHE_TTL,
    headers = {},
  } = options;

  const url = endpoint.startsWith('http') ? endpoint : `${API_BASE}${endpoint}`;
  const cacheKey = `${method}:${url}:${JSON.stringify(body)}`;

  // Check cache for GET requests
  if (method === 'GET' && useCache) {
    const cached = getCached(cacheKey);
    if (cached) {
      return { ok: true, data: cached, cached: true };
    }
  }

  const fetchOptions = {
    method,
    credentials: 'same-origin',
    headers: {
      'X-CSRF-Token': getCsrfToken(),
      ...headers,
    },
  };

  if (body && method !== 'GET') {
    fetchOptions.headers['Content-Type'] = 'application/json';
    fetchOptions.body = JSON.stringify(body);
  }

  try {
    const response = await fetch(url, fetchOptions);
    const data = await response.json().catch(() => ({}));

    if (!response.ok) {
      return {
        ok: false,
        status: response.status,
        error: data.error || `Request failed with status ${response.status}`,
        data,
      };
    }

    // Cache successful GET responses
    if (method === 'GET' && useCache) {
      setCache(cacheKey, data, cacheTTL);
    }

    return { ok: true, data, status: response.status };
  } catch (error) {
    console.error('[API] Network error:', error);
    return {
      ok: false,
      error: 'Network error. Please check your connection.',
      networkError: true,
    };
  }
}

// Convenience methods
export const get = (endpoint, options = {}) => api(endpoint, { ...options, method: 'GET' });
export const post = (endpoint, body, options = {}) => api(endpoint, { ...options, method: 'POST', body });
export const put = (endpoint, body, options = {}) => api(endpoint, { ...options, method: 'PUT', body });
export const del = (endpoint, options = {}) => api(endpoint, { ...options, method: 'DELETE' });

// Prefetch common data
export async function prefetch(endpoints) {
  return Promise.all(endpoints.map(ep => get(ep, { useCache: true })));
}

// Batch multiple API calls
export async function batch(calls) {
  return Promise.all(calls.map(({ endpoint, ...options }) => api(endpoint, options)));
}

export default { api, get, post, put, del, clearCache, prefetch, batch };

