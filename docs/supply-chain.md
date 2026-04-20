# Supply Chain

The `lan-software` Helm charts are published as signed OCI artifacts with
attached SPDX SBOMs. This page documents how the charts are built + signed
and how end users verify them.

## Publication

Tagged releases on `main` trigger `.github/workflows/release.yaml`, which:

1. `helm package`s every chart (`lan-common`, `lancore`, `lanbrackets`,
   `lanentrance`, `lanshout`, `lanhelp`, `lan-software`) into `dist/`.
2. Pushes each tarball to `oci://ghcr.io/lan-software/charts/<chart>:<tag>`
   using the repository's `GITHUB_TOKEN`.
3. Signs each pushed OCI artifact with **cosign keyless** (GitHub OIDC
   identity token, no long-lived key material).
4. Generates an SPDX SBOM per tarball with `syft` and attaches it as a
   cosign attestation (`--type spdxjson`) to the same OCI artifact.
5. Uploads the tarballs + SBOMs as workflow artifacts (90-day retention).

Expected workflow identity for verification:
`https://github.com/lan-software/LanChart/.github/workflows/release.yaml@refs/tags/<tag>`
issued by `https://token.actions.githubusercontent.com`.

## End-user verification

### Install cosign

```sh
# Homebrew / Linuxbrew:
brew install cosign

# Manual (linux amd64):
curl -L -o cosign https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
chmod +x cosign && sudo mv cosign /usr/local/bin/
```

### Verify the signature

```sh
REF="oci://ghcr.io/lan-software/charts/lan-software:0.1.0"

cosign verify \
  --certificate-identity-regexp 'https://github.com/lan-software/LanChart/\.github/workflows/release\.yaml@refs/tags/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  "${REF#oci://}"
```

Expected output: a JSON report confirming the signature matches an identity
minted by the `lan-software/LanChart` release workflow.

### Verify + download the SBOM

```sh
cosign verify-attestation \
  --type spdxjson \
  --certificate-identity-regexp 'https://github.com/lan-software/LanChart/\.github/workflows/release\.yaml@refs/tags/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  "${REF#oci://}" \
  | jq -r '.payload' | base64 -d | jq '.predicate' > lan-software.spdx.json
```

The emitted `lan-software.spdx.json` is a standard SPDX 2.3 document; feed it
to `syft`, `grype`, `trivy`, `sbom-utility`, or any SBOM-compatible tool.

## Local signing (operator-maintained key)

For operators who want to re-sign the published artifact with their own
trust anchor (e.g. an enterprise CA-signed cosign key):

```sh
# Create a cosign key pair once:
cosign generate-key-pair
# → cosign.key, cosign.pub

# Pull the release artifact, re-sign with the local key, and re-publish
# to a private registry:
export COSIGN_KEY=./cosign.key
./scripts/cosign-sign.sh oci://registry.internal.example.com/lan-software/charts/lan-software:0.1.0
./scripts/sbom-attach.sh dist/lan-software-0.1.0.tgz oci://registry.internal.example.com/lan-software/charts/lan-software:0.1.0
```

## Version pins used in CI

| Tool             | Pinned version       | Where |
|------------------|---------------------|-------|
| Helm             | v3.16.3              | `.github/workflows/*.yaml` |
| kubeconform      | v0.6.7               | `.github/workflows/lint.yaml` |
| conftest         | v0.56.0              | `.github/workflows/lint.yaml` |
| cosign           | v2.4.1               | `.github/workflows/release.yaml` |
| syft             | v1.14.0              | `.github/workflows/release.yaml` |
| kind             | v0.24.0              | `.github/workflows/kind-smoke.yaml` |
| helm-unittest    | 0.7.2                | `.github/workflows/lint.yaml` |
| helm-docs        | v1.14.2              | `.github/workflows/docs.yaml` |
| kind node image  | kindest/node:v1.31.0 | `.github/workflows/kind-smoke.yaml` |

Bumping any of these is a deliberate review — CRD drift + cosign policy
changes frequently require matching test updates. Track version bumps in
a dedicated PR.

## Transparency log

All keyless signatures are published to the Sigstore public transparency
log ([rekor.sigstore.dev](https://rekor.sigstore.dev/)). You can inspect
any `lan-software` signature at:
`https://search.sigstore.dev/?logIndex=<index>` or via the `cosign tree`
command.
