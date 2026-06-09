output "collector-config-maps" {
  value = [
    {
      filename      = local.langfuse_filename
      configMapName = kubernetes_config_map_v1.langfuse.metadata[0].name
    },
  ]
  description = "list(object({ filename = string, configMapName = string })) ||| The OTEL config fragments to merge into the collector. Consumed by an otel-collector's `extender` connection."
}

output "kubernetes_namespace" {
  value       = local.kubernetes_namespace
  description = "string ||| The namespace (from the shared cluster-namespace) where the config maps were created. The collector validates this matches its own namespace."
}
