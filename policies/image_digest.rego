package main

# Warn when a container image is pinned only by tag (no @sha256: digest).
# SSS ENV-DEP-010 requires production images to be digest-pinned.
#
# Emitted as `warn` rather than `deny`: the chart's default image.tag is
# Chart.AppVersion (a human-readable semver), which is not digest-pinned.
# Digest pinning happens at release time when the Docker image exists.
#
# Runs under conftest --combine; each element of `input` is
# `{path, contents: <doc>}`.

warn[msg] {
  some i
  obj := input[i].contents
  obj.kind == "Deployment"
  c := obj.spec.template.spec.containers[_]
  image := c.image
  not contains(image, "@sha256:")
  msg := sprintf("Deployment/%s container %q uses tag-pinned image %q (SSS ENV-DEP-010 recommends digest pinning)", [obj.metadata.name, c.name, image])
}
