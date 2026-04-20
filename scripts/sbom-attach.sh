#!/usr/bin/env bash
# Generate an SPDX SBOM for a chart tarball and attach it as a cosign
# attestation to the corresponding OCI artifact.
#
# Usage:
#   scripts/sbom-attach.sh dist/lan-software-0.1.0.tgz oci://ghcr.io/lan-software/charts/lan-software:0.1.0

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <chart-tgz> <oci-ref>" >&2
  exit 2
fi

TGZ="$1"
REF="$2"
REF="${REF#oci://}"

mkdir -p sbom
BASE="$(basename "$TGZ" .tgz)"
OUT="sbom/${BASE}.spdx.json"

echo "[sbom] generating ${OUT}"
syft "${TGZ}" -o spdx-json="${OUT}"

echo "[sbom] attesting against ${REF}"
if [ -n "${COSIGN_KEY:-}" ]; then
  cosign attest --yes --key "${COSIGN_KEY}" --predicate "${OUT}" --type spdxjson "${REF}"
else
  COSIGN_EXPERIMENTAL=1 cosign attest --yes --predicate "${OUT}" --type spdxjson "${REF}"
fi
