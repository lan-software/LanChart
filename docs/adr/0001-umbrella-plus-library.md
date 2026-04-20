# ADR 0001 — Umbrella application chart + `lan-common` library chart

Date: 2026-04-20
Status: Accepted

## Context

The Lan Software ecosystem consists of LanCore (hub) plus four satellite
Laravel apps. Operators should be able to deploy all of them with a single
`helm install`, while individual sub-charts remain independently consumable.

## Decision

Ship a top-level `lan-software` **application** chart with sub-charts for
each app as Helm dependencies, plus a sibling `lan-common` **library** chart
(`type: library`) that exposes named templates consumed by every sub-chart.

## Consequences

- One `helm install` stands up the whole stack; `enabled: false` on any
  sub-chart opts it out.
- Shared concerns (labels, probes, security context, NetworkPolicy,
  migration Job, Deployment shape) live in exactly one place.
- Sub-charts can be helm-installed standalone for testing.
- Library charts must not render resources themselves — every sub-chart
  has to `include` the shared templates explicitly. This is the idiomatic
  Helm pattern and mirrors what bitnami-common does.

## Alternatives considered

- **Per-app top-level charts, no umbrella.** Rejected — forces operators to
  run 5 `helm install` commands and repeat `--set` flags.
- **Copy-paste templates into each sub-chart.** Rejected — drift guaranteed.
- **Unpublished `_helpers.tpl` per sub-chart.** Doesn't scale across 5 apps.
