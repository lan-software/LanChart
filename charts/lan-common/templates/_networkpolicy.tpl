{{/*
lan-common.networkPolicy — default-deny + explicit allow rules for one component.

Allow rules come from one of two sources:
  1. .Values.networkPolicy.ingress / .egress — raw rule blocks (escape hatch
     for operators who need something the token set does not cover).
  2. .Values.networkPolicy.allowFrom / .allowToEgress — named-token lists
     expanded by lan-common.networkPolicy.expand{Ingress,Egress} (see
     _networkpolicyRules.tpl).

If raw rules are set they fully replace the expanded token rules for that
direction; if both are empty the default-deny base stands (DNS egress only).

Usage: include "lan-common.networkPolicy" (dict "context" . "component" "web" "port" 80)
*/}}
{{- define "lan-common.networkPolicy" -}}
{{- if .context.Values.networkPolicy.enabled -}}
{{- $ctx := .context -}}
{{- $component := .component -}}
{{- $port := .port | default ($ctx.Values.image.port | default 80) -}}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "lan-common.componentName" (dict "context" $ctx "component" $component) }}
  namespace: {{ $ctx.Release.Namespace }}
  labels:
    {{- include "lan-common.labels" (dict "context" $ctx "component" $component) | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "lan-common.selectorLabels" (dict "context" $ctx "component" $component) | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    {{- if $ctx.Values.networkPolicy.ingress }}
    {{- toYaml $ctx.Values.networkPolicy.ingress | nindent 4 }}
    {{- else }}
    {{- include "lan-common.networkPolicy.expandIngress" (dict "context" $ctx "component" $component "port" $port) | nindent 4 }}
    {{- end }}
  egress:
    {{- if $ctx.Values.networkPolicy.egress }}
    {{- toYaml $ctx.Values.networkPolicy.egress | nindent 4 }}
    {{- else }}
    {{- include "lan-common.networkPolicy.expandEgress" (dict "context" $ctx) | nindent 4 }}
    {{- if not (has "dns" ($ctx.Values.networkPolicy.allowToEgress | default list)) }}
    # Always allow DNS — stays in place even if the operator forgot to
    # include "dns" in allowToEgress.
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    {{- end }}
    {{- end }}
{{- end -}}
{{- end -}}
