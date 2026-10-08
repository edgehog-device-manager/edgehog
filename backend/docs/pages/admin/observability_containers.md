<!---
  Copyright 2026 SECO Mind Srl

  SPDX-License-Identifier: Apache-2.0
-->

# Container telemetry

The containers feature emits [`:telemetry`](https://hexdocs.pm/telemetry) events
for the provisioning of individual resources on devices and for the
orchestration of application deployments. Event definitions live in
`Edgehog.Containers.Telemetry` (`lib/edgehog/containers/telemetry.ex`); the
Prometheus mapping lives in `Edgehog.Containers.PromExPlugin`
(`lib/edgehog/containers/prom_ex_plugin.ex`).

See the [observability overview](observability.md) for how to attach handlers
and for the identifier cardinality options.

## Events

All lifecycles follow the `start`/`stop` convention. `start` measurements are
`%{count: 1}`; `stop` measurements add `duration` (native time units) and, for
provisioning, `retries`. `stop` metadata adds `result` (`:ok` or `:error`),
`reason`, `duration`, and `duration_unit` (`:native`).

### Provisioning

| Event                                            | Emitted when                                                                                                                                                                                                  | Measurements                   | Metadata                                                                                                                                                     |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `[:edgehog, :containers, :provisioning, :start]` | A provisioner starts provisioning a resource on a device (image, volume, network, device mapping, device request, container, or deployment provisioners under `lib/edgehog/containers/*/provisioner/core.ex`) | `count`                        | `resource_type`, `started_at`, `tenant`, plus `deployment_id`, and, unless `containers_telemetry_include_identifiers` is `false`, `resource_id`, `device_id` |
| `[:edgehog, :containers, :provisioning, :stop]`  | The provisioning terminates, successfully or not                                                                                                                                                              | `count`, `duration`, `retries` | Start metadata plus `result`, `reason` (the provisioning outcome, e.g. `:ready` or `:already_ready`, or the failure reason), `duration`, `duration_unit`     |

`resource_type` is derived from the provisioned resource module name (e.g. an image deployment
provisioner reports `image_deployment`). Use the
`Edgehog.Containers.Telemetry.provisioning_start_event/0` and `provisioning_stop_event/0`
accessors instead of hardcoding the event names.

### Deployment orchestration

| Event                                          | Emitted when                                                                                                                  | Measurements        | Metadata                                                                                    |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------- | ------------------------------------------------------------------------------------------- |
| `[:edgehog, :containers, :deployment, :start]` | The deployment orchestrator (`lib/edgehog/containers/deployment/orchestrator.ex`) starts conducting an application deployment | `count`             | `started_at`, `tenant`, plus, unless identifiers are disabled, `deployment_id`, `device_id` |
| `[:edgehog, :containers, :deployment, :stop]`  | The deployment orchestration terminates, successfully or not                                                                  | `count`, `duration` | Start metadata plus `result`, `duration`, `duration_unit`                                   |

### Container deployment orchestration

| Event                                                    | Emitted when                                                                                                                                          | Measurements        | Metadata                                                                                                               |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `[:edgehog, :containers, :container_deployment, :start]` | The container deployment orchestrator (`lib/edgehog/containers/container/deployment/orchestrator.ex`) starts conducting a single container deployment | `count`             | `started_at`, `tenant`, plus, unless identifiers are disabled, `container_deployment_id`, `deployment_id`, `device_id` |
| `[:edgehog, :containers, :container_deployment, :stop]`  | The container deployment orchestration terminates, successfully or not                                                                                | `count`, `duration` | Start metadata plus `result`, `duration`, `duration_unit`                                                              |

## Prometheus metrics

`Edgehog.Containers.PromExPlugin` exposes three event-metric groups. Identifier
labels (`deployment_id`, `resource_id`, `device_id`, `container_deployment_id`)
are only present when `containers_telemetry_include_identifiers` is `true` (the
default).

### Provisioning (`:containers_provisioning_event_metrics`)

| Metric                                             | Type         | Source event / measurement                                                                                                                                      |
| -------------------------------------------------- | ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `edgehog_containers_provisioning_started_total`    | counter      | provisioning `start`, `count`. Labels: `resource_type`, `resource_id`, `deployment_id`, `device_id`, `tenant`                                                   |
| `edgehog_containers_provisioning_completed_total`  | counter      | provisioning `stop`, `count`. Labels: as above plus `result`, `reason`                                                                                          |
| `edgehog_containers_provisioning_duration_seconds` | distribution | provisioning `stop`, `duration` (converted to seconds). Labels: `resource_type`, `deployment_id`, `device_id`, `result`, `reason`, `tenant`. Buckets: 100ms–60s |
| `edgehog_containers_provisioning_retries`          | distribution | provisioning `stop`, `retries`. Labels: `result`, `reason`, `tenant`. Buckets: 0–100                                                                            |

### Deployment (`:containers_deployment_event_metrics`)

| Metric                                           | Type         | Source event / measurement                                                                                                        |
| ------------------------------------------------ | ------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| `edgehog_containers_deployment_started_total`    | counter      | deployment `start`, `count`. Labels: `deployment_id`, `device_id`, `tenant`                                                       |
| `edgehog_containers_deployment_completed_total`  | counter      | deployment `stop`, `count`. Labels: as above plus `result`                                                                        |
| `edgehog_containers_deployment_duration_seconds` | distribution | deployment `stop`, `duration` (converted to seconds). Labels: `deployment_id`, `device_id`, `result`, `tenant`. Buckets: 1s–10min |

### Container deployment (`:containers_container_deployment_event_metrics`)

| Metric                                                     | Type         | Source event / measurement                                                                                                                                              |
| ---------------------------------------------------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `edgehog_containers_container_deployment_started_total`    | counter      | container deployment `start`, `count`. Labels: `container_deployment_id`, `deployment_id`, `device_id`, `tenant`                                                        |
| `edgehog_containers_container_deployment_completed_total`  | counter      | container deployment `stop`, `count`. Labels: as above plus `result`                                                                                                    |
| `edgehog_containers_container_deployment_duration_seconds` | distribution | container deployment `stop`, `duration` (converted to seconds). Labels: `container_deployment_id`, `deployment_id`, `device_id`, `result`, `tenant`. Buckets: 100ms–60s |
|                                                            |              |                                                                                                                                                                         |
