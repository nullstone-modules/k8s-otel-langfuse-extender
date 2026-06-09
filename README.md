# k8s-otel-langfuse-extender

Extends an OpenTelemetry collector to export GenAI traces to [Langfuse](https://langfuse.com)
**without forking the collector module**.

This module is an **otel-extender**: it creates a Kubernetes config map holding an OTEL config
fragment (a Langfuse `otlphttp` exporter plus a filtered `traces/langfuse` pipeline) and reports it
through its outputs. A collector that supports the `extender` connection (e.g.
`gcp-gke-otel-collector`) mounts the fragment and passes it as an additional `--config`. When this
extender is connected, Langfuse receives a filtered copy of the traces while the collector's existing
destinations (Cloud Trace, etc.) keep receiving everything.

## Connections

| Name                | Contract                       | Required | Purpose                                                       |
|---------------------|--------------------------------|----------|---------------------------------------------------------------|
| `cluster-namespace` | `cluster-namespace/*/k8s:*`    | yes      | The cluster + namespace to create the config map in.          |

**Wire this to the SAME `cluster-namespace` block as the collector.** The collector mounts the config
map from its own namespace, so both blocks must target the same namespace. The collector enforces this
at plan time (it compares its namespace to this module's `kubernetes_namespace` output) and fails with
a clear message otherwise.

The connection contract is provider-wildcarded, so the module works against a GKE
(`cluster-namespace/gcp/k8s:gke`) or EKS (`cluster-namespace/aws/k8s:eks`) cluster-namespace. The
kubernetes provider and secret resolution branch automatically on the connected cloud.

> Note: today the only collector that consumes the `extender` connection is the GKE collector, so the
> GKE path is the exercised one. The EKS path mirrors established patterns and is ready for a future
> EKS collector.

## Credentials

Langfuse OTLP ingestion uses HTTP Basic auth: `Authorization: Basic <auth_key>`, where `auth_key` is
the base64 encoding of `"<public_key>:<secret_key>"`. Generate it once and pass it via the single
`auth_key` variable, which accepts either a plaintext value or a `{{ secret(...) }}` reference to a
secret stored in Nullstone:

```bash
echo -n "pk-lf-...:sk-lf-..." | base64    # -> the auth_key value
```

```hcl
auth_key = "{{ secret(langfuse-auth-key) }}"
```

Because the collector only injects `--config` files (it cannot set env vars on its pod), the module
resolves any `{{ secret(...) }}` reference to its value at apply time (GCP Secret Manager on GKE, AWS
Secrets Manager on EKS) and writes the token straight into the `Authorization` header in the config map.

## Variables

| Name                | Default                                            | Description                                                                                       |
|---------------------|----------------------------------------------------|---------------------------------------------------------------------------------------------------|
| `endpoint`          | `https://us.cloud.langfuse.com/api/public/otel`    | Langfuse OTLP endpoint. Defaults to Langfuse Cloud **US**; override for other regions.            |
| `auth_key`          | _(required, sensitive)_                            | base64 of `"<public_key>:<secret_key>"`. Used as the `Basic` token. Supports `{{ secret(...) }}`. |
| `filter_statements` | `["attributes[\"gen_ai.system\"] == nil"]`         | OTTL span conditions selecting which spans to **drop**. Default keeps only GenAI spans.           |
| `filter_error_mode` | `ignore`                                           | Filter processor error handling: `ignore`, `silent`, or `propagate`.                              |
| `ingestion_version` | `4`                                                | `x-langfuse-ingestion-version` header value (Langfuse realtime). Empty string omits header.       |

### Langfuse regions

| Region | Endpoint                                           |
|--------|----------------------------------------------------|
| US     | `https://us.cloud.langfuse.com/api/public/otel`    |
| EU     | `https://cloud.langfuse.com/api/public/otel`       |
| JP     | `https://jp.cloud.langfuse.com/api/public/otel`    |
| HIPAA  | `https://hipaa.cloud.langfuse.com/api/public/otel` |

For self-hosted Langfuse, set `endpoint` to `https://<your-host>/api/public/otel`.

### Modifying the filter

By default, only GenAI spans are forwarded — every span where `attributes["gen_ai.system"]` is unset is
dropped. `filter_statements` is a list of OTTL span conditions; a span is dropped if it matches **any**
of them. To forward everything, set it to an empty list:

```hcl
filter_statements = []   # no filter processor; all traces go to Langfuse
```

Or widen/narrow what reaches Langfuse with your own conditions, e.g. also drop health-check spans:

```hcl
filter_statements = [
  "attributes[\"gen_ai.system\"] == nil",
  "name == \"GET /healthz\"",
]
```

## Generated fragment

```yaml
exporters:
  otlphttp/langfuse:
    endpoint: https://us.cloud.langfuse.com/api/public/otel
    headers:
      Authorization: "Basic <auth_key>"
      x-langfuse-ingestion-version: "4"
processors:
  filter/langfuse:
    error_mode: ignore
    traces:
      span:
        - 'attributes["gen_ai.system"] == nil'
service:
  pipelines:
    traces/langfuse:                # NEW pipeline key -> merges cleanly, no list conflict
      receivers: [otlp]             # shares the base otlp receiver by reference
      processors: [k8sattributes, memory_limiter, batch, filter/langfuse]
      exporters: [otlphttp/langfuse]
```

## Outputs

| Name                    | Description                                                                              |
|-------------------------|------------------------------------------------------------------------------------------|
| `collector-config-maps` | `list(object({ filename, configMapName }))` — the fragments for the collector to mount.  |
| `kubernetes_namespace`  | The namespace the config map was created in (validated against the collector).           |
