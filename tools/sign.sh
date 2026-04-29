#!/usr/bin/env bash
# sign.sh TARBALL [COSIGN_KEY]
#
# cosign sign-blob the supplied tarball. Writes <TARBALL>.sig next to
# the input. The cosign private key path defaults to $COSIGN_KEY env or
# ./cosign.key (which is .gitignored).

set -euo pipefail

TARBALL="${1:?usage: sign.sh TARBALL [KEY]}"
KEY="${2:-${COSIGN_KEY:-./cosign.key}}"
COSIGN_BIN="${COSIGN_BIN:-cosign}"

command -v "$COSIGN_BIN" >/dev/null 2>&1 || { echo "cosign ($COSIGN_BIN) not in PATH; install cosign v2 (\`go install github.com/sigstore/cosign/v2/cmd/cosign@latest\`) and set COSIGN_BIN" >&2; exit 2; }
[ -f "$TARBALL" ] || { echo "no such file: $TARBALL" >&2; exit 2; }
[ -f "$KEY" ]     || { echo "no such key: $KEY" >&2; exit 2; }

OUT="${TARBALL}.sig"

# We pin to cosign v2 syntax. cosign v3 reworked sign-blob to require
# either a sigstore signing-config or the new JSON bundle format —
# unnecessary complexity for an offline/private key flow. nova-api's
# verifier consumes the legacy raw base64 signature next to the
# artifact, which v2 produces with --output-signature.
#
# COSIGN_PASSWORD must be exported in the environment if the key is
# password-protected (recommended).
"$COSIGN_BIN" sign-blob \
  --key "$KEY" \
  --output-signature "$OUT" \
  --tlog-upload=false \
  --yes \
  "$TARBALL" >/dev/null

echo "signed: $OUT"
