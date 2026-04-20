{{/*
lan-common.pdb — PodDisruptionBudget for a given component.
Emitted only when pdb.enabled AND replicas >= 2.
Usage: include "lan-common.pdb" (dict "context" . "component" "web" "pdb" .Values.web.pdb "replicas" .Values.web.replicaCount)
*/}}
{{- define "lan-common.pdb" -}}
{{- if and .pdb.enabled (gt (int (.replicas | default 1)) 1) -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "lan-common.componentName" (dict "context" .context "component" .component) }}
  namespace: {{ .context.Release.Namespace }}
  labels:
    {{- include "lan-common.labels" (dict "context" .context "component" .component) | nindent 4 }}
spec:
  {{- if .pdb.minAvailable }}
  minAvailable: {{ .pdb.minAvailable }}
  {{- else if .pdb.maxUnavailable }}
  maxUnavailable: {{ .pdb.maxUnavailable }}
  {{- else }}
  minAvailable: 1
  {{- end }}
  selector:
    matchLabels:
      {{- include "lan-common.selectorLabels" (dict "context" .context "component" .component) | nindent 6 }}
{{- end -}}
{{- end -}}
