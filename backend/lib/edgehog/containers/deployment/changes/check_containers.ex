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

defmodule Edgehog.Containers.Deployment.Changes.CheckContainers do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Devices

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    %{tenant: tenant} = context
    deployment = changeset.data

    with {:ok, :created_networks} <- Ash.Changeset.fetch_argument_or_change(changeset, :status),
         {:ok, deployment} <-
           Ash.load(deployment, [:device, release: [:containers]], reuse_values?: true),
         {:ok, available_containers} <-
           Devices.available_containers(deployment.device, tenant: tenant) do
      available_containers = Enum.map(available_containers, & &1.id)

      missing_containers =
        Enum.reject(deployment.release.containers, &(&1.id in available_containers))

      if missing_containers == [] do
        Ash.Changeset.change_attribute(changeset, :status, :created_containers)
      else
        changeset
      end
    else
      _ -> changeset
    end
  end
end
