#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.ManualActions.SendDeployRequest do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias Edgehog.Containers
  alias Edgehog.Devices

  @impl Ash.Resource.Actions.Implementation
  def run(input, _opts, context) do
    deployment = input.arguments.deployment
    %{tenant: tenant} = context

    with {:ok, deployment} <-
           Ash.load(deployment, device: [], release: [containers: [:image, :networks, :volumes]]) do
      device = deployment.device

      release = deployment.release
      containers = release.containers
      images = containers |> Enum.map(& &1.image) |> Enum.uniq()

      networks =
        containers
        |> Enum.flat_map(& &1.networks)
        |> Enum.uniq_by(& &1.id)

      volumes =
        containers
        |> Enum.flat_map(& &1.volumes)
        |> Enum.uniq_by(& &1.id)

      with :ok <- send_create_image_requests(device, images),
           :ok <- send_create_volume_requests(device, volumes),
           :ok <- send_create_container_requests(device, containers),
           :ok <- deploy_networks(device, networks),
           {:ok, _device} <- Devices.send_create_deployment_request(device, deployment) do
        Containers.deployment_set_status(deployment, :sent, nil, tenant: tenant)
      end
    end
  end

  defp deploy_networks(device, networks) do
    networks =
      networks
      |> Enum.reject(&network_deployed?(&1, device))
      |> Enum.uniq_by(& &1.id)

    Enum.reduce_while(networks, :ok, fn network, _acc ->
      case Containers.deploy_network(network, device, tenant: network.tenant_id) do
        {:ok, _network_deployment} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp network_deployed?(network, device) do
    case Containers.fetch_network_deployment(network.id, device.id, tenant: network.tenant_id) do
      {:ok, _network_deployment} -> true
      _ -> false
    end
  end

  defp send_create_image_requests(device, images) do
    Enum.reduce_while(images, :ok, fn image, _acc ->
      case Devices.send_create_image_request(device, image) do
        {:ok, _device} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp send_create_volume_requests(device, volumes) do
    Enum.reduce_while(volumes, :ok, fn volume, _acc ->
      case Devices.send_create_volume_request(device, volume) do
        {:ok, _device} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp send_create_container_requests(device, containers) do
    Enum.reduce_while(containers, :ok, fn container, _acc ->
      case Devices.send_create_container_request(device, container) do
        {:ok, _device} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
