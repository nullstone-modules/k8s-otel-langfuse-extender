// Build the OTEL config fragment that the collector deep-merges on top of its base config.
//
// The collector merges multiple `--config` files: maps merge recursively, but lists are *replaced*.
// So this fragment contributes only NEW map keys -- its own exporter, an optional filter processor,
// and a new `traces/langfuse` pipeline -- rather than touching the base `traces` pipeline. The
// pipeline references processors (`k8sattributes`, `memory_limiter`, `batch`) and the `otlp` receiver
// that already exist in the collector's base config.
locals {
  // The file name the fragment is mounted as, and the config map data key (collector mounts via subPath).
  langfuse_filename = "langfuse.yaml"

  filter_enabled = length(var.filter_statements) > 0

  langfuse_headers = merge(
    { Authorization = "Basic ${local.langfuse_auth}" },
    var.ingestion_version != "" ? { "x-langfuse-ingestion-version" = var.ingestion_version } : {},
  )

  // Base processors shared from the collector config, plus our filter when enabled.
  langfuse_pipeline_processors = concat(
    ["k8sattributes", "memory_limiter", "batch"],
    local.filter_enabled ? ["filter/langfuse"] : [],
  )

  langfuse_fragment = merge(
    {
      exporters = {
        "otlphttp/langfuse" = {
          endpoint = var.endpoint
          headers  = local.langfuse_headers
        }
      }
      service = {
        pipelines = {
          "traces/langfuse" = {
            receivers  = ["otlp"]
            processors = local.langfuse_pipeline_processors
            exporters  = ["otlphttp/langfuse"]
          }
        }
      }
    },
    local.filter_enabled ? {
      processors = {
        "filter/langfuse" = {
          error_mode = var.filter_error_mode
          traces = {
            span = var.filter_statements
          }
        }
      }
    } : {},
  )
}

resource "kubernetes_config_map_v1" "langfuse" {
  metadata {
    name      = local.resource_name
    namespace = local.kubernetes_namespace
    labels    = local.k8s_labels
  }

  data = {
    (local.langfuse_filename) = yamlencode(local.langfuse_fragment)
  }
}
