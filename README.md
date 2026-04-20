# LanChart

Helm chart repository for the Lan Software ecosystem.

`lan-software` is an umbrella Helm chart that deploys LanCore plus its four
Laravel satellite apps (LanBrackets, LanEntrance, LanShout, LanHelp) onto a
Kubernetes 1.29+ cluster, using operator-managed Postgres (CloudNativePG),
Redis-compatible cache (Dragonfly), S3 (external or MinIO Tenant), and TLS
(cert-manager).

## Layout

```
charts/
├── lan-software/    # umbrella application chart (top-level)
├── lan-common/      # library chart: shared templates (labels, deployment, probes, …)
├── lancore/         # LanCore sub-chart (octane + horizon + pulse)
├── lanbrackets/     # octane flavor, writable public/ cache
├── lanentrance/     # server flavor, JWKS client for ticket validation
├── lanshout/        # server flavor
└── lanhelp/         # server flavor, staff email
```

See [docs/quickstart.md](docs/quickstart.md) for install instructions and
[docs/operators.md](docs/operators.md) for the prerequisite-operator matrix.
Architectural decisions are recorded under [docs/adr/](docs/adr/).

The chart is consumed from the OCI registry at
`oci://ghcr.io/lan-software/charts/lan-software`.

## Prerequisites

- Kubernetes 1.29+ with RBAC + Pod Security Admission enabled
- Helm 3.14+ (or Helm 4.x)
- Cluster-scoped operators: `cert-manager`, `ingress-nginx`, CloudNativePG,
  Dragonfly Operator (and optionally MinIO Operator, prometheus-operator)

See [docs/operators.md](docs/operators.md) for install commands and pinned
versions.

## Quick start

```bash
# 1. Install prerequisite operators (see docs/operators.md)

# 2. Create a values file from examples/values-dev-kind.yaml or
#    examples/values-prod.yaml and override global.domain + credentials.

# 3. Install the umbrella.
helm install lan-software \
    oci://ghcr.io/lan-software/charts/lan-software \
    --version 0.1.0 \
    -n lan-software --create-namespace \
    -f my-values.yaml
```

See [LanCore SIP §3.5](../LanCore/docs/mil-std-498/SIP.md) for the full
canonical install procedure and the MIL-STD-498-tracked verification steps.

## Development

```bash
make lint       # helm lint + kubeconform across all charts
make template   # render the umbrella to stdout for manual inspection
make unittest   # helm-unittest (Phase 3 — CI target)
make kind-up    # create a local kind 1.31 cluster with prereq operators
make install-dev  # helm install using examples/values-dev-kind.yaml
make smoke      # curl /up on each app
```

## License

Apache-2.0 — see LICENSE.

## References

- MIL-STD-498 documentation hierarchy: `../LanCore/docs/mil-std-498/`
- Implementation plan: `~/.claude/plans/mighty-stirring-ripple.md`
- Source for each sub-chart's app: sibling submodules under `../`
