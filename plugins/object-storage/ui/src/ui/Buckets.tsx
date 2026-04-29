import { useEffect, useState } from 'react';
import { api } from '../api';
import type { Bucket } from '../types';

interface Props {
  onSelect: (name: string) => void;
}

function formatBytes(n?: number): string {
  if (n == null) return '—';
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
  let i = 0;
  let v = n;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return `${v.toFixed(v >= 10 || i === 0 ? 0 : 1)} ${units[i]}`;
}

export function Buckets({ onSelect }: Props) {
  const [buckets, setBuckets] = useState<Bucket[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState('');

  async function load() {
    setError(null);
    try {
      const r = await api.listBuckets();
      setBuckets(r.buckets ?? []);
    } catch (e) {
      setError((e as Error).message);
      setBuckets([]);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  async function onCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!newName.trim()) return;
    setCreating(true);
    setError(null);
    try {
      await api.createBucket(newName.trim());
      setNewName('');
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setCreating(false);
    }
  }

  return (
    <div>
      {error && <div className="os-error">{error}</div>}

      <div className="os-panel">
        <h2>Create bucket</h2>
        <form className="os-row" onSubmit={onCreate}>
          <input
            className="os-input os-grow"
            placeholder="bucket-name"
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            pattern="[a-z0-9][a-z0-9.\-]{1,61}[a-z0-9]"
            required
          />
          <button className="os-btn" type="submit" disabled={creating || !newName.trim()}>
            {creating ? 'Creating…' : 'Create'}
          </button>
        </form>
      </div>

      <div className="os-panel">
        <h2>Buckets</h2>
        {buckets == null ? (
          <div className="os-empty">Loading…</div>
        ) : buckets.length === 0 ? (
          <div className="os-empty">No buckets yet.</div>
        ) : (
          <table className="os-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Created</th>
                <th>Objects</th>
                <th>Size</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {buckets.map((b) => (
                <tr key={b.name}>
                  <td className="mono">{b.name}</td>
                  <td className="mono">{new Date(b.creationDate).toISOString().slice(0, 19) + 'Z'}</td>
                  <td className="mono">{b.objects ?? '—'}</td>
                  <td className="mono">{formatBytes(b.sizeBytes)}</td>
                  <td>
                    <button className="os-btn ghost" onClick={() => onSelect(b.name)}>
                      Inspect
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
