# ADR 0006 — Post-install Job to bootstrap satellite LANCORE_TOKENs

Date: 2026-04-20
Status: Superseded by [ADR-0008 Declarative integration-app configuration](0008-declarative-integration-config.md)

> **⚠ Superseded.** The post-install bootstrap Job described here was
> replaced with a pre-install `integrations:sync` hook Job that reconciles
> LanCore's `config/integrations.php` into the database. See ADR-0008 for
> the current design. This document is retained for historical context.

## Context

Each satellite app (`LanBrackets`, `LanEntrance`, `LanShout`, `LanHelp`)
authenticates to LanCore via a `LANCORE_TOKEN` + `LANCORE_WEBHOOK_SECRET`.
These are not known at `helm install` time — they must be minted by
LanCore (via `php artisan integration:create` + `integration:token`) once
LanCore itself is Ready.

Options:

- **Operator runs commands manually after `helm install`.** Works, but
  defeats the "one helm install" UX goal; easy to forget.
- **Sub-chart init container calls LanCore.** Chicken/egg: satellites
  can't come up until LanCore is Ready, but LanCore may not yet have
  processed the request.
- **Post-install Helm hook Job in the umbrella chart.** Run once, after
  everything is Ready; writes per-satellite Secrets; triggers rollouts.

## Decision

The umbrella chart ships `bootstrap-job.yaml` as a
`helm.sh/hook: post-install,post-upgrade` Job with `hook-weight: 10` so it
runs after migrations (`-5`), sub-chart deployments, and RBAC setup.

The Job:
1. Waits for LanCore web pods to reach Ready.
2. For each enabled satellite: `kubectl exec` into a LanCore pod and runs
   `integration:create` (idempotent by slug) then `integration:token`.
3. Writes per-satellite Secret `{app}-lancore` with `token` and
   `webhook_secret` keys.
4. `kubectl rollout restart` the satellite Deployments so they pick up
   the token from `envFrom: secretRef`.

RBAC is namespace-scoped: `get pods`, `create pods/exec`, `get/create/patch
secrets`, `get/patch deployments`. No ClusterRole.

## Consequences

- First-install UX: `helm install` → done. Operators only need to provide
  credentials Secrets for mail/Stripe/S3 out of band.
- Upgrade UX: the Job re-runs but short-circuits when the Secret already
  has a populated `token`.
- **Caveat**: `integration:token` prints the plaintext token once; the
  script parses it heuristically (first long alphanumeric blob on a line
  by itself). If the artisan command's output format changes, the parser
  will break. Pin LanCore's `integration:token` format as part of the
  integration contract; add a test case in Phase 2.
- The Job can be disabled with `bootstrap.enabled: false` for operators who
  prefer manual bootstrap (documented in NOTES.txt).

## Alternatives

- **Custom Kubernetes operator for LanCore integration apps.** Over-kill
  for the cardinality (4 satellites).
- **Asking LanCore to emit webhook secrets via a structured API instead of
  CLI output parsing.** A reasonable Phase 2 LanCore improvement; would
  simplify the bootstrap script.
