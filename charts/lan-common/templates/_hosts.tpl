{{/*
lan-common.lancoreHost — returns the canonical external hostname for
LanCore. Prefers `global.lancoreHost` if set, otherwise derives
`lancore.<global.domain>`. Fails loudly if neither is set.
Usage: include "lan-common.lancoreHost" .
*/}}
{{- define "lan-common.lancoreHost" -}}
{{- $g := .Values.global | default dict -}}
{{- if $g.lancoreHost -}}
{{- $g.lancoreHost -}}
{{- else if $g.domain -}}
{{- printf "lancore.%s" $g.domain -}}
{{- else -}}
{{- fail "global.domain or global.lancoreHost must be set" -}}
{{- end -}}
{{- end -}}

{{/*
lan-common.satelliteHost — returns the external hostname for a given
satellite slug, honouring `global.satelliteHostStyle` (flat | prefixed |
custom) and per-satellite overrides under `global.integrations.<slug>.host`.

Usage: include "lan-common.satelliteHost" (dict "context" . "slug" "lanbrackets")
*/}}
{{- define "lan-common.satelliteHost" -}}
{{- $ctx := .context -}}
{{- $slug := required "lan-common.satelliteHost requires slug" .slug -}}
{{- $g := $ctx.Values.global | default dict -}}
{{- $integ := get ($g.integrations | default dict) $slug | default dict -}}
{{- $style := $g.satelliteHostStyle | default "flat" -}}
{{- if $integ.host -}}
{{- $integ.host -}}
{{- else if not $g.domain -}}
{{- fail (printf "global.domain must be set to derive host for %s" $slug) -}}
{{- else if eq $style "flat" -}}
{{- printf "%s.%s" $slug $g.domain -}}
{{- else if eq $style "prefixed" -}}
{{- printf "%s.lancore.%s" $slug $g.domain -}}
{{- else if eq $style "custom" -}}
{{- fail (printf "satelliteHostStyle=custom but global.integrations.%s.host is unset" $slug) -}}
{{- else -}}
{{- fail (printf "Unknown satelliteHostStyle: %s" $style) -}}
{{- end -}}
{{- end -}}

{{/*
lan-common.scheme — default https, overridable via global.scheme.
Usage: include "lan-common.scheme" .
*/}}
{{- define "lan-common.scheme" -}}
{{- ($.Values.global).scheme | default "https" -}}
{{- end -}}

{{/*
lan-common.lancoreBaseUrl — externally-reachable LanCore URL
(for browser redirects: SSO, callback).
Usage: include "lan-common.lancoreBaseUrl" .
*/}}
{{- define "lan-common.lancoreBaseUrl" -}}
{{- printf "%s://%s" (include "lan-common.scheme" .) (include "lan-common.lancoreHost" .) -}}
{{- end -}}

{{/*
lan-common.lancoreInternalUrl — in-cluster LanCore Service DNS
(for server-to-server calls that bypass external DNS/TLS).
Usage: include "lan-common.lancoreInternalUrl" .
*/}}
{{- define "lan-common.lancoreInternalUrl" -}}
{{- printf "http://lancore-web.%s.svc.cluster.local" .Release.Namespace -}}
{{- end -}}

{{/*
lan-common.satelliteCallbackUrl — SSO callback URL for a satellite.
Usage: include "lan-common.satelliteCallbackUrl" (dict "context" . "slug" "lanbrackets")
*/}}
{{- define "lan-common.satelliteCallbackUrl" -}}
{{- $host := include "lan-common.satelliteHost" . -}}
{{- printf "%s://%s/auth/callback" (include "lan-common.scheme" .context) $host -}}
{{- end -}}

{{/*
lan-common.integrationsSeedSecretName — the umbrella's shared seed Secret.
Usage: include "lan-common.integrationsSeedSecretName" .
*/}}
{{- define "lan-common.integrationsSeedSecretName" -}}
{{- printf "%s-integrations-seed" .Release.Name -}}
{{- end -}}

{{/*
lan-common.upperSlug — uppercases a satellite slug for env-var naming.
e.g. "lanbrackets" -> "LANBRACKETS". Used to derive env var keys like
`LANBRACKETS_LANCORE_TOKEN`.
Usage: include "lan-common.upperSlug" (dict "slug" "lanbrackets")
*/}}
{{- define "lan-common.upperSlug" -}}
{{- required "upperSlug requires slug" .slug | upper | replace "-" "_" -}}
{{- end -}}
