{{/*
lancore-specific helper templates. Most shared helpers live in lan-common.
*/}}

{{/*
lancore.appSecretName — the name of the synthesised app Secret.
*/}}
{{- define "lancore.appSecretName" -}}
{{ include "lan-common.fullname" . }}-app
{{- end -}}

{{/*
lancore.signingKeysSecretName — override-aware.
*/}}
{{- define "lancore.signingKeysSecretName" -}}
{{ .Values.ticketing.signingKeys.secretName | default (printf "%s-ticket-signing-keys" (include "lan-common.fullname" .)) }}
{{- end -}}
