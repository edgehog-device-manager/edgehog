#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Containers.Container.Changes.DeployContainerOnDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers
  alias Edgehog.Devices

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    %{tenant: tenant} = context

    Ash.Changeset.after_action(changeset, fn _changeset, deployment ->
      with {:ok, deployment} <-
             Ash.load(deployment, device: [], container: [:image, :networks, :volumes]),
           {:ok, _image_deployment} <- deploy_image(deployment, tenant),
           :ok <- deploy_networks(deployment, tenant),
           :ok <- deploy_volumes(deployment, tenant),
           {:ok, _device} <-
             Devices.send_create_container_request(deployment.device, deployment.contianer, tenant: tenant) do
        {:ok, deployment}
      end
    end)
  end

  def deploy_image(deployment, tenant) do
    image = deployment.image
    Containers.deploy_image(image, tenant)
  end

  def deploy_networks(deployment, tenant) do
    networks = deployment.container.networks
    device = deployment.device

    Enum.reduce_while(networks, :ok, fn network, _acc ->
      case Containers.deploy_network(network.id, device.id, tenant: tenant) do
        {:ok, _network_deployment} -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  def deploy_volumes(deployment, tenant) do
    volumes = deployment.container.volumes
    device = deployment.device

    Enum.reduce_while(volumes, :ok, fn volume, _acc ->
      case Containers.deploy_volume(volume.id, device.id, tenant: tenant) do
        {:ok, _volume_deployment} -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end
end
