package main

# Every Deployment in the release namespace must have at least one
# NetworkPolicy whose podSelector matchLabels is a subset of the
# Deployment's pod-template labels. Opt out per-Deployment by annotating
# `lan-software.mawiguko.dev/skip-netpol: "true"`.
#
# Runs under conftest --combine; conftest passes each document wrapped as
# `{path, contents}`, so we index through `.contents`.

deny[msg] {
  some i
  d := input[i].contents
  d.kind == "Deployment"
  not skip_netpol(d)
  pod_labels := object.get(d.spec.template.metadata, "labels", {})
  not matching_netpol_exists(pod_labels)
  msg := sprintf("Deployment/%s has no matching NetworkPolicy", [d.metadata.name])
}

skip_netpol(d) {
  annotations := object.get(d.metadata, "annotations", {})
  annotations["lan-software.mawiguko.dev/skip-netpol"] == "true"
}

matching_netpol_exists(pod_labels) {
  some j
  np := input[j].contents
  np.kind == "NetworkPolicy"
  match_labels := object.get(np.spec.podSelector, "matchLabels", {})
  selector_matches(match_labels, pod_labels)
}

selector_matches(required, actual) {
  count(required) > 0
  matched := {key | some key; required[key] == actual[key]}
  count(matched) == count(required)
}
