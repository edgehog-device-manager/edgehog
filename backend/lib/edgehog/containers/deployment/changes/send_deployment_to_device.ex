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

defmodule Edgehog.Containers.Deployment.Changes.SendDeploymentToDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Devices

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    Ash.Changeset.after_action(changeset, &after_action(&1, &2, tenant))
  end

  defp after_action(_changeset, deployment, tenant) do
    with {:ok, deployment} <-
           Ash.load(deployment, [:container_deployments, :device], tenant: tenant) do
      container_deployments = deployment.container_deployments

      Enum.each(container_deployments, &deploy_container(&1, deployment, tenant))

      with {:ok, _device} <-
             Devices.send_create_deployment_request(deployment.device, deployment, tenant: tenant),
           do: {:ok, deployment}
    end
  end

  defp deploy_container(container_deployment, deployment, tenant) do
    container_deployment
    |> Ash.Changeset.for_update(:send_deployment, %{deployment: deployment}, tenant: tenant)
    |> Ash.update(tenant: tenant)
  end
end
