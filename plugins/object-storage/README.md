# Object Storage (RustFS) — NovaNAS Tier 2 plugin

S3-compatible object storage for NovaNAS, packaged as the **first Tier 2
plugin**. Powered by [RustFS](https://rustfs.com), federated to the local
Keycloak realm `novanas`, and backed by a dedicated ZFS dataset.

> This plugin **supersedes** the Tier-1-style RustFS deployment that
> currently lives in the main NovaNAS repo under `deploy/rustfs/`,
> `deploy/systemd/rustfs.service`, and
> `deploy/keycloak/create-rustfs-client.sh`. After the Tier 2 plugin
> engine lands and a live install of this plugin is verified end-to-end,
> those files will be removed in a follow-up commit on the main repo.

## What it does

- Runs the `rustfs` daemon as a systemd unit under user `rustfs:rustfs`.
- Serves the S3 API on `https://<host>:9000` (talk to it directly with
  AWS CLI, boto3, mc, rclone, …). **This port is NOT proxied by
  nova-api** — S3 SDKs use Sig v4 and must hit the daemon directly.
- Serves the management/admin surface on `https://<host>:9001/rustfs/`
  with its own embedded React console at `/rustfs/console`. The
  Aurora-mounted UI window (this plugin's React module) calls a small
  subset of the admin API through nova-api at
  `/api/v1/plugins/object-storage/admin/*` (bearer-passthrough auth).
- Federates IAM to Keycloak via OIDC. Realm roles `nova-admin`,
  `nova-operator`, `nova-viewer` map to RustFS policies `consoleAdmin`,
  `readwrite`, `readonly` respectively, via the `groups` claim emitted
  by a realm-roles-as-groups protocol mapper.
- Stores all data on `tank/objects` (ZFS, recordsize=1M,
  compression=lz4, atime=off, xattr=sa, acltype=posixacl).

## Port allocation

| Port | Bound by | Purpose | Proxied by nova-api? |
|------|----------|---------|----------------------|
| 9000 | rustfs   | S3 API (Sig v4)              | No — clients hit it directly |
| 9001 | rustfs   | Admin / web console (TLS)    | Yes — `/api/v1/plugins/object-storage/admin/*` |

Operator firewalls 9000 to whatever subnets need S3 access. Port 9001 is
only needed for direct console access; the Aurora window can call the
admin API via nova-api on 8443.

## Auto-provisioning (`needs:`)

The Tier 2 plugin engine reads `manifest.yaml`'s `needs:` block and
provisions the following before the systemd unit ever starts:

1. **ZFS dataset** `tank/objects`, mounted at
   `/var/lib/nova-plugins/object-storage/data` with NAS-friendly
   properties. See `needs/dataset.yaml`.
2. **TLS certificate** issued by the local Nova CA, CN
   `rustfs.novanas.local`, dropped into
   `/var/lib/nova-plugins/object-storage/certs/{rustfs_cert.pem,rustfs_key.pem}`.
   See `needs/tls.yaml`.
3. **Keycloak client** `rustfs` (confidential, auth-code +
   client_credentials, with audience and realm-roles-as-groups
   protocol mappers). The engine writes the rotated client secret into
   `/var/lib/nova-plugins/object-storage/etc/rustfs.env` as
   `RUSTFS_IDENTITY_OPENID_CLIENT_SECRET=…`. See
   `needs/keycloak-client.json`.

The plugin's own `deploy/install.sh` is intentionally narrow: it only
fetches the RustFS binary into the plugin's lib dir and lays down the
env file from the template if one does not already exist. All identity
and storage provisioning is the engine's job.

## Filesystem layout under `/var/lib/nova-plugins/object-storage/`

```
/var/lib/nova-plugins/object-storage/
├── bin/rustfs                   — pinned RustFS binary
├── data/                        — ZFS dataset mountpoint (tank/objects)
├── certs/                       — TLS cert + key (mode 0640, owner rustfs:rustfs)
├── etc/rustfs.env               — runtime env (engine writes OIDC secret here)
└── log/                         — stdout/stderr log files
```

## Admin API surface

The Aurora window calls a small admin/management subset through nova-api.
The exact RustFS admin paths are pinned to the
[upstream rustfs/console](https://github.com/rustfs/console) source — at
the time of writing the verified, stable surface is:

| Admin endpoint                    | Verb | Purpose |
|-----------------------------------|------|---------|
| `/rustfs/admin/v1/info`           | GET  | server info, version |
| `/rustfs/admin/v1/buckets`        | GET  | list buckets |
| `/rustfs/admin/v1/buckets/{name}` | PUT  | create bucket |
| `/rustfs/admin/v1/buckets/{name}` | DEL  | delete bucket |
| `/rustfs/admin/v1/users`          | GET  | list IAM users |
| `/rustfs/admin/v1/policies`       | GET  | list IAM policies |
| `/rustfs/admin/v1/healthz`        | GET  | health probe |

> **Caveat / known gap.** RustFS pre-1.0 has been moving the admin API
> path prefix between releases (early betas exposed `/api/v1/admin/`,
> later betas migrated to `/rustfs/admin/v1/`). Before publishing a
> 1.x.x of this plugin, verify the live paths against the pinned RustFS
> binary and update `manifest.yaml`'s `api.routes[].upstream` to match.
> The Aurora UI module reads from the proxy path
> `/api/v1/plugins/object-storage/admin/*`, so only `manifest.yaml`
> needs to change — not the UI source.

## Bearer-passthrough auth

`api.routes[].auth: bearer-passthrough` means nova-api validates the
caller's Keycloak JWT (already required for any Aurora call) and forwards
the token unchanged on the upstream request to RustFS. RustFS's OIDC
config (`RUSTFS_IDENTITY_OPENID_*`) accepts the SAME realm token because
the audience mapper makes `aud: rustfs` present.

## Uninstall

```
nova plugin uninstall object-storage          # data preserved
nova plugin uninstall object-storage --purge  # destroys tank/objects
```

The `lifecycle.preUninstall.confirm` block on the manifest is shown to
the operator before any destructive action. By default, the ZFS dataset
and every byte of object data is **preserved**. `--purge` is required
to also `zfs destroy -r tank/objects` and remove the Keycloak client.

## Build / publish

From the marketplace repo root:

```
# 1. Build the UI bundle (requires node + npm).
cd plugins/object-storage/ui
npm ci
npm run build         # produces ui/dist/main.js

# 2. Build the package tarball.
cd ../../..
./tools/build-package.sh plugins/object-storage dist/

# 3. Sign with the marketplace key (private key NOT in this repo).
./tools/sign.sh dist/object-storage-1.0.0.tar.gz

# 4. Verify the signature against the public key:
cosign verify-blob \
    --key trust/novanas-marketplace.pub \
    --signature dist/object-storage-1.0.0.tar.gz.sig \
    dist/object-storage-1.0.0.tar.gz

# 5. Publish a GitHub release + update index.json.
./tools/publish.sh dist/object-storage-1.0.0.tar.gz
```

## License

Apache-2.0. RustFS itself is Apache-2.0 (see
<https://github.com/rustfs/rustfs/blob/main/LICENSE>).
