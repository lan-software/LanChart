{{/*
lan-common.hpa — HorizontalPodAutoscaler for a given component.
Usage: include "lan-common.hpa" (dict "context" . "component" "web" "hpa" .Values.web.hpa)
*/}}
{{- define "lan-common.hpa" -}}
{{- if .hpa.enabled -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "lan-common.componentName" (dict "context" .context "component" .component) }}
  namespace: {{ .context.Release.Namespace }}
  labels:
    {{- include "lan-common.labels" (dict "context" .context "component" .component) | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "lan-common.componentName" (dict "context" .context "component" .component) }}
  minReplicas: {{ .hpa.minReplicas | default 2 }}
  maxReplicas: {{ .hpa.maxReplicas | default 6 }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .hpa.targetCPUUtilizationPercentage | default 70 }}
    {{- if .hpa.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .hpa.targetMemoryUtilizationPercentage }}
    {{- end }}
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
    scaleUp:
      stabilizationWindowSeconds: 60
{{- end -}}
{{- end -}}
