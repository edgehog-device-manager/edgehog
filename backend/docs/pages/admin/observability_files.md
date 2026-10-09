<!---
  Copyright 2026 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# File telemetry

The files feature emits [`:telemetry`](https://hexdocs.pm/telemetry) events for
the lifecycle of file download requests. Event definitions live in
`Edgehog.Files.Telemetry` (`lib/edgehog/files/telemetry.ex`); the Prometheus
mapping lives in `Edgehog.Files.PromExPlugin`
(`lib/edgehog/files/prom_ex_plugin.ex`).

See the [observability overview](observability.md) for how to attach handlers
and for the identifier cardinality options.

## Events

Both lifecycles follow the `start`/`stop` convention. `start` measurements are
`%{count: 1, system_time: System.system_time()}`; `stop` measurements are
`%{count: 1, duration: duration, retries: retries}` with duration in native time
units. `stop` metadata adds `result` (`:ok` or `:error`), `reason`, `duration`,
and `duration_unit` (`:native`).

### File download requests

| Event                                                | Emitted when                                                                                                                         | Measurements                   | Metadata                                                                                                                                                                                                             |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `[:edgehog, :files, :file_download_request, :start]` | The file download request provisioner (`lib/edgehog/files/file_download_request/provisioner/core.ex`) starts provisioning a download | `count`, `system_time`         | `transfer_type` (`:download`), `destination_type`, `progress_tracked`, `needs_encoding`, `started_at`, `tenant`, plus, unless `files_telemetry_include_identifiers` is `false`, `request_id`, `device_id`, `file_id` |
| `[:edgehog, :files, :file_download_request, :stop]`  | The download request terminates, successfully or not                                                                                 | `count`, `duration`, `retries` | Start metadata plus `result`, `reason` (the provisioning outcome, e.g. `:ready` or `:already_ready`, or the failure reason), `duration`, `duration_unit`                                                             |

### File upload requests*

The `file_upload_request_started/1`, `file_upload_request_completed/5`, and
`file_upload_request_failed/5` functions and the corresponding PromEx metrics
exist, with the same shape as the download events (`transfer_type: :upload`,
`source_type` instead of `destination_type`, identifiers `request_id` and
`device_id`) The tables below document the events as defined so consumers and
future emitters stay consistent:

| Event                                              | Measurements                   | Metadata                                                                                                                                                                   |
| -------------------------------------------------- | ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `[:edgehog, :files, :file_upload_request, :start]` | `count`, `system_time`         | `transfer_type` (`:upload`), `source_type`, `progress_tracked`, `needs_encoding`, `started_at`, `tenant`, plus, unless identifiers are disabled, `request_id`, `device_id` |
| `[:edgehog, :files, :file_upload_request, :stop]`  | `count`, `duration`, `retries` | Start metadata plus `result`, `reason`, `duration`, `duration_unit`                                                                                                        |

## Prometheus metrics

`Edgehog.Files.PromExPlugin` exposes two event-metric groups. Identifier labels
(`request_id`, `device_id`, `file_id`) are only present when
`files_telemetry_include_identifiers` is `true` (the default).

### Download (`:files_file_download_request_event_metrics`)

| Metric                                                 | Type         | Source event / measurement                                                                                                                         |
| ------------------------------------------------------ | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `edgehog_files_file_download_request_started_total`    | counter      | download `start`, `count`. Labels: `destination_type`, `request_id`, `device_id`, `file_id`, `tenant_slug`                                         |
| `edgehog_files_file_download_request_completed_total`  | counter      | download `stop`, `count`. Labels: as above plus `result`, `reason`                                                                                 |
| `edgehog_files_file_download_request_duration_seconds` | distribution | download `stop`, `duration` (converted to seconds). Labels: `destination_type`, `device_id`, `result`, `reason`, `tenant_slug`. Buckets: 100ms–60s |
| `edgehog_files_file_download_request_retries`          | last value   | download `stop`, `retries`. Labels: `destination_type`, `device_id`, `result`, `tenant_slug`                                                       |

### Upload (`:files_file_upload_request_event_metrics`)

| Metric                                               | Type         | Source event / measurement                                                                                                                  |
| ---------------------------------------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `edgehog_files_file_upload_request_started_total`    | counter      | upload `start`, `count`. Labels: `source_type`, `request_id`, `device_id`, `tenant_slug`                                                    |
| `edgehog_files_file_upload_request_completed_total`  | counter      | upload `stop`, `count`. Labels: as above plus `result`, `reason`                                                                            |
| `edgehog_files_file_upload_request_duration_seconds` | distribution | upload `stop`, `duration` (converted to seconds). Labels: `source_type`, `device_id`, `result`, `reason`, `tenant_slug`. Buckets: 100ms–60s |
| `edgehog_files_file_upload_request_retries`          | last value   | upload `stop`, `retries`. Labels: `source_type`, `device_id`, `result`, `tenant_slug`                                                       |

Note the asymmetry with containers: retries are a `last_value` gauge here versus
a distribution for container provisioning.
