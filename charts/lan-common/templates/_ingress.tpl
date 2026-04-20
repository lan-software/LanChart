{{/*
lan-common.ingress — main Ingress for a sub-chart. Admin-only paths (e.g.
/horizon, /pulse on LanCore) are gated by one of two auth modes, selected
via .Values.ingress.adminAuth.mode:

  - "none"        — no auth (Phase 1 default; insecure for prod).
  - "basic"       — nginx basic-auth via an htpasswd Secret the operator
                    provisions out of band (.Values.ingress.adminAuth.basic.secretName).
  - "oauth2proxy" — delegates to an oauth2-proxy Service the operator
                    owns separately (.Values.ingress.adminAuth.oauth2proxy.upstream).

The chart does NOT deploy an oauth2-proxy pod; ADR-0002 keeps cluster-wide
auth infrastructure out of app charts.

Because nginx-ingress scopes auth annotations to the entire Ingress, the
admin paths live on a **second** Ingress object named `{{ fullname }}-admin`
that reuses the same host, rewrites to the main Service, and carries the
auth annotations. This keeps the main Ingress annotation-free.

Usage: include "lan-common.ingress" (dict "context" . "component" "web" "servicePort" 80)
*/}}
{{- define "lan-common.ingress" -}}
{{- if .context.Values.ingress.enabled -}}
{{- $ctx := .context -}}
{{- $component := .component -}}
{{- $servicePort := .servicePort | default 80 -}}
{{- $serviceName := include "lan-common.componentName" (dict "context" $ctx "component" $component) -}}
{{- $adminAuth := ($ctx.Values.ingress.adminAuth | default dict) -}}
{{- $adminMode := $adminAuth.mode | default "none" -}}
{{- $adminPaths := $ctx.Values.ingress.adminPaths | default list -}}
{{- /* Host-derivation fallback:
      - If ingress.hosts[].host is set, use it verbatim.
      - Else if .Values.lancore.appSlug is set, derive via lan-common.satelliteHost.
      - Else derive via lan-common.lancoreHost (LanCore itself).
      - Paths default to / Prefix when not supplied.
*/ -}}
{{- $defaultHost := "" -}}
{{- $lancoreSubchart := (($ctx.Values.lancore | default dict).appSlug | default "") -}}
{{- if $lancoreSubchart -}}
{{- $defaultHost = include "lan-common.satelliteHost" (dict "context" $ctx "slug" $lancoreSubchart) -}}
{{- else -}}
{{- $defaultHost = include "lan-common.lancoreHost" $ctx -}}
{{- end -}}
{{- $rawHosts := ($ctx.Values.ingress.hosts | default list) -}}
{{- $resolvedHosts := list -}}
{{- if $rawHosts -}}
{{- range $h := $rawHosts -}}
{{- $host := $h.host | default $defaultHost -}}
{{- $paths := $h.paths | default (list (dict "path" "/" "pathType" "Prefix")) -}}
{{- $resolvedHosts = append $resolvedHosts (dict "host" $host "paths" $paths) -}}
{{- end -}}
{{- else -}}
{{- $resolvedHosts = list (dict "host" $defaultHost "paths" (list (dict "path" "/" "pathType" "Prefix"))) -}}
{{- end -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "lan-common.fullname" $ctx }}
  namespace: {{ $ctx.Release.Namespace }}
  labels:
    {{- include "lan-common.labels" (dict "context" $ctx "component" $component) | nindent 4 }}
  annotations:
    {{- if $ctx.Values.ingress.tls.enabled }}
    cert-manager.io/cluster-issuer: {{ $ctx.Values.ingress.tls.issuerRef.name | quote }}
    {{- end }}
    {{- with $ctx.Values.ingress.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- if $ctx.Values.ingress.className }}
  ingressClassName: {{ $ctx.Values.ingress.className }}
  {{- end }}
  {{- if $ctx.Values.ingress.tls.enabled }}
  tls:
    - hosts:
        {{- range $resolvedHosts }}
        - {{ .host | quote }}
        {{- end }}
      secretName: {{ $ctx.Values.ingress.tls.secretName | default (printf "%s-tls" (include "lan-common.fullname" $ctx)) }}
  {{- end }}
  rules:
    {{- range $resolvedHosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path | default "/" }}
            pathType: {{ .pathType | default "Prefix" }}
            backend:
              service:
                name: {{ $serviceName }}
                port:
                  number: {{ $servicePort }}
          {{- end }}
    {{- end }}
{{- if and (ne $adminMode "none") $adminPaths }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "lan-common.fullname" $ctx }}-admin
  namespace: {{ $ctx.Release.Namespace }}
  labels:
    {{- include "lan-common.labels" (dict "context" $ctx "component" $component) | nindent 4 }}
    lan-software.mawiguko.dev/admin-ingress: "true"
  annotations:
    {{- if $ctx.Values.ingress.tls.enabled }}
    cert-manager.io/cluster-issuer: {{ $ctx.Values.ingress.tls.issuerRef.name | quote }}
    {{- end }}
    {{- if eq $adminMode "basic" }}
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: {{ $adminAuth.basic.secretName | default (printf "%s-admin-basic-auth" (include "lan-common.fullname" $ctx)) | quote }}
    nginx.ingress.kubernetes.io/auth-realm: "LanCore admin"
    {{- else if eq $adminMode "oauth2proxy" }}
    nginx.ingress.kubernetes.io/auth-url: {{ printf "%s/oauth2/auth" ($adminAuth.oauth2proxy.upstream | default "http://oauth2-proxy.auth.svc.cluster.local:4180") | quote }}
    nginx.ingress.kubernetes.io/auth-signin: {{ printf "%s/oauth2/start?rd=$escaped_request_uri" ($adminAuth.oauth2proxy.signinBase | default "https://$host") | quote }}
    nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-Request-User,X-Auth-Request-Email,X-Auth-Request-Groups"
    {{- end }}
    {{- with $adminAuth.extraAnnotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- if $ctx.Values.ingress.className }}
  ingressClassName: {{ $ctx.Values.ingress.className }}
  {{- end }}
  {{- if $ctx.Values.ingress.tls.enabled }}
  tls:
    - hosts:
        {{- range $resolvedHosts }}
        - {{ .host | quote }}
        {{- end }}
      secretName: {{ $ctx.Values.ingress.tls.secretName | default (printf "%s-tls" (include "lan-common.fullname" $ctx)) }}
  {{- end }}
  rules:
    {{- range $host := $resolvedHosts }}
    - host: {{ $host.host | quote }}
      http:
        paths:
          {{- range $adminPaths }}
          - path: {{ . | quote }}
            pathType: Prefix
            backend:
              service:
                name: {{ $serviceName }}
                port:
                  number: {{ $servicePort }}
          {{- end }}
    {{- end }}
{{- end }}
{{- end -}}
{{- end -}}
