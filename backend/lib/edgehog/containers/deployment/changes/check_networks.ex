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

defmodule Edgehog.Containers.Deployment.Changes.CheckNetworks do
  @moduledoc false
  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    deployment = changeset.data

    with {:ok, :created_images} <- Ash.Changeset.fetch_argument_or_change(changeset, :status),
         {:ok, deployment} <-
           Ash.load(deployment,
             device: :available_networks,
             release: [:release_networks, :containers]
           ) do
      available_network_ids =
        Enum.map(deployment.device.available_networks, & &1.id)

      missing_networks =
        deployment.release.release_networks
        |> Enum.map(& &1.network_id)
        |> Enum.reject(&(&1 in available_network_ids))

      if missing_networks == [] do
        Ash.Changeset.change_attribute(changeset, :status, :created_networks)
      else
        changeset
      end
    else
      _ -> changeset
    end
  end
end
