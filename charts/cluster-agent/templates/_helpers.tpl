{{- define "agent.name" -}}kubewatcher-agent{{- end -}}
{{- define "agent.identitySecret" -}}kubewatcher-agent-identity{{- end -}}
{{- define "agent.labels" -}}
app.kubernetes.io/name: cluster-agent
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}
