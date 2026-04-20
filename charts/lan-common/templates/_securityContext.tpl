{{/*
lan-common.podSecurityContext — pod-level defaults.

NOTE: LanBase starts supervisord as PID 1 under root (needed to manage
child-process stdio + chown + su-exec drop to www-data). This precludes PSA
`restricted` today — the Phase 1 target is PSA `baseline`. Sub-charts may
override via .Values.podSecurityContext once LanBase supports a non-root
supervisor.
*/}}
{{- define "lan-common.podSecurityContext" -}}
{{- $defaults := dict
  "fsGroup" 82
  "fsGroupChangePolicy" "OnRootMismatch"
  "seccompProfile" (dict "type" "RuntimeDefault")
-}}
{{- $merged := mergeOverwrite $defaults (.Values.podSecurityContext | default dict) -}}
{{- toYaml $merged -}}
{{- end -}}

{{/*
lan-common.containerSecurityContext — container-level defaults.

- allowPrivilegeEscalation: false (but SETUID cap kept so su-exec can drop).
- Drop ALL capabilities, then add back the narrow set supervisord + su-exec
  require: CHOWN (entrypoint chown), SETUID/SETGID (su-exec drop),
  NET_BIND_SERVICE (FrankenPHP binds :80), DAC_OVERRIDE/FOWNER (chown + mkdir
  on a tree the image owner doesn't equal).
- readOnlyRootFilesystem: true (Phase 2). The deployment template mounts
  emptyDir volumes for every path the runtime writes to: /tmp,
  /var/run/supervisor, /var/log/supervisor, /data/caddy, /config/caddy,
  /var/www/html/storage/{framework,logs,app}, /var/www/html/bootstrap/cache.
*/}}
{{- define "lan-common.containerSecurityContext" -}}
{{- $defaults := dict
  "allowPrivilegeEscalation" false
  "privileged" false
  "readOnlyRootFilesystem" true
  "capabilities" (dict
    "drop" (list "ALL")
    "add" (list "CHOWN" "FOWNER" "DAC_OVERRIDE" "NET_BIND_SERVICE" "SETUID" "SETGID")
  )
  "seccompProfile" (dict "type" "RuntimeDefault")
-}}
{{- $merged := mergeOverwrite $defaults (.Values.containerSecurityContext | default dict) -}}
{{- toYaml $merged -}}
{{- end -}}
