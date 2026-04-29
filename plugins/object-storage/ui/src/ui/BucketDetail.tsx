import { useEffect, useState } from 'react';
import { api } from '../api';
import type { BucketStats } from '../types';

interface Props {
  name: string;
  onBack: () => void;
  onDeleted: () => void;
}

export function BucketDetail({ name, onBack, onDeleted }: Props) {
  const [stats, setStats] = useState<BucketStats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    api
      .bucketStats(name)
      .then((s) => {
        if (!cancelled) setStats(s);
      })
      .catch((e: Error) => {
        if (!cancelled) setError(e.message);
      });
    return () => {
      cancelled = true;
    };
  }, [name]);

  async function onDelete() {
    if (!confirm(`Delete bucket "${name}"? This cannot be undone.`)) return;
    try {
      await api.deleteBucket(name);
      onDeleted();
    } catch (e) {
      setError((e as Error).message);
    }
  }

  return (
    <div>
      <div className="os-row" style={{ marginBottom: 16 }}>
        <button className="os-btn ghost" onClick={onBack}>
          ← Buckets
        </button>
        <div className="os-grow" />
        <button className="os-btn danger" onClick={onDelete}>
          Delete bucket
        </button>
      </div>

      {error && <div className="os-error">{error}</div>}

      <div className="os-panel">
        <h2>{name}</h2>
        <dl className="os-kv">
          <dt>Objects</dt>
          <dd>{stats?.objects ?? '—'}</dd>
          <dt>Size</dt>
          <dd>{stats?.sizeBytes != null ? `${stats.sizeBytes} bytes` : '—'}</dd>
        </dl>
      </div>

      <div className="os-panel">
        <h2>Recent activity</h2>
        {!stats ? (
          <div className="os-empty">Loading…</div>
        ) : stats.recentActivity.length === 0 ? (
          <div className="os-empty">No recent activity.</div>
        ) : (
          <table className="os-table">
            <thead>
              <tr>
                <th>Time</th>
                <th>User</th>
                <th>Action</th>
                <th>Key</th>
              </tr>
            </thead>
            <tbody>
              {stats.recentActivity.map((a, i) => (
                <tr key={i}>
                  <td className="mono">{a.timestamp}</td>
                  <td className="mono">{a.user}</td>
                  <td className="mono">{a.action}</td>
                  <td className="mono">{a.key ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
