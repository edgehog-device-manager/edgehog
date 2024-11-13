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

defmodule Edgehog.Containers.Changes.CreateDefaultNetwork do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers.ContainerNetwork
  alias Edgehog.Containers.Network

  @impl Ash.Resource.Change
  def change(changeset, _opts, _ctx) do
    Ash.Changeset.after_action(changeset, fn _changeset, release ->
      with {:ok, release} <- Ash.load(release, :containers),
           {:ok, network} <- create_default_network(release.tenant_id),
           :ok <- create_networks(release, network) do
        {:ok, release}
      end
    end)
  end

  defp create_networks(release, network) do
    Enum.reduce_while(release.containers, :ok, fn container, _acc ->
      add_network(container, network)
    end)
  end

  defp create_default_network(tenant) do
    default_network_parameters = %{
      driver: "bridge",
      options: ["isolate=true"],
      internal: true,
      enable_ipv6: false
    }

    Network
    |> Ash.Changeset.for_create(:create, default_network_parameters)
    |> Ash.create(tenant: tenant)
  end

  defp add_network(container, network) do
    params = %{
      container_id: container.id,
      network_id: network.id
    }

    case Ash.create(ContainerNetwork, params, tenant: container.tenant_id) do
      {:ok, _device} -> {:cont, :ok}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end
end
