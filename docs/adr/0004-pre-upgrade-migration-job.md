# ADR 0004 — Pre-upgrade Helm hook Job for migrations

Date: 2026-04-20
Status: Accepted

## Context

Laravel apps run schema migrations once per release. The existing Docker
contract (SSDD §3.1.1.3, SIP §3.4.2) says: **exactly one container per
release runs migrations**; all others set `SKIP_MIGRATE=1`. This invariant
must be preserved in Kubernetes.

Options:

- **Init container on every pod.** N parallel migrators race the schema,
  slow every pod cold-start, and burn a migration timeout on every rolling
  restart.
- **Separate Deployment for a migrator pod.** Perpetually running for
  a one-shot action; awkward to gate Deployment rollout on its completion.
- **Helm `pre-install,pre-upgrade` hook Job.** Single run per release;
  Helm blocks Deployment rollout until the Job completes.

## Decision

Each sub-chart ships a `job-migrate.yaml` template marked
`helm.sh/hook: pre-install,pre-upgrade` with
`hook-weight: -5` and `hook-delete-policy: before-hook-creation`. Web and
worker Deployments always set `SKIP_MIGRATE=1`.

## Consequences

- Rollback via `helm rollback` does **not** reverse migrations (Helm hook
  Jobs are fire-and-forget). Database-level rollback is the operator's
  responsibility — CloudNativePG PITR is the documented escape hatch.
- A failed migration aborts the release. `helm upgrade` reports the Job's
  non-zero exit code.
- `hook-delete-policy: before-hook-creation` leaves the previous Job
  around until the next upgrade, useful for diagnosing failures.

## Alternatives

- `hook-delete-policy: hook-succeeded` — cleaner but hides past migration
  logs.
