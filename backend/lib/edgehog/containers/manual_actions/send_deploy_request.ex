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

      with :ok <- deploy_images(device, images, deployment),
           :ok <- deploy_volumes(device, volumes, deployment),
           :ok <- deploy_networks(device, networks, deployment),
           :ok <- deploy_containers(device, containers, deployment),
           {:ok, _device} <- Devices.send_create_deployment_request(device, deployment) do
        Containers.mark_deployment_as_sent(deployment, tenant: tenant)
      end
    end
  end

  defp deploy_networks(device, networks, deployment) do
    networks =
      networks
      |> Enum.reject(&network_deployed?(&1, device))
      |> Enum.uniq_by(& &1.id)

    Enum.reduce_while(networks, :ok, fn network, _acc ->
      case Containers.deploy_network(network, device, deployment, tenant: network.tenant_id) do
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

  defp deploy_images(device, images, deployment) do
    images =
      images
      |> Enum.reject(&image_deployed?(&1, device))
      |> Enum.uniq_by(& &1.id)

    Enum.reduce_while(images, :ok, fn image, _acc ->
      case Containers.deploy_image(image, device, deployment, tenant: image.tenant_id) do
        {:ok, _image_deployment} ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp image_deployed?(image, device) do
    case Containers.fetch_image_deployment(image.id, device.id, tenant: image.tenant_id) do
      {:ok, _deployment} ->
        true

      _ ->
        false
    end
  end

  defp deploy_volumes(device, volumes, deployment) do
    volumes =
      volumes
      |> Enum.reject(&volume_deployed?(&1, device))
      |> Enum.uniq_by(& &1.id)

    Enum.reduce_while(volumes, :ok, fn volume, _acc ->
      case Containers.deploy_volume(volume, device, deployment, tenant: volume.tenant_id) do
        {:ok, _device} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp deploy_containers(device, containers, deployment) do
    containers =
      containers
      |> Enum.uniq_by(& &1.id)
      |> Enum.reject(&container_deployed?(&1, device))

    Enum.reduce_while(containers, :ok, fn container, _acc ->
      case Containers.deploy_container(container, device, deployment, tenant: container.tenant_id) do
        {:ok, _device} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp volume_deployed?(volume, device) do
    case Containers.fetch_volume_deployment(volume.id, device.id, tenant: volume.tenant_id) do
      {:ok, _deployment} -> true
      _ -> false
    end
  end

  defp container_deployed?(container, device) do
    case Containers.fetch_container_deployment(container.id, device.id, tenant: container.tenant_id) do
      {:ok, _container_deployment} -> true
      _ -> false
    end
  end
end
