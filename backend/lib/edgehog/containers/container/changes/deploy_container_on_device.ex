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

defmodule Edgehog.Containers.Container.Changes.DeployContainerOnDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers
  alias Edgehog.Devices

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    Ash.Changeset.after_action(changeset, &send_deployment(&1, &2, tenant))
  end

  defp send_deployment(changeset, container_deployment, tenant) do
    deployment = Ash.Changeset.get_argument(changeset, :deployment)

    with {:ok, container_deployment} <-
           Ash.load(container_deployment, [
             :image_deployment,
             :volume_deployments,
             :network_deployments,
             :device_mapping_deployments,
             :device,
             :container,
             :state
           ]) do
      image_deployment = container_deployment.image_deployment
      volume_deployments = container_deployment.volume_deployments
      network_deployments = container_deployment.network_deployments
      device_mapping_deployments = container_deployment.device_mapping_deployments

      resources = [
        image_deployment | volume_deployments ++ network_deployments ++ device_mapping_deployments
      ]

      Enum.each(resources, &deploy_resource(&1, deployment, tenant))

      with {:ok, _device} <-
             Devices.send_create_container_request(
               container_deployment.device,
               container_deployment.container,
               deployment,
               tenant: tenant
             ),
           do: maybe_update_state(container_deployment, tenant)
    end
  end

  defp deploy_resource(res, deployment, tenant) do
    res
    |> Ash.Changeset.for_update(:send_deployment, %{deployment: deployment}, tenant: tenant)
    |> Ash.update(tenant: tenant)
  end

  defp maybe_update_state(container_deployment, tenant) do
    case container_deployment.state do
      :created ->
        Containers.mark_container_deployment_as_sent(container_deployment, tenant: tenant)

      _others ->
        {:ok, container_deployment}
    end
  end
end
