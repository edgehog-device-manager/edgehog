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

defmodule Edgehog.Containers.Deployment.Changes.SendUpgrade do
  @moduledoc """
  A change to upgrade the deployment of an application to a newer version.

  This ensures that the communication with the device happens only when the
  database has been updated with relevant information _and_ in case of success
  """
  use Ash.Resource.Change
  alias Edgehog.Containers.DeploymentReadyAction

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &send_upgrade/2)
  end

  defp send_upgrade(changeset, deployment) do
    tenant = changeset.tenant
    device_id = deployment.device_id
    # SAFETY: we have validated the parameter in the validations, so it must exist.
    target_id = Ash.Changeset.get_argument(changeset, :target)

    with {:ok, action} <-
           DeploymentReadyAction
           |> Ash.Changeset.for_create(
             :create_deployment,
             %{
               deployment: %{device_id: device_id, release_id: target_id},
               action_type: :upgrade_deployment,
               action_arguments: %{upgrade_target_id: deployment.id}
             }
           )
           |> Ash.create(tenant: tenant) do
      {:ok, action.deployment}
    end
  end
end
