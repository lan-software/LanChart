{{/*
lan-common.prometheusRule — emit a monitoring.coreos.com/v1 PrometheusRule
only when BOTH the sub-chart's .Values.prometheusRule.enabled and
.Values.global.monitoring.enabled are true.

The caller supplies a `groups` list (each group a dict with `name` and
`rules`) OR lets the sub-chart set .Values.prometheusRule.overrideGroups
to fully replace the library-provided defaults.

Usage:
  include "lan-common.prometheusRule" (dict "context" . "groups" $groups)
*/}}
{{- define "lan-common.prometheusRule" -}}
{{- $ctx := .context -}}
{{- $monitoring := ($ctx.Values.global | default dict).monitoring | default dict -}}
{{- if and $ctx.Values.prometheusRule.enabled $monitoring.enabled -}}
{{- $groups := .groups | default list -}}
{{- if $ctx.Values.prometheusRule.overrideGroups -}}
{{- $groups = $ctx.Values.prometheusRule.overrideGroups -}}
{{- end -}}
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: {{ include "lan-common.fullname" $ctx }}
  namespace: {{ $ctx.Release.Namespace }}
  labels:
    {{- include "lan-common.labels" (dict "context" $ctx) | nindent 4 }}
    {{- with $monitoring.ruleLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  groups:
    {{- toYaml $groups | nindent 4 }}
{{- end -}}
{{- end -}}

{{/*
lan-common.prometheusRule.baseGroups — default rule groups every Laravel
sub-chart inherits: HTTP 5xx rate spike, pod restart storm, failed migration
Job. Sub-charts concat their own groups on top.
Usage: include "lan-common.prometheusRule.baseGroups" (dict "context" .) | fromYaml
*/}}
{{- define "lan-common.prometheusRule.baseGroups" -}}
- name: {{ include "lan-common.name" .context }}.availability
  rules:
    - alert: {{ include "lan-common.name" .context | title }}HTTP5xxRateHigh
      expr: |
        sum(rate(nginx_ingress_controller_requests{exported_namespace="{{ .context.Release.Namespace }}",exported_service=~"{{ include "lan-common.name" .context }}.*",status=~"5.."}[5m]))
        / sum(rate(nginx_ingress_controller_requests{exported_namespace="{{ .context.Release.Namespace }}",exported_service=~"{{ include "lan-common.name" .context }}.*"}[5m]))
        > 0.02
      for: 5m
      labels:
        severity: warning
        app: {{ include "lan-common.name" .context }}
      annotations:
        summary: "{{ include "lan-common.name" .context }} 5xx rate > 2% for 5m"
        description: "HTTP 5xx responses exceed 2% of total requests sustained over 5 minutes."
    - alert: {{ include "lan-common.name" .context | title }}PodRestartStorm
      expr: |
        max by (pod) (
          increase(kube_pod_container_status_restarts_total{namespace="{{ .context.Release.Namespace }}",pod=~"{{ include "lan-common.fullname" .context }}.*"}[10m])
        ) > 3
      for: 5m
      labels:
        severity: warning
        app: {{ include "lan-common.name" .context }}
      annotations:
        summary: "{{ include "lan-common.name" .context }} pod restarting repeatedly"
        description: "A pod has restarted more than 3 times in the last 10 minutes."
- name: {{ include "lan-common.name" .context }}.migrations
  rules:
    - alert: {{ include "lan-common.name" .context | title }}MigrationJobFailed
      expr: |
        max by (job_name) (
          kube_job_status_failed{namespace="{{ .context.Release.Namespace }}",job_name=~"{{ include "lan-common.fullname" .context }}-migrate.*"}
        ) > 0
      for: 1m
      labels:
        severity: critical
        app: {{ include "lan-common.name" .context }}
      annotations:
        summary: "{{ include "lan-common.name" .context }} pre-upgrade migration Job failed"
        description: "The pre-install/pre-upgrade migration Job has a non-zero failure count. Releases will not roll forward."
{{- end -}}
