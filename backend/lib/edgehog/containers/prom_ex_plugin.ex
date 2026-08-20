#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.Containers.PromExPlugin do
  @moduledoc """
  PromEx plugin for the Edgehog containers feature.

  Exposes the following metric groups:

  - `:containers_provisioning_event_metrics` exposing, for every resource type
    provisioned on a device (image deployments, volume deployments, network
    deployments, device mapping deployments, device request deployments,
    container deployments and deployments), the provisioning lifecycle:
    - `edgehog_containers_provisioning_started_total`
    - `edgehog_containers_provisioning_completed_total` (labeled by `result`)
    - `edgehog_containers_provisioning_duration_seconds` (labeled by `result`)
    - `edgehog_containers_provisioning_retries`

  - `:containers_deployment_event_metrics` exposing the end-to-end lifecycle of
    an application deployment:
    - `edgehog_containers_deployment_started_total`
    - `edgehog_containers_deployment_completed_total` (labeled by `result`)
    - `edgehog_containers_deployment_duration_seconds`

  - `:containers_container_deployment_event_metrics` exposing the lifecycle of a
    single container deployment:
    - `edgehog_containers_container_deployment_started_total`
    - `edgehog_containers_container_deployment_completed_total` (labeled by `result`)
    - `edgehog_containers_container_deployment_duration_seconds`

  The provisioning metrics carry `resource_type`, `result` and `reason` labels,
  which are low cardinality. Additionally, unless the
  `:containers_telemetry_include_identifiers` configuration option is set to
  `false`, the metrics also carry the high cardinality identifier labels
  `deployment_id`, `resource_id` and `device_id`, so that the metrics can be
  filtered per specific deployment, resource or device in Grafana (e.g. using a
  dashboard variable resolved to the device ids of a device group).
  """

  use PromEx.Plugin

  alias Edgehog.Containers.Telemetry

  @impl PromEx.Plugin
  def event_metrics(_opts) do
    [
      provisioning_event_metrics(),
      deployment_event_metrics(),
      container_deployment_event_metrics()
    ]
  end

  defp provisioning_event_metrics do
    metric_prefix = [:edgehog, :containers, :provisioning]

    Event.build(
      :containers_provisioning_event_metrics,
      [
        counter(
          metric_prefix ++ [:started, :total],
          event_name: Telemetry.provisioning_start_event(),
          measurement: :count,
          description: "Number of provisioning operations started for a resource on a device.",
          tags: [:resource_type, :resource_id, :deployment_id, :device_id],
          tag_values: &identifiers_tag_values/1
        ),
        counter(
          metric_prefix ++ [:completed, :total],
          event_name: Telemetry.provisioning_stop_event(),
          measurement: :count,
          description: "Number of provisioning operations completed for a resource on a device.",
          tags: [:resource_type, :resource_id, :deployment_id, :device_id, :result, :reason],
          tag_values: &identifiers_tag_values/1
        ),
        distribution(
          metric_prefix ++ [:duration, :seconds],
          event_name: Telemetry.provisioning_stop_event(),
          measurement: :duration,
          description: "The time it took for a provisioning operation to complete.",
          tags: [:resource_type, :deployment_id, :device_id, :result, :reason],
          tag_values: &identifiers_tag_values/1,
          reporter_options: [buckets: [100, 250, 500, 1000, 2500, 5000, 10_000, 60_000]],
          unit: {:native, :second}
        ),
        distribution(
          metric_prefix ++ [:retries],
          event_name: Telemetry.provisioning_stop_event(),
          measurement: :retries,
          description: "The number of retries of a provisioning operation.",
          tags: [:result, :reason],
          tag_values: &identifiers_tag_values/1,
          reporter_options: [buckets: [0, 1, 2, 3, 4, 5, 10, 25, 50, 100]]
        )
      ]
    )
  end

  defp deployment_event_metrics do
    metric_prefix = [:edgehog, :containers, :deployment]

    Event.build(
      :containers_deployment_event_metrics,
      [
        counter(
          metric_prefix ++ [:started, :total],
          event_name: Telemetry.deployment_start_event(),
          measurement: :count,
          description: "Number of application deployments started.",
          tags: [:deployment_id, :device_id],
          tag_values: &identifiers_tag_values/1
        ),
        counter(
          metric_prefix ++ [:completed, :total],
          event_name: Telemetry.deployment_stop_event(),
          measurement: :count,
          description: "Number of application deployments completed, either successfully or not.",
          tags: [:deployment_id, :device_id, :result],
          tag_values: &identifiers_tag_values/1
        ),
        distribution(
          metric_prefix ++ [:duration, :seconds],
          event_name: Telemetry.deployment_stop_event(),
          measurement: :duration,
          description: "The time it took for an application deployment to complete.",
          tags: [:deployment_id, :device_id, :result],
          tag_values: &identifiers_tag_values/1,
          reporter_options: [buckets: [1000, 2500, 5000, 10_000, 60_000, 300_000, 600_000]],
          unit: {:native, :second}
        )
      ]
    )
  end

  defp container_deployment_event_metrics do
    metric_prefix = [:edgehog, :containers, :container_deployment]

    Event.build(
      :containers_container_deployment_event_metrics,
      [
        counter(
          metric_prefix ++ [:started, :total],
          event_name: Telemetry.container_deployment_start_event(),
          measurement: :count,
          description: "Number of container deployments started.",
          tags: [:container_deployment_id, :deployment_id, :device_id],
          tag_values: &identifiers_tag_values/1
        ),
        counter(
          metric_prefix ++ [:completed, :total],
          event_name: Telemetry.container_deployment_stop_event(),
          measurement: :count,
          description: "Number of container deployments completed, either successfully or not.",
          tags: [:container_deployment_id, :deployment_id, :device_id, :result],
          tag_values: &identifiers_tag_values/1
        ),
        distribution(
          metric_prefix ++ [:duration, :seconds],
          event_name: Telemetry.container_deployment_stop_event(),
          measurement: :duration,
          description: "The time it took for a container deployment to complete.",
          tags: [:container_deployment_id, :deployment_id, :device_id, :result],
          tag_values: &identifiers_tag_values/1,
          reporter_options: [buckets: [100, 250, 500, 1000, 2500, 5000, 10_000, 60_000]],
          unit: {:native, :second}
        )
      ]
    )
  end

  defp identifiers_tag_values(metadata) do
    Map.take(metadata, [
      :resource_type,
      :resource_id,
      :deployment_id,
      :device_id,
      :container_deployment_id,
      :result,
      :reason
    ])
  end
end
