#!/usr/bin/env bash
# publish.sh PLUGIN_DIR
#
# End-to-end publish flow:
#   1. Build the package tarball
#   2. cosign sign-blob it
#   3. Create / update a GitHub Release tagged <plugin>-<version>
#   4. Upload tarball + signature as release assets
#   5. Update index.json with the new entry
#   6. Commit + push index.json
#
# Requires: gh, cosign, jq, yq.
# COSIGN_KEY env or ./cosign.key. COSIGN_PASSWORD env recommended.

set -euo pipefail

PLUGIN_DIR="${1:?usage: publish.sh PLUGIN_DIR}"

for tool in gh cosign jq yq tar; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool not in PATH" >&2; exit 2; }
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
TOOLS="$REPO_ROOT/tools"

NAME="$(yq -r '.metadata.name' "$PLUGIN_DIR/manifest.yaml")"
VERSION="$(yq -r '.metadata.version' "$PLUGIN_DIR/manifest.yaml")"
TAG="${NAME}-${VERSION}"
DISPLAY="$(yq -r '.spec.displayName // .metadata.name' "$PLUGIN_DIR/manifest.yaml")"
CATEGORY="$(yq -r '.spec.category // "other"' "$PLUGIN_DIR/manifest.yaml")"
DESCRIPTION="$(yq -r '.spec.description // ""' "$PLUGIN_DIR/manifest.yaml")"
VENDOR="$(yq -r '.metadata.vendor // "novanas.io"' "$PLUGIN_DIR/manifest.yaml")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

bash "$TOOLS/build-package.sh" "$PLUGIN_DIR" "$WORK"
TARBALL="$WORK/${NAME}-${VERSION}.tar.gz"

bash "$TOOLS/sign.sh" "$TARBALL"
SIG="$TARBALL.sig"
SIZE=$(stat -f%z "$TARBALL" 2>/dev/null || stat -c%s "$TARBALL")
SHA="$(shasum -a 256 "$TARBALL" | awk '{print $1}')"

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "release $TAG already exists; updating assets"
  gh release upload "$TAG" "$TARBALL" "$SIG" --clobber
else
  gh release create "$TAG" "$TARBALL" "$SIG" \
    --title "$DISPLAY $VERSION" \
    --notes "Release of $NAME at version $VERSION."
fi

URL="https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/download/${TAG}/${NAME}-${VERSION}.tar.gz"
SIG_URL="${URL}.sig"

ICON_URL="https://raw.githubusercontent.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/main/plugins/${NAME}/icon.svg"

# Update index.json: insert-or-replace the entry for this name/version.
jq --arg name "$NAME" \
   --arg displayName "$DISPLAY" \
   --arg category "$CATEGORY" \
   --arg vendor "$VENDOR" \
   --arg description "$DESCRIPTION" \
   --arg icon "$ICON_URL" \
   --arg version "$VERSION" \
   --arg url "$URL" \
   --arg sigUrl "$SIG_URL" \
   --arg released "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg sha "$SHA" \
   --argjson size "$SIZE" \
   '
    # Engine schema: top-level {version:1, updated, plugins[]}.
    # Per-version: {version, tarballUrl, signatureUrl, sha256, size, releasedAt}.
    .version = 1
    | .updated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    | (if (.trust // null) == null then .trust = {publicKey:"https://raw.githubusercontent.com/azrtydxb/NovaNas-packages/main/trust/novanas-marketplace.pub", signer:"novanas.io marketplace"} else . end)
    | .plugins = (
        (.plugins // [])
        | (if (any(.name == $name)) then . else . + [{
            name: $name, displayName: $displayName, category: $category,
            vendor: $vendor, icon: $icon, description: $description,
            versions: []
          }] end)
      )
    | (.plugins[] | select(.name == $name)).versions |= (
        (map(select(.version != $version))) + [{
          version: $version, tarballUrl: $url, signatureUrl: $sigUrl,
          sha256: $sha, size: $size, releasedAt: $released
        }]
        | sort_by(.version) | reverse
      )
   ' "$REPO_ROOT/index.json" > "$WORK/index.json"

mv "$WORK/index.json" "$REPO_ROOT/index.json"

echo
echo "Published $NAME $VERSION."
echo "  release: $TAG"
echo "  tarball: $URL"
echo "  index:   updated $REPO_ROOT/index.json"
echo
echo "Next: git add index.json && git commit -m 'release: $TAG' && git push"
