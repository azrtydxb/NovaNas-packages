// Types mirror the RustFS admin API surface as documented in the
// plugin's README.md. Exact shapes pinned to rustfs/console source —
// re-verify against the running daemon before each plugin release.

export interface ServerInfo {
  version: string;
  uptimeSeconds: number;
  nodeId?: string;
}

export interface Bucket {
  name: string;
  creationDate: string; // ISO-8601
  objects?: number;
  sizeBytes?: number;
}

export interface BucketStats {
  objects: number;
  sizeBytes: number;
  recentActivity: ActivityEvent[];
}

export interface ActivityEvent {
  timestamp: string;
  user: string;
  action: 'PUT' | 'GET' | 'DELETE' | 'LIST';
  key?: string;
}

export interface OidcClientInfo {
  clientId: string;
  issuer: string;
  redirectUri: string;
  groupsClaim: string;
  // Operators can rotate via the engine; this is read-only.
  secretFingerprint?: string;
}
