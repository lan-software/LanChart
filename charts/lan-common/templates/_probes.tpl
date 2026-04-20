{{/*
lan-common.probes — Laravel /up probe set, tuned for Octane cold-boot.
Usage: include "lan-common.probes" (dict "context" . "port" "http")
*/}}
{{- define "lan-common.probes" -}}
livenessProbe:
  httpGet:
    path: /up
    port: {{ .port | default "http" }}
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 5
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /up
    port: {{ .port | default "http" }}
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
startupProbe:
  httpGet:
    path: /up
    port: {{ .port | default "http" }}
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 12
{{- end -}}
