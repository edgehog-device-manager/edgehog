#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Reconciler.Core do
  @moduledoc """
  Core component for the reconciler, provides `reconcile` function.
  """

  alias Edgehog.Containers
  alias Edgehog.Devices

  require Ash.Query
  require Logger

  @spec reconcile(%{device_id: integer(), tenant: Edgehog.Tenants.Tenant.t()}) ::
          :ok | {:error, term()}
  def reconcile(%{device_id: device_id, tenant: tenant}) do
    # We start each reconciliation in its own task not to disrupt others
    with {:ok, device} <- Devices.fetch_device(device_id, tenant: tenant, not_found_error?: true) do
      Task.start(fn -> reconcile_images(device, tenant) end)
      Task.start(fn -> reconcile_volumes(device, tenant) end)
      Task.start(fn -> reconcile_networks(device, tenant) end)
      Task.start(fn -> reconcile_containers(device, tenant) end)
      Task.start(fn -> reconcile_deployments(device, tenant) end)

      :ok
    end
  end

  @doc """
  Returns online the number of online devices and a stream that contains them.
  """
  def online_devices(tenant) do
    online_devices =
      Devices.Device
      |> Ash.Query.for_read(:read, %{})
      |> Ash.Query.filter(online: true)
      |> Ash.Query.sort(last_connection: :asc)
      |> Ash.stream!(tenant: tenant)

    online_devices_n =
      Devices.Device
      |> Ash.Query.filter(online: true)
      |> Ash.count(tenant: tenant)

    with {:ok, online_devices_n} <- online_devices_n,
         do: {online_devices_n, online_devices}
  end

  def reconcile_images(device, tenant) do
    available_images = device |> Ash.load!(:available_images) |> Map.get(:available_images, [])

    available_images
    |> Enum.map(&reconcile_image(&1, device, tenant))
    |> Enum.reject(&(&1 == :ok))
    |> Enum.each(&Logger.warning("Error while fetching image deployment: #{inspect(&1)}"))
  end

  def reconcile_volumes(device, tenant) do
    available_volumes = device |> Ash.load!(:available_volumes) |> Map.get(:available_volumes, [])

    available_volumes
    |> Enum.map(&reconcile_volume(&1, device, tenant))
    |> Enum.reject(&(&1 == :ok))
    |> Enum.each(&Logger.warning("Error while fetching volume deployment: #{inspect(&1)}"))
  end

  def reconcile_networks(device, tenant) do
    available_networks =
      device |> Ash.load!(:available_networks) |> Map.get(:available_networks, [])

    available_networks
    |> Enum.map(&reconcile_network(&1, device, tenant))
    |> Enum.reject(&(&1 == :ok))
    |> Enum.each(&Logger.warning("Error while fetching network deployment: #{inspect(&1)}"))
  end

  def reconcile_device_mappings(device, tenant) do
    available_device_mappings =
      device |> Ash.load!(:available_device_mappings) |> Map.get(:available_device_mappings, [])

    available_device_mappings
    |> Enum.map(&reconcile_device_mapping(&1, device, tenant))
    |> Enum.reject(&(&1 == :ok))
    |> Enum.each(&Logger.warning("Error while fetching device_mapping deployment: #{inspect(&1)}"))
  end

  def reconcile_containers(device, tenant) do
    available_containers =
      device |> Ash.load!(:available_containers) |> Map.get(:available_containers, [])

    available_containers
    |> Enum.map(&reconcile_container(&1, device, tenant))
    |> Enum.reject(&(&1 == :ok))
    |> Enum.each(&Logger.warning("Error while fetching container deployment: #{inspect(&1)}"))
  end

  def reconcile_deployments(device, tenant) do
    available_deployments =
      device |> Ash.load!(:available_deployments) |> Map.get(:available_deployments, [])

    available_deployments
    |> Enum.map(&reconcile_deployment(&1, device, tenant))
    |> Enum.reject(&(&1 == :ok))
    |> Enum.each(&Logger.warning("Error while fetching container deployment: #{inspect(&1)}"))
  end

  defp reconcile_image(image_desc, device, tenant) do
    res =
      Containers.fetch_image_deployment(image_desc.id, device.id, tenant: tenant, load: :state)

    with {:ok, image_deployment} <- res,
         :reconcile <- reconcile_image?(image_deployment.state, image_desc.pulled) do
      Logger.warning(
        "Reconciling image #{image_desc.id} on device #{device.device_id}." <>
          "state #{inspect(image_deployment.state)} inconsistent with property in astarte: #{inspect(image_desc.pulled)}"
      )

      marking =
        if image_desc.pulled,
          do: Containers.mark_image_deployment_as_pulled(image_deployment),
          else: Containers.mark_image_deployment_as_unpulled(image_deployment)

      with {:ok, _} <- marking, do: :ok
    end
  end

  defp reconcile_volume(volume_desc, device, tenant) do
    res =
      Containers.fetch_volume_deployment(volume_desc.id, device.id, tenant: tenant, load: :state)

    with {:ok, volume_deployment} <- res,
         :reconcile <- reconcile_volume?(volume_deployment.state, volume_desc.created) do
      Logger.warning(
        "Reconciling volume #{volume_desc.id} on device #{device.device_id}." <>
          "state #{inspect(volume_deployment.state)} inconsistent with property in astarte: #{inspect(volume_desc.created)}"
      )

      marking =
        if volume_desc.created,
          do: Containers.mark_volume_deployment_as_available(volume_deployment),
          else: Containers.mark_volume_deployment_as_unavailable(volume_deployment)

      with {:ok, _} <- marking, do: :ok
    end
  end

  defp reconcile_network(network_desc, device, tenant) do
    res =
      Containers.fetch_network_deployment(network_desc.id, device.id,
        tenant: tenant,
        load: :state
      )

    with {:ok, network_deployment} <- res,
         :reconcile <- reconcile_network?(network_deployment.state, network_desc.created) do
      Logger.warning(
        "Reconciling network #{network_desc.id} on device #{device.device_id}." <>
          "state #{inspect(network_deployment.state)} inconsistent with property in astarte: #{inspect(network_desc.created)}"
      )

      marking =
        if network_desc.created,
          do: Containers.mark_network_deployment_as_available(network_deployment),
          else: Containers.mark_network_deployment_as_unavailable(network_deployment)

      with {:ok, _} <- marking, do: :ok
    end
  end

  defp reconcile_device_mapping(device_mapping_desc, device, tenant) do
    res =
      Containers.fetch_device_mapping_deployment(device_mapping_desc.id, device.id,
        tenant: tenant,
        load: :state
      )

    with {:ok, device_mapping_deployment} <- res,
         :reconcile <-
           reconcile_device_mapping?(device_mapping_deployment.state, device_mapping_desc.present) do
      Logger.warning(
        "Reconciling device_mapping #{device_mapping_desc.id} on device #{device.device_id}." <>
          "state #{inspect(device_mapping_deployment.state)} inconsistent with property in astarte: #{inspect(device_mapping_desc.present)}"
      )

      marking =
        if device_mapping_desc.present,
          do: Containers.mark_device_mapping_deployment_as_present(device_mapping_deployment),
          else: Containers.mark_device_mapping_deployment_as_not_present(device_mapping_deployment)

      with {:ok, _} <- marking, do: :ok
    end
  end

  defp reconcile_container(container_desc, device, tenant) do
    res =
      Containers.fetch_container_deployment(container_desc.id, device.id,
        tenant: tenant,
        load: :state
      )

    with {:ok, container_deployment} <- res,
         :reconcile <- reconcile_container?(container_deployment.state, container_desc.status) do
      Logger.warning(
        "Reconciling container #{container_desc.id} on device #{device.device_id}." <>
          "state #{inspect(container_deployment.state)} inconsistent with property in astarte: #{inspect(container_desc.status)}"
      )

      marking =
        case container_desc.status do
          "Received" ->
            Containers.mark_container_deployment_as_received(container_deployment, tenant: tenant)

          "Created" ->
            Containers.mark_container_deployment_as_created(container_deployment, tenant: tenant)

          "Running" ->
            Containers.mark_container_deployment_as_running(container_deployment, tenant: tenant)

          "Stopped" ->
            Containers.mark_container_deployment_as_stopped(container_deployment, tenant: tenant)
        end

      with {:ok, _} <- marking, do: :ok
    end
  end

  defp reconcile_deployment(desc, device, tenant) do
    res =
      Containers.fetch_deployment(desc.id, tenant: tenant, load: :state)

    with {:ok, deployment} <- res,
         :reconcile <- reconcile_deployment?(deployment.state, desc.status) do
      Logger.warning(
        "Reconciling deployment #{desc.id} on device #{device.device_id}." <>
          "state #{inspect(deployment.state)} inconsistent with property in astarte: #{inspect(desc.status)}"
      )

      marking =
        deployment
        |> Ash.Changeset.for_update(:set_state, %{state: desc.status})
        |> Ash.update(tenant: tenant)

      with {:ok, _} <- marking, do: :ok
    end
  end

  defp reconcile_image?(:unpulled, false), do: :ok
  defp reconcile_image?(:pulled, true), do: :ok
  defp reconcile_image?(_, _), do: :reconcile

  defp reconcile_volume?(:unavailable, false), do: :ok
  defp reconcile_volume?(:available, true), do: :ok
  defp reconcile_volume?(_, _), do: :reconcile

  defp reconcile_network?(:unavailable, false), do: :ok
  defp reconcile_network?(:available, true), do: :ok
  defp reconcile_network?(_, _), do: :reconcile

  defp reconcile_device_mapping?(:not_present, false), do: :ok
  defp reconcile_device_mapping?(:present, true), do: :ok
  defp reconcile_device_mapping?(_, _), do: :reconcile

  defp reconcile_container?(state, status) do
    case {state, status} do
      {:received, "Received"} -> :ok
      {:device_created, "Created"} -> :ok
      {:stopped, "Stopped"} -> :ok
      {:running, "Running"} -> :ok
      _ -> :reconcile
    end
  end

  defp reconcile_deployment?(state, status) do
    case {state, status} do
      {:started, "Started"} -> :ok
      {:stopped, "Stopped"} -> :ok
      _ -> :reconcile
    end
  end
end
