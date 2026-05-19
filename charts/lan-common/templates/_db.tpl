{{/*
lan-common.dbHost — resolves the Postgres host for a Lan-Software app.

Resolution order:
  1. Per-app override .Values.database.existing.host (highest priority).
  2. global.database.provider == "zalando"  -> {{ global.database.zalando.clusterName }}
     (the Zalando postgres-operator creates a read-write Service named after
     the postgresql CR, in the release namespace).
  3. global.database.provider == "external" -> global.database.external.host.

Fails loudly if no host can be resolved.

Usage: include "lan-common.dbHost" .
*/}}
{{- define "lan-common.dbHost" -}}
{{- $existingHost := (((.Values.database).existing).host) | default "" -}}
{{- $g := .Values.global | default dict -}}
{{- $db := $g.database | default dict -}}
{{- $provider := $db.provider | default "external" -}}
{{- if $existingHost -}}
{{- $existingHost -}}
{{- else if eq $provider "zalando" -}}
{{- $cluster := required "global.database.zalando.clusterName is required when provider=zalando" (($db.zalando).clusterName) -}}
{{- $cluster -}}
{{- else if eq $provider "external" -}}
{{- $h := ($db.external).host | default "" -}}
{{- if not $h -}}
{{- fail "global.database.external.host must be set when provider=external (or set .Values.database.existing.host on the sub-chart)" -}}
{{- end -}}
{{- $h -}}
{{- else -}}
{{- fail (printf "Unknown global.database.provider: %s" $provider) -}}
{{- end -}}
{{- end -}}

{{/*
lan-common.dbPort — resolves the Postgres port.

Per-app .Values.database.existing.port wins; otherwise global.database.external.port
(zalando always uses 5432).

Usage: include "lan-common.dbPort" .
*/}}
{{- define "lan-common.dbPort" -}}
{{- $existingPort := (((.Values.database).existing).port) -}}
{{- $g := .Values.global | default dict -}}
{{- $db := $g.database | default dict -}}
{{- $provider := $db.provider | default "external" -}}
{{- if $existingPort -}}
{{- $existingPort -}}
{{- else if eq $provider "external" -}}
{{- ($db.external).port | default 5432 -}}
{{- else -}}
{{- 5432 -}}
{{- end -}}
{{- end -}}

{{/*
lan-common.dbPasswordSecretName — resolves the K8s Secret name that holds
the per-app Postgres password.

  1. Per-app override .Values.database.existing.passwordSecret.name.
  2. provider=zalando -> "<username>.<clusterName>.credentials.postgresql.acid.zalan.do"
     (Zalando postgres-operator naming convention).
  3. provider=external -> required; fails if unset.

Usage: include "lan-common.dbPasswordSecretName" .
*/}}
{{- define "lan-common.dbPasswordSecretName" -}}
{{- $existingName := (((((.Values.database).existing).passwordSecret).name)) | default "" -}}
{{- $g := .Values.global | default dict -}}
{{- $db := $g.database | default dict -}}
{{- $provider := $db.provider | default "external" -}}
{{- if $existingName -}}
{{- $existingName -}}
{{- else if eq $provider "zalando" -}}
{{- $cluster := required "global.database.zalando.clusterName is required when provider=zalando" (($db.zalando).clusterName) -}}
{{- $user := required ".Values.database.existing.username is required" .Values.database.existing.username -}}
{{- printf "%s.%s.credentials.postgresql.acid.zalan.do" $user $cluster -}}
{{- else -}}
{{- fail ".Values.database.existing.passwordSecret.name must be set when global.database.provider=external" -}}
{{- end -}}
{{- end -}}

{{/*
lan-common.dbPasswordSecretKey — the key inside the Secret. Zalando always
writes the password under key "password". External instances may use a
different key; per-app override wins.

Usage: include "lan-common.dbPasswordSecretKey" .
*/}}
{{- define "lan-common.dbPasswordSecretKey" -}}
{{- (((((.Values.database).existing).passwordSecret).key)) | default "password" -}}
{{- end -}}
