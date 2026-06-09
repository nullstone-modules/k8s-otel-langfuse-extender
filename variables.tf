variable "endpoint" {
  type        = string
  default     = "https://us.cloud.langfuse.com/api/public/otel"
  description = <<EOF
The Langfuse OTLP ingestion endpoint.
Defaults to Langfuse Cloud US. Override for other regions:
  - US:    https://us.cloud.langfuse.com/api/public/otel
  - EU:    https://cloud.langfuse.com/api/public/otel
  - JP:    https://jp.cloud.langfuse.com/api/public/otel
  - HIPAA: https://hipaa.cloud.langfuse.com/api/public/otel
For self-hosted Langfuse, use https://<your-host>/api/public/otel.
EOF
}

variable "auth_key" {
  type        = string
  sensitive   = true
  description = <<EOF
The Langfuse Basic auth token: the base64 encoding of "<public_key>:<secret_key>"
(e.g. `echo -n "pk-lf-...:sk-lf-..." | base64`). It is used as-is in the
`Authorization: Basic <auth_key>` header sent to Langfuse.
This value supports `{{ secret(...) }}` interpolation to reference a secret stored in Nullstone.
EOF
}

variable "filter_statements" {
  type        = list(string)
  default     = ["attributes[\"gen_ai.system\"] == nil"]
  description = <<EOF
OTTL span conditions that select which spans to DROP before exporting to Langfuse.
A span is dropped if it matches any statement in this list.
The default drops every non-GenAI span so only GenAI traces are forwarded.
Set to an empty list `[]` to disable filtering and forward all traces.
See https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/filterprocessor
EOF
}

variable "filter_error_mode" {
  type        = string
  default     = "ignore"
  description = <<EOF
How the filter processor reacts to errors evaluating a statement: `ignore`, `silent`, or `propagate`.
`ignore` logs the error and continues (recommended so a malformed span never drops the pipeline).
EOF
}

variable "ingestion_version" {
  type        = string
  default     = "4"
  description = <<EOF
Value for the `x-langfuse-ingestion-version` header that Langfuse recommends for realtime preview.
Set to an empty string to omit the header.
EOF
}
