package main

# Every chart-managed resource MUST carry the recommended Kubernetes labels.
# This is a stricter-than-Helm baseline — app.kubernetes.io/part-of must be
# "lan-software" so the whole umbrella is greppable from kubectl.

required_labels := [
  "app.kubernetes.io/name",
  "app.kubernetes.io/instance",
  "app.kubernetes.io/managed-by",
  "app.kubernetes.io/part-of",
  "helm.sh/chart",
]

# Skip some kinds that commonly don't carry these labels (hook tokens, etc).
skip_kinds := {"CustomResourceDefinition"}

deny[msg] {
  not skip_kinds[input.kind]
  input.metadata.name
  label := required_labels[_]
  not input.metadata.labels[label]
  msg := sprintf("%s/%s missing required label %q", [input.kind, input.metadata.name, label])
}

deny[msg] {
  not skip_kinds[input.kind]
  input.metadata.name
  input.metadata.labels["app.kubernetes.io/part-of"]
  input.metadata.labels["app.kubernetes.io/part-of"] != "lan-software"
  msg := sprintf("%s/%s has app.kubernetes.io/part-of=%q, expected %q", [input.kind, input.metadata.name, input.metadata.labels["app.kubernetes.io/part-of"], "lan-software"])
}
