{{/*
lan-common.serviceAccount — renders a ServiceAccount when .Values.serviceAccount.create.
Usage: {{ include "lan-common.serviceAccount" . }}
*/}}
{{- define "lan-common.serviceAccount" -}}
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "lan-common.serviceAccountName" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "lan-common.labels" (dict "context" .) | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .Values.serviceAccount.automountToken | default false }}
{{- end -}}
{{- end -}}
