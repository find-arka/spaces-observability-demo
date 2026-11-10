{{/* Azure-side id. Resource group, VNet, subnet and AKS names derive from it
     (<id>-rg, <id>-vnet, <id>-sn, <id>-aks), so it must be unique per subscription. */}}
{{- define "samples.id" -}}
{{- required "controlPlane is required" .Values.controlPlane | printf "demo-%s" -}}
{{- end -}}
