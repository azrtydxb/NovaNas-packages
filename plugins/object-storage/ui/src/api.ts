// Thin fetch wrapper around the nova-api proxy for the object-storage
// admin surface. nova-api injects the operator's bearer token upstream
// (manifest.yaml api.routes[].auth: bearer-passthrough), so we just
// rely on the browser's same-origin session cookie / fetch credentials.

import type { Bucket, BucketStats, OidcClientInfo, ServerInfo } from './types';

const BASE = '/api/v1/plugins/object-storage/admin';

async function req<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    credentials: 'include',
    headers: { 'Accept': 'application/json', ...(init?.headers ?? {}) },
    ...init,
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`${res.status} ${res.statusText}: ${body || path}`);
  }
  // Some admin endpoints return 204 No Content.
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

export const api = {
  info: () => req<ServerInfo>('/v1/info'),
  health: () => req<{ status: string }>('/healthz'),

  listBuckets: () => req<{ buckets: Bucket[] }>('/v1/buckets'),
  createBucket: (name: string) =>
    req<void>(`/v1/buckets/${encodeURIComponent(name)}`, { method: 'PUT' }),
  deleteBucket: (name: string) =>
    req<void>(`/v1/buckets/${encodeURIComponent(name)}`, { method: 'DELETE' }),
  bucketStats: (name: string) =>
    req<BucketStats>(`/v1/buckets/${encodeURIComponent(name)}/stats`),

  oidcClient: () => req<OidcClientInfo>('/v1/identity/openid'),
  rotateRootCredentials: () =>
    req<{ accessKey: string; secretKey: string }>('/v1/credentials/root/rotate', {
      method: 'POST',
    }),
};
