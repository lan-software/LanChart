# ADR 0007 — Horizon / Pulse admin-path authentication

Date: 2026-04-20
Status: Accepted

## Context

LanCore exposes two administrative web dashboards:

- `/horizon` — Laravel Horizon UI (queue workers, job metrics)
- `/pulse` — Laravel Pulse UI (application health)

Both are authorization-gated *inside* LanCore via Gate::define closures, but
the closures rely on the caller already being authenticated with an admin
session. For production deployments we want an additional perimeter layer
so unauthenticated traffic never reaches the dashboards (defence in depth
against Horizon/Pulse framework CVEs and accidental credential disclosure).

## Decision

The LanCore sub-chart emits a **second** Ingress (`{{ fullname }}-admin`)
scoped to the admin paths only. It carries auth annotations driven by
`ingress.adminAuth.mode`:

- `none` — no second Ingress emitted. Traffic falls through to the main
  Ingress and LanCore's internal Gate enforces auth. Acceptable for dev /
  kind clusters; **not** recommended for production.
- `basic` — nginx-ingress `auth-type: basic` + `auth-secret` annotations.
  Operator provisions an htpasswd Secret out of band. Simple, robust, works
  from day one.
- `oauth2proxy` — nginx-ingress `auth-url` + `auth-signin` annotations
  pointing at an operator-provided oauth2-proxy Service. Target identity
  provider is LanCore itself via OIDC.

The chart does **not** ship an oauth2-proxy Deployment (per ADR-0002:
cluster-wide auth infra is the cluster operator's concern, not the app
chart's).

## Consequences

- `mode: basic` is a working default for production: day-one-usable, no
  external dependencies. The LanCore-internal admin Gate still applies.
- `mode: oauth2proxy` is **not** usable against a stock LanCore today.
  LanCore exposes a custom OAuth2-style authorization flow
  (`GET /sso/authorize`, `POST /sso/exchange` — see
  `routes/integrations.php:36`, `routes/api-integrations.php:25`) but not
  full OIDC: no `.well-known/openid-configuration`, no JWKS endpoint, no
  `id_token` emission. oauth2-proxy's `--provider=oidc` requires all three.
  Enabling `mode: oauth2proxy` in production therefore blocks on a LanCore
  follow-up patch that adds an OIDC-compliance layer on top of the
  existing integration auth.
- Until that LanCore patch lands, production values files should use
  `mode: basic`.
- The second Ingress means two cert-manager Certificate resources share the
  same host; that is safe (same TLS secretName), but means two ACME
  challenges on first-install. If challenges rate-limit, flip
  `ingress.tls.createCertificate: false` on the admin Ingress manually.

## Phase 2 → future path

1. Phase 2 (now): ship both mode wirings. Default `mode: none` in values
   so Phase 1 kind smoke tests are unaffected. `examples/values-prod.yaml`
   sets `mode: basic` with a commented-out `mode: oauth2proxy` block.
2. Phase 2a (LanCore-side): implement OIDC discovery endpoints under
   `/oauth2/*`, publish JWKS at `/.well-known/jwks.json`, emit `id_token`s
   with `aud` matching the oauth2-proxy client. LanCore integration app
   scopes (`user:read`, `user:email`, `user:roles`) map cleanly to OIDC
   scope claims. Add an MIL-STD-498 SRS requirement and an IRS interface.
3. Phase 2b: once LanCore OIDC is in prod, `examples/values-prod.yaml`
   flips to `mode: oauth2proxy` by default.

## Alternatives considered

- **Embed oauth2-proxy as a Deployment in the umbrella chart.** Rejected
  (ADR-0002 — auth infra is cluster-operator concern, and multi-tenant
  clusters would fight over a shared oauth2-proxy).
- **Use nginx-ingress's built-in `external-auth-url` without oauth2-proxy
  (i.e. hit a LanCore endpoint directly).** Would require a LanCore
  `/api/admin/auth-check` endpoint that validates a session cookie and
  returns 200/401. Simpler than full OIDC but requires cookie-forwarding
  configuration on the ingress; treated as a fallback we can build if the
  full OIDC path is too slow.
