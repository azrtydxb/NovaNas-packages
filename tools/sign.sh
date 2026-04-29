#!/usr/bin/env bash
# sign.sh TARBALL [COSIGN_KEY]
#
# cosign sign-blob the supplied tarball. Writes <TARBALL>.sig next to
# the input. The cosign private key path defaults to $COSIGN_KEY env or
# ./cosign.key (which is .gitignored).

set -euo pipefail

TARBALL="${1:?usage: sign.sh TARBALL [KEY]}"
KEY="${2:-${COSIGN_KEY:-./cosign.key}}"

command -v cosign >/dev/null 2>&1 || { echo "cosign not in PATH" >&2; exit 2; }
[ -f "$TARBALL" ] || { echo "no such file: $TARBALL" >&2; exit 2; }
[ -f "$KEY" ]     || { echo "no such key: $KEY" >&2; exit 2; }

OUT="${TARBALL}.sig"

# COSIGN_PASSWORD must be exported in the environment if the key is
# password-protected (recommended).
cosign sign-blob \
  --key "$KEY" \
  --output-signature "$OUT" \
  --yes \
  "$TARBALL"

echo "signed: $OUT"
