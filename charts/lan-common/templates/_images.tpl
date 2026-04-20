{{/*
lan-common.image — fully-qualified image reference honouring the umbrella's
global.image.registry and the sub-chart's image.repository + image.tag.
If image.repository already contains a registry (slashes >= 2), the global
registry is ignored so operators can override per-app.
*/}}
{{- define "lan-common.image" -}}
{{- $global := .context.Values.global | default dict -}}
{{- $globalImage := $global.image | default dict -}}
{{- $registry := $globalImage.registry | default "" -}}
{{- $repo := .image.repository -}}
{{- $tag := default .context.Chart.AppVersion .image.tag -}}
{{- if and $registry (not (contains "/" $repo | not)) -}}
{{- /* if repo has no slash, prefix the registry */ -}}
{{- end -}}
{{- if $registry -}}
{{- if hasPrefix $registry $repo -}}
{{ printf "%s:%s" $repo $tag }}
{{- else if contains "/" $repo -}}
{{ printf "%s:%s" $repo $tag }}
{{- else -}}
{{ printf "%s/%s:%s" $registry $repo $tag }}
{{- end -}}
{{- else -}}
{{ printf "%s:%s" $repo $tag }}
{{- end -}}
{{- end -}}

{{/*
lan-common.imagePullSecrets — merges global + per-chart pull secrets, deduped.
*/}}
{{- define "lan-common.imagePullSecrets" -}}
{{- $secrets := list -}}
{{- $global := .Values.global | default dict -}}
{{- range ($global.imagePullSecrets | default list) -}}
{{- $secrets = append $secrets . -}}
{{- end -}}
{{- range (.Values.imagePullSecrets | default list) -}}
{{- $secrets = append $secrets . -}}
{{- end -}}
{{- if $secrets -}}
imagePullSecrets:
{{- range ($secrets | uniq) }}
  - {{ toYaml . | nindent 4 | trim }}
{{- end -}}
{{- end -}}
{{- end -}}
