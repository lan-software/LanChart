{{/*
Umbrella-level helper templates. Most shared helpers live in lan-common.
*/}}

{{- define "lan-software.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "lan-software.labels" -}}
app.kubernetes.io/name: lan-software
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: lan-software
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{/*
Enabled satellite slugs for the bootstrap Job.
*/}}
{{- define "lan-software.enabledSatellites" -}}
{{- $list := list -}}
{{- if (index .Values "lanbrackets" "enabled") -}}{{- $list = append $list "lanbrackets" -}}{{- end -}}
{{- if (index .Values "lanentrance" "enabled") -}}{{- $list = append $list "lanentrance" -}}{{- end -}}
{{- if (index .Values "lanshout" "enabled") -}}{{- $list = append $list "lanshout" -}}{{- end -}}
{{- if (index .Values "lanhelp" "enabled") -}}{{- $list = append $list "lanhelp" -}}{{- end -}}
{{- $list | toJson -}}
{{- end -}}
