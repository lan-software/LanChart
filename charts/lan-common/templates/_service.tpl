{{/*
lan-common.service — ClusterIP Service pointing at the web/server component.
Usage: include "lan-common.service" (dict "context" . "component" "web" "port" 80 "targetPort" "http")
*/}}
{{- define "lan-common.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "lan-common.componentName" (dict "context" .context "component" .component) }}
  namespace: {{ .context.Release.Namespace }}
  labels:
    {{- include "lan-common.labels" (dict "context" .context "component" .component) | nindent 4 }}
  {{- with .context.Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .context.Values.service.type | default "ClusterIP" }}
  ports:
    - name: http
      port: {{ .port | default 80 }}
      targetPort: {{ .targetPort | default "http" }}
      protocol: TCP
    {{- if .context.Values.serviceMonitor.enabled }}
    - name: metrics
      port: {{ .context.Values.service.metricsPort | default 9090 }}
      targetPort: {{ .context.Values.service.metricsPort | default 9090 }}
      protocol: TCP
    {{- end }}
  selector:
    {{- include "lan-common.selectorLabels" (dict "context" .context "component" .component) | nindent 4 }}
{{- end -}}
