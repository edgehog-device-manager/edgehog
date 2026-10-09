<!---
  Copyright 2026 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Observability

Edgehog exposes operational telemetry through the Erlang
[`:telemetry`](https://hexdocs.pm/telemetry) library and ships
[PromEx](https://hexdocs.pm/prom_ex) plugins that turn those events into
Prometheus metrics with Grafana dashboards.

This section documents what is exposed and how to consume it:

- [Container events](observability_containers.md): provisioning and deployment
  orchestration of containerized applications.
- [File events](observability_files.md): file download and upload request
  lifecycles.
- [Platform stack](observability_stack.md): non-Edgehog-specific metrics
  (Phoenix, Ecto, BEAM, Absinthe, application).

## Consuming events

Each telemetry module exposes `*_event()` accessors returning the event name, so
handlers never hardcode it:

```elixir
:telemetry.attach(
  "my-container-provisioning-logger",
  Edgehog.Containers.Telemetry.provisioning_stop_event(),
  &MyApp.handle_provisioning_stop/4,
  nil
)
```

All lifecycle events follow the `start`/`stop` convention: the `start` handler
receives `%{count: 1}` (files also include `system_time`) and metadata with a
`started_at` monotonic timestamp; the corresponding `stop` event carries
`%{count: 1, duration: duration}` plus `result` (`:ok` or `:error`), `reason`,
and `duration`/`duration_unit` (`:native`) in metadata. Durations are in native
time units; PromEx converts them to seconds.

## Identifier labels and cardinality

Provisioning and file-transfer stop events can carry high-cardinality
identifiers (`device_id`, `deployment_id`, `resource_id`, `request_id`,
`file_id`) so metrics can be filtered per device, deployment, or request in
Grafana. This increases the number of Prometheus time series.

Two configuration options control this, both defaulting to `true` (see
`Edgehog.Config`, `lib/edgehog/config.ex`):

| Environment variable                       | Option                                     | Effect when `false`                                                                                  |
| ------------------------------------------ | ------------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| `CONTAINERS_TELEMETRY_INCLUDE_IDENTIFIERS` | `containers_telemetry_include_identifiers` | Container metrics lose `deployment_id`, `resource_id`, `device_id`, `container_deployment_id` labels |
| `FILES_TELEMETRY_INCLUDE_IDENTIFIERS`      | `files_telemetry_include_identifiers`      | File metrics lose `request_id`, `device_id`, `file_id` labels                                        |

Low-cardinality labels (`tenant_slug`, `resource_type`, `result`, `reason`,
`destination_type`/`source_type`) are always present. If you do not filter
dashboards per device or deployment, set the corresponding option to `false` to
keep cardinality low.

## Grafana dashboards

PromEx uploads its built-in dashboards for the application, BEAM, Phoenix, Ecto,
and Absinthe metrics (see `dashboards/0` in `lib/edgehog/prom_ex.ex`). There are
currently no custom dashboards for the container and file-transfer metric
groups; query the metric names listed in the
[container](observability_containers.md#prometheus-metrics) and
[file](observability_files.md#prometheus-metrics) pages directly in Grafana.
