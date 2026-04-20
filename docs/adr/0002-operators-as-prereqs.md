# ADR 0002 — Operators are cluster-scoped prerequisites, not chart deps

Date: 2026-04-20
Status: Accepted

## Context

The chart uses CloudNativePG (Postgres), Dragonfly Operator (cache), and
cert-manager (TLS). Each ships CRDs that affect the whole cluster.

## Decision

Operators are **NOT** declared as Helm dependencies of the `lan-software`
chart. The chart emits only their Custom Resources (`Cluster`, `Dragonfly`,
`Certificate`, `Tenant`) guarded by `*.createInstance` / `*.createCluster`
values toggles. Operators are installed cluster-wide, once, by the cluster
operator (see `docs/operators.md`).

## Consequences

- The chart cannot install an operator on its own. This is a feature: CRDs
  are shared cluster state and should not be owned by an app chart whose
  uninstall could in principle nuke them across all namespaces.
- Multiple `lan-software` releases (per-environment, per-tenant) can
  coexist on the same cluster without fighting over operator versions.
- Operators can be upgraded on their own cadence without tearing down the
  application.

## Alternatives considered

- **Ship CNPG/Dragonfly/cert-manager as `dependencies:` in Chart.yaml.**
  Rejected — `helm uninstall` of the app release would orphan / remove CRDs
  in use by unrelated workloads. Helm CRD lifecycle handling is
  historically brittle for this reason.
- **Embed the operator manifests verbatim in `templates/`.** Same problem.
