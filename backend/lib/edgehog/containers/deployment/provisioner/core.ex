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

defmodule Edgehog.Containers.Deployment.Provisioner.Core do
  @moduledoc """
  The module describing the Core functions required by the deployment provisioner.

  For more information, check the `Edgehog.Containers.Provisioner.Core.Behaviour` docs.
  """
  use Edgehog.Containers.Provisioner.Core

  alias Edgehog.Astarte.Device.AvailableDeployments.DeploymentStatus
  alias Edgehog.Devices

  require Logger

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def ready?(%{state: state}), do: state in [:started, :stopped]

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def topic(%{id: id}), do: "deployments:provisioning:#{id}"
  def topic(id), do: "deployments:provisioning:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def subscribe_topic(%{id: id}), do: "deployments:#{id}"
  def subscribe_topic(id), do: "deployments:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def name(%{id: id}),
    do: {:via, Registry, {Edgehog.Containers.Deployment.Provisioner.Registry, id}}

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def send_to_device(deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, deployment} <- Ash.load(deployment, :device, tenant: tenant),
         device = deployment.device,
         {:ok, device} <-
           Devices.send_create_deployment_request(device, deployment, tenant: tenant) do
      deployment
      |> Ash.Changeset.for_update(:mark_as_sent, %{}, tenant: tenant)
      |> Ash.update!()

      Logger.info("""
      Deployment #{deployment.id} provisioned on device #{device.device_id}. Waiting events
      """)

      :ok
    end
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def reconcile(deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, deployment} <-
           Ash.load(deployment, [device: [:available_deployments]], tenant: tenant),
         {:ok, device} <- Map.fetch(deployment, :device),
         {:ok, available_deployments} <- Map.fetch(device, :available_deployments) do
      available_deployments
      |> Enum.find(:not_found, &(&1.id == deployment.id))
      |> maybe_update(deployment, tenant)
    end
  end

  def maybe_update(%DeploymentStatus{status: status}, deployment, tenant) do
    # NOTE: this will trigger a publish on the appropriate topic, the
    # provisioner will react to it.

    action =
      case status do
        :started -> :mark_as_started
        :stopped -> :mark_as_stopped
      end

    deployment
    |> Ash.Changeset.for_update(action)
    |> Ash.update(tenant: tenant)
  end

  def maybe_update(other, _deployment, _tenant), do: other
end
