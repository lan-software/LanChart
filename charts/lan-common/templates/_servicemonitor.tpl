{{/*
lan-common.serviceMonitor — Prometheus Operator ServiceMonitor for /metrics.
Gated on .Values.serviceMonitor.enabled AND global.monitoring.enabled.
Usage: include "lan-common.serviceMonitor" (dict "context" . "component" "web")
*/}}
{{- define "lan-common.serviceMonitor" -}}
{{- $ctx := .context -}}
{{- $global := $ctx.Values.global | default dict -}}
{{- $monitoring := $global.monitoring | default dict -}}
{{- if and $ctx.Values.serviceMonitor.enabled $monitoring.enabled -}}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "lan-common.componentName" (dict "context" $ctx "component" .component) }}
  namespace: {{ $ctx.Release.Namespace }}
  labels:
    {{- include "lan-common.labels" (dict "context" $ctx "component" .component) | nindent 4 }}
    {{- with $monitoring.extraLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  selector:
    matchLabels:
      {{- include "lan-common.selectorLabels" (dict "context" $ctx "component" .component) | nindent 6 }}
  endpoints:
    - port: metrics
      path: {{ $ctx.Values.serviceMonitor.path | default "/metrics" }}
      interval: {{ $ctx.Values.serviceMonitor.interval | default "30s" }}
      scrapeTimeout: {{ $ctx.Values.serviceMonitor.scrapeTimeout | default "10s" }}
{{- end -}}
{{- end -}}
