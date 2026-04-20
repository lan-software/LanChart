{{/*
lan-common.jobMigrate — pre-install/pre-upgrade Helm hook Job that runs
`php artisan migrate --force` against the app's Postgres database. All web
and worker Deployments ship with SKIP_MIGRATE=1; this Job is the single
migrator per release (matches SSDD §3.1.1.3 + §4.3).
Usage: include "lan-common.jobMigrate" (dict "context" . "extraEnv" ... "extraArgs" ...)
*/}}
{{- define "lan-common.jobMigrate" -}}
{{- $ctx := .context -}}
{{- if $ctx.Values.migrations.enabled -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "lan-common.componentName" (dict "context" $ctx "component" "migrate") }}-{{ now | date "20060102-150405" }}
  namespace: {{ $ctx.Release.Namespace }}
  labels:
    {{- include "lan-common.labels" (dict "context" $ctx "component" "migrate") | nindent 4 }}
  annotations:
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "-5"
    helm.sh/hook-delete-policy: before-hook-creation
spec:
  backoffLimit: {{ $ctx.Values.migrations.backoffLimit | default 2 }}
  activeDeadlineSeconds: {{ $ctx.Values.migrations.activeDeadlineSeconds | default 600 }}
  ttlSecondsAfterFinished: {{ $ctx.Values.migrations.ttlSecondsAfterFinished | default 86400 }}
  template:
    metadata:
      labels:
        {{- include "lan-common.labels" (dict "context" $ctx "component" "migrate") | nindent 8 }}
    spec:
      restartPolicy: Never
      serviceAccountName: {{ include "lan-common.serviceAccountName" $ctx }}
      {{- include "lan-common.imagePullSecrets" $ctx | nindent 6 }}
      securityContext:
        {{- include "lan-common.podSecurityContext" $ctx | nindent 8 }}
      containers:
        - name: migrate
          image: {{ include "lan-common.image" (dict "context" $ctx "image" $ctx.Values.image) }}
          imagePullPolicy: {{ $ctx.Values.image.pullPolicy | default "IfNotPresent" }}
          securityContext:
            {{- include "lan-common.containerSecurityContext" $ctx | nindent 12 }}
          command: {{ $ctx.Values.migrations.command | default (list "php" "artisan" "migrate" "--force") | toJson }}
          {{- with .extraArgs }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          env:
            - name: ROLE
              value: "migrate"
            - name: SKIP_MIGRATE
              value: "0"
            {{- include "lan-common.commonEnv" (dict "context" $ctx) | nindent 12 }}
            {{- include "lan-common.otelEnv" (dict "context" $ctx) | nindent 12 }}
            {{- with .extraEnv }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- if or $ctx.Values.configMap.enabled $ctx.Values.appSecrets.enabled }}
          envFrom:
            {{- if $ctx.Values.configMap.enabled }}
            - configMapRef:
                name: {{ include "lan-common.fullname" $ctx }}
            {{- end }}
            {{- if $ctx.Values.appSecrets.enabled }}
            - secretRef:
                name: {{ include "lan-common.fullname" $ctx }}-app
            {{- end }}
          {{- end }}
          resources:
            {{- toYaml ($ctx.Values.migrations.resources | default dict) | nindent 12 }}
          volumeMounts:
            # Same emptyDir set as the main Deployment so the migrate Job
            # runs with readOnlyRootFilesystem: true.
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
{{- end -}}
{{- end -}}
