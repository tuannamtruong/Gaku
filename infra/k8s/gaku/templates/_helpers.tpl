{{/* Image reference, e.g. include "gaku.image" (dict "root" . "name" "gaku-api") */}}
{{- define "gaku.image" -}}
{{- with .root.Values.image.registry }}{{ . }}/{{ end }}{{ .name }}:{{ .root.Values.image.tag }}
{{- end }}

{{- define "gaku.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/part-of: gaku
{{- end }}

{{/* The same keys as the image labels in docker/Dockerfile. */}}
{{- define "gaku.buildAnnotations" -}}
org.opencontainers.image.version: {{ .Values.image.tag | quote }}
org.opencontainers.image.created: {{ dateInZone "2006-01-02T15:04:05Z" (now) "UTC" | quote }}
{{- with .Values.gitSha }}
org.opencontainers.image.revision: {{ . | quote }}
{{- end }}
{{- end }}

{{/* Prefers placing an app's replicas on different AZs and nodes. Takes the app label. */}}
{{- define "gaku.spread" -}}
topologySpreadConstraints:
{{- range list "topology.kubernetes.io/zone" "kubernetes.io/hostname" }}
  - maxSkew: 1
    topologyKey: {{ . }}
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: {{ $ }}
{{- end }}
{{- end }}
