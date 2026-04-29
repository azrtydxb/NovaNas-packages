#!/bin/sh
# deploy/install.sh — plugin-aware RustFS installer.
#
# Invoked by the NovaNAS Tier 2 plugin engine AFTER it has provisioned
# the dataset, TLS cert, and Keycloak client (see manifest.yaml needs:).
# This script is intentionally narrow:
#
#   1. create the rustfs:rustfs system user/group if missing
#   2. ensure the plugin's lib directories exist with correct ownership
#   3. download the pinned RustFS release tarball, verify sha256,
#      install the binary at PLUGIN_LIB/bin/rustfs
#   4. lay down PLUGIN_LIB/etc/rustfs.env from the template if missing
#      (operator + engine edits win on re-run)
#
# The script does NOT:
#   - create ZFS datasets         (engine, via needs.dataset)
#   - issue TLS certificates       (engine, via needs.tlsCert)
#   - create Keycloak clients      (engine, via needs.oidcClient)
#   - install the systemd unit     (engine, copies deploy/rustfs.service
#                                   into /etc/systemd/system/)
#   - start the service            (engine)
#
# Environment overrides:
#   RUSTFS_VERSION   override the pinned upstream version
#   PLUGIN_LIB       plugin lib root (default /var/lib/nova-plugins/object-storage)
#   PLUGIN_DIR       plugin source dir (default: dirname of this script /..)

set -eu

RUSTFS_VERSION="${RUSTFS_VERSION:-1.0.0-beta.1}"
PLUGIN_LIB="${PLUGIN_LIB:-/var/lib/nova-plugins/object-storage}"
PLUGIN_DIR="${PLUGIN_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

ENV_TEMPLATE_SRC="${PLUGIN_DIR}/deploy/rustfs.env.template"
BIN_DST="${PLUGIN_LIB}/bin/rustfs"
ENV_FILE="${PLUGIN_LIB}/etc/rustfs.env"

log()  { printf '[install-object-storage] %s\n' "$*"; }
warn() { printf '[install-object-storage] WARN: %s\n' "$*" >&2; }
die()  { printf '[install-object-storage] ERROR: %s\n' "$*" >&2; exit 1; }

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "must run as root (use sudo)"
    fi
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_root
require_cmd curl
require_cmd unzip
require_cmd sha256sum
require_cmd install

[ -f "$ENV_TEMPLATE_SRC" ] || die "env template not found at $ENV_TEMPLATE_SRC"

case "$(uname -s)" in
    Linux) : ;;
    *) die "unsupported OS $(uname -s); RustFS releases only target Linux" ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  PKG_ARCH="x86_64-musl"  ;;
    aarch64) PKG_ARCH="aarch64-musl" ;;
    *) die "unsupported CPU arch: $ARCH" ;;
esac

PKG_NAME="rustfs-linux-${PKG_ARCH}-v${RUSTFS_VERSION}.zip"
PKG_URL="https://github.com/rustfs/rustfs/releases/download/${RUSTFS_VERSION}/${PKG_NAME}"

# ----- User & group ----------------------------------------------------------

if ! getent group rustfs >/dev/null 2>&1; then
    log "creating rustfs group"
    groupadd --system rustfs
else
    log "rustfs group already exists"
fi

if ! getent passwd rustfs >/dev/null 2>&1; then
    log "creating rustfs system user"
    useradd --system --gid rustfs \
        --home-dir "$PLUGIN_LIB" \
        --shell /usr/sbin/nologin \
        --comment "NovaNAS RustFS object storage" \
        rustfs
else
    log "rustfs user already exists"
fi

# ----- Directories -----------------------------------------------------------

log "ensuring plugin directories under $PLUGIN_LIB"
install -d -m 0750 -o rustfs -g rustfs "$PLUGIN_LIB"
install -d -m 0755 -o root   -g root   "$PLUGIN_LIB/bin"
install -d -m 0755 -o root   -g rustfs "$PLUGIN_LIB/etc"
install -d -m 0750 -o rustfs -g rustfs "$PLUGIN_LIB/log"
# data/ + certs/ are created and populated by the engine via needs:.
# We do NOT chown them here.
install -d -m 0750 -o rustfs -g rustfs "$PLUGIN_LIB/data" 2>/dev/null || true
install -d -m 0750 -o rustfs -g rustfs "$PLUGIN_LIB/certs" 2>/dev/null || true

# ----- Download + install binary --------------------------------------------

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

log "downloading $PKG_URL"
curl -fsSL --retry 3 -o "$TMP_DIR/$PKG_NAME" "$PKG_URL" \
    || die "failed to download $PKG_URL"

if curl -fsSL --retry 3 -o "$TMP_DIR/$PKG_NAME.sha256" "$PKG_URL.sha256" 2>/dev/null; then
    log "verifying sha256 checksum"
    EXPECTED="$(awk '{print $1}' "$TMP_DIR/$PKG_NAME.sha256")"
    ACTUAL="$(sha256sum "$TMP_DIR/$PKG_NAME" | awk '{print $1}')"
    if [ "$EXPECTED" != "$ACTUAL" ]; then
        die "checksum mismatch: expected $EXPECTED, got $ACTUAL"
    fi
    log "sha256 ok"
else
    warn "no .sha256 sidecar published for $PKG_NAME — checksum verification skipped"
    warn "(GPG .asc signature is available at ${PKG_URL}.asc; verify out-of-band)"
fi

log "extracting"
unzip -qo "$TMP_DIR/$PKG_NAME" -d "$TMP_DIR/extract"
SRC_BIN="$(find "$TMP_DIR/extract" -type f -name rustfs | head -n1)"
[ -n "$SRC_BIN" ] || die "rustfs binary not found inside $PKG_NAME"

log "installing binary to $BIN_DST"
install -m 0755 -o root -g root "$SRC_BIN" "$BIN_DST.new"
mv -f "$BIN_DST.new" "$BIN_DST"

# ----- env file (template -> PLUGIN_LIB/etc/rustfs.env) ---------------------

if [ -f "$ENV_FILE" ]; then
    log "$ENV_FILE already exists — leaving operator + engine edits intact"
else
    log "installing env file from template to $ENV_FILE"
    install -m 0640 -o root -g rustfs "$ENV_TEMPLATE_SRC" "$ENV_FILE"
fi

log "object-storage plugin install ${RUSTFS_VERSION}: binary + env in place."
log "Engine will now provision needs (dataset, TLS, Keycloak client) and start the unit."
