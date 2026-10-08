<!---
  Copyright 2026 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Platform telemetry

Besides the Edgehog-specific [container](observability_containers.md) and
[file](observability_files.md) events, Edgehog collects standard platform
telemetry through PromEx built-in plugins and the Phoenix telemetry setup.
Nothing here is Edgehog-specific: these are the same metrics any Phoenix/Ecto
application gets from PromEx and `Telemetry.Metrics`. They are documented here
so operators know what already exists before adding custom instrumentation.

## PromEx built-in plugins

Enabled in `plugins/0` (`lib/edgehog/prom_ex.ex`):

| Plugin                                                                        | What it collects                                                                                                                                                                                                               |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `PromEx.Plugins.Application`                                                  | OTP application status (started applications, versions)                                                                                                                                                                        |
| `PromEx.Plugins.Beam`                                                         | BEAM VM metrics: memory, allocators, schedulers, run queues, process counts                                                                                                                                                    |
| `PromEx.Plugins.Phoenix` (with `EdgehogWeb.Router` and `EdgehogWeb.Endpoint`) | HTTP request lifecycle: request counts, durations, statuses per route                                                                                                                                                          |
| `PromEx.Plugins.Ecto`                                                         | Database interaction: query counts, queue/decode/query/idle times per repo. Since all persistence (including Ash resources) goes through Ecto repos, Ash-driven database load is visible here; there is no separate Ash plugin |
| `PromEx.Plugins.Absinthe`                                                     | GraphQL (Absinthe) operation counts, durations, errors                                                                                                                                                                         |

> [!NOTE]
> Some metrics are **not** exposed: `Oban`, `PhoenixLiveView`. If those
> dependencies are adopted later, uncomment the corresponding plugin and
> dashboard lines.

Corresponding Grafana dashboards are uploaded by `dashboards/0`
(`lib/edgehog/prom_ex.ex`): `application.json`, `beam.json`, `phoenix.json`,
`ecto.json`, `absinthe.json`.

## Phoenix console metrics

The web telemetry supervisor (`lib/edgehog_web/telemetry.ex`) defines
`Telemetry.Metrics` summaries intended for a console reporter during development
(currently commented out in the supervision tree):

- `phoenix.endpoint.stop.duration` and `phoenix.router_dispatch.stop.duration`
  (tagged by route), in milliseconds.
- `edgehog.repo.query.*`: `total_time`, `decode_time`, `query_time`,
  `queue_time`, `idle_time`, in milliseconds.
- `vm.memory.total` (bytes to kilobytes) and `vm.total_run_queue_lengths.*`
  (total, cpu, io).

A `:telemetry_poller` child (10s period) is supervised for periodic VM
measurements, with `periodic_measurements/0` left empty as a hook for future
custom poller functions.

For production Prometheus scraping, rely on the PromEx plugins above rather than
these console metrics.
