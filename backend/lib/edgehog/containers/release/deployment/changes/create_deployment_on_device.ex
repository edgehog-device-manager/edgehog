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

defmodule Edgehog.Containers.Release.Deployment.Changes.CreateDeploymentOnDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers
  alias Edgehog.Devices

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    %{tenant: tenant} = context

    Ash.Changeset.after_action(changeset, fn _changeset, deployment ->
      with {:ok, deployment} <-
             Ash.load(deployment, [:device, release: [containers: [:networks]]]),
           :ok <- deploy_containers(deployment, tenant),
           {:ok, _device} <- Devices.send_create_deployment_request(deployment.device, deployment) do
        {:ok, deployment}
      end
    end)
  end

  def deploy_containers(deployment, tenant) do
    containers = dbg(deployment.release.containers)
    device = deployment.device

    Enum.reduce_while(containers, :ok, fn container, _acc ->
      case Containers.deploy_container(container.id, device.id, tenant: tenant) do
        {:ok, _container_deployment} -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end
end
