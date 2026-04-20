package main

# Pod Security policies — enforce PSA baseline on every rendered Pod spec
# produced by the chart (Deployment, Job, CronJob, DaemonSet, StatefulSet).
#
# Targets PSA profile: baseline (restricted tracked for Phase 4).
# Runs under conftest --combine; each element of `input` is
# `{path, contents: <doc>}`.

workload_kinds := {"Deployment", "Job", "CronJob", "DaemonSet", "StatefulSet"}

pod_spec(obj) = spec {
  obj.kind == "Deployment"
  spec := obj.spec.template.spec
}

pod_spec(obj) = spec {
  obj.kind == "Job"
  spec := obj.spec.template.spec
}

pod_spec(obj) = spec {
  obj.kind == "CronJob"
  spec := obj.spec.jobTemplate.spec.template.spec
}

pod_spec(obj) = spec {
  obj.kind == "DaemonSet"
  spec := obj.spec.template.spec
}

pod_spec(obj) = spec {
  obj.kind == "StatefulSet"
  spec := obj.spec.template.spec
}

# PSA baseline: hostPath volumes are forbidden.
deny[msg] {
  some i
  obj := input[i].contents
  workload_kinds[obj.kind]
  spec := pod_spec(obj)
  v := spec.volumes[_]
  v.hostPath
  msg := sprintf("%s/%s: hostPath volume is not allowed (PSA baseline)", [obj.kind, obj.metadata.name])
}

# PSA baseline: no privileged containers.
deny[msg] {
  some i
  obj := input[i].contents
  workload_kinds[obj.kind]
  spec := pod_spec(obj)
  c := array.concat(spec.containers, object.get(spec, "initContainers", []))[_]
  c.securityContext.privileged == true
  msg := sprintf("%s/%s: container %q runs privileged", [obj.kind, obj.metadata.name, c.name])
}

# PSA baseline: no hostNetwork / hostPID / hostIPC.
deny[msg] {
  some i
  obj := input[i].contents
  workload_kinds[obj.kind]
  spec := pod_spec(obj)
  spec.hostNetwork == true
  msg := sprintf("%s/%s: hostNetwork is not allowed", [obj.kind, obj.metadata.name])
}

deny[msg] {
  some i
  obj := input[i].contents
  workload_kinds[obj.kind]
  spec := pod_spec(obj)
  spec.hostPID == true
  msg := sprintf("%s/%s: hostPID is not allowed", [obj.kind, obj.metadata.name])
}

deny[msg] {
  some i
  obj := input[i].contents
  workload_kinds[obj.kind]
  spec := pod_spec(obj)
  spec.hostIPC == true
  msg := sprintf("%s/%s: hostIPC is not allowed", [obj.kind, obj.metadata.name])
}

# Every container must have a seccompProfile (pod-level or container-level).
deny[msg] {
  some i
  obj := input[i].contents
  workload_kinds[obj.kind]
  spec := pod_spec(obj)
  c := array.concat(spec.containers, object.get(spec, "initContainers", []))[_]
  not object.get(object.get(c, "securityContext", {}), "seccompProfile", {}).type
  not object.get(object.get(spec, "securityContext", {}), "seccompProfile", {}).type
  msg := sprintf("%s/%s: container %q has no seccompProfile (pod or container level)", [obj.kind, obj.metadata.name, c.name])
}

# Every container must drop ALL caps before adding any.
deny[msg] {
  some i
  obj := input[i].contents
  workload_kinds[obj.kind]
  spec := pod_spec(obj)
  c := array.concat(spec.containers, object.get(spec, "initContainers", []))[_]
  caps := object.get(object.get(c, "securityContext", {}), "capabilities", {})
  not array_contains(object.get(caps, "drop", []), "ALL")
  msg := sprintf("%s/%s: container %q must drop ALL capabilities before adding any", [obj.kind, obj.metadata.name, c.name])
}

# allowPrivilegeEscalation must be explicitly false.
deny[msg] {
  some i
  obj := input[i].contents
  workload_kinds[obj.kind]
  spec := pod_spec(obj)
  c := array.concat(spec.containers, object.get(spec, "initContainers", []))[_]
  object.get(c, "securityContext", {}).allowPrivilegeEscalation != false
  msg := sprintf("%s/%s: container %q must set allowPrivilegeEscalation: false", [obj.kind, obj.metadata.name, c.name])
}

array_contains(arr, val) {
  arr[_] == val
}
