#!/usr/bin/env bash
# Sign an OCI chart artifact with cosign.
#
# Defaults to keyless / GitHub OIDC via the ambient ID token (what the
# release.yaml workflow uses). If COSIGN_KEY is set and points at a local
# key file, uses that key instead (for operators who maintain their own
# signing key out of GitHub Actions).
#
# Usage:
#   scripts/cosign-sign.sh oci://ghcr.io/lan-software/charts/lan-software:0.1.0
#   COSIGN_KEY=./cosign.key scripts/cosign-sign.sh oci://...

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <oci-ref>" >&2
  exit 2
fi

REF="$1"
# cosign wants the ref WITHOUT the oci:// prefix.
REF="${REF#oci://}"

if [ -n "${COSIGN_KEY:-}" ]; then
  echo "[sign] keyful signing with COSIGN_KEY=${COSIGN_KEY}"
  cosign sign --yes --key "${COSIGN_KEY}" "${REF}"
else
  echo "[sign] keyless signing (OIDC identity token from ambient environment)"
  COSIGN_EXPERIMENTAL=1 cosign sign --yes "${REF}"
fi
