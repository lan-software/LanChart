# ADR 0008 — Declarative integration-app configuration via `config/integrations.php`

Date: 2026-04-20
Status: Accepted
Supersedes: [ADR-0006 Satellite token bootstrap Job](0006-satellite-token-bootstrap-job.md)

## Context

Phase 1 shipped an imperative cross-app SSO bootstrap: a Helm `post-install`
Job (`lan-software-bootstrap`) that `kubectl exec`ed into a LanCore pod,
ran `php artisan integration:create` + `integration:token` per satellite,
parsed the minted plaintext token from stdout, wrote it to a per-app
Secret, and then `kubectl rollout restart`ed the satellite Deployments so
they picked up the token. Functional but fragile: depends on stdout
parsing, runs as a post-install step (satellites briefly came up token-less
on first boot), required Role + RoleBinding granting `pods/exec` + `secrets
create/patch`, and was the only imperative step in an otherwise declarative
install.

Parallel operator feedback: setting up the four satellites via LanCore's
admin UI is unnecessarily manual for production — operators describing
their whole fleet in `values.yaml` plus a few Secrets is the expected
ergonomic for a Helm-driven install.

## Decision

Move the source of truth for the four Lan* integration apps from the
database (populated imperatively) to LanCore's `config/integrations.php`
(populated from env vars). A new Artisan command, `integrations:sync`,
reconciles the config into the database by:

1. Upserting the `IntegrationApp` row for each configured slug.
2. Deleting all existing `IntegrationToken` rows for that slug and
   inserting a single `config-seeded` token whose SHA-256 hash corresponds
   to the plaintext provided in env.
3. Deleting and recreating the `Webhook` rows (announcement + roles) from
   config-supplied secrets.

Slugs NOT listed in `config/integrations.php` are left untouched — the UI
and imperative Artisan commands still work for operator-specific custom
integrations.

The Helm umbrella chart runs `integrations:sync` as a **pre-install,
pre-upgrade** Helm hook Job on the LanCore sub-chart, ordered by
`hook-weight: -4` (after the migration Job at -5, before any Deployment
rolls). Token material + webhook secrets come from a single shared
`{release-name}-integrations-seed` Secret, auto-generated via the Helm
`lookup` idiom (stable across upgrades) and overridable per-slug via
`values.yaml` for ExternalSecrets / operator-supplied credentials.

## Consequences

- **One `helm install` = working fleet.** No post-install step, no stdout
  parsing, no RBAC to grant `pods/exec`. Satellites mount their slice of
  the shared Secret via `envFrom` at boot.
- **Declarative.** `values.yaml` owns the topology: `global.domain`,
  `global.satelliteHostStyle`, `global.lancoreHost`, `global.integrations.<slug>.*`.
  Hostname flips with a single edit.
- **Destructive-by-design for config-managed slugs.** Any token or webhook
  row for the four Lan* slugs is replaced on every `integrations:sync`
  run. Token stability across `helm upgrade` is preserved via the shared
  Secret's `lookup`-driven stability — the *hash* in the DB changes on
  every sync, but the hash maps to the *same* plaintext the satellite
  holds, so authentication keeps working.
- **Admin UI preserved.** The `Index.vue` and `Edit.vue` pages get an
  amber "config-managed" badge for affected slugs warning operators that
  edits will be overwritten on the next release. Fields are not locked.
- **RBAC simplified.** The umbrella no longer emits a ServiceAccount +
  Role + RoleBinding for the bootstrap Job. Only the
  `integrations-sync` Job runs, and it re-uses the LanCore
  ServiceAccount (no new RBAC grants).
- **First-adoption step is destructive.** On the first upgrade after
  adopting this ADR, any tokens minted by the old bootstrap-Job path for
  the four slugs are wiped and replaced with config-seeded ones. Because
  the seed Secret is generated fresh on the first Helm install of this
  version (`lookup` returns nil), the tokens in LanCore and in the
  satellite Secrets rotate together — no satellite outage. But operators
  of long-lived releases should preview with
  `php artisan integrations:sync --dry-run` first.

## Alternatives considered

- **Keep the imperative post-install Job; fix its flakiness.** Band-aid
  approach. Doesn't address the operator-ergonomics complaint about
  needing to log into the UI for the initial setup.
- **Create a Kubernetes operator for integration apps.** Overkill for
  cardinality of 4. Adds a CRD, a controller Deployment, RBAC, release
  coupling between LanCore and the operator.
- **Push integration apps through `DatabaseSeeder::run()`.** Wrong layer:
  seeders are one-shot on fresh DBs; the reconciler runs on every upgrade.
- **Use LanCore's existing `SetupDevIntegrationCommand` in prod.** That
  command is interactive (`confirm(…)` prompts) and hard-codes local dev
  hostnames; adapting it to production would have produced something
  structurally equivalent to this reconciler.
