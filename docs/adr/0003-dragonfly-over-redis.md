# ADR 0003 — Dragonfly Operator for cache / sessions / queues

Date: 2026-04-20
Status: Accepted

## Context

LanCore needs a Redis-compatible in-memory store for cache, sessions,
queues (Horizon), and rate-limiting. Satellites need the same for cache;
most of them use a database queue, not Redis.

Options weighed:

- **Bitnami Redis sub-chart** — safe, boring, well-trodden.
- **Spotahome / OT-CONTAINER-KIT Redis Operator** — CRD-driven, HA out of
  the box. Inconsistent licensing / maintenance story across forks.
- **Valkey Operator** — Linux Foundation Redis fork, young ecosystem.
- **Dragonfly Operator** — modern multi-threaded Redis wire-protocol
  compatible store, lower memory footprint.

## Decision

Use **Dragonfly Operator** (`dragonflydb.io/v1alpha1 Dragonfly` CR).

## Consequences

- Consistent operator pattern with CloudNativePG — one pane of glass for
  stateful infra.
- Dragonfly speaks the Redis wire protocol, so Laravel's phpredis client,
  Horizon (pub/sub + sorted sets), and `laravel/cache` require zero changes.
- Lower memory floor per instance than bitnami Redis at the same throughput.
- **Caveat**: Dragonfly uses the BSL/DCL license (source-available, not
  OSI-approved). Operators who require strict OSS licensing should swap in
  Valkey Operator via values overrides (Phase 3 task; the values shape
  under `cache:` is already operator-agnostic enough to support the swap
  once a template exists).

## Phase 1 → Phase 2 path

- Phase 1 ships Dragonfly CR templates only.
- Phase 2 adds a `cache.driver: valkey` alternative template for
  license-sensitive operators.
