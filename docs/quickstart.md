# Quick Start

Install LanCore and its satellite apps onto an existing Kubernetes cluster
with the `lan-software` umbrella chart.

## Prerequisites

Install these once per cluster (see [operators.md](operators.md) for pinned
versions):

| Prerequisite | Purpose |
|--------------|---------|
| Kubernetes 1.29+ with RBAC | Target cluster |
| Helm 3.14+ (or Helm 4.x) | Chart tool |
| ingress-nginx | External Ingress controller |
| cert-manager *(optional)* | Required only when `global.tls.mode: acme` |
| Zalando postgres-operator *(optional)* | Required only when `global.database.provider: zalando` |
| Dragonfly Operator | Redis-compatible cache CR controller |
| MinIO Operator *(optional)* | Required only if any sub-chart sets `storage.mode: minio-tenant` |
| prometheus-operator *(optional)* | Required only if `global.monitoring.enabled: true` |

## Choosing a database provider

`global.database.provider` (umbrella values) picks how Postgres is sourced:

| Mode | What the chart does | When to use |
|------|---------------------|-------------|
| `zalando` *(default)* | Emits one shared `acid.zalan.do/v1 postgresql` CR with a database + login role per app. The operator generates a credentials Secret per role. | New clusters where you want the chart to manage Postgres. |
| `external` | Emits no CR; each app connects to `global.database.external.host` (or `database.existing.host` per app) using a password Secret you create out of band. | RDS, Cloud SQL, an existing self-managed Postgres, or a database that lives outside this chart's lifecycle. |

For `external` mode, set per app:
```yaml
lancore:
  database:
    existing:
      host: pg.example.internal
      username: lancore
      database: lancore
      passwordSecret: { name: lancore-db, key: password }
```

## Choosing a TLS mode

`global.tls.mode` picks how TLS reaches the apps:

| Mode | Chart-emitted Ingress | Use when |
|------|----------------------|----------|
| `acme` *(default)* | `cert-manager.io/cluster-issuer` annotation + `spec.tls` so cert-manager issues a Certificate from `global.tls.acme.issuerRef`. | Public clusters with cert-manager and a ClusterIssuer (e.g. Let's Encrypt). |
| `preprovisioned` | `spec.tls.secretName` from each sub-chart's `ingress.tls.secretName`; no cert-manager involvement. | You manage TLS Secrets out of band (corporate PKI, externalsecrets pulling from Vault, etc.). |
| `passthrough` | No `spec.tls`; ingress speaks plain HTTP. `force-ssl-redirect`/`ssl-redirect` disabled. Laravel's TrustProxies middleware is wired via `TRUSTED_PROXIES` and `SESSION_SECURE_COOKIE=true`. | An upstream reverse proxy (LAN gateway, HAProxy, cloud LB) terminates TLS and forwards `X-Forwarded-Proto`. |

See [`docs/adr/0010-tls-modes.md`](adr/0010-tls-modes.md) for the full rationale.

## Install

```bash
# 1. Create the release namespace. PSA baseline is the Phase 1 target.
kubectl create namespace lan-software
kubectl label namespace lan-software \
    pod-security.kubernetes.io/enforce=baseline --overwrite

# 2. Create a values file. For local kind clusters, copy examples/values-dev-kind.yaml.
#    For a k3s test rollout, copy examples/values-k3s.yaml.
#    For production, override at minimum:
#      global.domain
#      global.database.provider (and global.database.zalando.* or .external.*)
#      global.tls.mode          (and the matching sub-block)
#      credential Secrets (mail, Stripe, WebPush, S3) — created out of band

# 3. Install.
helm install lan-software \
    oci://ghcr.io/lan-software/charts/lan-software --version 0.1.0 \
    --namespace lan-software \
    -f my-values.yaml
```

## Verify

Each app exposes a `/up` readiness endpoint. From within the cluster:

```bash
for app in lancore lanbrackets lanentrance lanshout lanhelp; do
  kubectl -n lan-software run --rm -i "curl-$app" \
    --image=curlimages/curl --restart=Never -- \
    curl -fsSL --max-time 10 "http://${app}-web.lan-software.svc.cluster.local/up" \
    || echo "FAIL: $app"
done
```

The Helm release also produces a post-install Job called
`lan-software-bootstrap` that provisions LanCore integration apps + tokens
for every enabled satellite. Watch it:

```bash
kubectl -n lan-software get jobs
kubectl -n lan-software logs job/lan-software-bootstrap
```

## Local kind development

```bash
# From the LanChart repository root:
make kind-up          # creates a kind 1.31 cluster
make prereqs          # installs the cluster-scoped prereq operators
make dep-up           # resolves the umbrella's Chart.yaml dependencies
make install-dev      # helm install with examples/values-dev-kind.yaml
make smoke            # curls /up on each app
```

Tear down: `make uninstall-dev && make kind-down`.

## References

- [SIP §3.5](../../LanCore/docs/mil-std-498/SIP.md#35-quick-start-production-kubernetes-via-helm) — canonical install procedure (MIL-STD-498 tracked)
- [SSDD §4.3](../../LanCore/docs/mil-std-498/SSDD.md#43-high-availability) — production HA topology
- [SSDD §5.1](../../LanCore/docs/mil-std-498/SSDD.md#51-network-architecture) — Network architecture
- [SSDD §5.6](../../LanCore/docs/mil-std-498/SSDD.md#56-key-storage-design-kubernetes) — Ed25519 keyring storage
