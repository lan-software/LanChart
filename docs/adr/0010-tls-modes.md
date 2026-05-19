# ADR 0010 — Three-way TLS termination toggle

Date: 2026-05-19
Status: Accepted

## Context

The umbrella previously hardcoded a single TLS shape: every Ingress emitted a
`cert-manager.io/cluster-issuer` annotation plus a `spec.tls` block referencing
an auto-derived Secret name. This forced every install — including dev kind
clusters with no ACME reachability and homelab k3s nodes sitting behind an
existing reverse proxy — to either run cert-manager or fight the chart.

Three concrete deployment shapes need to coexist:

1. **Public cluster with Let's Encrypt.** cert-manager + a ClusterIssuer
   manage Certificates end-to-end. (The original behaviour.)
2. **Manually-managed TLS Secrets.** Some operators ship certs from a
   corporate PKI or via external-secrets pulling from Vault, and want the
   chart to consume those Secrets without involving cert-manager.
3. **Upstream reverse proxy.** On LAN/k3s rollouts, an HAProxy /
   pfSense / homelab gateway terminates TLS and forwards plain HTTP to the
   cluster. The chart-emitted Ingress should speak plain HTTP, but Laravel
   should still know the public scheme is `https://` so callback URLs,
   secure cookies, and OAuth redirects work.

## Decision

Introduce `global.tls.mode` with three values:

| Mode | Ingress annotations | `spec.tls` | Env tweaks |
|------|--------------------|------------|------------|
| `acme` *(default)* | `cert-manager.io/cluster-issuer: <issuer>` | `secretName` defaults to `{{ fullname }}-tls` (cert-manager auto-fills) | `SESSION_SECURE_COOKIE=true` |
| `preprovisioned` | none | `secretName` taken from `ingress.tls.secretName` (required) | `SESSION_SECURE_COOKIE=true` |
| `passthrough` | `force-ssl-redirect: "false"`, `ssl-redirect: "false"` | omitted | `TRUSTED_PROXIES=<cidrs>`, `SESSION_SECURE_COOKIE=true` |

Per-app `ingress.tls.enabled` and `ingress.tls.issuerRef.name` are removed.
Per-app `ingress.tls.secretName` remains as an override (required under
`preprovisioned`, optional under `acme`).

The chart **does not** create the cert-manager `ClusterIssuer` even under
`acme` mode — that stays a cluster-scoped prerequisite per ADR-0002.

## Consequences

- The `passthrough` mode covers two important cases for free:
  - LAN/k3s rollouts behind a homelab gateway.
  - Service-mesh-fronted clusters where the mesh sidecar already handles TLS.
- Laravel sees the right scheme regardless of mode: in `passthrough`, the
  `TRUSTED_PROXIES` env wires the framework's TrustProxies middleware to
  honour `X-Forwarded-Proto: https` from the upstream proxy; in the other
  modes the pod itself terminates TLS at the Ingress.
- `SESSION_SECURE_COOKIE` is always `true` in production (`acme`,
  `preprovisioned`, `passthrough` with `forceSecureCookies: true`). The
  kind dev values explicitly opt out for local plain-HTTP debugging.
- Existing values files with `ingress.tls.enabled` / `ingress.tls.issuerRef`
  on each sub-chart no longer take effect. The provided `examples/values-*`
  files have been updated; downstream operators must follow.
- `preprovisioned` fails the template render (via Helm `required`) when
  `ingress.tls.secretName` is empty on any sub-chart — this is intentional
  so misconfiguration cannot ship a half-protected ingress.

## Alternatives considered

- **Keep the per-app boolean (`ingress.tls.enabled`).** Mixed flag + mode
  semantics gets confusing quickly, and prod deployments always want the
  same termination strategy across every Lan-Software app.
- **Two modes only (`acme` + `passthrough`).** Rejected — manually managed
  TLS Secrets are common enough (corporate PKI, GitOps-controlled certs)
  that omitting them would push those operators into an awkward chart fork
  or a `passthrough` workaround.
- **Render the ClusterIssuer under `acme`.** Rejected per ADR-0002.

## Implementation notes

- The mode-aware branching lives in
  `charts/lan-common/templates/_ingress.tpl`. The same logic applies to the
  optional admin Ingress (`{{ fullname }}-admin`) so basic-auth-protected
  /horizon and /pulse paths get the same TLS treatment as the main ingress.
- `TRUSTED_PROXIES` is consumed by the LanBase bootstrap entrypoint, which
  wires it into Laravel's TrustProxies middleware. The default value is
  `"*"`; tighten to the proxy CIDR (e.g. `10.0.0.0/8`) on production
  installs so `X-Forwarded-*` headers can't be spoofed by other workloads.
