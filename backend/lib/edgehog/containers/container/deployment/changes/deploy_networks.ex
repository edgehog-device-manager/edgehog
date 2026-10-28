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

defmodule Edgehog.Containers.Container.Deployment.Changes.DeployNetworks do
  @moduledoc """
  Deploys or reuses `Network.Deployment` records for each network attached to
  the container and relates `:network_deployments`.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    with true <- changeset.valid?,
         {:ok, container} <- Ash.Changeset.fetch_argument(changeset, :container),
         {:ok, device} <- Ash.Changeset.fetch_argument(changeset, :device),
         {:ok, container} <- Ash.load(container, [:networks], tenant: tenant) do
      inputs =
        Enum.map(container.networks || [], fn network ->
          %{
            network_id: network.id,
            device_id: device.id,
            network: network,
            device: device
          }
        end)

      Ash.Changeset.manage_relationship(changeset, :network_deployments, inputs,
        on_no_match: {:create, :deploy},
        on_match: :ignore,
        on_lookup: :relate,
        use_identities: [:network_instance]
      )
    else
      {:error, error} -> Ash.Changeset.add_error(changeset, error)
      _ -> changeset
    end
  end
end
