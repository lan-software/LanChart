package main

# Warn when a container image is pinned only by tag (no @sha256: digest).
# SSS ENV-DEP-010 requires production images to be digest-pinned.
#
# This is emitted as `warn` rather than `deny` during Phase 3 — the chart
# defaults (image.tag = Chart.AppVersion) do NOT pin to a digest, because
# digests are only known after a release tag is cut. Phase 3 CI runs on
# pre-release state, so promoting to `deny` here would block every lint
# until the release workflow has produced real tags.

warn[msg] {
  input.kind == "Deployment"
  c := input.spec.template.spec.containers[_]
  image := c.image
  not contains(image, "@sha256:")
  msg := sprintf("Deployment/%s container %q uses tag-pinned image %q (SSS ENV-DEP-010 recommends digest pinning)", [input.metadata.name, c.name, image])
}
