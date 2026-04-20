{{/*
lan-common.labels — standard recommended labels + part-of + component.
Usage: include "lan-common.labels" (dict "context" . "component" "web")
*/}}
{{- define "lan-common.labels" -}}
helm.sh/chart: {{ include "lan-common.chart" .context }}
{{ include "lan-common.selectorLabels" . }}
{{- if .context.Chart.AppVersion }}
app.kubernetes.io/version: {{ .context.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: lan-software
{{- end -}}

{{/*
lan-common.selectorLabels — stable match-labels for Deployment/Service selectors.
Usage: include "lan-common.selectorLabels" (dict "context" . "component" "web")
Intentionally excludes version/chart so label values remain stable across upgrades.
*/}}
{{- define "lan-common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lan-common.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
lan-software.mawiguko.dev/component: {{ .component }}
{{- end }}
{{- end -}}
