{{/*
lan-common.commonEnv — env shared by every Laravel application container.
Usage: include "lan-common.commonEnv" (dict "context" .)
*/}}
{{- define "lan-common.commonEnv" -}}
{{- $global := .context.Values.global | default dict -}}
- name: APP_ENV
  value: {{ .context.Values.appEnv | default "production" | quote }}
- name: APP_DEBUG
  value: {{ .context.Values.appDebug | default false | quote }}
- name: LOG_CHANNEL
  value: {{ .context.Values.logChannel | default "stderr" | quote }}
- name: APP_URL
  value: {{ .context.Values.appUrl | default (printf "%s://%s" (include "lan-common.scheme" .context) (include "lan-common.computedChartHost" .context)) | quote }}
- name: TZ
  value: {{ .context.Values.timezone | default "UTC" | quote }}
{{- end -}}

{{/*
lan-common.otelEnv — OTel exporter env; only rendered when global.otel.enabled.
*/}}
{{- define "lan-common.otelEnv" -}}
{{- $global := .context.Values.global | default dict -}}
{{- $otel := $global.otel | default dict -}}
{{- if $otel.enabled -}}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ $otel.endpoint | quote }}
- name: OTEL_SERVICE_NAME
  value: {{ include "lan-common.name" .context | quote }}
- name: OTEL_RESOURCE_ATTRIBUTES
  value: {{ printf "service.name=%s,service.namespace=%s,service.version=%s" (include "lan-common.name" .context) .context.Release.Namespace .context.Chart.AppVersion | quote }}
{{- end -}}
{{- end -}}

{{/*
lan-common.computedChartHost — computes this chart's external host, honouring
global.domain + satelliteHostStyle. Falls back to lancoreHost when the chart
is LanCore itself (no .Values.lancore.appSlug).
Usage: include "lan-common.computedChartHost" .
*/}}
{{- define "lan-common.computedChartHost" -}}
{{- $slug := ((.Values.lancore | default dict).appSlug | default "") -}}
{{- if $slug -}}
{{- include "lan-common.satelliteHost" (dict "context" . "slug" $slug) -}}
{{- else -}}
{{- include "lan-common.lancoreHost" . -}}
{{- end -}}
{{- end -}}

{{/*
lan-common.lancoreSatelliteEnv — bearer-token + webhook-secret env vars that
every satellite needs. LANCORE_TOKEN and LANCORE_WEBHOOK_SECRET are pulled
from the umbrella's shared `{{ Release.Name }}-integrations-seed` Secret,
keyed by `<SLUG>_LANCORE_TOKEN` and `<SLUG>_ROLES_WEBHOOK_SECRET`
respectively. Non-secret env (base URL, callback, slug) is emitted by each
sub-chart's configmap-env.yaml via the lancoreBaseUrl / satelliteCallbackUrl
helpers — not here.

Usage: include "lan-common.lancoreSatelliteEnv" (dict "context" .)
*/}}
{{- define "lan-common.lancoreSatelliteEnv" -}}
{{- $lancore := .context.Values.lancore | default dict -}}
{{- $sat := $lancore.satellite | default dict -}}
{{- if $sat.enabled -}}
{{- $slug := required "lancore.appSlug is required on satellite charts" $lancore.appSlug -}}
{{- $upper := $slug | upper | replace "-" "_" -}}
{{- $seedName := include "lan-common.integrationsSeedSecretName" .context -}}
- name: LANCORE_TIMEOUT
  value: {{ $sat.timeoutSeconds | default 5 | quote }}
- name: LANCORE_RETRIES
  value: {{ $sat.retries | default 2 | quote }}
- name: LANCORE_RETRY_DELAY
  value: {{ $sat.retryDelayMs | default 100 | quote }}
- name: LANCORE_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ $seedName }}
      key: {{ printf "%s_LANCORE_TOKEN" $upper | quote }}
- name: LANCORE_WEBHOOK_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ $seedName }}
      key: {{ printf "%s_ROLES_WEBHOOK_SECRET" $upper | quote }}
{{- end -}}
{{- end -}}
