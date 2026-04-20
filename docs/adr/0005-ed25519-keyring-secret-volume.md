# ADR 0005 — Ed25519 ticket-signing keyring as Kubernetes Secret volume

Date: 2026-04-20
Status: Accepted

## Context

LanCore signs ticket validation tokens (LCT1) with Ed25519 private keys.
`TicketKeyRing` (SDD §3.3.2) reads the key files from
`storage/keys/ticket_signing/{kid}.key` at Octane boot. Production on
Docker uses a host-mounted filesystem; key rotation writes new files to the
same path (SSDD §5a.4).

In Kubernetes, we need to preserve the filesystem-read semantics while:

1. Not requiring each pod to have write access to the keyring.
2. Supporting horizontal scale-out (all replicas must see the same keys).
3. Making rotation operator-friendly and auditable.

## Decision

- The keyring is a Kubernetes `Secret` (one `data` key per `kid`, filename
  `{kid}.key`).
- All LanCore web and worker pods mount the Secret as a **projected
  volume, read-only**, at `/var/www/html/storage/keys/ticket_signing/`,
  mode `0400`.
- **Rotation is a dedicated Kubernetes Job**, not an in-pod command. The
  Job runs `php artisan tickets:keys:rotate`, patches the Secret with a
  new `kid`, and bumps a pod-template annotation on the LanCore web
  Deployment to trigger a rolling restart (so in-memory key caches refresh).
- Dev-only escape hatch: `ticketing.signingKeys.inlineKeys` values map
  renders the Secret from values. Never use in production.

## Consequences

- `TicketKeyRing` works unchanged — it still reads filesystem paths.
- PSA `restricted` compatibility: the Secret mount is read-only, satisfying
  `readOnlyRootFilesystem` once Phase 2 tightens the container security
  context.
- Rotation is auditable (separate Job object with its own logs) and cannot
  be triggered by a compromised web pod.

## Alternatives

- **HashiCorp Vault Agent sidecar.** Heavier; reserved for organisations
  already running Vault.
- **CSI Secrets Store driver.** Phase 3+ option for operators who want
  AWS Secrets Manager / GCP Secret Manager as the upstream.
- **Keys in env vars.** Would require changing `TicketKeyRing` to read env
  instead of files — out of scope for Phase 1.
