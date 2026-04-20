package main

# Pod Security policies — enforce PSA baseline on every rendered Pod spec
# produced by the chart (Deployment, Job, CronJob, DaemonSet, StatefulSet).
#
# Targets PSA profile: baseline (restricted tracked for Phase 4).
# Docs: https://kubernetes.io/docs/concepts/security/pod-security-standards/

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
  workload_kinds[input.kind]
  spec := pod_spec(input)
  v := spec.volumes[_]
  v.hostPath
  msg := sprintf("%s/%s: hostPath volume is not allowed (PSA baseline)", [input.kind, input.metadata.name])
}

# PSA baseline: no privileged containers.
deny[msg] {
  workload_kinds[input.kind]
  spec := pod_spec(input)
  c := array.concat(spec.containers, object.get(spec, "initContainers", []))[_]
  c.securityContext.privileged == true
  msg := sprintf("%s/%s: container %q runs privileged", [input.kind, input.metadata.name, c.name])
}

# PSA baseline: no hostNetwork / hostPID / hostIPC.
deny[msg] {
  workload_kinds[input.kind]
  spec := pod_spec(input)
  spec.hostNetwork == true
  msg := sprintf("%s/%s: hostNetwork is not allowed", [input.kind, input.metadata.name])
}

deny[msg] {
  workload_kinds[input.kind]
  spec := pod_spec(input)
  spec.hostPID == true
  msg := sprintf("%s/%s: hostPID is not allowed", [input.kind, input.metadata.name])
}

deny[msg] {
  workload_kinds[input.kind]
  spec := pod_spec(input)
  spec.hostIPC == true
  msg := sprintf("%s/%s: hostIPC is not allowed", [input.kind, input.metadata.name])
}

# Every container must have a seccompProfile.
deny[msg] {
  workload_kinds[input.kind]
  spec := pod_spec(input)
  c := array.concat(spec.containers, object.get(spec, "initContainers", []))[_]
  not c.securityContext.seccompProfile.type
  not spec.securityContext.seccompProfile.type
  msg := sprintf("%s/%s: container %q has no seccompProfile (pod or container level)", [input.kind, input.metadata.name, c.name])
}

# Every container must drop ALL caps before adding narrow ones.
deny[msg] {
  workload_kinds[input.kind]
  spec := pod_spec(input)
  c := array.concat(spec.containers, object.get(spec, "initContainers", []))[_]
  caps := object.get(c.securityContext, "capabilities", {})
  not array_contains(object.get(caps, "drop", []), "ALL")
  msg := sprintf("%s/%s: container %q must drop ALL capabilities before adding any", [input.kind, input.metadata.name, c.name])
}

# allowPrivilegeEscalation must be explicitly false.
deny[msg] {
  workload_kinds[input.kind]
  spec := pod_spec(input)
  c := array.concat(spec.containers, object.get(spec, "initContainers", []))[_]
  c.securityContext.allowPrivilegeEscalation != false
  msg := sprintf("%s/%s: container %q must set allowPrivilegeEscalation: false", [input.kind, input.metadata.name, c.name])
}

array_contains(arr, val) {
  arr[_] == val
}
