// Entrypoint for the object-storage Aurora window.
//
// Aurora's shell does:
//   const mod = await import('/api/v1/plugins/object-storage/ui/main.js');
//   mountInWindow(mod.default, { ... });
//
// React + ReactDOM are externalized by vite.config.ts; the shell provides
// them via an importmap. CSS is bundled in dist/main.css and the shell
// injects it into the window's shadow root.

import { useState } from 'react';
import './ui/styles.css';
import { Buckets } from './ui/Buckets';
import { BucketDetail } from './ui/BucketDetail';
import { Settings } from './ui/Settings';

type Tab = 'buckets' | 'settings';

export default function ObjectStorageApp() {
  const [tab, setTab] = useState<Tab>('buckets');
  const [selected, setSelected] = useState<string | null>(null);

  return (
    <div className="os-root">
      <header className="os-header">
        <h1>Object Storage</h1>
        <span style={{ color: 'var(--fg-dim)', font: '11px ui-monospace, monospace' }}>
          RustFS · S3-compatible · ZFS-backed
        </span>
      </header>

      <nav className="os-tabs">
        <button
          className={`os-tab ${tab === 'buckets' ? 'active' : ''}`}
          onClick={() => {
            setTab('buckets');
            setSelected(null);
          }}
        >
          Buckets
        </button>
        <button
          className={`os-tab ${tab === 'settings' ? 'active' : ''}`}
          onClick={() => {
            setTab('settings');
            setSelected(null);
          }}
        >
          Settings
        </button>
      </nav>

      <main className="os-body">
        {tab === 'buckets' &&
          (selected ? (
            <BucketDetail
              name={selected}
              onBack={() => setSelected(null)}
              onDeleted={() => setSelected(null)}
            />
          ) : (
            <Buckets onSelect={setSelected} />
          ))}
        {tab === 'settings' && <Settings />}
      </main>
    </div>
  );
}
