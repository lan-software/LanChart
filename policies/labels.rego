package main

# Every chart-managed resource MUST carry the recommended Kubernetes labels,
# and `app.kubernetes.io/part-of` must be "lan-software" so the whole
# umbrella is greppable from kubectl.
#
# Runs under conftest --combine; each element of `input` is
# `{path, contents: <doc>}`.

required_labels := [
  "app.kubernetes.io/name",
  "app.kubernetes.io/instance",
  "app.kubernetes.io/managed-by",
  "app.kubernetes.io/part-of",
  "helm.sh/chart",
]

skip_kinds := {"CustomResourceDefinition"}

deny[msg] {
  some i
  obj := input[i].contents
  obj.metadata.name
  not skip_kinds[obj.kind]
  label := required_labels[_]
  not object.get(obj.metadata, "labels", {})[label]
  msg := sprintf("%s/%s missing required label %q", [obj.kind, obj.metadata.name, label])
}

deny[msg] {
  some i
  obj := input[i].contents
  obj.metadata.name
  not skip_kinds[obj.kind]
  part_of := object.get(obj.metadata, "labels", {})["app.kubernetes.io/part-of"]
  part_of
  part_of != "lan-software"
  msg := sprintf("%s/%s has app.kubernetes.io/part-of=%q, expected %q", [obj.kind, obj.metadata.name, part_of, "lan-software"])
}
