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

defmodule Edgehog.Containers.Network.Deployment.Provisioner.Core do
  @moduledoc """
  The module describing the Core functions required by the network deployment provisioner.

  For more information, check the `Edgehog.Containers.Provisioner.Core.Behaviour` docs.
  """
  use Edgehog.Containers.Provisioner.Core

  alias Edgehog.Astarte.Device.AvailableNetworks.NetworkStatus
  alias Edgehog.Devices

  require Logger

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def ready?(%{state: state}), do: state in [:available, :unavailable]

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def topic(%{id: id}), do: "ready:network_deployments:#{id}"
  def topic(id), do: "ready:network_deployments:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def subscribe_topic(%{id: id}), do: "network_deployments:#{id}"
  def subscribe_topic(id), do: "network_deployments:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def name(%{id: id}),
    do: {:via, Registry, {Edgehog.Containers.Network.Deployment.Provisioner.Registry, id}}

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def send_to_device(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    with {:ok, resource} <- Ash.load(resource, [:network, :device], tenant: tenant),
         {:ok, actual_resource} <- Map.fetch(resource, :network),
         {:ok, device} <- Map.fetch(resource, :device),
         {:ok, device} <-
           Devices.send_create_network_request(device, actual_resource, deployment,
             tenant: tenant
           ) do
      Logger.info("""
      Network #{actual_resource.id} provisioned on device #{device.device_id}. Waiting events
      """)

      :ok
    end
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def reconcile(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, resource} <-
           Ash.load(resource, [network: [], device: [:available_networks]], tenant: tenant),
         {:ok, actual_resource} <- Map.fetch(resource, :network),
         {:ok, device} <- Map.fetch(resource, :device),
         {:ok, available_resources} <- Map.fetch(device, :available_networks) do
      available_resources
      |> Enum.find(:not_found, &(&1.id == actual_resource.id))
      |> maybe_update(resource, tenant)
    end
  end

  defp maybe_update(%NetworkStatus{created: created}, resource, tenant) do
    action =
      if created,
        do: :mark_as_available,
        else: :mark_as_unavailable

    # NOTE: this will trigger a publish on the appropriate topic, the
    # provisioner will react to it.
    resource
    |> Ash.Changeset.for_update(action)
    |> Ash.update(tenant: tenant)
  end

  defp maybe_update(other, _resource, _tenant), do: other
end
