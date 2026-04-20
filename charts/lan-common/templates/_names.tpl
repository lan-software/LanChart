{{/*
lan-common.name — the chart's short name (respects nameOverride).
*/}}
{{- define "lan-common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
lan-common.fullname — release-scoped full name (respects fullnameOverride).
Matches chart name when it already contains the release, otherwise prefixes the release name.
*/}}
{{- define "lan-common.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
lan-common.componentName — fullname suffixed with a component (web|worker|server|migrate).
Usage: include "lan-common.componentName" (dict "context" . "component" "web")
*/}}
{{- define "lan-common.componentName" -}}
{{- $fullname := include "lan-common.fullname" .context -}}
{{- printf "%s-%s" $fullname .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
lan-common.chart — chart name and version, formatted per Helm conventions.
*/}}
{{- define "lan-common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
lan-common.serviceAccountName — named SA or auto-named fallback.
*/}}
{{- define "lan-common.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "lan-common.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
