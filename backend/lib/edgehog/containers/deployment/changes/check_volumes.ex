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

defmodule Edgehog.Containers.Deployment.Changes.CheckVolumes do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    deployment = changeset.data

    with {:ok, :created_networks} <- Ash.Changeset.fetch_argument_or_change(changeset, :status),
         {:ok, deployment} <- Ash.load(deployment, device: [], release: [containers: [:volumes]]) do
      device = deployment.device

      deployments_ready? =
        deployment.release.containers
        |> Enum.flat_map(& &1.volumes)
        |> Enum.uniq_by(& &1.id)
        |> Enum.map(
          &Containers.fetch_volume_deployment!(&1.id, device.id,
            tenant: &1.tenant_id,
            load: [:ready?]
          )
        )
        |> Enum.all?(& &1.ready?)

      if deployments_ready?,
        do: Ash.Changeset.change_attribute(changeset, :status, :created_volumes),
        else: changeset
    else
      _ -> changeset
    end
  end
end
