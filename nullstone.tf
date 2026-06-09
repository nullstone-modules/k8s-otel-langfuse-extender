data "ns_workspace" "this" {}

// Generate a random suffix to ensure uniqueness of resources
resource "random_string" "resource_suffix" {
  length  = 5
  lower   = true
  upper   = false
  numeric = false
  special = false
}

locals {
  tags          = data.ns_workspace.this.tags
  stack_name    = data.ns_workspace.this.stack_name
  env_name      = data.ns_workspace.this.env_name
  block_name    = data.ns_workspace.this.block_name
  block_ref     = data.ns_workspace.this.block_ref
  resource_name = "${local.block_ref}-${random_string.resource_suffix.result}"

  k8s_labels = {
    // k8s-recommended labels
    "app.kubernetes.io/name"       = local.block_name
    "app.kubernetes.io/component"  = "otel-extender"
    "app.kubernetes.io/part-of"    = local.stack_name
    "app.kubernetes.io/managed-by" = "nullstone"
    // nullstone labels
    "nullstone.io/stack"     = local.stack_name
    "nullstone.io/block-ref" = local.block_ref
    "nullstone.io/block"     = local.block_name
    "nullstone.io/env"       = local.env_name
  }
}
