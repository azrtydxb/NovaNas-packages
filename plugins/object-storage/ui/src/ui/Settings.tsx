import { useEffect, useState } from 'react';
import { api } from '../api';
import type { OidcClientInfo, ServerInfo } from '../types';

export function Settings() {
  const [info, setInfo] = useState<ServerInfo | null>(null);
  const [oidc, setOidc] = useState<OidcClientInfo | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [rotating, setRotating] = useState(false);
  const [rotated, setRotated] = useState<{ accessKey: string; secretKey: string } | null>(null);

  useEffect(() => {
    Promise.allSettled([api.info(), api.oidcClient()]).then(([i, o]) => {
      if (i.status === 'fulfilled') setInfo(i.value);
      if (o.status === 'fulfilled') setOidc(o.value);
      if (i.status === 'rejected' && o.status === 'rejected') {
        setError(i.reason?.message ?? 'failed to load settings');
      }
    });
  }, []);

  async function onRotate() {
    if (
      !confirm(
        'Rotate the RustFS root credentials?\n\n' +
          'Any AWS CLI / boto / mc client using the existing access key will stop ' +
          'working until reconfigured with the new key.',
      )
    )
      return;
    setRotating(true);
    setError(null);
    try {
      const r = await api.rotateRootCredentials();
      setRotated(r);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setRotating(false);
    }
  }

  return (
    <div>
      {error && <div className="os-error">{error}</div>}

      <div className="os-panel">
        <h2>Server</h2>
        <dl className="os-kv">
          <dt>Version</dt>
          <dd>{info?.version ?? '—'}</dd>
          <dt>Uptime</dt>
          <dd>{info?.uptimeSeconds != null ? `${info.uptimeSeconds}s` : '—'}</dd>
          <dt>Node</dt>
          <dd>{info?.nodeId ?? '—'}</dd>
        </dl>
      </div>

      <div className="os-panel">
        <h2>OIDC client</h2>
        <dl className="os-kv">
          <dt>Client ID</dt>
          <dd>{oidc?.clientId ?? '—'}</dd>
          <dt>Issuer</dt>
          <dd>{oidc?.issuer ?? '—'}</dd>
          <dt>Redirect URI</dt>
          <dd>{oidc?.redirectUri ?? '—'}</dd>
          <dt>Groups claim</dt>
          <dd>{oidc?.groupsClaim ?? '—'}</dd>
        </dl>
        <div style={{ marginTop: 12 }}>
          <a
            className="os-btn ghost"
            href="https://192.168.10.204:8443/admin/master/console/#/novanas/users"
            target="_blank"
            rel="noreferrer"
          >
            Manage users in Keycloak →
          </a>
        </div>
      </div>

      <div className="os-panel">
        <h2>Root credentials</h2>
        <p style={{ color: 'var(--fg-dim)', fontSize: 12, marginTop: 0 }}>
          Break-glass S3 root key. Day-to-day access should use OIDC (per-user keys minted by RustFS
          when a Keycloak user logs in).
        </p>
        <button className="os-btn" onClick={onRotate} disabled={rotating}>
          {rotating ? 'Rotating…' : 'Rotate root credentials'}
        </button>
        {rotated && (
          <div className="os-panel" style={{ marginTop: 12 }}>
            <h2>New root credentials (saved once)</h2>
            <dl className="os-kv">
              <dt>Access key</dt>
              <dd>{rotated.accessKey}</dd>
              <dt>Secret key</dt>
              <dd>{rotated.secretKey}</dd>
            </dl>
            <p style={{ color: 'var(--danger)', fontSize: 12 }}>
              Copy this now — the secret will not be shown again.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
