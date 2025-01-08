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

defmodule Edgehog.Containers.ManualActions.SendDeploymentUpgrade do
  @moduledoc false

  use Ash.Resource.ManualUpdate

  alias Edgehog.Containers.DeploymentReadyAction

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    tenant = changeset.tenant
    device_id = Ash.Changeset.get_data(changeset, :device_id)
    # SAFETY: we have validated the parameter in the validations, so it must exist.
    target_id = Ash.Changeset.get_argument(changeset, :target)

    with {:ok, action} <-
           DeploymentReadyAction
           |> Ash.Changeset.for_create(
             :create_deployment,
             %{
               deployment: %{device_id: device_id, release_id: target_id},
               action_type: :upgrade_deployment,
               action_arguments: %{upgrade_target_id: Ash.Changeset.get_data(changeset, :id)}
             }
           )
           |> Ash.create(tenant: tenant) do
      {:ok, action.deployment}
    end
  end
end