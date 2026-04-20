{{/*
lan-common.networkPolicy.expandIngress — map named tokens in
.networkPolicy.allowFrom to concrete Ingress rule blocks.
Usage: include "lan-common.networkPolicy.expandIngress" (dict "context" . "component" "web" "port" 80)
Returns a YAML fragment suitable for `spec.ingress:`.
*/}}
{{- define "lan-common.networkPolicy.expandIngress" -}}
{{- $ctx := .context -}}
{{- $component := .component -}}
{{- $httpPort := .port | default 80 -}}
{{- $metricsPort := $ctx.Values.service.metricsPort | default 9090 -}}
{{- $monitoring := (($ctx.Values.global | default dict).monitoring | default dict) -}}
{{- range $token := ($ctx.Values.networkPolicy.allowFrom | default list) -}}
{{- if eq $token "ingress-nginx" }}
- from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
  ports:
    - protocol: TCP
      port: {{ $httpPort }}
{{- else if eq $token "prometheus" }}
{{- if $monitoring.enabled }}
- from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: {{ $monitoring.namespace | default "monitoring" }}
  ports:
    - protocol: TCP
      port: {{ $metricsPort }}
{{- end }}
{{- else if eq $token "otel-collector" }}
{{- if ($ctx.Values.global | default dict).otel | default dict | default dict }}
- from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: observability
  ports:
    - protocol: TCP
      port: {{ $httpPort }}
{{- end }}
{{- else if or (eq $token "lanbrackets") (eq $token "lanentrance") (eq $token "lanshout") (eq $token "lanhelp") (eq $token "lancore") }}
- from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: {{ $ctx.Release.Namespace }}
      podSelector:
        matchLabels:
          app.kubernetes.io/part-of: lan-software
          app.kubernetes.io/name: {{ $token }}
  ports:
    - protocol: TCP
      port: {{ $httpPort }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
lan-common.networkPolicy.expandEgress — map named tokens in
.networkPolicy.allowToEgress to concrete Egress rule blocks.
Usage: include "lan-common.networkPolicy.expandEgress" (dict "context" .)
*/}}
{{- define "lan-common.networkPolicy.expandEgress" -}}
{{- $ctx := .context -}}
{{- range $token := ($ctx.Values.networkPolicy.allowToEgress | default list) -}}
{{- if eq $token "dns" }}
- to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
  ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
{{- else if eq $token "postgres" }}
- to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: {{ $ctx.Release.Namespace }}
  ports:
    - protocol: TCP
      port: 5432
{{- else if eq $token "cache" }}
- to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: {{ $ctx.Release.Namespace }}
  ports:
    - protocol: TCP
      port: 6379
{{- else if eq $token "lancore-internal" }}
- to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: {{ $ctx.Release.Namespace }}
      podSelector:
        matchLabels:
          app.kubernetes.io/part-of: lan-software
          app.kubernetes.io/name: lancore
          lan-software.mawiguko.dev/component: web
  ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 8080
{{- else if eq $token "s3" }}
# Egress to an external S3 endpoint; narrow via networkPolicy.egress override
# when storage.mode: minio-tenant (in-cluster).
- to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
          - 10.0.0.0/8
          - 172.16.0.0/12
          - 192.168.0.0/16
          - 169.254.0.0/16
  ports:
    - protocol: TCP
      port: 443
- to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: minio-tenant
  ports:
    - protocol: TCP
      port: 9000
{{- else if eq $token "smtp" }}
- to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
          - 10.0.0.0/8
          - 172.16.0.0/12
          - 192.168.0.0/16
          - 169.254.0.0/16
  ports:
    - protocol: TCP
      port: 25
    - protocol: TCP
      port: 465
    - protocol: TCP
      port: 587
- to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: {{ $ctx.Release.Namespace }}
  ports:
    - protocol: TCP
      port: 1025
{{- else if or (eq $token "stripe") (eq $token "webpush") (eq $token "tmt2") }}
- to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
          - 10.0.0.0/8
          - 172.16.0.0/12
          - 192.168.0.0/16
          - 169.254.0.0/16
  ports:
    - protocol: TCP
      port: 443
{{- end }}
{{- end }}
{{- end -}}
