package main

# Every Deployment in the release namespace must have at least one
# NetworkPolicy whose podSelector matches its pod template labels, UNLESS
# the Deployment explicitly opts out via
# `lan-software.mawiguko.dev/skip-netpol: "true"` annotation.
#
# This runs against the full rendered manifest stream; conftest provides
# `input_documents` as a collection of all documents when you call it with
# `--combine`. We therefore run it as two passes: first with individual
# documents (checks labels + security), then here we build a set view.

deployments[obj] {
  obj := input
  obj.kind == "Deployment"
}

netpols[obj] {
  obj := input
  obj.kind == "NetworkPolicy"
}

deny[msg] {
  d := deployments[_]
  not object.get(d.metadata, "annotations", {})["lan-software.mawiguko.dev/skip-netpol"] == "true"
  pod_labels := d.spec.template.metadata.labels
  not network_policy_matches(pod_labels)
  msg := sprintf("Deployment/%s has no matching NetworkPolicy", [d.metadata.name])
}

network_policy_matches(labels) {
  np := netpols[_]
  match_labels := object.get(np.spec.podSelector, "matchLabels", {})
  every_label_matches(match_labels, labels)
}

every_label_matches(required, actual) {
  # Every key in `required` must exist in `actual` with the same value.
  required[key] == actual[key]
  # Trigger the evaluation for all keys:
  count({k | required[k]}) == count({k | required[k]; required[k] == actual[k]})
}
