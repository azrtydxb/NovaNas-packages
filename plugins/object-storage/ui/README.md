# Object Storage — Aurora UI module

This is the React module the Aurora shell mounts as a window when the
operator opens the **Object Storage** app.

## How the Aurora shell loads it

The shell does roughly:

```ts
const mod = await import('/api/v1/plugins/object-storage/ui/main.js');
const Root = mod.default;
mountInWindow(Root, { window: { name: 'Object Storage', ... } });
```

so this module MUST default-export a React component. React and
ReactDOM are externalized — the shell provides them via an importmap.

## Layout

```
src/
├── main.tsx          — entrypoint, exports default <ObjectStorageApp/>
├── api.ts            — thin fetch wrapper around the nova-api proxy
├── ui/
│   ├── styles.css    — Aurora-style dark CSS (no Tailwind dep)
│   ├── Buckets.tsx   — bucket list + create form
│   ├── BucketDetail.tsx
│   └── Settings.tsx  — root-cred rotation, OIDC client info
└── types.ts
```

## Development

```bash
npm ci
npm run build         # produces dist/main.js (ESM) + dist/main.css
npm run lint          # tsc --noEmit
```

The build script is invoked by `tools/build-package.sh` in the
marketplace repo. The tarball ships only `dist/`; sources are excluded.

## Calling the admin API

All admin/management calls go through nova-api at
`/api/v1/plugins/object-storage/admin/*`. nova-api validates the
operator's Keycloak JWT and forwards it (bearer-passthrough) on the
upstream request to RustFS on `https://127.0.0.1:9001/rustfs/admin/`.

The S3 API on port 9000 is **not** proxied — S3 SDKs need to talk to
the daemon directly so Sig v4 works.

## Extending

Add a new tab by dropping a component into `src/ui/` and wiring it into
the tab strip in `main.tsx`. Keep the Aurora dark aesthetic: monospace
headings, subtle gradient accents, dense data tables, no toy colors.
