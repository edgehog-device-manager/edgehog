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

defmodule Edgehog.Containers.Telemetry do
  @moduledoc """
  Emits the telemetry events of the containers feature.

  Events can be emitted on the following topics:

  - `[:edgehog, :containers, :provisioning, :start]` when a provisioner
    starts provisioning a resource. Metadata contains `resource_type`,
    `resource_id`, `deployment_id` and `device_id`.
  - `[:edgehog, :containers, :provisioning, :stop]` when a provisioner
    terminates, either successfully or with a failure. Metadata contains
    `resource_type`, `resource_id`, `deployment_id`, `device_id`, `result`
    (either `:ok` or `:error`) and `reason` (either the provisioning outcome,
    e.g. `:ready` or `:already_ready`, or the failure reason). Measurements
    contain `duration` (native time) and `retries`.
  - `[:edgehog, :containers, :deployment, :start]` when a deployment
    orchestrator starts conducting a deployment. Metadata contains
    `deployment_id` and `device_id`.
  - `[:edgehog, :containers, :deployment, :stop]` when a deployment
    orchestrator terminates, either successfully or with a failure. Metadata
    contains `deployment_id`, `device_id` and `result`. Measurements contain
    `duration` (native time).
  - `[:edgehog, :containers, :container_deployment, :start]` when a container
    deployment orchestrator starts conducting a container deployment. Metadata
    contains `container_deployment_id`, `deployment_id` and `device_id`.
  - `[:edgehog, :containers, :container_deployment, :stop]` when a container
    deployment orchestrator terminates, either successfully or with a failure.
    Metadata contains `container_deployment_id`, `deployment_id`, `device_id`
    and `result`. Measurements contain `duration` (native time).
  """

  alias Edgehog.Config
  alias Edgehog.Containers.Deployment

  @provisioning_start [:edgehog, :containers, :provisioning, :start]
  @provisioning_stop [:edgehog, :containers, :provisioning, :stop]
  @deployment_start [:edgehog, :containers, :deployment, :start]
  @deployment_stop [:edgehog, :containers, :deployment, :stop]
  @container_deployment_start [:edgehog, :containers, :container_deployment, :start]
  @container_deployment_stop [:edgehog, :containers, :container_deployment, :stop]

  def provisioning_start_event, do: @provisioning_start

  def provisioning_stop_event, do: @provisioning_stop

  def deployment_start_event, do: @deployment_start

  def deployment_stop_event, do: @deployment_stop

  def container_deployment_start_event, do: @container_deployment_start

  def container_deployment_stop_event, do: @container_deployment_stop

  @doc """
  Emits a provisioning start event and returns the monotonic time the
  provisioning started, to be used when emitting the corresponding stop event.

  Returns the start time, computed with `System.monotonic_time/0`
  """
  def provisioning_started(resource, context) do
    start = System.monotonic_time()

    metadata =
      [started_at: start]
      |> Keyword.merge(base_metadata(resource, context))
      |> Map.new()

    :telemetry.execute(@provisioning_start, %{count: 1}, metadata)

    start
  end

  @doc """
  Emits a successful provisioning stop event.
  """
  def provisioning_completed(resource, context, started_at, retries, reason) do
    duration = System.monotonic_time() - started_at

    metadata =
      [
        result: :ok,
        reason: reason,
        duration: duration,
        duration_unit: :native
      ]
      |> Keyword.merge(base_metadata(resource, context))
      |> Map.new()

    :telemetry.execute(
      @provisioning_stop,
      %{count: 1, duration: duration, retries: retries},
      metadata
    )
  end

  @doc """
  Emits a failed provisioning stop event.
  """
  def provisioning_failed(resource, context, started_at, retries, reason) do
    duration = System.monotonic_time() - started_at

    metadata =
      [
        result: :error,
        reason: reason,
        duration: duration,
        duration_unit: :native
      ]
      |> Keyword.merge(base_metadata(resource, context))
      |> Map.new()

    :telemetry.execute(
      @provisioning_stop,
      %{count: 1, duration: duration, retries: retries},
      metadata
    )
  end

  @doc """
  Emits a deployment orchestration start event and returns the monotonic time
  the orchestration started, to be used when emitting the corresponding stop
  event.

  Returns the start time, computed with `System.monotonic_time/0`
  """
  def deployment_started(deployment) do
    start = System.monotonic_time()

    metadata =
      [started_at: start]
      |> Keyword.merge(deployment_metadata(deployment))
      |> Map.new()

    :telemetry.execute(@deployment_start, %{count: 1}, metadata)

    start
  end

  @doc """
  Emits a successful deployment orchestration stop event.
  """
  def deployment_completed(deployment, started_at) do
    duration = System.monotonic_time() - started_at

    metadata =
      [result: :ok, duration: duration, duration_unit: :native]
      |> Keyword.merge(deployment_metadata(deployment))
      |> Map.new()

    :telemetry.execute(@deployment_stop, %{count: 1, duration: duration}, metadata)
  end

  @doc """
  Emits a failed deployment orchestration stop event.
  """
  def deployment_failed(deployment, started_at) do
    duration = System.monotonic_time() - started_at

    metadata =
      [result: :error, duration: duration, duration_unit: :native]
      |> Keyword.merge(deployment_metadata(deployment))
      |> Map.new()

    :telemetry.execute(@deployment_stop, %{count: 1, duration: duration}, metadata)
  end

  @doc """
  Emits a container deployment orchestration start event and returns the
  monotonic time the orchestration started, to be used when emitting the
  corresponding stop event.

  Returns the start time, computed with `System.monotonic_time/0`
  """
  def container_deployment_started(container_deployment, deployment) do
    start = System.monotonic_time()

    metadata =
      [started_at: start]
      |> Keyword.merge(container_deployment_metadata(container_deployment, deployment))
      |> Map.new()

    :telemetry.execute(@container_deployment_start, %{count: 1}, metadata)

    start
  end

  @doc """
  Emits a successful container deployment orchestration stop event.
  """
  def container_deployment_completed(container_deployment, deployment, started_at) do
    duration = System.monotonic_time() - started_at

    metadata =
      [result: :ok, duration: duration, duration_unit: :native]
      |> Keyword.merge(container_deployment_metadata(container_deployment, deployment))
      |> Map.new()

    :telemetry.execute(@container_deployment_stop, %{count: 1, duration: duration}, metadata)
  end

  @doc """
  Emits a failed container deployment orchestration stop event.
  """
  def container_deployment_failed(container_deployment, deployment, started_at) do
    duration = System.monotonic_time() - started_at

    metadata =
      [result: :error, duration: duration, duration_unit: :native]
      |> Keyword.merge(container_deployment_metadata(container_deployment, deployment))
      |> Map.new()

    :telemetry.execute(@container_deployment_stop, %{count: 1, duration: duration}, metadata)
  end

  def resource_type(%module{}) do
    module
    |> Module.split()
    |> Enum.drop(2)
    |> Enum.map_join("_", &Macro.underscore/1)
  end

  def include_identifiers?, do: Config.containers_telemetry_include_identifiers!()

  defp base_metadata(resource, context) do
    resource_metadata(resource) ++ deployment_id_metadata(resource, context)
  end

  defp deployment_metadata(deployment) do
    identifiers =
      if include_identifiers?() do
        [
          deployment_id: Map.get(deployment, :id),
          device_id: Map.get(deployment, :device_id)
        ]
      else
        []
      end

    identifiers
  end

  defp container_deployment_metadata(container_deployment, deployment) do
    identifier =
      if include_identifiers?() do
        [container_deployment_id: Map.get(container_deployment, :id)]
      else
        []
      end

    identifier ++ deployment_metadata(deployment)
  end

  defp resource_metadata(resource) do
    resource_type = resource_type(resource)

    identifiers =
      if include_identifiers?() do
        [
          resource_id: Map.get(resource, :id),
          device_id: Map.get(resource, :device_id)
        ]
      else
        []
      end

    [resource_type: resource_type] ++ identifiers
  end

  defp deployment_id_metadata(%Deployment{id: id}, _context), do: [deployment_id: id]

  defp deployment_id_metadata(_resource, context) do
    case Keyword.get(context, :deployment) do
      %{id: deployment_id} -> [deployment_id: deployment_id]
      _ -> [deployment_id: nil]
    end
  end
end
