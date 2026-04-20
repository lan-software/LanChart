{{/*
lan-common.deployment — renders a full Deployment for one component of a Laravel
sub-chart. The caller passes:
  context    — the sub-chart's root template context (.)
  component  — "web" | "worker" | "server"
  values     — the component sub-block (e.g. .Values.web or .Values.worker)
  extraEnv   — optional list of {name, value | valueFrom} env entries
  extraVolumes / extraVolumeMounts — optional
Usage: include "lan-common.deployment" (dict "context" . "component" "web" "values" .Values.web)
*/}}
{{- define "lan-common.deployment" -}}
{{- $ctx := .context -}}
{{- $v := .values -}}
{{- $component := .component -}}
{{- $name := include "lan-common.componentName" (dict "context" $ctx "component" $component) -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $name }}
  namespace: {{ $ctx.Release.Namespace }}
  labels:
    {{- include "lan-common.labels" (dict "context" $ctx "component" $component) | nindent 4 }}
spec:
  {{- if not (and $ctx.Values.hpa $ctx.Values.hpa.enabled) }}
  replicas: {{ $v.replicaCount | default 1 }}
  {{- end }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      {{- include "lan-common.selectorLabels" (dict "context" $ctx "component" $component) | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "lan-common.labels" (dict "context" $ctx "component" $component) | nindent 8 }}
      annotations:
        {{- with $ctx.Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        checksum/config: {{ $ctx.Values | toYaml | sha256sum | trunc 63 }}
    spec:
      serviceAccountName: {{ include "lan-common.serviceAccountName" $ctx }}
      {{- include "lan-common.imagePullSecrets" $ctx | nindent 6 }}
      securityContext:
        {{- include "lan-common.podSecurityContext" $ctx | nindent 8 }}
      {{- with $ctx.Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $ctx.Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $ctx.Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      terminationGracePeriodSeconds: {{ $v.terminationGracePeriodSeconds | default 30 }}
      containers:
        - name: app
          image: {{ include "lan-common.image" (dict "context" $ctx "image" $ctx.Values.image) }}
          imagePullPolicy: {{ $ctx.Values.image.pullPolicy | default "IfNotPresent" }}
          securityContext:
            {{- include "lan-common.containerSecurityContext" $ctx | nindent 12 }}
          {{- with $v.command }}
          command:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $v.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          ports:
            - name: http
              containerPort: {{ $ctx.Values.image.port | default 8080 }}
              protocol: TCP
            {{- if $ctx.Values.serviceMonitor.enabled }}
            - name: metrics
              containerPort: {{ $ctx.Values.service.metricsPort | default 9090 }}
              protocol: TCP
            {{- end }}
          env:
            - name: ROLE
              value: {{ $v.roleEnv | default $component | quote }}
            - name: SKIP_MIGRATE
              value: {{ $v.skipMigrate | default "1" | quote }}
            {{- if eq $component "web" }}
            - name: OCTANE_WORKERS
              value: {{ $v.octaneWorkers | default "auto" | quote }}
            - name: OCTANE_MAX_REQUESTS
              value: {{ $v.octaneMaxRequests | default "500" | quote }}
            {{- end }}
            {{- include "lan-common.commonEnv" (dict "context" $ctx) | nindent 12 }}
            {{- include "lan-common.otelEnv" (dict "context" $ctx) | nindent 12 }}
            {{- include "lan-common.lancoreSatelliteEnv" (dict "context" $ctx) | nindent 12 }}
            {{- with .extraEnv }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- if or $ctx.Values.configMap.enabled $ctx.Values.appSecrets.enabled .envFromExtras }}
          envFrom:
            {{- if $ctx.Values.configMap.enabled }}
            - configMapRef:
                name: {{ include "lan-common.fullname" $ctx }}
            {{- end }}
            {{- if $ctx.Values.appSecrets.enabled }}
            - secretRef:
                name: {{ include "lan-common.fullname" $ctx }}-app
            {{- end }}
            {{- with .envFromExtras }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}
          {{- if eq $component "web" }}
          {{- include "lan-common.probes" (dict "context" $ctx) | nindent 10 }}
          {{- else if eq $component "server" }}
          {{- include "lan-common.probes" (dict "context" $ctx) | nindent 10 }}
          {{- end }}
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 5"]
          resources:
            {{- toYaml ($v.resources | default dict) | nindent 12 }}
          volumeMounts:
            # Core writable paths for supervisord + FrankenPHP + Laravel on
            # a readOnlyRootFilesystem. See LanBase/entrypoint.sh for the set
            # the entrypoint creates/chowns at boot.
            - name: tmp
              mountPath: /tmp
            - name: supervisor-run
              mountPath: /var/run/supervisor
            - name: supervisor-log
              mountPath: /var/log/supervisor
            - name: caddy-data
              mountPath: /data/caddy
            - name: caddy-config
              mountPath: /config/caddy
            - name: storage-framework
              mountPath: /var/www/html/storage/framework
            - name: storage-logs
              mountPath: /var/www/html/storage/logs
            - name: storage-app
              mountPath: /var/www/html/storage/app
            - name: bootstrap-cache
              mountPath: /var/www/html/bootstrap/cache
            {{- with .extraVolumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
      volumes:
        - name: tmp
          emptyDir: {}
        - name: supervisor-run
          emptyDir: {}
        - name: supervisor-log
          emptyDir: {}
        - name: caddy-data
          emptyDir: {}
        - name: caddy-config
          emptyDir: {}
        - name: storage-framework
          emptyDir: {}
        - name: storage-logs
          emptyDir: {}
        - name: storage-app
          emptyDir: {}
        - name: bootstrap-cache
          emptyDir: {}
        {{- with .extraVolumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
{{- end -}}
