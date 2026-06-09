// Langfuse OTLP uses HTTP Basic auth: `Authorization: Basic <auth_key>`, where `auth_key` is the
// base64 encoding of "<public_key>:<secret_key>".
//
// `auth_key` may be supplied either as a plaintext value or as a `{{ secret(...) }}` reference. The
// collector only injects `--config` files (it can't set env vars on its pod), so the header must be a
// resolved literal baked into the fragment -- we resolve any secret reference to its plaintext value
// here and use it directly in `langfuse.tf`.
//
// `ns_env_variables.secret_refs["<KEY>"]` is populated only when the value matches the secret-ref
// pattern; it holds the underlying secret identifier (a GCP Secret Manager name, or an AWS Secrets
// Manager ARN). Mirrors gcp-firebase-idp/oauth.tf (GCP) and aws-eks-app/env_vars.tf (AWS).
data "ns_env_variables" "interpolation" {
  input_env_variables = {}
  input_secrets = {
    LANGFUSE_AUTH_KEY = var.auth_key
  }
}

locals {
  auth_key_secret_ref = lookup(data.ns_env_variables.interpolation.secret_refs, "LANGFUSE_AUTH_KEY", "")
}

// --- GCP (GKE): resolve a secret reference from Google Secret Manager ---
data "google_secret_manager_secret_version" "auth_key" {
  count  = local.is_gcp && local.auth_key_secret_ref != "" ? 1 : 0
  secret = local.auth_key_secret_ref
}

// --- AWS (EKS): resolve a secret reference from AWS Secrets Manager ---
data "aws_secretsmanager_secret_version" "auth_key" {
  count     = local.is_aws && local.auth_key_secret_ref != "" ? 1 : 0
  secret_id = local.auth_key_secret_ref
}

locals {
  // Resolved plaintext auth token: pull from the cloud secret manager when the input was a
  // `{{ secret(...) }}` reference, otherwise use the plain var value.
  langfuse_auth = (
    length(data.google_secret_manager_secret_version.auth_key) > 0 ? data.google_secret_manager_secret_version.auth_key[0].secret_data :
    length(data.aws_secretsmanager_secret_version.auth_key) > 0 ? data.aws_secretsmanager_secret_version.auth_key[0].secret_string :
    var.auth_key
  )
}
