# NovaNas-packages

The marketplace repository for **NovaNAS Tier 2 first-party plugins**.

## Tiers — quick reference

NovaNAS organises everything into three tiers; this repo holds **Tier 2 only**.

| Tier | Where it lives | Examples | Trust | Aurora chrome integration |
|---|---|---|---|---|
| **1 — Core** | [`azrtydxb/NovaNas`](https://github.com/azrtydxb/NovaNas) — bundled with the OS image | Storage, identity, observability, KubeVirt VMs | Highest, atomic with OS | Native |
| **2 — First-party plugins** | **This repo** | Object Storage (RustFS), Cloud Sync, Hyper-Backup-equivalent | We sign + version + test | Yes — gets a window in Aurora |
| **3 — Community apps** | Helm chart repos (TrueCharts, etc.); installed via `/api/v1/workloads` | Plex, Jellyfin, Nextcloud | Third-party | No — opens in a new browser tab |

Tier 2 plugins are NovaNAS-published, marketplace-installable, signed
with the marketplace key, and **integrate with the Aurora chrome** —
they extend the nova-api namespace and ship a React UI module that
mounts as a window. Tier 3 community apps cannot do those things.

## Repository layout

```
NovaNas-packages/
├── README.md                        — this file
├── index.json                       — marketplace index (machine-readable)
├── trust/
│   └── novanas-marketplace.pub      — cosign public verification key
├── plugins/                         — sources for each plugin
│   ├── object-storage/              — RustFS as a first-party plugin
│   │   ├── manifest.yaml            — plugin.yaml (declarative)
│   │   ├── README.md
│   │   ├── icon.svg
│   │   ├── deploy/                  — systemd unit OR helm chart
│   │   ├── ui/                      — React module sources
│   │   └── needs/                   — auto-provisioning specs
│   └── ...
└── tools/
    ├── build-package.sh             — tarballs sources + manifest + ui bundle
    ├── sign.sh                      — cosign sign-blob
    └── publish.sh                   — uploads tarball to GitHub Release + updates index.json
```

Binary distribution = GitHub Releases on this repo. Each plugin
version produces a release tagged `<plugin-name>-<version>` with the
signed tarball as a release asset. `index.json` references those
release URLs.

## Installation flow (operator perspective)

```text
Aurora App Center
    └─> GET /api/v1/plugins/index   (nova-api fetches index.json)
        └─> POST /api/v1/plugins {name, version}
            ├─> nova-api downloads the tarball + signature
            ├─> cosign verify-blob  --key trust/novanas-marketplace.pub
            ├─> Run manifest.yaml `needs:` (create dataset, Keycloak
            │   client, TLS cert, ...)
            ├─> Deploy via systemd or Helm
            ├─> Mount declared API routes into nova-api router
            └─> Register UI bundle for the chrome to load
```

## Signing

Packages are signed with [cosign](https://github.com/sigstore/cosign)
using the NovaNAS marketplace key. The public key
(`trust/novanas-marketplace.pub`) is baked into the OS image; nova-api
verifies every package signature before install.

## Authoring a plugin

See `docs/authoring.md` (TBD) and the `plugins/object-storage/`
reference implementation. The minimum surface:

1. `manifest.yaml` declaring deployment, needs, API routes, UI window
2. `deploy/` directory with the systemd unit or Helm chart
3. `ui/` directory with a Vite-built ESM React module
4. `icon.svg`
5. `README.md`

`tools/build-package.sh` produces a signed tarball; `tools/publish.sh`
uploads it to a GitHub Release and updates `index.json`.

## License

Apache-2.0 unless individual plugin manifests declare otherwise.
