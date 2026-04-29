#!/usr/bin/env bash
# build-package.sh PLUGIN_DIR OUTPUT_DIR
#
# Tarballs a plugin's manifest + deploy assets + (optionally) a built UI
# bundle into a single .tar.gz suitable for upload to a GitHub Release.
#
# Layout inside the tarball:
#   manifest.yaml
#   icon.svg
#   README.md
#   deploy/
#   needs/
#   ui/                    (only if the plugin has a UI; built bundle copied in)
#
# The plugin directory must contain manifest.yaml. Version is read from
# manifest.yaml's metadata.version.

set -euo pipefail

PLUGIN_DIR="${1:?usage: build-package.sh PLUGIN_DIR OUTPUT_DIR}"
OUTPUT_DIR="${2:?usage: build-package.sh PLUGIN_DIR OUTPUT_DIR}"

[ -d "$PLUGIN_DIR" ] || { echo "no such dir: $PLUGIN_DIR" >&2; exit 2; }
[ -f "$PLUGIN_DIR/manifest.yaml" ] || { echo "missing manifest.yaml" >&2; exit 2; }

NAME="$(awk '/^  name:/ {print $2; exit}' "$PLUGIN_DIR/manifest.yaml")"
VERSION="$(awk '/^  version:/ {print $2; exit}' "$PLUGIN_DIR/manifest.yaml")"

[ -n "$NAME" ] || { echo "manifest.yaml missing metadata.name" >&2; exit 2; }
[ -n "$VERSION" ] || { echo "manifest.yaml missing metadata.version" >&2; exit 2; }

mkdir -p "$OUTPUT_DIR"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Copy plugin sources, excluding UI build inputs and dotfiles.
rsync -a \
  --exclude=ui/node_modules \
  --exclude=ui/src \
  --exclude=ui/package.json \
  --exclude=ui/package-lock.json \
  --exclude=ui/vite.config.ts \
  --exclude=ui/tsconfig.json \
  --exclude='.*' \
  "$PLUGIN_DIR/" "$STAGE/$NAME/"

# Copy built UI bundle if it exists.
if [ -d "$PLUGIN_DIR/ui/dist" ]; then
  rm -rf "$STAGE/$NAME/ui"
  cp -r "$PLUGIN_DIR/ui/dist" "$STAGE/$NAME/ui"
elif [ -d "$PLUGIN_DIR/ui/build" ]; then
  rm -rf "$STAGE/$NAME/ui"
  cp -r "$PLUGIN_DIR/ui/build" "$STAGE/$NAME/ui"
fi

OUTPUT="$OUTPUT_DIR/${NAME}-${VERSION}.tar.gz"
tar -C "$STAGE" -czf "$OUTPUT" "$NAME"

echo "built: $OUTPUT"
echo "size:  $(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT") bytes"
echo "sha256:"
shasum -a 256 "$OUTPUT" | awk '{print "  " $1}'
